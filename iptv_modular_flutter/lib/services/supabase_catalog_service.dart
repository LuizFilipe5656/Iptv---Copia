import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/addon.dart';
import '../models/movie.dart';
import '../models/stremio_meta_item.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../config/supabase_config.dart';

/// Serviço para sincronizar catálogos de todos os addons com o Supabase
/// Salva de qual addon veio cada informação para rastreamento
class SupabaseCatalogService {
  SupabaseCatalogService({
    required AddonRepository addonRepository,
    required CatalogRepository catalogRepository,
  })  : _addonRepository = addonRepository,
        _catalogRepository = catalogRepository;

  final AddonRepository _addonRepository;
  final CatalogRepository _catalogRepository;

  final SupabaseClient _client = Supabase.instance.client;

  /// Sincroniza catálogos de TODOS os addons instalados com o Supabase
  /// - Para cada addon, busca todos os catálogos disponíveis
  /// - Faz merge de filmes e séries, removendo duplicatas
  /// - Salva no Supabase com rastreamento de origem (addon)
  Future<CatalogSyncResult> syncCatalogsFromAllAddons({
    int batchSize = 50,
    VoidCallback? onProgress,
  }) async {
    debugPrint('[supabase-catalog] Starting full catalog sync from all addons');

    final addons = await _addonRepository.getInstalledAddons();
    debugPrint('[supabase-catalog] Found ${addons.length} installed addons');

    final allMovies = <String, Movie>{};
    final allSeries = <String, Movie>{};
    final addonSources = <String, Set<String>>{}; // contentId -> addonIds

    // Processa cada addon
    for (final addon in addons) {
      debugPrint('[supabase-catalog] Processing addon: ${addon.name} (${addon.id})');

      try {
        final manifest = await _addonRepository.getManifest(addon);
        final catalogs = manifest.catalogs;

        debugPrint('[supabase-catalog] ${addon.name}: Found ${catalogs.length} catalogs');

        // Processa cada catálogo do addon
        for (final catalog in catalogs) {
          if (catalog.extra.any((extra) => extra.isRequired)) {
            debugPrint('[supabase-catalog] Skipping ${catalog.name}: has required filters');
            continue;
          }

          try {
            final items = await _catalogRepository.getCatalog(
              addon: addon,
              catalog: catalog,
              extra: const {},
            );

            debugPrint('[supabase-catalog] ${addon.name}/${catalog.name}: ${items.length} items');

            // Separa filmes e séries
            for (final item in items) {
              final contentId = item.id;
              final movie = _itemToMovie(item, catalog.type);

              // Rastreia origem
              addonSources.putIfAbsent(contentId, () => <String>{});
              addonSources[contentId]!.add(addon.id);

              // Adiciona ao mapa apropriado
              if (catalog.type == 'movie' || catalog.type == 'movies') {
                allMovies[contentId] = movie;
              } else {
                allSeries[contentId] = movie;
              }
            }

            if (onProgress != null) {
              onProgress();
            }
          } catch (error) {
            debugPrint('[supabase-catalog] ${addon.name}/${catalog.name} failed: $error');
          }
        }
      } catch (error) {
        debugPrint('[supabase-catalog] ${addon.name} failed completely: $error');
      }
    }

    debugPrint('[supabase-catalog] Total unique movies: ${allMovies.length}');
    debugPrint('[supabase-catalog] Total unique series: ${allSeries.length}');

    // Sincroniza com Supabase em batches
    final movieResult = await _syncMovies(
      allMovies.values.toList(),
      addonSources,
      batchSize: batchSize,
    );

    final seriesResult = await _syncSeries(
      allSeries.values.toList(),
      addonSources,
      batchSize: batchSize,
    );

    final result = CatalogSyncResult(
      moviesProcessed: movieResult.processed,
      moviesAdded: movieResult.added,
      moviesUpdated: movieResult.updated,
      seriesProcessed: seriesResult.processed,
      seriesAdded: seriesResult.added,
      seriesUpdated: seriesResult.updated,
      addonSources: addonSources,
    );

    debugPrint('[supabase-catalog] Sync complete:');
    debugPrint('[supabase-catalog] - Movies: ${result.moviesProcessed} processed, ${result.moviesAdded} added, ${result.moviesUpdated} updated');
    debugPrint('[supabase-catalog] - Series: ${result.seriesProcessed} processed, ${result.seriesAdded} added, ${result.seriesUpdated} updated');

    return result;
  }

  /// Sincroniza apenas os catálogos de um addon específico
  Future<CatalogSyncResult> syncAddonCatalogs(
    Addon addon, {
    int batchSize = 50,
  }) async {
    debugPrint('[supabase-catalog] Syncing catalogs for addon: ${addon.name}');

    final allMovies = <String, Movie>{};
    final allSeries = <String, Movie>{};
    final addonSources = <String, Set<String>>{};

    try {
      final manifest = await _addonRepository.getManifest(addon);
      final catalogs = manifest.catalogs;

      for (final catalog in catalogs) {
        if (catalog.extra.any((extra) => extra.isRequired)) {
          continue;
        }

        try {
          final items = await _catalogRepository.getCatalog(
            addon: addon,
            catalog: catalog,
            extra: const {},
          );

          for (final item in items) {
            final contentId = item.id;
            final movie = _itemToMovie(item, catalog.type);

            addonSources.putIfAbsent(contentId, () => <String>{});
            addonSources[contentId]!.add(addon.id);

            if (catalog.type == 'movie' || catalog.type == 'movies') {
              allMovies[contentId] = movie;
            } else {
              allSeries[contentId] = movie;
            }
          }
        } catch (error) {
          debugPrint('[supabase-catalog] ${addon.name}/${catalog.name} failed: $error');
        }
      }
    } catch (error) {
      debugPrint('[supabase-catalog] ${addon.name} failed: $error');
    }

    final movieResult = await _syncMovies(
      allMovies.values.toList(),
      addonSources,
      batchSize: batchSize,
    );

    final seriesResult = await _syncSeries(
      allSeries.values.toList(),
      addonSources,
      batchSize: batchSize,
    );

    return CatalogSyncResult(
      moviesProcessed: movieResult.processed,
      moviesAdded: movieResult.added,
      moviesUpdated: movieResult.updated,
      seriesProcessed: seriesResult.processed,
      seriesAdded: seriesResult.added,
      seriesUpdated: seriesResult.updated,
      addonSources: addonSources,
    );
  }

  /// Sincroniza filmes com o Supabase
  Future<_SyncResult> _syncMovies(
    List<Movie> movies,
    Map<String, Set<String>> addonSources, {
    required int batchSize,
  }) async {
    var processed = 0;
    var added = 0;
    var updated = 0;

    for (var i = 0; i < movies.length; i += batchSize) {
      final batch = movies.skip(i).take(batchSize).toList();

      for (final movie in batch) {
        try {
          final contentId = movie.imdbId ?? movie.id;
          final sources = addonSources[contentId] ?? {};

          // Verifica se já existe
          final existing = await _client
              .from('movies')
              .select('id')
              .eq('content_id', contentId)
              .maybeSingle();

          final movieData = {
            'content_id': contentId,
            'imdb_id': movie.imdbId,
            'title': movie.title,
            'type': 'movie',
            'overview': movie.overview,
            'poster_url': movie.posterUrl,
            'banner_url': movie.bannerUrl,
            'imdb_rating': movie.imdbRating,
            'release_year': movie.releaseYear,
            'genres': movie.genres,
            'addon_sources': sources.toList(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          if (existing == null) {
            // Insert
            await _client.from('movies').insert({
              ...movieData,
              'created_at': DateTime.now().toIso8601String(),
            });
            added++;
          } else {
            // Update
            await _client
                .from('movies')
                .update(movieData)
                .eq('content_id', contentId);
            updated++;
          }

          processed++;
        } catch (error) {
          debugPrint('[supabase-catalog] Failed to sync movie ${movie.title}: $error');
        }
      }
    }

    return _SyncResult(
      processed: processed,
      added: added,
      updated: updated,
    );
  }

  /// Sincroniza séries com o Supabase
  Future<_SyncResult> _syncSeries(
    List<Movie> series,
    Map<String, Set<String>> addonSources, {
    required int batchSize,
  }) async {
    var processed = 0;
    var added = 0;
    var updated = 0;

    for (var i = 0; i < series.length; i += batchSize) {
      final batch = series.skip(i).take(batchSize).toList();

      for (final serie in batch) {
        try {
          final contentId = serie.imdbId ?? serie.id;
          final sources = addonSources[contentId] ?? {};

          // Verifica se já existe
          final existing = await _client
              .from('series')
              .select('id')
              .eq('content_id', contentId)
              .maybeSingle();

          final seriesData = {
            'content_id': contentId,
            'imdb_id': serie.imdbId,
            'title': serie.title,
            'type': serie.type,
            'overview': serie.overview,
            'poster_url': serie.posterUrl,
            'banner_url': serie.bannerUrl,
            'imdb_rating': serie.imdbRating,
            'release_year': serie.releaseYear,
            'genres': serie.genres,
            'addon_sources': sources.toList(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          if (existing == null) {
            // Insert
            await _client.from('series').insert({
              ...seriesData,
              'created_at': DateTime.now().toIso8601String(),
            });
            added++;
          } else {
            // Update
            await _client
                .from('series')
                .update(seriesData)
                .eq('content_id', contentId);
            updated++;
          }

          processed++;
        } catch (error) {
          debugPrint('[supabase-catalog] Failed to sync series ${serie.title}: $error');
        }
      }
    }

    return _SyncResult(
      processed: processed,
      added: added,
      updated: updated,
    );
  }

  /// Busca todos os filmes do Supabase
  Future<List<Movie>> fetchAllMovies() async {
    try {
      final response = await _client
          .from('movies')
          .select()
          .order('updated_at', ascending: false);

      if (response == null) return [];

      return (response as List)
          .map((json) => _supabaseJsonToMovie(json as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('[supabase-catalog] Failed to fetch movies: $error');
      return [];
    }
  }

  /// Busca todas as séries do Supabase
  Future<List<Movie>> fetchAllSeries() async {
    try {
      final response = await _client
          .from('series')
          .select()
          .order('updated_at', ascending: false);

      if (response == null) return [];

      return (response as List)
          .map((json) => _supabaseJsonToMovie(json as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('[supabase-catalog] Failed to fetch series: $error');
      return [];
    }
  }

  /// Busca filme por content_id ou imdb_id
  Future<Movie?> fetchMovie(String id) async {
    try {
      final response = await _client
          .from('movies')
          .select()
          .or('content_id.eq.$id,imdb_id.eq.$id')
          .maybeSingle();

      if (response == null) return null;

      return _supabaseJsonToMovie(response as Map<String, dynamic>);
    } catch (error) {
      debugPrint('[supabase-catalog] Failed to fetch movie: $error');
      return null;
    }
  }

  /// Busca série por content_id ou imdb_id
  Future<Movie?> fetchSeries(String id) async {
    try {
      final response = await _client
          .from('series')
          .select()
          .or('content_id.eq.$id,imdb_id.eq.$id')
          .maybeSingle();

      if (response == null) return null;

      return _supabaseJsonToMovie(response as Map<String, dynamic>);
    } catch (error) {
      debugPrint('[supabase-catalog] Failed to fetch series: $error');
      return null;
    }
  }

  Movie _itemToMovie(StremioMetaItem item, String type) {
    return Movie(
      id: item.id,
      imdbId: item.id.split(':').first,
      title: item.name,
      type: type,
      overview: item.description,
      posterUrl: item.poster,
      bannerUrl: item.background,
      imdbRating: double.tryParse(item.imdbRating),
      releaseYear: _year(item.releaseInfo),
      genres: item.genres,
    );
  }

  Movie _supabaseJsonToMovie(Map<String, dynamic> json) {
    return Movie(
      id: json['content_id'] ?? json['imdb_id'] ?? '',
      imdbId: json['imdb_id'],
      title: json['title'] ?? '',
      type: json['type'] ?? 'movie',
      overview: json['overview'] ?? '',
      posterUrl: json['poster_url'],
      bannerUrl: json['banner_url'],
      imdbRating: json['imdb_rating']?.toDouble(),
      releaseYear: json['release_year']?.toInt(),
      genres: (json['genres'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  int? _year(String? value) {
    if (value == null) return null;
    return int.tryParse(RegExp(r'\d{4}').firstMatch(value)?.group(0) ?? '');
  }
}

/// Resultado da sincronização de catálogos
class CatalogSyncResult {
  const CatalogSyncResult({
    required this.moviesProcessed,
    required this.moviesAdded,
    required this.moviesUpdated,
    required this.seriesProcessed,
    required this.seriesAdded,
    required this.seriesUpdated,
    required this.addonSources,
  });

  final int moviesProcessed;
  final int moviesAdded;
  final int moviesUpdated;
  final int seriesProcessed;
  final int seriesAdded;
  final int seriesUpdated;
  final Map<String, Set<String>> addonSources;

  int get totalProcessed => moviesProcessed + seriesProcessed;
  int get totalAdded => moviesAdded + seriesAdded;
  int get totalUpdated => moviesUpdated + seriesUpdated;
}

class _SyncResult {
  const _SyncResult({
    required this.processed,
    required this.added,
    required this.updated,
  });

  final int processed;
  final int added;
  final int updated;
}

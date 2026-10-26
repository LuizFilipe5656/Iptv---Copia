import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/addon.dart';
import '../models/movie.dart';
import '../models/stremio_addon_manifest.dart';
import '../models/stremio_meta_item.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import 'cinemeta_service.dart';
import 'multi_addon_metadata_service.dart';


class SeriesMetadataService {
  SeriesMetadataService({
    required AddonRepository addonRepository,
    required CatalogRepository catalogRepository,
    http.Client? client,
    bool useMultiAddonAggregator = true,
  })  : _addonRepository = addonRepository,
        _catalogRepository = catalogRepository,
        _client = client,
        _useMultiAddonAggregator = useMultiAddonAggregator;

  final AddonRepository _addonRepository;
  final CatalogRepository _catalogRepository;
  final http.Client? _client;
  final bool _useMultiAddonAggregator;

  late final MultiAddonMetadataService _multiAddonService =
      MultiAddonMetadataService(
    addonRepository: _addonRepository,
    catalogRepository: _catalogRepository,
    client: _client,
  );


  Future<SeriesMetadata> load({
    required Movie series,
    required String type,
    SeriesMetadata? fallback,
  }) async {
    // Usa o novo aggregator multi-addon se ativado
    if (_useMultiAddonAggregator) {
      debugPrint('[series] Using MultiAddonMetadataService aggregator');
      return await _multiAddonService.fetchSeriesMetadata(
        series: series,
        type: type,
        fallback: fallback,
      );
    }

    // Mantém o comportamento legado se o aggregator estiver desativado
    debugPrint('[series] Using legacy single-addon approach');
    return await _loadLegacy(series, type, fallback);
  }

  /// Método legado para compatibilidade
  Future<SeriesMetadata> _loadLegacy(
    Movie series,
    String type,
    SeriesMetadata? fallback,
  ) async {
    var contentId = series.imdbId ?? series.id;
    debugPrint('[series] Conteúdo: ${series.title}');
    debugPrint('[series] Tipo: $type');
    debugPrint('[series] Meta ID recebido: $contentId');

    if (!contentId.startsWith('tt')) {
      try {
        final cinemeta = CinemetaService();
        final searchResults = await cinemeta.searchSeries(series.title);
        if (searchResults.isNotEmpty) {
          final bestMatch = searchResults.first;
          contentId = bestMatch.imdbId ?? bestMatch.id;
          debugPrint('[series] Resolved IMDb ID via Cinemeta search: $contentId');
        }
        cinemeta.close();
      } catch (e) {
        debugPrint('[series] Cinemeta search resolution failed: $e');
      }
    }

    final episodesByNumber = <String, SeriesEpisode>{};
    if (fallback != null) {
      for (final episode in fallback.episodes) {
        _mergeEpisode(episodesByNumber, episode);
      }
    }

    try {
      final cinemeta = CinemetaService();
      final cinemetaMeta = await cinemeta.seriesMetadata(contentId);
      if (cinemetaMeta != null) {
        for (final episode in cinemetaMeta.episodes) {
          _mergeEpisode(episodesByNumber, episode);
        }
        debugPrint('[series] Provider utilizado: Cinemeta');
      }
      cinemeta.close();
    } catch (e) {
      debugPrint('[series] Cinemeta seriesMetadata failed: $e');
    }

    final addons = (await _addonRepository.getContentMetadataProviders())
        .where((addon) => addon.id != 'cinemeta')
        .toList(growable: false);

    final providerResults = await Future.wait(
      addons.map(
        (addon) => _loadFromAddon(
          addon: addon,
          series: series,
          contentId: contentId,
          type: type,
        ),
      ),
    );

    for (final episode in providerResults.expand((result) => result)) {
      _mergeEpisode(episodesByNumber, episode);
    }

    if (episodesByNumber.isEmpty) {
      debugPrint('[series] Addon/Cinemeta episodes empty, falling back to TVMaze for "${series.title}"');
      final fallbackEpisodes = await _loadFromTvMaze(series, contentId);
      for (final episode in fallbackEpisodes) {
        _mergeEpisode(episodesByNumber, episode);
      }
    }

    final metadata = SeriesMetadata(
      series: fallback?.series ?? series,
      episodes: List.unmodifiable(episodesByNumber.values),
    );

    debugPrint('[series] Provider utilizado: Addons / TVMaze / Cinemeta');
    debugPrint('[series] Quantidade de temporadas encontradas: ${metadata.seasons.length}');
    debugPrint('[series] Quantidade de episódios encontrados: ${metadata.episodes.length}');

    return metadata;
  }

  Future<List<SeriesEpisode>> _loadFromTvMaze(
    Movie series,
    String contentId,
  ) async {
    final client = _client ?? http.Client();
    try {
      final show = await _findTvMazeShow(client, series, contentId);
      if (show == null || show['id'] is! num) {
        debugPrint(
          '[series] TVMaze show not found for "${series.title}" '
          '(id=$contentId)',
        );
        return const [];
      }

      final showId = (show['id'] as num).toInt();
      final response = await client
          .get(Uri.https('api.tvmaze.com', '/shows/$showId/episodes'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw http.ClientException(
          'TVMaze episodes returned HTTP ${response.statusCode}.',
          response.request?.url,
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        throw const FormatException('TVMaze episodes must be a JSON list.');
      }

      final episodes = <SeriesEpisode>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) {
          debugPrint('[series] Ignoring invalid TVMaze episode: $entry');
          continue;
        }
        final season = entry['season'];
        final number = entry['number'];
        final id = entry['id'];
        final name = entry['name'];
        if (season is! num ||
            number is! num ||
            id is! num ||
            name is! String ||
            name.trim().isEmpty) {
          debugPrint('[series] Ignoring invalid TVMaze episode: $entry');
          continue;
        }
        final episode = SeriesEpisode.tryFromJson({
          'id': 'tvmaze:$showId:${id.toInt()}',
          'title': name,
          'season': season,
          'episode': number,
          'overview': _plainText(entry['summary']),
          'thumbnail': _tvMazeImage(entry['image']),
          'runtime':
              entry['runtime'] == null ? null : '${entry['runtime']} min',
          if (season == 0) 'type': 'special',
        });
        if (episode != null) episodes.add(episode);
      }
      debugPrint('[series] Provider utilizado: TVMaze');
      debugPrint('[series] Quantidade de temporadas encontradas: ${SeriesMetadata(series: series, episodes: episodes).seasons.length}');
      debugPrint('[series] Quantidade de episódios encontrados: ${episodes.length}');
      return episodes;
    } catch (error) {
      debugPrint(
        '[series] TVMaze lookup failed for "${series.title}" '
        '(id=$contentId): $error',
      );
      return const [];
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<Map<String, dynamic>?> _findTvMazeShow(
    http.Client client,
    Movie series,
    String contentId,
  ) async {
    final imdbId = series.imdbId ?? contentId;
    if (imdbId.startsWith('tt')) {
      final response = await client
          .get(
            Uri.https(
              'api.tvmaze.com',
              '/lookup/shows',
              {'imdb': imdbId},
            ),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) return decoded;
      } else if (response.statusCode != 404) {
        throw http.ClientException(
          'TVMaze show lookup returned HTTP ${response.statusCode}.',
          response.request?.url,
        );
      }
    }

    final response = await client
        .get(
          Uri.https(
            'api.tvmaze.com',
            '/search/shows',
            {'q': series.title},
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'TVMaze search returned HTTP ${response.statusCode}.',
        response.request?.url,
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('TVMaze search must return a JSON list.');
    }
    final normalizedTitle = _normalizeTitle(series.title);
    for (final result in decoded) {
      if (result is! Map<String, dynamic> ||
          result['show'] is! Map<String, dynamic>) {
        continue;
      }
      final show = result['show'] as Map<String, dynamic>;
      if (show['name'] is String &&
          _normalizeTitle(show['name'] as String) == normalizedTitle) {
        return show;
      }
    }
    return null;
  }

  String _normalizeTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _plainText(Object? value) {
    if (value is! String) return '';
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _tvMazeImage(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final image = value['medium'] ?? value['original'];
    return image is String ? image : null;
  }

  Future<List<SeriesEpisode>> _loadFromAddon({
    required Addon addon,
    required Movie series,
    required String contentId,
    required String type,
  }) async {
    final episodes = <SeriesEpisode>[];
    try {
      final manifest = await _addonRepository.getManifest(addon);
      final types = _supportedTypes(type, manifest);
      var queriedMeta = false;

      for (final candidateType in types) {
        if (!manifest.supportsResource('meta', candidateType, contentId)) {
          continue;
        }
        queriedMeta = true;
        try {
          final item = await _catalogRepository.getMeta(
            addon: addon,
            type: candidateType,
            id: contentId,
          );
          episodes.addAll(_episodesFrom(item.raw['videos']));
        } catch (error) {
          debugPrint(
            '[series] addon=${addon.name}, meta type=$candidateType '
            'failed: $error',
          );
        }
      }

      final catalogs = manifest.catalogs.where(
        (catalog) => types.contains(catalog.type),
      );
      var queriedCatalog = false;
      for (final catalog in catalogs) {
        final searchExtra = catalog.extra.where(
          (extra) =>
              const {'search', 'query', 'q'}.contains(extra.name.toLowerCase()),
        );
        if (searchExtra.isEmpty && manifest.catalogs.length > 20) {
          continue;
        }
        final searchParameters = <String, String>{
          for (final extra in searchExtra) extra.name: series.title,
        };
        final unsupportedRequiredExtra = catalog.extra.any(
          (extra) =>
              extra.isRequired && !searchParameters.containsKey(extra.name),
        );
        if (unsupportedRequiredExtra) {
          debugPrint(
            '[series] addon=${addon.name}, catalog=${catalog.name} skipped: '
            'required search parameter unavailable',
          );
          continue;
        }

        queriedCatalog = true;
        try {
          final items = await _catalogRepository.getCatalog(
            addon: addon,
            catalog: catalog,
            extra: searchParameters,
          );
          final matches = items.where(
            (item) => _matchesSeries(item, series, contentId),
          );
          for (final item in matches) {
            episodes.addAll(_episodesFrom(item.raw['videos']));
            if (manifest.supportsResource('meta', item.type, item.id)) {
              try {
                final details = await _catalogRepository.getMeta(
                  addon: addon,
                  type: item.type,
                  id: item.id,
                  fallback: item,
                );
                episodes.addAll(_episodesFrom(details.raw['videos']));
              } catch (error) {
                debugPrint(
                  '[series] addon=${addon.name}, catalog meta '
                  'id=${item.id} failed: $error',
                );
              }
            }
          }
        } catch (error) {
          debugPrint(
            '[series] addon=${addon.name}, catalog=${catalog.name} failed: '
            '$error',
          );
        }
      }

      final uniqueEpisodes = <String, SeriesEpisode>{};
      for (final episode in episodes) {
        _mergeEpisode(uniqueEpisodes, episode);
      }
      final result = uniqueEpisodes.values.toList(growable: false);
      final seasonCount =
          SeriesMetadata(series: series, episodes: result).seasons.length;
      debugPrint('[series] Provider utilizado: ${addon.name}');
      debugPrint('[series] Quantidade de temporadas encontradas: $seasonCount');
      debugPrint('[series] Quantidade de episódios encontrados: ${result.length}');
      return result;
    } catch (error) {
      debugPrint('[series] addon=${addon.name} failed: $error');
      return const [];
    }
  }

  List<String> _supportedTypes(
    String requestedType,
    StremioAddonManifest manifest,
  ) {
    final candidates = <String>[
      requestedType.toLowerCase(),
      'series',
      'anime',
      'cartoon',
    ];
    return candidates
        .where(
            (type) => manifest.types.isEmpty || manifest.types.contains(type))
        .toSet()
        .toList(growable: false);
  }

  bool _matchesSeries(
    StremioMetaItem item,
    Movie series,
    String contentId,
  ) {
    final ids = {series.id, series.imdbId, contentId}
        .whereType<String>()
        .map(_baseId)
        .toSet();
    if (ids.contains(_baseId(item.id))) return true;
    return _normalizeTitle(item.name) == _normalizeTitle(series.title);
  }

  String _baseId(String value) => value.split(':').first.toLowerCase();

  List<SeriesEpisode> _episodesFrom(Object? videos) {
    if (videos is! List) return const [];
    final episodes = <SeriesEpisode>[];
    for (final video in videos) {
      if (video is! Map<String, dynamic>) {
        debugPrint('[series] Ignoring invalid addon episode: $video');
        continue;
      }
      final episode = SeriesEpisode.tryFromJson(video);
      if (episode != null) episodes.add(episode);
    }
    return episodes;
  }

  void _mergeEpisode(
    Map<String, SeriesEpisode> episodes,
    SeriesEpisode episode,
  ) {
    final key = '${episode.season}:${episode.episode}';
    final previous = episodes[key];
    if (previous == null) {
      episodes[key] = episode;
      return;
    }
    episodes[key] = SeriesEpisode(
      id: previous.id,
      title: previous.title,
      season: previous.season,
      episode: previous.episode,
      overview:
          previous.overview.isNotEmpty ? previous.overview : episode.overview,
      thumbnailUrl: previous.thumbnailUrl ?? episode.thumbnailUrl,
      runtime: previous.runtime ?? episode.runtime,
      kind: previous.kind ?? episode.kind,
    );
  }
}

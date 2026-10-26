import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/addon.dart';
import '../models/movie.dart';
import '../models/stremio_addon_manifest.dart';
import '../models/stremio_meta_item.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../services/cinemeta_service.dart';
import '../utils/localized_text.dart';

class MultiAddonMetadataService {
  const MultiAddonMetadataService({
    required AddonRepository addonRepository,
    required CatalogRepository catalogRepository,
    http.Client? client,
  })  : _addonRepository = addonRepository,
        _catalogRepository = catalogRepository,
        _client = client;

  final AddonRepository _addonRepository;
  final CatalogRepository _catalogRepository;
  final http.Client? _client;

  Future<SeriesMetadata> fetchSeriesMetadata({
    required Movie series,
    required String type,
    SeriesMetadata? fallback,
  }) async {
    var contentId = series.imdbId ?? series.id;

    if (!contentId.startsWith('tt') &&
        !contentId.startsWith('mal:') &&
        !contentId.startsWith('anilist:') &&
        !contentId.startsWith('tvmaze:')) {
      final cinemeta = CinemetaService();

      try {
        final results = await cinemeta.searchSeries(series.title);

        if (results.isNotEmpty) {
          contentId = results.first.imdbId ?? results.first.id;
        }
      } catch (error) {
        debugPrint('[multi-addon] Cinemeta search failed: $error');
      } finally {
        cinemeta.close();
      }
    }

    final episodesByNumber = <String, SeriesEpisode>{};

    if (fallback != null) {
      for (final episode in fallback.episodes) {
        _mergeEpisode(episodesByNumber, episode);
      }
    }

    final allAddons = await _addonRepository.getContentMetadataProviders();

    debugPrint(
      '[multi-addon] Consultando ${allAddons.length} addons '
      'para "${series.title}"',
    );

    final results = await Future.wait(
      allAddons.map(
        (addon) => _fetchFromAddon(
          addon,
          series,
          contentId,
          type,
        ),
      ),
    );

    for (final addonEpisodes in results) {
      for (final episode in addonEpisodes) {
        _mergeEpisode(episodesByNumber, episode);
      }
    }

    if (episodesByNumber.isEmpty) {
      debugPrint(
        '[multi-addon] Nenhum episódio encontrado nos addons. '
        'Consultando TVMaze.',
      );

      final tvmazeEpisodes = await _fetchFromTvMaze(series, contentId);

      for (final episode in tvmazeEpisodes) {
        _mergeEpisode(episodesByNumber, episode);
      }
    }

    final episodes = episodesByNumber.values.toList()
      ..sort((a, b) {
        final seasonOrder = a.season.compareTo(b.season);

        if (seasonOrder != 0) {
          return seasonOrder;
        }

        return a.episode.compareTo(b.episode);
      });

    final metadata = SeriesMetadata(
      series: fallback?.series ?? series,
      episodes: List.unmodifiable(episodes),
    );

    debugPrint(
      '[multi-addon] "${series.title}": '
      '${metadata.seasons.length} temporadas, '
      '${metadata.episodes.length} episódios',
    );

    return metadata;
  }

  Future<Movie> fetchMovieMetadata({
    required Movie movie,
    required String type,
  }) async {
    var contentId = movie.imdbId ?? movie.id;

    if (!contentId.startsWith('tt') &&
        !contentId.startsWith('mal:') &&
        !contentId.startsWith('anilist:') &&
        !contentId.startsWith('tvmaze:')) {
      final cinemeta = CinemetaService();

      try {
        final results = await cinemeta.searchMovies(movie.title);

        if (results.isNotEmpty) {
          contentId = results.first.imdbId ?? results.first.id;
        }
      } catch (error) {
        debugPrint('[multi-addon] Movie search failed: $error');
      } finally {
        cinemeta.close();
      }
    }

    final addons = await _addonRepository.getContentMetadataProviders();

    final results = await Future.wait(
      addons.map(
        (addon) => _fetchMovieFromAddon(
          addon,
          movie,
          contentId,
          type,
        ),
      ),
    );

    LocalizedText? portugueseSynopsis;
    String? fallbackSynopsis;
    String? poster;
    String? background;
    String? rating;
    String? releaseInfo;
    List<String>? genres;

    for (final item in results) {
      if (item == null) {
        continue;
      }

      final synopsis = localizedText(
        item.raw,
        fields: const [
          'description',
          'overview',
          'summary',
          'plot',
        ],
      );

      if (synopsis != null) {
        if (synopsis.isPortuguese) {
          portugueseSynopsis ??= synopsis;
        } else {
          fallbackSynopsis ??= synopsis.text;
        }
      }

      poster ??= item.poster;
      background ??= item.background;

      if (item.imdbRating.isNotEmpty) {
        rating ??= item.imdbRating;
      }

      if (item.releaseInfo.isNotEmpty) {
        releaseInfo ??= item.releaseInfo;
      }

      if (item.genres.isNotEmpty) {
        genres ??= item.genres;
      }
    }

    return Movie(
      id: movie.id,
      imdbId: movie.imdbId,
      title: movie.title,
      type: movie.type,
      overview: portugueseSynopsis?.text ??
          (movie.overview.isNotEmpty ? movie.overview : fallbackSynopsis ?? ''),
      posterUrl: movie.posterUrl ?? poster,
      bannerUrl: movie.bannerUrl ?? background,
      imdbRating: movie.imdbRating ?? double.tryParse(rating ?? ''),
      releaseYear: movie.releaseYear ?? _year(releaseInfo),
      genres: movie.genres.isNotEmpty ? movie.genres : genres ?? const [],
    );
  }

  Future<List<SeriesEpisode>> _fetchFromAddon(
    Addon addon,
    Movie series,
    String contentId,
    String type,
  ) async {
    final episodes = <SeriesEpisode>[];

    try {
      final manifest = await _addonRepository.getManifest(addon);
      final types = _supportedTypes(type, manifest);

      for (final candidateType in types) {
        if (!manifest.supportsResource(
          'meta',
          candidateType,
          contentId,
        )) {
          continue;
        }

        try {
          final item = await _catalogRepository.getMeta(
            addon: addon,
            type: candidateType,
            id: contentId,
          );

          episodes.addAll(_episodesFrom(item.raw['videos']));
        } catch (error) {
          debugPrint(
            '[multi-addon] ${addon.name}: '
            'meta $candidateType failed: $error',
          );
        }
      }

      final catalogs = manifest.catalogs.where(
        (catalog) => types.contains(catalog.type),
      );

      for (final catalog in catalogs) {
        final searchExtras = catalog.extra.where(
          (extra) => const {
            'search',
            'query',
            'q',
          }.contains(extra.name.toLowerCase()),
        );

        if (searchExtras.isEmpty && manifest.catalogs.length > 20) {
          continue;
        }

        final parameters = <String, String>{
          for (final extra in searchExtras) extra.name: series.title,
        };

        final missingRequired = catalog.extra.any(
          (extra) => extra.isRequired && !parameters.containsKey(extra.name),
        );

        if (missingRequired) {
          continue;
        }

        try {
          final items = await _catalogRepository.getCatalog(
            addon: addon,
            catalog: catalog,
            extra: parameters,
          );

          final matches = items.where(
            (item) => _matchesContent(
              item,
              series,
              contentId,
            ),
          );

          for (final item in matches) {
            episodes.addAll(_episodesFrom(item.raw['videos']));

            if (!manifest.supportsResource(
              'meta',
              item.type,
              item.id,
            )) {
              continue;
            }

            try {
              final details = await _catalogRepository.getMeta(
                addon: addon,
                type: item.type,
                id: item.id,
                fallback: item,
              );

              episodes.addAll(
                _episodesFrom(details.raw['videos']),
              );
            } catch (error) {
              debugPrint(
                '[multi-addon] ${addon.name}: '
                'details ${item.id} failed: $error',
              );
            }
          }
        } catch (error) {
          debugPrint(
            '[multi-addon] ${addon.name}: '
            'catalog ${catalog.name} failed: $error',
          );
        }
      }

      debugPrint(
        '[multi-addon] ${addon.name}: '
        '${episodes.length} episódios recebidos',
      );

      return episodes;
    } catch (error) {
      debugPrint(
        '[multi-addon] ${addon.name} unavailable: $error',
      );

      return const [];
    }
  }

  Future<StremioMetaItem?> _fetchMovieFromAddon(
    Addon addon,
    Movie movie,
    String contentId,
    String type,
  ) async {
    try {
      final manifest = await _addonRepository.getManifest(addon);
      final types = _compatibleTypes(type, manifest);

      for (final candidateType in types) {
        if (!manifest.supportsResource(
          'meta',
          candidateType,
          contentId,
        )) {
          continue;
        }

        try {
          final item = await _catalogRepository.getMeta(
            addon: addon,
            type: candidateType,
            id: contentId,
          );

          if (_matchesContent(item, movie, contentId)) {
            return item;
          }
        } catch (error) {
          debugPrint(
            '[multi-addon] ${addon.name}: '
            'movie meta failed: $error',
          );
        }
      }

      final catalogs = manifest.catalogs.where(
        (catalog) => types.contains(catalog.type),
      );

      for (final catalog in catalogs) {
        final searchExtras = catalog.extra.where(
          (extra) => const {
            'search',
            'query',
            'q',
          }.contains(extra.name.toLowerCase()),
        );

        if (searchExtras.isEmpty && manifest.catalogs.length > 20) {
          continue;
        }

        final parameters = <String, String>{
          for (final extra in searchExtras) extra.name: movie.title,
        };

        if (catalog.extra.any(
          (extra) => extra.isRequired && !parameters.containsKey(extra.name),
        )) {
          continue;
        }

        try {
          final items = await _catalogRepository.getCatalog(
            addon: addon,
            catalog: catalog,
            extra: parameters,
          );

          for (final item in items) {
            if (!_matchesContent(item, movie, contentId)) {
              continue;
            }

            if (!manifest.supportsResource(
              'meta',
              item.type,
              item.id,
            )) {
              return item;
            }

            try {
              return await _catalogRepository.getMeta(
                addon: addon,
                type: item.type,
                id: item.id,
                fallback: item,
              );
            } catch (error) {
              debugPrint(
                '[multi-addon] ${addon.name}: '
                'movie details failed: $error',
              );

              return item;
            }
          }
        } catch (error) {
          debugPrint(
            '[multi-addon] ${addon.name}: '
            'movie catalog failed: $error',
          );
        }
      }

      return null;
    } catch (error) {
      debugPrint(
        '[multi-addon] ${addon.name}: $error',
      );

      return null;
    }
  }

  Future<List<SeriesEpisode>> _fetchFromTvMaze(
    Movie series,
    String contentId,
  ) async {
    final client = _client ?? http.Client();

    try {
      final show = await _findTvMazeShow(
        client,
        series,
        contentId,
      );

      if (show == null || show['id'] is! num) {
        return const [];
      }

      final showId = (show['id'] as num).toInt();

      final response = await client
          .get(
            Uri.https(
              'api.tvmaze.com',
              '/shows/$showId/episodes',
            ),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (decoded is! List) {
        return const [];
      }

      final episodes = <SeriesEpisode>[];

      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) {
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

        if (episode != null) {
          episodes.add(episode);
        }
      }

      return episodes;
    } catch (error) {
      debugPrint('[multi-addon] TVMaze failed: $error');
      return const [];
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<Map<String, dynamic>?> _findTvMazeShow(
    http.Client client,
    Movie series,
    String contentId,
  ) async {
    final imdbId = series.imdbId ?? contentId;
    // Catalogos TVmaze ja possuem o ID exato.
    // Evita buscar outra serie com nome semelhante.
    final tvmazeMatch = RegExp(r'^tvmaze:(\d+)$').firstMatch(contentId);
    if (tvmazeMatch != null) {
      final showId = tvmazeMatch.group(1)!;
      final response = await client
          .get(Uri.https('api.tvmaze.com', '/shows/$showId'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      debugPrint(
        '[multi-addon] TVMaze show $showId unavailable',
      );
      return null;
    }

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
        final decoded = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
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
      return null;
    }

    final decoded = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    if (decoded is! List) {
      return null;
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

  List<SeriesEpisode> _episodesFrom(Object? videos) {
    if (videos is! List) {
      return const [];
    }

    final episodes = <SeriesEpisode>[];

    for (final video in videos) {
      if (video is! Map<String, dynamic>) {
        continue;
      }

      final normalized = <String, dynamic>{
        ...video,
        'title': video['title'] ?? video['name'],
        'episode': video['episode'] ?? video['number'],
      };

      final episode = SeriesEpisode.tryFromJson(normalized);

      if (episode != null) {
        episodes.add(episode);
      }
    }

    return episodes;
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
      'tv',
      'dorama',
      'drama',
      'kdrama',
      'cdrama',
      'jdrama',
    ];

    return candidates
        .where(
          (type) => manifest.types.isEmpty || manifest.types.contains(type),
        )
        .toSet()
        .toList(growable: false);
  }

  List<String> _compatibleTypes(
    String requestedType,
    StremioAddonManifest manifest,
  ) {
    final normalized = requestedType.toLowerCase();

    final episodic = const {
      'series',
      'anime',
      'cartoon',
      'dorama',
      'drama',
      'kdrama',
      'cdrama',
      'jdrama',
    }.contains(normalized);

    final types = <String>[
      normalized,
      if (episodic) 'series',
      if (episodic) 'tv',
    ];

    return types
        .where(
          (type) => manifest.types.isEmpty || manifest.types.contains(type),
        )
        .toSet()
        .toList(growable: false);
  }

  bool _matchesContent(
    StremioMetaItem item,
    Movie content,
    String contentId,
  ) {
    final acceptedIds = {
      content.id,
      content.imdbId,
      contentId,
    }.whereType<String>().map(_baseId).toSet();

    if (acceptedIds.contains(_baseId(item.id))) {
      return true;
    }

    return _normalizeTitle(item.name) == _normalizeTitle(content.title);
  }

  String _baseId(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized.startsWith('tt')) {
      return normalized.split(':').first;
    }
    return normalized;
  }

  String _normalizeTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _plainText(Object? value) {
    if (value is! String) {
      return '';
    }

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
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final image = value['medium'] ?? value['original'];

    return image is String ? image : null;
  }

  int? _year(String? value) {
    if (value == null) {
      return null;
    }

    return int.tryParse(
      RegExp(r'\d{4}').firstMatch(value)?.group(0) ?? '',
    );
  }
}

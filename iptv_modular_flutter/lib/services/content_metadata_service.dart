import 'package:flutter/foundation.dart';

import '../models/addon.dart';
import '../models/movie.dart';
import '../models/stremio_addon_manifest.dart';
import '../models/stremio_meta_item.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../utils/localized_text.dart';

class ContentMetadataService {
  const ContentMetadataService({
    required AddonRepository addonRepository,
    required CatalogRepository catalogRepository,
  })  : _addonRepository = addonRepository,
        _catalogRepository = catalogRepository;

  final AddonRepository _addonRepository;
  final CatalogRepository _catalogRepository;

  Future<Movie> enrich({
    required Movie content,
    required String type,
  }) async {
    // Cria uma lista modificável para evitar:
    // Unsupported operation: sort
    final providers =
        (await _addonRepository.getContentMetadataProviders()).toList()
          ..sort((first, second) {
            if (first.id == 'cinemeta' && second.id != 'cinemeta') {
              return 1;
            }
            if (second.id == 'cinemeta' && first.id != 'cinemeta') {
              return -1;
            }

            final firstAnime = _isAnimeProvider(first);
            final secondAnime = _isAnimeProvider(second);

            if (type.toLowerCase() == 'anime' && firstAnime != secondAnime) {
              return firstAnime ? -1 : 1;
            }

            return 0;
          });

    debugPrint(
      '[metadata] Consultando ${providers.length} provedores para '
      '"${content.title}"',
    );

    // Uma falha em um addon não interrompe os demais.
    final metadata = await Future.wait(
      providers.map(
        (addon) => _loadFromAddon(addon, content, type),
      ),
    );

    final available = metadata.whereType<StremioMetaItem>().toList();

    debugPrint(
      '[metadata] Provedores com metadados: ${available.length}',
    );

    LocalizedText? portugueseSynopsis;
    String? fallbackSynopsis;
    String? poster;
    String? background;
    String? rating;
    String? releaseInfo;
    List<String>? genres;

    for (final item in available) {
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
      id: content.id,
      imdbId: content.imdbId,
      title: content.title,
      type: content.type,
      overview: portugueseSynopsis?.text ??
          (content.overview.isNotEmpty
              ? content.overview
              : fallbackSynopsis ?? ''),
      posterUrl: content.posterUrl ?? poster,
      bannerUrl: content.bannerUrl ?? background,
      imdbRating: content.imdbRating ?? double.tryParse(rating ?? ''),
      releaseYear: content.releaseYear ?? _year(releaseInfo),
      genres: content.genres.isNotEmpty ? content.genres : genres ?? const [],
    );
  }

  Future<StremioMetaItem?> _loadFromAddon(
    Addon addon,
    Movie content,
    String requestedType,
  ) async {
    if (!addon.enabled) {
      return null;
    }

    try {
      final manifest = await _addonRepository.getManifest(addon);
      final contentId = content.imdbId ?? content.id;
      final matches = <StremioMetaItem>[];

      final compatibleTypes = _compatibleTypes(requestedType, manifest);

      // Primeira tentativa: metadados diretos.
      for (final candidateType in compatibleTypes) {
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

          if (_matchesContent(item, content, contentId)) {
            matches.add(item);
          } else {
            debugPrint(
              '[metadata] addon=${addon.name}, '
              'meta id=${item.id} não corresponde '
              'ao conteúdo id=$contentId '
              'title="${content.title}"',
            );
          }
        } catch (error) {
          debugPrint(
            '[metadata] addon=${addon.name}, '
            'meta type=$candidateType falhou: $error',
          );
        }
      }

      // Segunda tentativa: pesquisar nos catálogos do addon.
      final supportedTypes = compatibleTypes.toSet();

      final catalogs = manifest.catalogs
          .where(
            (catalog) => supportedTypes.contains(catalog.type),
          )
          .toList(growable: false);

      for (final catalog in catalogs) {
        final searchableExtras = catalog.extra.where(
          (extra) => const {
            'search',
            'query',
            'q',
          }.contains(extra.name.toLowerCase()),
        );

        if (searchableExtras.isEmpty && manifest.catalogs.length > 20) {
          continue;
        }

        final parameters = <String, String>{
          for (final extra in searchableExtras) extra.name: content.title,
        };

        final hasMissingRequiredExtra = catalog.extra.any(
          (extra) => extra.isRequired && !parameters.containsKey(extra.name),
        );

        if (hasMissingRequiredExtra) {
          debugPrint(
            '[metadata] addon=${addon.name}, '
            'catalog=${catalog.name} ignorado: '
            'parâmetro obrigatório indisponível',
          );
          continue;
        }

        try {
          final items = await _catalogRepository.getCatalog(
            addon: addon,
            catalog: catalog,
            extra: parameters,
          );

          for (final item in items) {
            if (!_matchesContent(item, content, contentId)) {
              continue;
            }

            matches.add(item);

            // Busca detalhes completos usando o ID original
            // retornado pelo catálogo.
            if (manifest.supportsResource(
              'meta',
              item.type,
              item.id,
            )) {
              try {
                final detailedItem = await _catalogRepository.getMeta(
                  addon: addon,
                  type: item.type,
                  id: item.id,
                  fallback: item,
                );

                matches.add(detailedItem);
              } catch (error) {
                debugPrint(
                  '[metadata] addon=${addon.name}, '
                  'catalog meta id=${item.id} falhou: $error',
                );
              }
            }
          }
        } catch (error) {
          debugPrint(
            '[metadata] addon=${addon.name}, '
            'catalog=${catalog.name} falhou: $error',
          );
        }
      }

      if (matches.isEmpty) {
        debugPrint(
          '[metadata] addon=${addon.name}, '
          'type=$requestedType, '
          'id=$contentId: nenhum metadado correspondente',
        );
        return null;
      }

      debugPrint(
        '[metadata] addon=${addon.name}, '
        'registros encontrados=${matches.length}, '
        'sinopse em português='
        '${matches.any(_hasPortugueseSynopsis)}',
      );

      return _mergeItems(matches);
    } catch (error) {
      debugPrint(
        '[metadata] addon=${addon.name} indisponível: $error',
      );
      return null;
    }
  }

  StremioMetaItem _mergeItems(
    List<StremioMetaItem> items,
  ) {
    final base = items.first;

    final selectedSynopses = items
        .map(
          (item) => localizedText(
            item.raw,
            fields: const [
              'description',
              'overview',
              'summary',
              'plot',
            ],
          ),
        )
        .whereType<LocalizedText>()
        .toList(growable: false);

    LocalizedText? synopsis;

    for (final value in selectedSynopses) {
      if (value.isPortuguese) {
        synopsis = value;
        break;
      }
    }

    synopsis ??= selectedSynopses.isEmpty ? null : selectedSynopses.first;

    return StremioMetaItem.fromJson({
      ...base.raw,
      if (synopsis != null) 'description': synopsis.text,
      'poster': items.map((item) => item.poster).firstWhere(
            (value) => value != null && value.isNotEmpty,
            orElse: () => base.poster,
          ),
      'background': items.map((item) => item.background).firstWhere(
            (value) => value != null && value.isNotEmpty,
            orElse: () => base.background,
          ),
      'imdbRating': items.map((item) => item.imdbRating).firstWhere(
            (value) => value.isNotEmpty,
            orElse: () => '',
          ),
      'genres': items.map((item) => item.genres).firstWhere(
            (value) => value.isNotEmpty,
            orElse: () => base.genres,
          ),
    });
  }

  bool _hasPortugueseSynopsis(
    StremioMetaItem item,
  ) {
    final synopsis = localizedText(
      item.raw,
      fields: const [
        'description',
        'overview',
        'summary',
        'plot',
      ],
    );

    return synopsis?.isPortuguese ?? false;
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

  String _baseId(String value) => value.split(':').first.toLowerCase();

  String _normalizeTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool _isAnimeProvider(Addon addon) {
    final normalized = '${addon.id} ${addon.name}'.toLowerCase();

    return normalized.contains('anime') || normalized.contains('kitsu');
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

  int? _year(String? value) {
    if (value == null) {
      return null;
    }

    return int.tryParse(
      RegExp(r'\d{4}').firstMatch(value)?.group(0) ?? '',
    );
  }
}

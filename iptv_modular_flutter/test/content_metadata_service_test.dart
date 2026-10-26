import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_modular_flutter/models/addon.dart';
import 'package:iptv_modular_flutter/models/movie.dart';
import 'package:iptv_modular_flutter/models/stremio_addon_manifest.dart';
import 'package:iptv_modular_flutter/models/stremio_meta_item.dart';
import 'package:iptv_modular_flutter/repositories/addon_repository.dart';
import 'package:iptv_modular_flutter/repositories/catalog_repository.dart';
import 'package:iptv_modular_flutter/services/content_metadata_service.dart';

void main() {
  test('prefers Portuguese synopsis and keeps the original poster', () async {
    final addon = Addon(
      id: 'metadata',
      name: 'Metadata',
      url: 'https://metadata.example/manifest.json',
    );
    final addonRepository = _MetadataAddonRepository(addon);
    final catalogRepository = _MetadataCatalogRepository();

    final movie = await ContentMetadataService(
      addonRepository: addonRepository,
      catalogRepository: catalogRepository,
    ).enrich(
      content: const Movie(
        id: 'tt123',
        imdbId: 'tt123',
        title: 'Filme',
        overview: 'English overview',
        posterUrl: 'https://images.example/primary.jpg',
      ),
      type: 'movie',
    );

    expect(movie.overview, 'Sinopse em português');
    expect(movie.posterUrl, 'https://images.example/primary.jpg');
    expect(movie.bannerUrl, 'https://images.example/background.jpg');
    expect(movie.genres, ['Drama']);
  });

  test('uses searchable addon catalogs when meta resource is unavailable',
      () async {
    final addon = Addon(
      id: 'catalog-only',
      name: 'Catalog Only',
      url: 'https://catalog.example/manifest.json',
    );
    final movie = await ContentMetadataService(
      addonRepository: _CatalogOnlyAddonRepository(addon),
      catalogRepository: _CatalogOnlyMetadataRepository(),
    ).enrich(
      content: const Movie(
        id: 'tt123',
        imdbId: 'tt123',
        title: 'Filme',
        overview: 'English synopsis.',
      ),
      type: 'movie',
    );

    expect(movie.overview, 'Sinopse localizada em português.');
    expect(movie.posterUrl, 'https://images.example/catalog-poster.jpg');
    expect(movie.bannerUrl, 'https://images.example/catalog-background.jpg');
    expect(movie.genres, ['Drama']);
    expect(movie.releaseYear, 2024);
  });
}

class _MetadataAddonRepository extends AddonRepository {
  _MetadataAddonRepository(this.addon);

  final Addon addon;

  @override
  Future<List<Addon>> getContentMetadataProviders() async => [addon];

  @override
  Future<StremioAddonManifest> getManifest(Addon addon) async =>
      StremioAddonManifest.fromJson({
        'id': addon.id,
        'name': addon.name,
        'resources': [
          {
            'name': 'meta',
            'types': ['movie'],
          },
        ],
        'types': ['movie'],
        'idPrefixes': ['tt'],
      });
}

class _MetadataCatalogRepository extends CatalogRepository {
  @override
  Future<StremioMetaItem> getMeta({
    required Addon addon,
    required String type,
    required String id,
    StremioMetaItem? fallback,
  }) async {
    return StremioMetaItem.fromJson({
      'id': id,
      'type': type,
      'name': 'Filme',
      'description': 'English overview',
      'translations': {
        'pt-BR': {'description': 'Sinopse em português'},
      },
      'poster': 'https://images.example/alternate.jpg',
      'background': 'https://images.example/background.jpg',
      'genres': ['Drama'],
    });
  }
}

class _CatalogOnlyAddonRepository extends AddonRepository {
  _CatalogOnlyAddonRepository(this.addon);

  final Addon addon;

  @override
  Future<List<Addon>> getContentMetadataProviders() async => [addon];

  @override
  Future<StremioAddonManifest> getManifest(Addon addon) async =>
      StremioAddonManifest.fromJson({
        'id': addon.id,
        'name': addon.name,
        'resources': ['catalog'],
        'types': ['movie'],
        'catalogs': [
          {
            'id': 'search',
            'type': 'movie',
            'name': 'Search',
            'extra': [
              {'name': 'search'},
            ],
          },
        ],
      });
}

class _CatalogOnlyMetadataRepository extends CatalogRepository {
  @override
  Future<StremioMetaItem> getMeta({
    required Addon addon,
    required String type,
    required String id,
    StremioMetaItem? fallback,
  }) {
    fail('Catalog-only provider must not be queried for meta.');
  }

  @override
  Future<List<StremioMetaItem>> getCatalog({
    required Addon addon,
    required StremioCatalog catalog,
    Map<String, String> extra = const {},
  }) async {
    expect(extra, {'search': 'Filme'});
    return [
      StremioMetaItem.fromJson({
        'id': 'tt123',
        'type': 'movie',
        'name': 'Filme',
        'description': 'English synopsis.',
        'translations': {
          'pt-BR': {'description': 'Sinopse localizada em português.'},
        },
        'poster': 'https://images.example/catalog-poster.jpg',
        'background': 'https://images.example/catalog-background.jpg',
        'genres': ['Drama'],
        'release_date': '2024-01-02',
      }),
    ];
  }
}

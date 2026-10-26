import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_modular_flutter/models/addon.dart';
import 'package:iptv_modular_flutter/models/movie.dart';
import 'package:iptv_modular_flutter/models/stremio_addon_manifest.dart';
import 'package:iptv_modular_flutter/models/stremio_meta_item.dart';
import 'package:iptv_modular_flutter/repositories/addon_repository.dart';
import 'package:iptv_modular_flutter/repositories/catalog_repository.dart';
import 'package:iptv_modular_flutter/services/series_metadata_service.dart';

void main() {
  test('queries later addons after failures and preserves season zero',
      () async {
    final addons = [
      Addon(
          id: 'cinemeta',
          name: 'Cinemeta',
          url: 'https://cinemeta.example/manifest.json'),
      Addon(
          id: 'failing',
          name: 'Falha',
          url: 'https://fail.example/manifest.json'),
      Addon(
          id: 'empty',
          name: 'Vazio',
          url: 'https://empty.example/manifest.json'),
      Addon(
          id: 'episodes',
          name: 'Episódios',
          url: 'https://episodes.example/manifest.json'),
    ];
    final repository = _AddonRepository(
      addons,
      {
        for (final addon in addons)
          addon.id: const StremioAddonManifest(
            id: 'test',
            name: 'Teste',
            resources: [StremioAddonResource(name: 'meta')],
            types: ['series'],
            catalogs: [],
          ),
      },
    );
    final catalogs = _CatalogRepository();

    final metadata = await SeriesMetadataService(
      addonRepository: repository,
      catalogRepository: catalogs,
    ).load(
      series: const Movie(
        id: 'tt123',
        imdbId: 'tt123',
        title: 'Série teste',
        type: 'series',
      ),
      type: 'series',
    );

    expect(catalogs.queriedAddonIds, ['failing', 'empty', 'episodes']);
    expect(metadata.seasons.keys, [0]);
    expect(metadata.episodes, hasLength(1));
    expect(metadata.episodes.single.title, 'Especial');
  });

  test('uses TVMaze episode data when addons expose no valid episodes',
      () async {
    final repository = _AddonRepository(const [], const {});
    final catalogs = _CatalogRepository();
    final client = MockClient((request) async {
      if (request.url.path == '/lookup/shows') {
        expect(request.url.queryParameters['imdb'], 'tt123');
        return http.Response.bytes(
          utf8.encode(jsonEncode({'id': 42, 'name': 'Série teste'})),
          200,
        );
      }
      expect(request.url.path, '/shows/42/episodes');
      return http.Response.bytes(
        utf8.encode(jsonEncode([
          {
            'id': 4201,
            'name': 'Piloto',
            'season': 1,
            'number': 1,
            'summary': '<p>Uma <b>sinopse</b> do episódio.</p>',
            'runtime': 45,
            'image': {'medium': 'https://images.example/episode.jpg'},
          },
          {
            'id': 4202,
            'name': 'Especial',
            'season': 0,
            'number': 1,
            'summary': null,
          },
          {
            'id': 4203,
            'name': 'Inválido sem número',
            'season': 1,
            'number': null,
          },
        ])),
        200,
      );
    });

    final metadata = await SeriesMetadataService(
      addonRepository: repository,
      catalogRepository: catalogs,
      client: client,
    ).load(
      series: const Movie(
        id: 'tt123',
        imdbId: 'tt123',
        title: 'Série teste',
        type: 'series',
      ),
      type: 'series',
    );

    expect(metadata.seasons.keys, [0, 1]);
    expect(metadata.episodes, hasLength(2));
    expect(metadata.seasons[1]!.single.overview, 'Uma sinopse do episódio.');
    expect(
      metadata.seasons[1]!.single.thumbnailUrl,
      'https://images.example/episode.jpg',
    );
    expect(metadata.seasons[1]!.single.runtime, '45 min');
    expect(metadata.seasons[0]!.single.specialCategory, 'Especiais');
    client.close();
  });
}

class _AddonRepository extends AddonRepository {
  _AddonRepository(this.addons, this.manifests);

  final List<Addon> addons;
  final Map<String, StremioAddonManifest> manifests;

  @override
  Future<List<Addon>> getInstalledAddons() async => addons;

  @override
  Future<List<Addon>> getContentMetadataProviders() async => addons;

  @override
  Future<StremioAddonManifest> getManifest(Addon addon) async =>
      manifests[addon.id]!;
}

class _CatalogRepository extends CatalogRepository {
  final queriedAddonIds = <String>[];

  @override
  Future<StremioMetaItem> getMeta({
    required Addon addon,
    required String type,
    required String id,
    StremioMetaItem? fallback,
  }) async {
    queriedAddonIds.add(addon.id);
    if (addon.id == 'failing') {
      throw StateError('Addon indisponível');
    }
    if (addon.id == 'empty') {
      return StremioMetaItem.fromJson({
        'id': id,
        'type': type,
        'name': 'Série teste',
        'videos': [],
      });
    }
    return StremioMetaItem.fromJson({
      'id': id,
      'type': type,
      'name': 'Série teste',
      'videos': [
        {
          'id': 'tt-special',
          'title': 'Especial',
          'season': 0,
          'episode': 1,
        },
      ],
    });
  }
}

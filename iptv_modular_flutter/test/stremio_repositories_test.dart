import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_modular_flutter/models/addon.dart';
import 'package:iptv_modular_flutter/models/stremio_addon_manifest.dart';
import 'package:iptv_modular_flutter/repositories/addon_repository.dart';
import 'package:iptv_modular_flutter/repositories/catalog_repository.dart';
import 'package:iptv_modular_flutter/repositories/stream_repository.dart';
import 'package:iptv_modular_flutter/utils/stremio_cache_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cache keys remain short for very long addon manifest URLs', () {
    final longUrl =
        'https://provider.example/${'configured/'.padRight(4000, 'x')}/manifest.json';
    final key = stremioCacheKey('stremio_catalog', 'addon-id|$longUrl');

    expect(key.length, lessThanOrEqualTo(255));
    expect(key, startsWith('stremio_catalog_'));
  });

  test('downloads and parses the manifest; uses cached data offline', () async {
    var requests = 0;
    final repository = AddonRepository(
      client: MockClient((request) async {
        requests++;
        if (requests > 1) {
          throw http.ClientException('offline');
        }
        return http.Response(
          jsonEncode({
            'id': 'catalog-provider',
            'name': 'Provider',
            'resources': [
              {
                'name': 'stream',
                'types': ['movie'],
                'idPrefixes': ['tt'],
              }
            ],
            'types': ['movie'],
            'idPrefixes': ['tt'],
            'catalogs': [
              {'id': 'popular', 'type': 'movie', 'name': 'Popular'},
            ],
          }),
          200,
        );
      }),
    );
    final addon = Addon(
      id: 'provider',
      name: 'Provider',
      url: 'https://provider.example/manifest.json',
    );

    final first = await repository.getManifest(addon);
    final second = await repository.getManifest(addon);

    expect(first.catalogs.single.id, 'popular');
    expect(first.supportsResource('stream', 'movie', 'tt123'), isTrue);
    expect(first.supportsResource('stream', 'series', 'tt123'), isFalse);
    expect(second.name, first.name);
    expect(requests, 2);
    repository.close();
  });

  test('requests catalog endpoint and parses metadata items', () async {
    Uri? requestedUri;
    final repository = CatalogRepository(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'metas': [
              {
                'id': 'tt123',
                'type': 'movie',
                'name': 'Filme real',
                'poster': 'https://images.example/poster.jpg',
                'releaseInfo': '2024',
              }
            ],
          }),
          200,
        );
      }),
    );
    final item = (await repository.getCatalog(
      addon: Addon(
        id: 'provider',
        name: 'Provider',
        url: 'https://provider.example/manifest.json',
      ),
      catalog: const StremioCatalog(
        id: 'popular',
        type: 'movie',
        name: 'Popular',
      ),
      extra: const {'search': 'ação'},
    ))
        .single;

    expect(requestedUri!.path, '/catalog/movie/popular.json');
    expect(requestedUri!.queryParameters['search'], 'ação');
    expect(item.name, 'Filme real');
    expect(item.releaseInfo, '2024');
    repository.close();
  });

  test('discovers meta/configuration capabilities and fetches detail metadata',
      () async {
    final repository = CatalogRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/meta/movie/tt42.json');
        return http.Response(
          jsonEncode({
            'meta': {
              'id': 'tt42',
              'type': 'movie',
              'name': 'Detalhe completo',
              'description': 'Sinopse',
              'genres': ['Drama'],
              'year': 2025,
              'imdbRating': '9.1',
            },
          }),
          200,
        );
      }),
    );
    final addonRepository = AddonRepository(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'id': 'universal',
              'name': 'Universal',
              'resources': ['meta', 'stream', 'subtitles'],
              'types': ['movie'],
              'behaviorHints': {'configurable': true},
              'configuration': [
                {'key': 'token', 'type': 'password', 'required': true}
              ],
            }),
            200,
          )),
    );
    final addon = Addon(
      id: 'universal',
      name: 'Universal',
      url: 'https://provider.example/manifest.json',
    );
    final manifest = await addonRepository.getManifest(addon);
    final details = await repository.getMeta(
      addon: addon,
      type: 'movie',
      id: 'tt42',
    );

    expect(manifest.hasMeta, isTrue);
    expect(manifest.hasStreams, isTrue);
    expect(manifest.hasSubtitles, isTrue);
    expect(manifest.behaviorHints['configurable'], isTrue);
    expect(manifest.configuration.single.key, 'token');
    expect(details.genres, ['Drama']);
    expect(details.year, '2025');
    expect(details.imdbRating, '9.1');
    repository.close();
    addonRepository.close();
  });

  test('searches only searchable catalogs across installed addons', () async {
    final repository = CatalogRepository(
      client: MockClient((request) async {
        expect(request.url.queryParameters['search'], 'matrix');
        return http.Response(
          jsonEncode({
            'metas': [
              {
                'id': 'tt13',
                'type': 'movie',
                'name': 'Matrix',
              },
            ],
          }),
          200,
        );
      }),
    );
    final addon = Addon(
      id: 'searchable',
      name: 'Searchable',
      url: 'https://provider.example/manifest.json',
    );
    final response = await repository.searchAcrossAddons(
      addons: [addon],
      query: 'matrix',
      loadManifest: (_) async => StremioAddonManifest.fromJson({
        'id': 'searchable',
        'name': 'Searchable',
        'types': ['movie'],
        'catalogs': [
          {
            'id': 'search',
            'type': 'movie',
            'extra': [
              {'name': 'search'},
            ],
          },
        ],
      }),
    );

    expect(response.results, hasLength(1));
    expect(response.results.single.item.name, 'Matrix');
    expect(response.errors, isEmpty);
    repository.close();
  });

  test('searches local results in catalogs without a search extra', () async {
    final repository = CatalogRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/catalog/movie/nfx.json');
        return http.Response(
          jsonEncode({
            'metas': [
              {'id': 'tt1', 'type': 'movie', 'name': 'The Matrix'},
              {'id': 'tt2', 'type': 'movie', 'name': 'Other film'},
            ],
          }),
          200,
        );
      }),
    );
    final response = await repository.searchAcrossAddons(
      addons: [
        Addon(
          id: 'catalog',
          name: 'Streaming Catalogs',
          url: 'https://catalog.example/manifest.json',
        ),
      ],
      query: 'matrix',
      loadManifest: (_) async => StremioAddonManifest.fromJson({
        'id': 'catalog',
        'name': 'Streaming Catalogs',
        'types': ['movie'],
        'catalogs': [
          {'id': 'nfx', 'type': 'movie', 'name': 'Netflix'},
        ],
      }),
    );

    expect(response.results, hasLength(1));
    expect(response.results.single.item.name, 'The Matrix');
    expect(response.errors, isEmpty);
    repository.close();
  });

  test('forwards supported filters and searches unsearchable catalogs locally',
      () async {
    final repository = CatalogRepository(
      client: MockClient((request) async {
        expect(request.url.queryParameters, {'genre': 'Drama', 'year': '2024'});
        return http.Response(
          jsonEncode({
            'metas': [
              {'id': 'tt1', 'type': 'movie', 'name': 'The Matrix'},
              {'id': 'tt2', 'type': 'movie', 'name': 'Other film'},
            ],
          }),
          200,
        );
      }),
    );
    final response = await repository.searchAcrossAddons(
      addons: [
        Addon(
          id: 'catalog',
          name: 'Catalog',
          url: 'https://catalog.example/manifest.json',
        ),
      ],
      query: 'matrix',
      catalogFilters: const {
        'genre': 'Drama',
        'year': '2024',
        'status': 'ended',
      },
      loadManifest: (_) async => StremioAddonManifest.fromJson({
        'id': 'catalog',
        'name': 'Catalog',
        'types': ['movie'],
        'catalogs': [
          {
            'id': 'nfx',
            'type': 'movie',
            'name': 'Catalog',
            'extra': [
              {'name': 'genre', 'options': ['Drama']},
              {'name': 'year'},
            ],
          },
        ],
      }),
    );

    expect(response.results, hasLength(1));
    expect(response.results.single.item.name, 'The Matrix');
    repository.close();
  });

  test('limits large catalogs to searchable catalogs and requested types',
      () async {
    final requestedPaths = <String>[];
    final repository = CatalogRepository(
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        return http.Response(
          jsonEncode({
            'metas': [
              {'id': 'tt1', 'type': 'movie', 'name': 'Search result'},
            ],
          }),
          200,
        );
      }),
    );
    final catalogs = [
      {
        'id': 'searchable',
        'type': 'movie',
        'name': 'Searchable',
        'extra': [
          {'name': 'search'},
        ],
      },
      for (var index = 0; index < 20; index++)
        {
          'id': 'static-$index',
          'type': 'movie',
          'name': 'Static $index',
        },
      {
        'id': 'series-search',
        'type': 'series',
        'name': 'Series Search',
        'extra': [
          {'name': 'search'},
        ],
      },
    ];

    final response = await repository.searchAcrossAddons(
      addons: [
        Addon(
          id: 'large',
          name: 'Large Catalog Provider',
          url: 'https://provider.example/manifest.json',
        ),
      ],
      query: 'title',
      types: const {'movie'},
      loadManifest: (_) async => StremioAddonManifest.fromJson({
        'id': 'large',
        'name': 'Large Catalog Provider',
        'types': ['movie', 'series'],
        'catalogs': catalogs,
      }),
    );

    expect(requestedPaths, ['/catalog/movie/searchable.json']);
    expect(response.results, hasLength(1));
    repository.close();
  });

  test('preserves encoded addon configuration in endpoint paths', () async {
    Uri? requestedUri;
    final repository = CatalogRepository(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(jsonEncode({'metas': []}), 200);
      }),
    );

    await repository.getCatalog(
      addon: Addon(
        id: 'configured',
        name: 'Configured',
        url:
            'https://provider.example/qualities=4k%7Caudio=dublado/manifest.json?key=secret',
      ),
      catalog: const StremioCatalog(
        id: 'popular',
        type: 'movie',
        name: 'Popular',
      ),
    );

    expect(
      requestedUri!.toString(),
      'https://provider.example/qualities=4k%7Caudio=dublado/catalog/movie/popular.json',
    );
    repository.close();
  });

  test('loads direct streams and subtitles but never treats torrents as URLs',
      () async {
    final manifestRepository = AddonRepository(
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'id': 'provider',
              'name': 'Provider',
              'resources': ['stream', 'subtitles'],
              'types': ['movie'],
              'idPrefixes': ['tt'],
            }),
            200,
          )),
    );
    final requestedPaths = <String>[];
    final repository = StreamRepository(
      addonRepository: manifestRepository,
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path.contains('/subtitles/')) {
          return http.Response(
            jsonEncode({
              'subtitles': [
                {'id': 'en', 'lang': 'eng', 'url': 'https://sub.example/en.vtt'}
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'streams': [
              {
                'title': '1080p',
                'url': 'https://video.example/movie.m3u8',
              },
              {'title': 'Torrent 4K', 'infoHash': 'abcdef012345'},
            ],
          }),
          200,
        );
      }),
    );
    final addon = Addon(
      id: 'provider',
      name: 'Provider',
      url: 'https://provider.example/manifest.json',
    );

    final result = await repository.getStreams(
      type: 'movie',
      contentId: 'tt123',
      addons: [addon],
    );

    expect(requestedPaths, [
      '/stream/movie/tt123.json',
      '/subtitles/movie/tt123.json',
    ]);
    expect(result.streams, hasLength(2));
    expect(result.streams.first.isDirectUrl, isTrue);
    expect(result.streams.last.isDirectUrl, isFalse);
    expect(result.streams.last.displayTitle, 'Torrent 4K');
    expect(result.subtitles.single.lang, 'eng');
    expect(result.errors, isEmpty);
    repository.close();
    manifestRepository.close();
  });
}

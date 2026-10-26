import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_modular_flutter/models/addon.dart';
import 'package:iptv_modular_flutter/models/movie.dart';
import 'package:iptv_modular_flutter/models/stremio_meta_item.dart';
import 'package:iptv_modular_flutter/repositories/addon_repository.dart';
import 'package:iptv_modular_flutter/repositories/stream_repository.dart';
import 'package:iptv_modular_flutter/screens/episode_screen.dart';
import 'package:iptv_modular_flutter/screens/season_screen.dart';
import 'package:iptv_modular_flutter/screens/stremio_details_screen.dart';
import 'package:iptv_modular_flutter/services/cinemeta_service.dart';

void main() {
  testWidgets(
    'details show metadata and do not request playback until Assistir',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      var watchRequests = 0;
      final item = StremioMetaItem.fromJson({
        'id': 'tt123',
        'type': 'movie',
        'name': 'Filme de teste',
        'description': 'Uma sinopse de teste.',
        'poster': 'https://images.example/poster.jpg',
        'background': 'https://images.example/banner.jpg',
        'releaseInfo': '2024',
        'imdbRating': '8.2',
        'genres': ['Drama', 'Aventura'],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: StremioDetailsScreen(
            item: item,
            catalogAddon: Addon(
              id: 'catalog',
              name: 'Catálogo de teste',
              url: 'https://catalog.example/manifest.json',
            ),
            onWatch: (_) async {
              watchRequests++;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Filme de teste'), findsOneWidget);
      expect(find.text('Uma sinopse de teste.'), findsOneWidget);
      expect(find.text('2024 · movie'), findsOneWidget);
      expect(find.text('8.2'), findsOneWidget);
      expect(find.text('Drama'), findsOneWidget);
      expect(find.text('Aventura'), findsOneWidget);
      expect(find.text('Catálogo: Catálogo de teste'), findsOneWidget);
      expect(watchRequests, 0);

      await tester.tap(find.text('Assistir'));
      await tester.pump();

      expect(watchRequests, 1);
    },
  );

  testWidgets('series details require an episode before source selection', (
    tester,
  ) async {
    var watchRequests = 0;
    final item = StremioMetaItem.fromJson({
      'id': 'tt0903747',
      'type': 'series',
      'name': 'Breaking Bad',
      'videos': [
        {
          'id': 'tt0959621',
          'title': 'Pilot',
          'season': 1,
          'episode': 1,
        },
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StremioDetailsScreen(
          item: item,
          catalogAddon: Addon(
            id: 'catalog',
            name: 'Catálogo de teste',
            url: 'https://catalog.example/manifest.json',
          ),
          onWatch: (_) async => watchRequests++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Temporadas'), findsOneWidget);
    expect(find.text('Temporada 1'), findsOneWidget);
    expect(find.text('Assistir'), findsNothing);
    expect(watchRequests, 0);

    await tester.tap(find.text('Temporada 1'));
    await tester.pumpAndSettle();
    expect(find.byType(SeasonScreen), findsOneWidget);
    expect(find.text('Pilot'), findsOneWidget);

    await tester.tap(find.text('Pilot'));
    await tester.pumpAndSettle();
    expect(find.byType(EpisodeScreen), findsOneWidget);
    expect(watchRequests, 0);
  });

  testWidgets('malformed series episodes show fallback instead of throwing', (
    tester,
  ) async {
    final item = StremioMetaItem.fromJson({
      'id': 'tt123',
      'type': 'series',
      'name': 'Série sem episódios válidos',
      'videos': [
        {'id': null, 'title': 'Inválido', 'season': 1, 'episode': 1},
        {'id': 'tt1', 'title': null, 'season': 1, 'episode': 2},
        {'id': 'tt2', 'title': 'Inválido', 'season': null, 'episode': 3},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StremioDetailsScreen(
          item: item,
          catalogAddon: Addon(
            id: 'catalog',
            name: 'Catálogo de teste',
            url: 'https://catalog.example/manifest.json',
          ),
          onWatch: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhuma temporada encontrada para este conteúdo.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('episode sources are queried only after choosing a source', (
    tester,
  ) async {
    final addons = _EmptyAddonRepository();
    final streams = _RecordingStreamRepository(addons);
    const series = Movie(
      id: 'tt0903747',
      imdbId: 'tt0903747',
      title: 'Breaking Bad',
      type: 'series',
    );
    const episode = SeriesEpisode(
      id: 'tt0959621',
      title: 'Pilot',
      season: 1,
      episode: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EpisodeScreen(
          series: series,
          episode: episode,
          addonRepository: addons,
          streamRepository: streams,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(streams.requests, isEmpty);

    await tester.tap(find.text('Selecionar fonte'));
    await tester.pumpAndSettle();

    expect(streams.requests, ['series:tt0903747:1:1']);
  });
}

class _EmptyAddonRepository extends AddonRepository {
  @override
  Future<List<Addon>> getInstalledAddons() async => const [];
}

class _RecordingStreamRepository extends StreamRepository {
  _RecordingStreamRepository(AddonRepository addonRepository)
      : super(addonRepository: addonRepository);

  final requests = <String>[];

  @override
  Future<StreamRepositoryResult> getStreams({
    required String type,
    required String contentId,
    required Iterable<Addon> addons,
  }) async {
    requests.add('$type:$contentId');
    return const StreamRepositoryResult(
      streams: [],
      subtitles: [],
      errors: {},
      compatibleProviderCount: 0,
    );
  }
}

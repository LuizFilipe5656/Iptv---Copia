import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_modular_flutter/main.dart';
import 'package:iptv_modular_flutter/models/continue_watching.dart';
import 'package:iptv_modular_flutter/models/addon.dart';
import 'package:iptv_modular_flutter/models/movie.dart';
import 'package:iptv_modular_flutter/models/stremio_addon_manifest.dart';
import 'package:iptv_modular_flutter/models/stremio_meta_item.dart';
import 'package:iptv_modular_flutter/models/subtitle_track.dart';
import 'package:iptv_modular_flutter/models/stremio_stream.dart';
import 'package:iptv_modular_flutter/models/watchhub_offer.dart';
import 'package:iptv_modular_flutter/screens/local_files_screen.dart';
import 'package:iptv_modular_flutter/screens/addons_screen.dart';
import 'package:iptv_modular_flutter/screens/addon_details_screen.dart';
import 'package:iptv_modular_flutter/screens/player_screen.dart';
import 'package:iptv_modular_flutter/screens/details_screen.dart';
import 'package:iptv_modular_flutter/screens/episode_screen.dart';
import 'package:iptv_modular_flutter/screens/favorites_screen.dart';
import 'package:iptv_modular_flutter/screens/season_screen.dart';
import 'package:iptv_modular_flutter/screens/search_screen.dart';
import 'package:iptv_modular_flutter/screens/settings_screen.dart';
import 'package:iptv_modular_flutter/screens/splash_screen.dart';
import 'package:iptv_modular_flutter/screens/watchhub_screen.dart';
import 'package:iptv_modular_flutter/screens/youtube_screen.dart';
import 'package:iptv_modular_flutter/services/addon_service.dart';
import 'package:iptv_modular_flutter/repositories/addon_repository.dart';
import 'package:iptv_modular_flutter/repositories/catalog_repository.dart';
import 'package:iptv_modular_flutter/repositories/stream_repository.dart';
import 'package:iptv_modular_flutter/services/cinemeta_service.dart';
import 'package:iptv_modular_flutter/services/favorites_service.dart';
import 'package:iptv_modular_flutter/services/localfiles_service.dart';
import 'package:iptv_modular_flutter/services/playback_progress_service.dart';
import 'package:iptv_modular_flutter/services/subtitles_service.dart';
import 'package:iptv_modular_flutter/services/watchhub_service.dart';
import 'package:iptv_modular_flutter/services/youtube_service.dart';
import 'package:iptv_modular_flutter/theme/app_theme.dart';
import 'package:iptv_modular_flutter/widgets/hero_banner.dart';
import 'package:iptv_modular_flutter/widgets/movie_card.dart';
import 'package:iptv_modular_flutter/widgets/continue_watching_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('banner usa imagem de rede, overlay escuro e ícone de detalhes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeroBanner(
            title: 'Filme em destaque',
            subtitle: 'Descrição do filme',
            backgroundImage: 'https://example.com/banner.jpg',
            actionLabel: 'Ver detalhes',
            onAction: () {},
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect(find.byIcon(Icons.info_outline), findsOneWidget);

    final overlay = tester.widget<DecoratedBox>(
      find.byType(DecoratedBox).last,
    );
    final gradient =
        (overlay.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.colors, [Colors.transparent, Colors.black87]);
  });

 testWidgets('splash exibe o nome oficial Cine Mobile', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SplashScreen(
        addonRepository: null,
        catalogRepository: null,
        streamRepository: null,
        themeMode: ThemeMode.dark,
        onThemeModeChanged: (_) async {},
        themeLoaded: true,
      ),
    ),
  );

  expect(find.text('Cine Mobile'), findsOneWidget);
});

  testWidgets('card usa dimensões e placeholder elegantes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MovieCard(
            movie: Movie(id: 'tt0000001', title: 'Filme sem poster'),
          ),
        ),
      ),
    );

    final cardSize = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(MovieCard),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(cardSize.width, 170);
    expect(cardSize.height, 255);
    expect(find.byIcon(Icons.movie_creation_outlined), findsOneWidget);

    final placeholder = tester.widget<Container>(find.byType(Container).last);
    expect(placeholder.color, const Color(0xFF10192D));
  });

  testWidgets('home exibe destaque, filmes, séries, animes e desenhos', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Cine Mobile'), findsOneWidget);
    expect(find.text('DESTAQUE'), findsOneWidget);
    expect(find.text('Filme de Teste'), findsWidgets);
    expect(find.text('CONTINUAR ASSISTINDO'), findsOneWidget);
    expect(find.text('CATÁLOGOS DOS ADDONS'), findsNothing);
    expect(find.text('Lançamentos'), findsNothing);
    expect(find.text('Tendências'), findsNothing);
    expect(find.text('Recomendados'), findsNothing);
    expect(find.text('Em Alta'), findsNothing);
    expect(find.text('TV'), findsNothing);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('FILMES POPULARES'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('FILMES POPULARES'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('FILMES EM DESTAQUE'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('FILMES EM DESTAQUE'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('SÉRIES POPULARES'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('SÉRIES POPULARES'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('SÉRIES EM DESTAQUE'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('SÉRIES EM DESTAQUE'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ANIMES'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('ANIMES'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('DESENHOS'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('DESENHOS'), findsOneWidget);
  });

  testWidgets('navegação superior exibe apenas as três seções públicas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_testApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.text('INÍCIO'), findsOneWidget);
    expect(find.text('DESCOBRIR'), findsOneWidget);
    expect(find.text('ADD-ONS'), findsNothing);
    expect(find.text('CONFIGURAÇÕES'), findsOneWidget);
    expect(find.text('TV'), findsNothing);

    await tester.tap(find.text('DESCOBRIR'));
    await tester.pump();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('FILTROS'), findsOneWidget);
    await tester.tap(find.text('CONFIGURAÇÕES'));
    await tester.pump();
    expect(find.text('Tema escuro'), findsOneWidget);
    await tester.tap(find.text('INÍCIO'));
    await tester.pump();
    expect(find.text('Cine Mobile'), findsOneWidget);
  });

  testWidgets('favoritos persiste filmes e séries e permite remover', (
    tester,
  ) async {
    final favorites = FavoritesService();
    const movie = Movie(
      id: 'tt0133093',
      imdbId: 'tt0133093',
      title: 'The Matrix',
      type: 'movie',
      overview: 'Uma simulação.',
      releaseYear: 1999,
    );
    const series = Movie(
      id: 'tt0903747',
      imdbId: 'tt0903747',
      title: 'Breaking Bad',
      type: 'series',
      releaseYear: 2008,
    );

    await favorites.add(movie);
    await favorites.add(series);
    final persistedFavorites = await FavoritesService().getFavorites();
    expect(
      persistedFavorites.map((favorite) => (favorite.id, favorite.type)),
      [('tt0133093', 'movie'), ('tt0903747', 'series')],
    );
    expect(await favorites.contains(movie), isTrue);

    await tester.pumpWidget(
      MaterialApp(home: FavoritesScreen(service: favorites)),
    );
    await tester.pumpAndSettle();
    expect(find.text('The Matrix'), findsOneWidget);
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('Filme'), findsOneWidget);
    expect(find.text('Série'), findsOneWidget);

    final removeButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byType(ListTile).first,
        matching: find.byType(IconButton),
      ),
    );
    removeButton.onPressed!();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final remainingFavorites = await favorites.getFavorites();
    expect(
      remainingFavorites.map((favorite) => (favorite.id, favorite.type)),
      [('tt0903747', 'series')],
    );
    await tester.pumpWidget(
      MaterialApp(home: FavoritesScreen(service: favorites)),
    );
    await tester.pumpAndSettle();
    expect(find.text('The Matrix'), findsNothing);
    expect(find.text('Breaking Bad'), findsOneWidget);
  });

  test('progresso de reprodução persiste id, posição e episódio', () async {
    final progressService = PlaybackProgressService();
    await progressService.save(
      const PlaybackProgress(
        contentId: 'tt0903747',
        title: 'Breaking Bad',
        contentType: 'series',
        url: 'https://example.com/episode.m3u8',
        positionMilliseconds: 1040000,
        durationMilliseconds: 1600000,
        updatedAtMilliseconds: 0,
        season: 1,
        episode: 3,
        posterUrl: 'https://example.com/poster.jpg',
        episodeTitle: '...And the Bag’s in the River',
      ),
    );

    final saved = await PlaybackProgressService().getProgress();
    expect(saved, hasLength(1));
    expect(saved.single.contentId, 'tt0903747');
    expect(saved.single.positionMilliseconds, 1040000);
    expect(saved.single.episodeLabel, 'T1 E3');
    expect(saved.single.formattedPosition, '17:20');
    expect(saved.single.progressPercentage, 65);
    expect(saved.single.posterUrl, 'https://example.com/poster.jpg');

    await progressService.remove(saved.single);
    expect(await progressService.getProgress(), isEmpty);
  });

  testWidgets('continuar assistindo abre o episódio no ponto salvo', (
    tester,
  ) async {
    final progressService = PlaybackProgressService();
    await progressService.save(
      const PlaybackProgress(
        contentId: 'tt0903747',
        title: 'Breaking Bad',
        contentType: 'series',
        url: 'https://example.com/episode.m3u8',
        positionMilliseconds: 1040000,
        durationMilliseconds: 1600000,
        updatedAtMilliseconds: 0,
        season: 1,
        episode: 3,
        posterUrl: 'https://example.com/poster.jpg',
      ),
    );
    PlayerLaunchRequest? launchRequest;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContinueWatchingSection(service: progressService),
        ),
        onGenerateRoute: (settings) {
          launchRequest = settings.arguments! as PlayerLaunchRequest;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Player de teste')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CONTINUAR ASSISTINDO'), findsOneWidget);
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('T1 E3'), findsOneWidget);
    expect(find.textContaining('17:20'), findsOneWidget);
    expect(find.textContaining('65% assistido'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.tap(find.text('Breaking Bad'));
    await tester.pumpAndSettle();
    expect(find.text('Player de teste'), findsOneWidget);
    expect(launchRequest?.contentId, 'tt0903747');
    expect(launchRequest?.season, 1);
    expect(launchRequest?.episode, 3);
    expect(launchRequest?.posterUrl, 'https://example.com/poster.jpg');
    expect(launchRequest?.startPositionMilliseconds, 1040000);
  });

  testWidgets('navegação superior abre descoberta e configurações sem addons',
      (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('INÍCIO'), findsOneWidget);
    expect(find.text('DESCOBRIR'), findsOneWidget);
    expect(find.text('ADD-ONS'), findsNothing);
    expect(find.text('CONFIGURAÇÕES'), findsOneWidget);

    await tester.tap(find.text('DESCOBRIR'));
    await tester.pump();
    expect(find.byType(SearchScreen), findsOneWidget);

    await tester.tap(find.text('CONFIGURAÇÕES'));
    await tester.pump();
    expect(find.text('Tema escuro'), findsOneWidget);
    expect(find.text('Add-ons'), findsNothing);
    expect(find.text('ADD-ONS FIXOS'), findsNothing);
    expect(find.text('ADD-ONS INSTALADOS'), findsNothing);
  });

  testWidgets('descoberta mostra filtros avançados', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SearchScreen()),
    );

    await tester.tap(find.text('FILTROS'));
    await tester.pumpAndSettle();

    expect(find.text('TIPO'), findsOneWidget);
    expect(find.text('Filmes'), findsOneWidget);
    expect(find.text('Séries'), findsOneWidget);
    expect(find.text('Animes'), findsOneWidget);
    expect(find.text('Desenhos'), findsOneWidget);
    expect(find.text('Ficção Científica'), findsOneWidget);
    expect(find.text('De'), findsOneWidget);
    expect(find.text('Até'), findsOneWidget);
    expect(find.textContaining('AVALIAÇÃO IMDb'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('Situação'), findsOneWidget);
    expect(find.text('Mais Popular'), findsOneWidget);
  });

  testWidgets('tela inicial abre a busca', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('Pesquise em todos os catálogos.'), findsOneWidget);
  });

  testWidgets('tela YouTube abre buscas de trailer, clipes e lives', (
    tester,
  ) async {
    final youtube = _FakeYoutubeService();
    await tester.pumpWidget(
      MaterialApp(
        home: YoutubeScreen(
          initialQuery: 'The Matrix',
          youtubeService: youtube,
        ),
      ),
    );

    expect(find.text('Trailer Oficial'), findsOneWidget);
    expect(find.text('Clipes'), findsOneWidget);
    expect(find.text('Lives'), findsOneWidget);
    await tester.tap(find.text('Trailer Oficial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clipes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lives'));
    await tester.pumpAndSettle();

    expect(youtube.searches, [
      ('The Matrix', YoutubeVideoCategory.officialTrailer),
      ('The Matrix', YoutubeVideoCategory.clips),
      ('The Matrix', YoutubeVideoCategory.lives),
    ]);
  });

  test('YouTube monta buscas oficiais com filtro de lives', () {
    const youtube = ExternalYoutubeService();

    final trailer = youtube.searchUri(
      ' The Matrix ',
      category: YoutubeVideoCategory.officialTrailer,
    );
    final clips = youtube.searchUri(
      'The Matrix',
      category: YoutubeVideoCategory.clips,
    );
    final lives = youtube.searchUri(
      'música',
      category: YoutubeVideoCategory.lives,
    );

    expect(trailer.host, 'www.youtube.com');
    expect(
        trailer.queryParameters['search_query'], 'The Matrix trailer oficial');
    expect(clips.queryParameters['search_query'], 'The Matrix clipes');
    expect(lives.queryParameters['search_query'], 'música');
    expect(lives.queryParameters['sp'], 'EgJAAQ==');
    expect(
      () => youtube.searchUri(' ', category: YoutubeVideoCategory.clips),
      throwsArgumentError,
    );
  });

  test('addons oficiais permanecem instalados e protegidos', () async {
    final addons = AddonService(bundle: _TestAddonAssetBundle());
    final initialCatalog = await addons.loadCatalog();
    expect(initialCatalog, hasLength(8));
    expect(
      initialCatalog.every((addon) => addon.fixed && addon.enabled),
      isTrue,
    );

    await expectLater(
      addons.setInstalled('opensubtitles_v3', false),
      throwsA(isA<StateError>()),
    );
    final reloadedCatalog = await addons.loadCatalog();
    expect(reloadedCatalog, hasLength(8));
    expect(
      reloadedCatalog
          .singleWhere((addon) => addon.id == 'opensubtitles_v3')
          .enabled,
      isTrue,
    );
  });

  test('addon service importa, atualiza e remove addons por URL', () async {
    var version = '1.0.0';
    final client = MockClient((request) async {
      expect(request.url, Uri.https('addons.example', '/manifest.json'));
      return http.Response(
        jsonEncode({
          'id': 'community-addon',
          'name': 'Community Addon',
          'version': version,
          'author': 'Community',
        }),
        200,
      );
    });
    final service = AddonService(
      bundle: _TestAddonAssetBundle(),
      client: client,
    );

    final installed =
        await service.importFromUrl('https://addons.example/manifest.json');
    expect(installed.id, 'community-addon');
    expect(installed.enabled, isTrue);
    expect(
      (await AddonService(
        bundle: _TestAddonAssetBundle(),
        client: client,
      ).loadCatalog())
          .any((addon) => addon.id == 'community-addon'),
      isTrue,
    );

    version = '1.1.0';
    final updated = await service.update('community-addon');
    expect(updated.version, '1.1.0');
    await service.deactivate('community-addon');
    expect(
      (await service.loadCatalog())
          .singleWhere((addon) => addon.id == 'community-addon')
          .enabled,
      isFalse,
    );
    await service.activate('community-addon');
    expect(
      (await service.loadCatalog())
          .singleWhere((addon) => addon.id == 'community-addon')
          .enabled,
      isTrue,
    );
    await service.removeAddon('community-addon');
    expect(
      (await service.loadCatalog())
          .any((addon) => addon.id == 'community-addon'),
      isFalse,
    );
    service.close();
  });

  test('modelo ContinueWatching serializa dados locais', () {
    final entry = ContinueWatching(
      contentId: 'tt0903747',
      title: 'Breaking Bad',
      position: 1040000,
      updatedAt: DateTime.utc(2026, 10, 15),
    );
    final decoded = ContinueWatching.fromJson(entry.toJson());
    expect(decoded.contentId, 'tt0903747');
    expect(decoded.title, 'Breaking Bad');
    expect(decoded.position, 1040000);
    expect(decoded.updatedAt, entry.updatedAt);
  });

  testWidgets('configurações oculta addons e mantém opções locais',
      (tester) async {
    ThemeMode? selectedTheme;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          themeMode: ThemeMode.dark,
          onThemeModeChanged: (mode) async => selectedTheme = mode,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tema escuro'), findsOneWidget);
    expect(find.text('Add-ons'), findsNothing);
    expect(find.text('Sobre'), findsOneWidget);
    expect(find.text('Cache'), findsOneWidget);
    expect(find.text('Conta'), findsOneWidget);
    expect(find.text('PERSISTÊNCIA LOCAL'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(selectedTheme, ThemeMode.light);
  });

  testWidgets('addons oficiais mostram detalhes e não podem ser removidos', (
    tester,
  ) async {
    final repository = AddonRepository(
      bundle: _TestAddonAssetBundle(),
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'id': 'opensubtitles_v3',
              'name': 'OpenSubtitles',
              'version': '1.0',
              'description': 'Legendas de teste',
              'resources': ['subtitles'],
              'types': ['movie'],
            }),
            200,
          )),
    );
    final service = AddonService(repository: repository);
    await tester.pumpWidget(
      MaterialApp(
        home: AddonsScreen(
          addonService: service,
          addonRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ADD-ONS INSTALADOS'), findsOneWidget);
    expect(find.text('DISPONÍVEIS'), findsNothing);
    expect(find.text('OpenSubtitles'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(8));
    expect(find.byIcon(Icons.cancel_outlined), findsNothing);

    await tester.tap(find.text('OpenSubtitles'));
    await tester.pumpAndSettle();
    expect(find.text('Versão: 1.0'), findsOneWidget);
    expect(find.text('Legendas disponível'), findsOneWidget);
    expect(find.text('Desinstalar'), findsNothing);
    repository.close();
  });

  test('WatchHub consulta e classifica catálogos por disponibilidade',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/stream/movie/tt0133093.json');
      return http.Response(
        jsonEncode({
          'streams': [
            {
              'name': 'Prime Video',
              'title': 'Subscription',
              'externalUrl': 'https://prime.example/title',
            },
            {
              'name': 'Apple TV',
              'title': 'Rent, Buy',
              'externalUrl': 'https://apple.example/title',
            },
            {
              'name': 'Pluto TV',
              'title': 'Free with Ads',
              'externalUrl': 'https://pluto.example/title',
            },
          ],
        }),
        200,
      );
    });
    final service = HttpWatchhubService(
      client: client,
      baseUri: Uri.https('watchhub.example', ''),
    );

    final offers = await service.availabilityFor('tt0133093');

    expect(offers, hasLength(3));
    expect(offers.first.provider, 'Prime Video');
    expect(
      offers.map((offer) => offer.availabilityType),
      [
        WatchAvailabilityType.subscription,
        WatchAvailabilityType.rentOrBuy,
        WatchAvailabilityType.free,
      ],
    );
    client.close();
  });

  testWidgets('WatchHub exibe catálogos e filtra por disponibilidade', (
    tester,
  ) async {
    final service = _FakeWatchhubService([
      WatchhubOffer(
        provider: 'Prime Video',
        title: 'Subscription',
        url: Uri(scheme: 'https', host: 'prime.example', path: '/title'),
      ),
      WatchhubOffer(
        provider: 'Apple TV',
        title: 'Rent, Buy',
        url: Uri(scheme: 'https', host: 'apple.example', path: '/title'),
      ),
    ]);
    final openedUrls = <Uri>[];
    const movie = Movie(id: 'tt0133093', title: 'The Matrix');
    await tester.pumpWidget(
      MaterialApp(
        home: WatchhubScreen(
          movie: movie,
          service: service,
          openUrl: (url) async {
            openedUrls.add(url);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Onde assistir'), findsOneWidget);
    expect(find.text('Prime Video'), findsOneWidget);
    expect(find.text('Apple TV'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Assinatura'));
    await tester.pumpAndSettle();
    expect(find.text('Prime Video'), findsOneWidget);
    expect(find.text('Apple TV'), findsNothing);

    await tester.tap(find.text('Prime Video'));
    await tester.pumpAndSettle();
    expect(openedUrls.single.host, 'prime.example');
    expect(service.lastContentId, 'tt0133093');
  });

  testWidgets('configura a identidade Cine Mobile sem faixa de depuração', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Cine Mobile');
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.routes!.keys, isNot(contains('/addons')));
    expect(app.routes!.keys, contains('/local-files'));
    expect(app.routes!.keys, contains('/search'));
    expect(app.onGenerateRoute, isNotNull);
  });

  testWidgets('home abre a tela de arquivos locais', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.tap(find.text('CONFIGURAÇÕES'));
    await tester.pump();
    await tester.ensureVisible(find.text('Arquivos locais'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Arquivos locais'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LocalFilesScreen), findsOneWidget);
    expect(find.text('Formatos aceitos: MP4, MKV e AVI.'), findsOneWidget);
  });

  test('player requer URL de stream', () {
    const player = PlayerScreen(url: 'https://example.com/stream.m3u8');

    expect(player.url, 'https://example.com/stream.m3u8');
  });

  test('Local Files reconhece MP4, MKV e AVI sem diferenciar maiúsculas', () {
    expect(
      LocalVideoFile.fromPath(r'C:\Videos\filme.MP4').extension,
      'mp4',
    );
    expect(
      LocalVideoFile.fromPath(r'C:\Videos\filme.mkv').extension,
      'mkv',
    );
    expect(
      LocalVideoFile.fromPath(r'C:\Videos\filme.avi').extension,
      'avi',
    );
    expect(
      () => LocalVideoFile.fromPath(r'C:\Videos\filme.mov'),
      throwsFormatException,
    );
  });

  testWidgets('Local Files abre arquivos selecionados no player como locais', (
    tester,
  ) async {
    final service = _FakeLocalFilesService([
      LocalVideoFile.fromPath(r'C:\Videos\filme.mkv'),
    ]);
    PlayerLaunchRequest? request;
    await tester.pumpWidget(
      MaterialApp(
        home: LocalFilesScreen(service: service),
        onGenerateRoute: (settings) {
          request = settings.arguments as PlayerLaunchRequest;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Player local')),
          );
        },
      ),
    );

    await tester.tap(find.text('Selecionar vídeos'));
    await tester.pumpAndSettle();
    expect(find.text('filme.mkv'), findsOneWidget);
    expect(find.text('MKV'), findsOneWidget);

    await tester.tap(find.text('filme.mkv'));
    await tester.pumpAndSettle();

    expect(find.text('Player local'), findsOneWidget);
    expect(request?.url, r'C:\Videos\filme.mkv');
    expect(request?.isLocalFile, isTrue);
    expect(service.pickCount, 1);
  });

  test('OpenSubtitles busca legendas em PT-BR, EN e ES', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/subtitles/movie/tt0133093.json');
      return http.Response(
        jsonEncode({
          'subtitles': [
            {
              'id': 'pt-1',
              'url': 'https://subs.example/pt.srt',
              'lang': 'pob',
              'subtitleFileName': 'filme_pt.srt',
            },
            {
              'id': 'en-1',
              'url': 'https://subs.example/en.srt',
              'lang': 'eng',
              'subtitleFileName': 'movie_en.srt',
            },
            {
              'id': 'es-1',
              'url': 'https://subs.example/es.srt',
              'lang': 'spa',
              'subtitleFileName': 'pelicula_es.srt',
            },
            {
              'id': 'fr-1',
              'url': 'https://subs.example/fr.srt',
              'lang': 'fre',
            },
            {
              'id': 'pt-pt-1',
              'url': 'https://subs.example/pt-pt.srt',
              'lang': 'por',
            },
          ],
        }),
        200,
      );
    });
    final service = OpenSubtitlesService(
      client: client,
      baseUri: Uri.https('opensubtitles.example', ''),
    );

    final tracks = await service.searchSubtitles('tt0133093');
    final portuguese = await service.searchSubtitles(
      'tt0133093',
      language: SubtitleLanguage.ptBr,
    );

    expect(
      tracks.map((track) => track.language),
      [
        SubtitleLanguage.ptBr,
        SubtitleLanguage.en,
        SubtitleLanguage.es,
      ],
    );
    expect(tracks.first.url, Uri.https('subs.example', '/pt.srt'));
    expect(portuguese, hasLength(1));
    expect(portuguese.single.name, 'filme_pt.srt');
    client.close();
  });

  test('carrega o catálogo de addons do bundle', () async {
    final addons =
        await AddonService(bundle: _TestAddonAssetBundle()).loadCatalog();

    expect(addons, hasLength(8));
    expect(addons.map((addon) => addon.id), contains('cinemeta'));
    expect(
      addons.singleWhere((addon) => addon.id == 'cinemeta').description,
      'Catálogos populares e busca de filmes e séries',
    );
    expect(
      addons.singleWhere((addon) => addon.id == 'opensubtitles_v3').description,
      'Legendas em PT-BR, EN e ES',
    );
    expect(addons.map((addon) => addon.id), [
      'cinemeta',
      'youtube',
      'public_domain_movies',
      'opensubtitles_v3',
      'froststream',
      'fenixflix',
      'comet.elfhosted.com',
      'pw.ers.netflix-catalog',
    ]);
    expect(addons.every((addon) => addon.enabled && addon.fixed), isTrue);
  });

  testWidgets('addon detail discovers capabilities and saves config', (
    tester,
  ) async {
    final manifest = {
      'id': 'future-addon',
      'name': 'Future Addon',
      'version': '1.2.3',
      'description': 'Provider universal de teste',
      'logo': 'https://example.com/logo.png',
      'resources': [
        'meta',
        {
          'name': 'stream',
          'types': ['movie'],
        },
        'subtitles',
      ],
      'types': ['movie'],
      'behaviorHints': {'configurable': true},
      'catalogs': [
        {
          'id': 'popular',
          'type': 'movie',
          'extra': [
            {'name': 'search'},
          ],
        },
      ],
      'configuration': [
        {
          'key': 'apiKey',
          'title': 'API Key',
          'type': 'password',
          'required': true,
        },
      ],
    };
    final requestedUrls = <Uri>[];
    final repository = AddonRepository(
      client: MockClient((request) async {
        requestedUrls.add(request.url);
        return http.Response(jsonEncode(manifest), 200);
      }),
    );
    final addon = Addon(
      id: 'future-addon',
      name: 'Future Addon',
      url: 'https://addon.example/manifest.json',
      fixed: true,
    );
    bool? installed;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                installed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => AddonDetailsScreen(
                      addon: addon,
                      repository: repository,
                    ),
                  ),
                );
              },
              child: const Text('Abrir detalhes'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir detalhes'));
    await tester.pumpAndSettle();

    expect(find.text('Future Addon'), findsOneWidget);
    expect(find.text('Versão: 1.2.3'), findsOneWidget);
    expect(find.text('Catálogo disponível'), findsOneWidget);
    expect(find.text('Metadados disponível'), findsOneWidget);
    expect(find.text('Streams disponível'), findsOneWidget);
    expect(find.text('Legendas disponível'), findsOneWidget);
    await tester.tap(find.text('Configurar'));
    await tester.pumpAndSettle();
    expect(find.text('Configurar Future Addon'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'secret-config-value');
    await tester.tap(find.text('Instalar addon'));
    await tester.pumpAndSettle();

    expect(installed, isTrue);
    expect(
      await repository.getAddonConfiguration(addon.id),
      {'apiKey': 'secret-config-value'},
    );
    expect(requestedUrls.last.pathSegments, [
      'apiKey=secret-config-value',
      'manifest.json',
    ]);
    repository.close();
  });

  test('Cinemeta lê catálogo, busca e metadados completos', () async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path == '/catalog/movie/top.json' ||
          request.url.path.contains('/search=matrix')) {
        return http.Response(
          jsonEncode({
            'metas': [
              {
                'id': 'tt0133093',
                'imdb_id': 'tt0133093',
                'type': 'movie',
                'name': 'The Matrix',
                'poster': 'https://example.com/poster.jpg',
                'background': 'https://example.com/banner.jpg',
                'imdbRating': '8.7',
                'releaseInfo': '1999',
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path == '/meta/movie/tt0133093.json') {
        return http.Response(
          jsonEncode({
            'meta': {
              'id': 'tt0133093',
              'type': 'movie',
              'name': 'The Matrix',
              'description': 'A hacker discovers a simulated reality.',
              'poster': 'https://example.com/poster.jpg',
              'background': 'https://example.com/banner.jpg',
              'imdbRating': '8.7',
            },
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    final service = CinemetaService(client: client);

    final catalog = await service.popularMovies();
    final search = await service.searchMovies('matrix');
    final details = await service.movieDetails('tt0133093');

    expect(catalog.single.title, 'The Matrix');
    expect(catalog.single.posterUrl, 'https://example.com/poster.jpg');
    expect(catalog.single.bannerUrl, 'https://example.com/banner.jpg');
    expect(catalog.single.imdbRating, 8.7);
    expect(catalog.single.releaseYear, 1999);
    expect(search.single.id, 'tt0133093');
    expect(details?.overview, 'A hacker discovers a simulated reality.');
    expect(requestedPaths, contains('/catalog/movie/top.json'));
    expect(requestedPaths, contains('/catalog/movie/top/search=matrix.json'));
    expect(requestedPaths, contains('/meta/movie/tt0133093.json'));
    client.close();
  });

  test('Cinemeta carrega episódios e agrupa temporadas da série', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/meta/series/tt0903747.json');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'meta': {
              'id': 'tt0903747',
              'type': 'series',
              'name': 'Breaking Bad',
              'description': 'Um professor de química vira produtor de drogas.',
              'poster': 'https://example.com/breaking-bad.jpg',
              'videos': [
                {
                  'id': 'tt1234567',
                  'title': 'Seven Thirty-Seven',
                  'season': 2,
                  'episode': 1,
                },
                {
                  'id': 'tt1054724',
                  'title': 'Cat’s in the Bag...',
                  'season': 1,
                  'episode': 2,
                },
                {
                  'id': 'tt0959621',
                  'title': 'Pilot',
                  'season': 1,
                  'episode': 1,
                  'overview': 'Walter começa uma nova vida.',
                },
              ],
            },
          }),
        ),
        200,
      );
    });
    final service = CinemetaService(
      client: client,
      baseUri: Uri.https('cinemeta.test', ''),
    );

    final metadata = await service.seriesMetadata('tt0903747');

    expect(metadata?.series.title, 'Breaking Bad');
    expect(metadata?.episodes, hasLength(3));
    expect(metadata?.seasons.keys, [1, 2]);
    expect(
      metadata?.seasons[1]?.map((episode) => episode.title),
      ['Pilot', 'Cat’s in the Bag...'],
    );
    expect(metadata?.seasons[2]?.single.title, 'Seven Thirty-Seven');
    client.close();
  });

  test('Cinemeta ignora episódios incompletos e preserva a temporada 0',
      () async {
    final client = MockClient((request) async => http.Response.bytes(
          utf8.encode(jsonEncode({
            'meta': {
              'id': 'tt0903747',
              'type': 'series',
              'name': 'Série de teste',
              'videos': [
                {
                  'id': 'tt100',
                  'title': 'Episódio regular',
                  'season': 1,
                  'episode': 1,
                },
                {
                  'id': null,
                  'title': 'Sem ID',
                  'season': 1,
                  'episode': 2,
                },
                {
                  'id': 'tt102',
                  'title': null,
                  'season': 1,
                  'episode': 3,
                },
                {
                  'id': 'tt103',
                  'title': 'Sem temporada',
                  'season': null,
                  'episode': 4,
                },
                {
                  'id': 'tt104',
                  'title': 'Sem número',
                  'season': 0,
                  'episode': null,
                },
                {
                  'id': 'tt105',
                  'title': 'OVA especial',
                  'season': 0,
                  'episode': 1,
                  'type': 'ova',
                },
              ],
            },
          })),
          200,
        ));
    final service = CinemetaService(
      client: client,
      baseUri: Uri.https('cinemeta.test', ''),
    );

    final metadata = await service.seriesMetadata('tt0903747');

    expect(metadata, isNotNull);
    expect(metadata!.episodes.map((episode) => episode.title), [
      'Episódio regular',
      'OVA especial',
    ]);
    expect(metadata.seasons.keys, [0, 1]);
    expect(metadata.seasons[0]!.single.specialCategory, 'OVAs');
    service.close();
  });

  testWidgets('DetailsScreen busca metadados do Cinemeta por título', (
    tester,
  ) async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path.contains('/catalog/series/top/search=')) {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'metas': [
                {
                  'id': 'tt0903747',
                  'imdb_id': 'tt0903747',
                  'type': 'series',
                  'name': 'Breaking Bad',
                },
              ],
            }),
          ),
          200,
        );
      }
      if (request.url.path == '/meta/series/tt0903747.json') {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'meta': {
                'id': 'tt0903747',
                'imdb_id': 'tt0903747',
                'type': 'series',
                'name': 'Breaking Bad',
                'description':
                    'Um professor de química vira produtor de drogas.',
                'poster': 'https://example.com/breaking-bad-poster.jpg',
                'background': 'https://example.com/breaking-bad-banner.jpg',
                'imdbRating': '9.5',
                'releaseInfo': '2008–2013',
                'videos': [
                  {
                    'id': 'tt0959621',
                    'title': 'Pilot',
                    'season': 1,
                    'episode': 1,
                  },
                ],
              },
            }),
          ),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    final service = CinemetaService(
      client: client,
      baseUri: Uri.https('cinemeta.test', ''),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DetailsScreen(
          title: 'Breaking Bad',
          type: 'series',
          cinemetaService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CachedNetworkImage), findsWidgets);
    final detailsScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('IMDb 9.5'),
      250,
      scrollable: detailsScrollable,
    );
    expect(find.text('IMDb 9.5'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Um professor de química vira produtor de drogas.'),
      250,
      scrollable: detailsScrollable,
    );
    expect(find.text('Um professor de química vira produtor de drogas.'),
        findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('2008'),
      250,
      scrollable: detailsScrollable,
    );
    expect(find.text('2008'), findsOneWidget);
    expect(
      find.text('Nenhuma temporada encontrada para este conteúdo.'),
      findsOneWidget,
    );
    expect(requestedPaths, hasLength(2));
    expect(
      requestedPaths.first,
      contains('/catalog/series/top/search='),
    );
    expect(requestedPaths.last, '/meta/series/tt0903747.json');
    service.close();
  });

  testWidgets('tocar na série abre temporadas e lista episódios',
      (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/meta/series/tt0903747.json');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'meta': {
              'id': 'tt0903747',
              'imdb_id': 'tt0903747',
              'type': 'series',
              'name': 'Breaking Bad',
              'description': 'A história de Walter White.',
              'imdbRating': '9.5',
              'releaseInfo': '2008',
              'videos': [
                {
                  'id': 'tt0959621',
                  'title': 'Pilot',
                  'season': 1,
                  'episode': 1,
                },
                {
                  'id': 'tt1054724',
                  'title': 'Cat’s in the Bag...',
                  'season': 1,
                  'episode': 2,
                },
                {
                  'id': 'tt10511920',
                  'title': 'Seven Thirty-Seven',
                  'season': 2,
                  'episode': 1,
                },
                {
                  'id': 'tt9999001',
                  'title': 'The Lost Episode OVA',
                  'season': 0,
                  'episode': 1,
                },
                {
                  'id': 'tt9999002',
                  'title': 'Bonus OAD',
                  'season': 0,
                  'episode': 2,
                },
                {
                  'id': 'tt9999003',
                  'title': 'Behind the Scenes',
                  'season': 0,
                  'episode': 3,
                  'type': 'extra',
                },
              ],
            },
          }),
        ),
        200,
      );
    });
    final service = CinemetaService(
      client: client,
      baseUri: Uri.https('cinemeta.test', ''),
    );
    final episodeAddons = _DetailsEpisodeAddonRepository();
    final episodeCatalogs = _DetailsEpisodeCatalogRepository();
    const series = Movie(
      id: 'tt0903747',
      title: 'Breaking Bad',
      type: 'series',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MovieCard(
            movie: series,
            cinemetaService: service,
            addonRepository: episodeAddons,
            catalogRepository: episodeCatalogs,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Breaking Bad'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.byType(DetailsScreen), findsOneWidget);
    final detailsScrollView = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('2008'),
      250,
      scrollable: detailsScrollView,
    );
    expect(find.text('2008'), findsOneWidget);
    expect(find.text('IMDb 9.5'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('A história de Walter White.'),
      250,
      scrollable: detailsScrollView,
    );
    expect(find.text('A história de Walter White.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Temporadas'),
      250,
      scrollable: detailsScrollView,
    );
    expect(find.text('Temporadas'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Temporada 1'),
      250,
      scrollable: detailsScrollView,
    );
    expect(find.text('Temporada 1'), findsOneWidget);
    expect(find.text('Temporada 2'), findsOneWidget);
    expect(find.text('Especiais · Temporada 0'), findsOneWidget);
    expect(find.text('OVAs'), findsOneWidget);
    expect(find.text('OADs'), findsOneWidget);
    expect(find.text('Extras'), findsOneWidget);

    await tester.drag(
      detailsScrollView,
      const Offset(0, 700),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Assistir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assistir'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Temporada 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temporada 1'));
    await tester.pumpAndSettle();
    expect(find.byType(SeasonScreen), findsOneWidget);
    expect(find.text('Episódio 01'), findsOneWidget);
    expect(find.text('Pilot'), findsOneWidget);
    expect(find.text('Episódio 02'), findsOneWidget);
    expect(find.text('Cat’s in the Bag...'), findsOneWidget);

    await tester.tap(find.text('Episódio 01'));
    await tester.pumpAndSettle();

    expect(find.byType(EpisodeScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Breaking Bad Pilot',
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    service.close();
  });

  testWidgets('card exibe detalhes Cinemeta ao ser tocado', (tester) async {
    const movie = Movie(
      id: 'tt0133093',
      title: 'The Matrix',
      overview: 'A hacker discovers a simulated reality.',
      imdbId: 'tt0133093',
      imdbRating: 8.7,
      releaseYear: 1999,
    );
    final youtube = _FakeYoutubeService();
    final watchhub = _FakeWatchhubService([]);
    final addons = _DetailsTestAddonRepository();
    final streams = _DetailsTestStreamRepository(addons);
    String? launchedPlayerUrl;
    final cinemeta = CinemetaService(
      client: MockClient((request) async {
        expect(request.url.path, '/meta/movie/tt0133093.json');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'meta': {
                'id': 'tt0133093',
                'imdb_id': 'tt0133093',
                'type': 'movie',
                'name': 'The Matrix',
                'description': movie.overview,
                'imdbRating': '8.7',
                'releaseInfo': '1999',
              },
            }),
          ),
          200,
        );
      }),
      baseUri: Uri.https('cinemeta.test', ''),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MovieCard(
            movie: movie,
            youtubeService: youtube,
            watchhubService: watchhub,
            watchhubOpenUrl: (_) async => true,
            cinemetaService: cinemeta,
            addonRepository: addons,
            streamRepository: streams,
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name != PlayerScreen.routeName) return null;
          final request = settings.arguments! as PlayerLaunchRequest;
          launchedPlayerUrl = request.url;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Player de teste')),
          );
        },
      ),
    );

    expect(find.byIcon(Icons.star), findsNothing);
    await tester.tap(find.text('The Matrix'));
    await tester.pumpAndSettle();

    expect(find.text('IMDb 8.7'), findsOneWidget);
    expect(find.text(movie.overview), findsOneWidget);
    await tester.tap(find.text('Trailer'));
    await tester.pumpAndSettle();

    expect(youtube.searches.single, (
      'The Matrix 1999',
      YoutubeVideoCategory.officialTrailer,
    ));

    await tester.tap(find.text('WatchHub'));
    await tester.pumpAndSettle();
    expect(find.text('Onde assistir'), findsOneWidget);
    expect(watchhub.lastContentId, 'tt0133093');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Assistir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assistir'));
    await tester.pumpAndSettle();

    expect(find.text('1080p'), findsOneWidget);
    expect(streams.lastType, 'movie');
    expect(streams.lastContentId, 'tt0133093');
    await tester.tap(find.text('1080p'));
    await tester.pumpAndSettle();
    expect(find.text('Player de teste'), findsOneWidget);
    expect(launchedPlayerUrl, 'https://video.example/movie.m3u8');
    cinemeta.close();
  });

  test('usa o tema escuro azul especificado', () {
    expect(AppTheme.darkTheme.brightness, Brightness.dark);
    expect(AppTheme.darkTheme.scaffoldBackgroundColor, const Color(0xFF050B18));
    expect(AppTheme.darkTheme.primaryColor, const Color(0xFF2196F3));
    expect(AppTheme.darkTheme.colorScheme.primary, const Color(0xFF2196F3));
    expect(AppTheme.darkTheme.colorScheme.secondary, const Color(0xFF42A5F5));
    expect(AppTheme.darkTheme.colorScheme.surface, const Color(0xFF10192D));
  });
}

MoviePlatformApp _testApp() {
  final client = MockClient((request) async {
    final series = request.url.path.contains('/series/');
    return http.Response.bytes(
      utf8.encode(jsonEncode({
        'metas': [
          {
            'id': series ? 'tt1234567' : 'tt0133093',
            'imdb_id': series ? 'tt1234567' : 'tt0133093',
            'type': series ? 'series' : 'movie',
            'name': series ? 'Série de Teste' : 'Filme de Teste',
            'description': 'Conteúdo de teste',
            'releaseInfo': series ? '2024' : '1999',
          },
        ],
      })),
      200,
    );
  });
  return MoviePlatformApp(
    homeCinemetaService: CinemetaService(
      client: client,
      baseUri: Uri.https('cinemeta.test', ''),
    ),
  );
}

class _FakeYoutubeService implements YoutubeService {
  final searches = <(String, YoutubeVideoCategory)>[];

  @override
  Uri searchUri(
    String query, {
    YoutubeVideoCategory category = YoutubeVideoCategory.officialTrailer,
  }) {
    return Uri.https('www.youtube.com', '/results', {
      'search_query': query,
      'category': category.name,
    });
  }

  @override
  Future<bool> openSearch(
    String query, {
    YoutubeVideoCategory category = YoutubeVideoCategory.officialTrailer,
  }) async {
    searches.add((query, category));
    return true;
  }
}

class _TestAddonAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key != 'assets/default_addons.json') {
      throw FlutterError('Asset não encontrado: $key');
    }
    final data = utf8.encode(jsonEncode([
      {
        'id': 'cinemeta',
        'name': 'Cinemeta',
        'description': 'Catálogos populares e busca de filmes e séries',
        'fixed': true,
        'enabled': true,
      },
      {
        'id': 'youtube',
        'name': 'YouTube',
        'description': 'Trailers oficiais, clipes e transmissões ao vivo',
        'fixed': true,
        'enabled': true,
      },
      {
        'id': 'public_domain_movies',
        'name': 'Public Domain Movies',
        'description': 'Catálogo de filmes de domínio público',
        'fixed': true,
        'enabled': true,
      },
      {
        'id': 'opensubtitles_v3',
        'name': 'OpenSubtitles',
        'url': 'https://opensubtitles.example/manifest.json',
        'description': 'Legendas em PT-BR, EN e ES',
        'fixed': true,
        'enabled': true,
      },
      {
        'id': 'froststream',
        'name': 'FrostStream',
        'description': 'Addon Stremio suportado',
        'fixed': true,
        'enabled': true,
      },
      {
        'id': 'fenixflix',
        'name': 'FenixFlix',
        'description': 'Addon Stremio suportado',
        'fixed': true,
        'enabled': true,
      },
      {
        'id': 'comet.elfhosted.com',
        'name': 'Comet | ElfHosted',
        'url': 'https://comet.elfhosted.com/manifest.json',
        'fixed': true,
        'enabled': true,
      },
      {
        'id': 'pw.ers.netflix-catalog',
        'name': 'Streaming Catalogs',
        'url':
            'https://7a82163c306e-stremio-netflix-catalog-addon.baby-beamup.club/manifest.json',
        'fixed': true,
        'enabled': true,
      },
    ]));
    return ByteData.sublistView(Uint8List.fromList(data));
  }
}

class _FakeWatchhubService implements WatchhubService {
  _FakeWatchhubService(this.offers);

  final List<WatchhubOffer> offers;
  String? lastContentId;
  String? lastType;

  @override
  Future<List<WatchhubOffer>> availabilityFor(
    String contentId, {
    String type = 'movie',
  }) async {
    lastContentId = contentId;
    lastType = type;
    return offers;
  }

  @override
  void close() {}
}

class _FakeLocalFilesService implements LocalFilesService {
  _FakeLocalFilesService(this.files);

  final List<LocalVideoFile> files;
  int pickCount = 0;

  @override
  Future<List<LocalVideoFile>> pickVideoFiles() async {
    pickCount++;
    return files;
  }
}

class _DetailsTestAddonRepository extends AddonRepository {
  @override
  Future<List<Addon>> getInstalledAddons() async => const [];
}

class _DetailsEpisodeAddonRepository extends AddonRepository {
  final addon = Addon(
    id: 'episode-provider',
    name: 'Episode Provider',
    url: 'https://episodes.example/manifest.json',
  );

  @override
  Future<List<Addon>> getContentMetadataProviders() async => [addon];

  @override
  Future<StremioAddonManifest> getManifest(Addon addon) async =>
      const StremioAddonManifest(
        id: 'episode-provider',
        name: 'Episode Provider',
        resources: [
          StremioAddonResource(
            name: 'meta',
            types: ['series'],
            idPrefixes: ['tt'],
          ),
        ],
        types: ['series'],
        catalogs: [],
      );
}

class _DetailsEpisodeCatalogRepository extends CatalogRepository {
  @override
  Future<StremioMetaItem> getMeta({
    required Addon addon,
    required String type,
    required String id,
    StremioMetaItem? fallback,
  }) async =>
      StremioMetaItem.fromJson({
        'id': id,
        'type': type,
        'name': 'Breaking Bad',
        'description': 'A história de Walter White.',
        'videos': [
          {
            'id': 'tt0959621',
            'title': 'Pilot',
            'season': 1,
            'episode': 1,
          },
          {
            'id': 'tt1054724',
            'title': 'Cat’s in the Bag...',
            'season': 1,
            'episode': 2,
          },
          {
            'id': 'tt10511920',
            'title': 'Seven Thirty-Seven',
            'season': 2,
            'episode': 1,
          },
          {
            'id': 'tt9999001',
            'title': 'The Lost Episode OVA',
            'season': 0,
            'episode': 1,
          },
          {
            'id': 'tt9999002',
            'title': 'Bonus OAD',
            'season': 0,
            'episode': 2,
          },
          {
            'id': 'tt9999003',
            'title': 'Behind the Scenes',
            'season': 0,
            'episode': 3,
            'type': 'extra',
          },
        ],
      });
}

class _DetailsTestStreamRepository extends StreamRepository {
  _DetailsTestStreamRepository(AddonRepository addonRepository)
      : super(addonRepository: addonRepository);

  String? lastType;
  String? lastContentId;

  @override
  Future<StreamRepositoryResult> getStreams({
    required String type,
    required String contentId,
    required Iterable<Addon> addons,
  }) async {
    lastType = type;
    lastContentId = contentId;
    return const StreamRepositoryResult(
      streams: [
        StremioStream(
          addonId: 'test',
          addonName: 'Addon de teste',
          title: '1080p',
          url: 'https://video.example/movie.m3u8',
        ),
      ],
      subtitles: [],
      errors: {},
      compatibleProviderCount: 1,
    );
  }
}

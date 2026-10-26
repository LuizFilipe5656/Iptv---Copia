import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';

import 'repositories/addon_repository.dart';
import 'repositories/catalog_repository.dart';
import 'repositories/stream_repository.dart';

import 'services/addon_service.dart';
import 'services/cinemeta_service.dart';
import 'services/local_storage_service.dart';
import 'services/permission_service.dart';
import 'services/streaming_addon_service.dart';

import 'screens/local_files_screen.dart';
import 'screens/movies_screen.dart';
import 'screens/player_screen.dart';
import 'screens/player_test_screen.dart';
import 'screens/search_screen.dart';
import 'screens/series_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/youtube_screen.dart';

import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Supabase antes dos serviços que dependem dele.
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Inicializa o armazenamento local.
  await LocalStorageService.initialize();

  final addonRepository = AddonRepository();

  final addonService = AddonService(
    repository: addonRepository,
  );

  final streamingAddonService = DefaultStreamingAddonService(
    repository: addonRepository,
  );

  await addonService.loadCatalog();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PermissionService>(
          create: (_) => PermissionService(),
        ),
        Provider<AddonService>(
          create: (_) => addonService,
          dispose: (_, service) => service.close(),
        ),
        Provider<StreamingAddonService>(
          create: (_) => streamingAddonService,
          dispose: (_, service) => service.close(),
        ),
        Provider<AddonRepository>(
          create: (_) => addonRepository,
          dispose: (_, repository) => repository.close(),
        ),
        Provider<CatalogRepository>(
          create: (_) => CatalogRepository(),
          dispose: (_, repository) => repository.close(),
        ),
        Provider<StreamRepository>(
          create: (context) => StreamRepository(
            addonRepository: context.read<AddonRepository>(),
          ),
          dispose: (_, repository) => repository.close(),
        ),
      ],
      child: const MoviePlatformApp(),
    ),
  );
}

class MoviePlatformApp extends StatefulWidget {
  const MoviePlatformApp({
    super.key,
    this.homeCinemetaService,
  });

  final CinemetaService? homeCinemetaService;

  @override
  State<MoviePlatformApp> createState() => _MoviePlatformAppState();
}

class _MoviePlatformAppState extends State<MoviePlatformApp> {
  static const _themeModeKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final preferences = await SharedPreferences.getInstance();

    final isDark = preferences.getBool(_themeModeKey) ?? true;

    if (!mounted) return;

    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _themeLoaded = true;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();

    final saved = await preferences.setBool(
      _themeModeKey,
      mode == ThemeMode.dark,
    );

    if (!saved) {
      throw StateError(
        'Não foi possível salvar o tema selecionado.',
      );
    }

    if (!mounted) return;

    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final addonRepository =
        Provider.of<AddonRepository>(context, listen: false);

    final catalogRepository =
        Provider.of<CatalogRepository>(context, listen: false);

    final streamRepository =
        Provider.of<StreamRepository>(context, listen: false);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cine Mobile',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,

      // A tela inicial verifica o login antes de abrir o catálogo.
      home: SplashScreen(
        cinemetaService: widget.homeCinemetaService,
        addonRepository: addonRepository,
        catalogRepository: catalogRepository,
        streamRepository: streamRepository,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
        themeLoaded: _themeLoaded,
      ),

      routes: {
        '/player-test': (_) => const PlayerTestScreen(),
        LocalFilesScreen.routeName: (_) => const LocalFilesScreen(),
        MoviesScreen.routeName: (_) => MoviesScreen(
              addonRepository: addonRepository,
              catalogRepository: catalogRepository,
              streamRepository: streamRepository,
            ),
        SearchScreen.routeName: (_) => SearchScreen(
              addonRepository: addonRepository,
              catalogRepository: catalogRepository,
              streamRepository: streamRepository,
            ),
        SeriesScreen.routeName: (_) => SeriesScreen(
              addonRepository: addonRepository,
              catalogRepository: catalogRepository,
              streamRepository: streamRepository,
            ),
        SettingsScreen.routeName: (_) => SettingsScreen(
              themeMode: _themeMode,
              onThemeModeChanged: _setThemeMode,
              themeLoaded: _themeLoaded,
              addonRepository: addonRepository,
              catalogRepository: catalogRepository,
              streamRepository: streamRepository,
            ),
        YoutubeScreen.routeName: (_) => const YoutubeScreen(),
      },

      onGenerateRoute: (settings) {
        if (settings.name != PlayerScreen.routeName) {
          return null;
        }

        final arguments = settings.arguments;

        final playerRequest = arguments is PlayerLaunchRequest
            ? arguments
            : arguments is String
                ? PlayerLaunchRequest(
                    url: arguments,
                    contentId: '',
                  )
                : null;

        if (playerRequest == null) {
          throw ArgumentError.value(
            arguments,
            'settings.arguments',
            'A rota do player exige um arquivo MP4, MKV ou AVI local, '
                'ou uma URL HTTP/HTTPS válida.',
          );
        }

        final request = playerRequest;
        final uri = Uri.tryParse(request.url);

        if (request.isLocalFile) {
          if (request.url.trim().isEmpty ||
              !RegExp(
                r'\.(mp4|mkv|avi)$',
                caseSensitive: false,
              ).hasMatch(request.url)) {
            throw ArgumentError.value(
              arguments,
              'settings.arguments',
              'O player local aceita apenas arquivos MP4, MKV ou AVI.',
            );
          }
        } else if (uri == null ||
            (uri.scheme != 'http' && uri.scheme != 'https') ||
            uri.host.isEmpty) {
          throw ArgumentError.value(
            arguments,
            'settings.arguments',
            'A rota do player exige uma URL HTTP ou HTTPS válida.',
          );
        }

        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => PlayerScreen(
            url: request.url,
            contentId: request.contentId.isEmpty ? null : request.contentId,
            contentType: request.contentType,
            contentTitle: request.contentTitle,
            season: request.season,
            episode: request.episode,
            episodeTitle: request.episodeTitle,
            posterUrl: request.posterUrl,
            startPositionMilliseconds: request.startPositionMilliseconds,
            progressService: request.progressService,
            nextEpisodeTitle: request.nextEpisodeTitle,
            onNextEpisode: request.onNextEpisode,
            addonSubtitles: request.addonSubtitles,
            isLocalFile: request.isLocalFile,
          ),
        );
      },
    );
  }
}

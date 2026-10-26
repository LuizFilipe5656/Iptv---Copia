import 'iptv_screen.dart';
import 'package:flutter/material.dart';

import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import '../services/cinemeta_service.dart';
import '../services/playback_progress_service.dart';

import 'addon_category_screen.dart';
import 'favorites_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.cinemetaService,
    this.addonRepository,
    this.catalogRepository,
    this.streamRepository,
    this.playbackProgressService,
    this.themeMode = ThemeMode.dark,
    this.onThemeModeChanged,
    this.themeLoaded = true,
  });

  final CinemetaService? cinemetaService;
  final AddonRepository? addonRepository;
  final CatalogRepository? catalogRepository;
  final StreamRepository? streamRepository;
  final PlaybackProgressService? playbackProgressService;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode mode)? onThemeModeChanged;
  final bool themeLoaded;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color cyan = Color(0xFF29B6F6);
  static const Color background = Color(0xFF07101F);
  static const Color cardColor = Color(0xFF101C30);

  int selectedTab = 0;

  void openCategory(String category) {
    Widget page;

    switch (category) {
      case 'Filmes':
        page = MoviesScreen(
          cinemetaService: widget.cinemetaService,
          addonRepository: widget.addonRepository,
          catalogRepository: widget.catalogRepository,
          streamRepository: widget.streamRepository,
          playbackProgressService: widget.playbackProgressService,
        );
        break;

      case 'Séries':
        page = SeriesScreen(
          addonRepository: widget.addonRepository,
          catalogRepository: widget.catalogRepository,
          streamRepository: widget.streamRepository,
          playbackProgressService: widget.playbackProgressService,
        );
        break;

      case 'Animes':
        page = AddonCategoryScreen(
          category: AddonCategory.anime,
          addonRepository: widget.addonRepository,
          catalogRepository: widget.catalogRepository,
          streamRepository: widget.streamRepository,
        );
        break;

      case 'IPTV':
        page = const IptvScreen();
        break;

      default:
        page = _CategoryPlaceholder(category: category);
        break;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => page,
      ),
    );
  }

  Widget buildHome() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(
            children: [
              const Icon(
                Icons.movie_creation_outlined,
                color: cyan,
                size: 31,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'CINE MOBILE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Pesquisar',
                icon: const Icon(Icons.search, color: cyan),
                onPressed: () {
                  setState(() => selectedTab = 1);
                },
              ),
              IconButton(
                tooltip: 'Perfil',
                icon: const Icon(
                  Icons.account_circle_outlined,
                  color: cyan,
                ),
                onPressed: () {
                  setState(() => selectedTab = 3);
                },
              ),
            ],
          ),
          const SizedBox(height: 38),
          const Text(
            'Olá! O que deseja assistir?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Escolha uma categoria para explorar.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 30),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.12,
            children: [
              categoryCard(
                'Filmes',
                Icons.movie_outlined,
              ),
              categoryCard(
                'Séries',
                Icons.tv_outlined,
              ),
              categoryCard(
                'IPTV',
                Icons.live_tv_outlined,
              ),
              categoryCard(
                'Animes',
                Icons.auto_awesome_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget categoryCard(String title, IconData icon) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => openCategory(title),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: cyan.withValues(alpha: 0.55),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: cyan.withValues(alpha: 0.10),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: cyan,
              ),
              const SizedBox(height: 17),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildBody() {
    switch (selectedTab) {
      case 1:
        return SearchScreen(
          showAppBar: false,
          addonRepository: widget.addonRepository,
          catalogRepository: widget.catalogRepository,
          streamRepository: widget.streamRepository,
        );

      case 2:
        return FavoritesScreen(
          cinemetaService: widget.cinemetaService,
          addonRepository: widget.addonRepository,
          catalogRepository: widget.catalogRepository,
          streamRepository: widget.streamRepository,
          playbackProgressService: widget.playbackProgressService,
        );

      case 3:
        return SettingsScreen(
          showAppBar: false,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          themeLoaded: widget.themeLoaded,
          addonRepository: widget.addonRepository,
          catalogRepository: widget.catalogRepository,
          streamRepository: widget.streamRepository,
          playbackProgressService: widget.playbackProgressService,
        );

      default:
        return buildHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedTab,
        onTap: (index) {
          setState(() => selectedTab = index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0B1728),
        selectedItemColor: cyan,
        unselectedItemColor: Colors.white54,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Descobrir',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            label: 'Biblioteca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _CategoryPlaceholder extends StatelessWidget {
  const _CategoryPlaceholder({
    required this.category,
  });

  final String category;

  @override
  Widget build(BuildContext context) {
    final isIptv = category == 'IPTV';

    return Scaffold(
      backgroundColor: const Color(0xFF07101F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1728),
        foregroundColor: const Color(0xFF29B6F6),
        title: Text(category),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isIptv ? Icons.live_tv_outlined : Icons.video_library_outlined,
                color: const Color(0xFF29B6F6),
                size: 68,
              ),
              const SizedBox(height: 22),
              Text(
                category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isIptv
                    ? 'A Ã¡rea de TV ao vivo ainda precisa '
                        'de uma fonte de canais compatÃ­vel.'
                    : 'Esta categoria ainda nÃ£o possui '
                        'uma tela configurada.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

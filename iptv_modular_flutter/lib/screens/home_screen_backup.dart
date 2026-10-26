
import 'package:flutter/material.dart';

import '../models/addon.dart';
import '../models/movie.dart';
import '../models/stremio_addon_manifest.dart';
import '../models/stremio_meta_item.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import '../services/cinemeta_service.dart';
import '../services/playback_progress_service.dart';
import '../widgets/continue_watching_section.dart';
import '../widgets/hero_banner.dart';
import '../widgets/movie_card.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

enum _HomeCategory {
  movies,
  series,
  anime,
  cartoons,
  doramas,
}

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
  late final CinemetaService _cinemeta;
  late final bool _ownsService;

  late Future<List<Movie>> _movies;
  late Future<List<Movie>> _series;
  late Future<List<Movie>> _anime;
  late Future<List<Movie>> _cartoons;
  late Future<List<Movie>> _doramas;

  int _selectedNavigationIndex = 0;

  static const int _maxCatalogsPerAddon = 12;
  static const int _maxItemsPerCatalog = 80;
  static const int _maxItemsPerSection = 150;

  @override
  void initState() {
    super.initState();

    _ownsService = widget.cinemetaService == null;
    _cinemeta = widget.cinemetaService ?? CinemetaService();

    _loadCatalogs();
  }

  void _loadCatalogs() {
    _movies = _loadCategory(_HomeCategory.movies);
    _series = _loadCategory(_HomeCategory.series);
    _anime = _loadCategory(_HomeCategory.anime);
    _cartoons = _loadCategory(_HomeCategory.cartoons);
    _doramas = _loadCategory(_HomeCategory.doramas);
  }

  Future<List<Movie>> _loadCategory(
    _HomeCategory category,
  ) async {
    final addonRepository = widget.addonRepository;
    final catalogRepository = widget.catalogRepository;

    final collected = <Movie>[];
    final seen = <String>{};

    if (addonRepository != null &&
        catalogRepository != null) {
      try {
        final addons =
            await addonRepository.getContentMetadataProviders();

        debugPrint(
          '[home] Consultando ${addons.length} addons '
          'para ${category.name}',
        );

        final results = await Future.wait(
          addons.map(
            (addon) => _loadAddonCategory(
              addon: addon,
              category: category,
              addonRepository: addonRepository,
              catalogRepository: catalogRepository,
            ),
          ),
        );

        for (final result in results) {
          for (final movie in result) {
            _addUnique(collected, seen, movie);
          }
        }
      } catch (error) {
        debugPrint(
          '[home] Falha geral nos addons '
          '(${category.name}): $error',
        );
      }
    }

    // Cinemeta continua disponível como complemento.
    // Não é mais a única fonte da tela inicial.
    if (category != _HomeCategory.doramas) {
      try {
        final fallback = await _loadCinemetaCategory(category);

        for (final movie in fallback) {
          _addUnique(collected, seen, movie);
        }
      } catch (error) {
        debugPrint(
          '[home] Cinemeta ${category.name}: $error',
        );
      }
    }

    debugPrint(
      '[home] ${category.name}: '
      '${collected.length} títulos encontrados',
    );

    return collected
        .take(_maxItemsPerSection)
        .toList(growable: false);
  }

  Future<List<Movie>> _loadCinemetaCategory(
    _HomeCategory category,
  ) {
    switch (category) {
      case _HomeCategory.movies:
        return _cinemeta.popularMovies();
      case _HomeCategory.series:
        return _cinemeta.popularSeries();
      case _HomeCategory.anime:
        return _cinemeta.popularAnime();
      case _HomeCategory.cartoons:
        return _cinemeta.popularCartoons();
      case _HomeCategory.doramas:
        return Future.value(<Movie>[]);
    }
  }

  Future<List<Movie>> _loadAddonCategory({
    required Addon addon,
    required _HomeCategory category,
    required AddonRepository addonRepository,
    required CatalogRepository catalogRepository,
  }) async {
    if (!addon.enabled) {
      return const [];
    }

    try {
      final manifest = await addonRepository.getManifest(addon);

      final catalogs = manifest.catalogs
          .where(
            (catalog) => _catalogMatches(
              addon: addon,
              catalog: catalog,
              category: category,
            ),
          )
          .where(_canLoadWithoutParameters)
          .take(_maxCatalogsPerAddon)
          .toList(growable: false);

      if (catalogs.isEmpty) {
        return const [];
      }

      final results = await Future.wait(
        catalogs.map(
          (catalog) async {
            try {
              final items = await catalogRepository.getCatalog(
                addon: addon,
                catalog: catalog,
              );

              final movies = <Movie>[];

              for (final item in items.take(_maxItemsPerCatalog)) {
                if (!_itemMatches(
                  item: item,
                  addon: addon,
                  catalog: catalog,
                  category: category,
                )) {
                  continue;
                }

                try {
                  movies.add(
                    _movieFromStremio(item),
                  );
                } catch (error) {
                  debugPrint(
                    '[home] Item inválido '
                    '${item.id}: $error',
                  );
                }
              }

              return movies;
            } catch (error) {
              debugPrint(
                '[home] Addon ${addon.name}, '
                'catálogo ${catalog.name}: $error',
              );

              return <Movie>[];
            }
          },
        ),
      );

      final collected = <Movie>[];
      final seen = <String>{};

      for (final result in results) {
        for (final movie in result) {
          _addUnique(collected, seen, movie);
        }
      }

      debugPrint(
        '[home] ${addon.name} / ${category.name}: '
        '${collected.length} títulos',
      );

      return collected;
    } catch (error) {
      debugPrint(
        '[home] Addon ${addon.name} indisponível: $error',
      );

      return const [];
    }
  }

  bool _canLoadWithoutParameters(
    StremioCatalog catalog,
  ) {
    return !catalog.extra.any(
      (extra) => extra.isRequired,
    );
  }

  bool _catalogMatches({
    required Addon addon,
    required StremioCatalog catalog,
    required _HomeCategory category,
  }) {
    final type = catalog.type.toLowerCase();

    final label = [
      addon.name,
      addon.id,
      catalog.name,
      catalog.id,
      type,
    ].join(' ').toLowerCase();

    final anime = _containsAny(label, const [
      'anime',
      'animes',
      'kitsu',
    ]);

    final cartoon = _containsAny(label, const [
      'cartoon',
      'cartoons',
      'desenho',
      'animation',
      'animated',
    ]);

    final dorama = _containsAny(label, const [
      'dorama',
      'doramas',
      'kdrama',
      'k-drama',
      'cdrama',
      'c-drama',
      'jdrama',
      'j-drama',
      'korean drama',
      'chinese drama',
      'japanese drama',
      'asian drama',
    ]);

    switch (category) {
      case _HomeCategory.movies:
        return type == 'movie';

      case _HomeCategory.series:
        return type == 'series' ||
            type == 'tv' ||
            type == 'anime' ||
            type == 'cartoon' ||
            type == 'dorama' ||
            type == 'drama';

      case _HomeCategory.anime:
        return type == 'anime' ||
            ((type == 'series' || type == 'tv') && anime);

      case _HomeCategory.cartoons:
        return type == 'cartoon' ||
            ((type == 'series' || type == 'tv') && cartoon);

      case _HomeCategory.doramas:
        return const {
              'dorama',
              'drama',
              'kdrama',
              'cdrama',
              'jdrama',
            }.contains(type) ||
            ((type == 'series' || type == 'tv') && dorama);
    }
  }

  bool _itemMatches({
    required StremioMetaItem item,
    required Addon addon,
    required StremioCatalog catalog,
    required _HomeCategory category,
  }) {
    final type = item.type.toLowerCase();

    if (category == _HomeCategory.movies) {
      return type == 'movie';
    }

    if (category == _HomeCategory.series) {
      return type != 'movie';
    }

    final label = [
      addon.name,
      addon.id,
      catalog.name,
      catalog.id,
      item.name,
      ...item.genres,
    ].join(' ').toLowerCase();

    if (category == _HomeCategory.anime) {
      return type == 'anime' ||
          _containsAny(label, const [
            'anime',
            'animes',
          ]);
    }

    if (category == _HomeCategory.cartoons) {
      return type == 'cartoon' ||
          _containsAny(label, const [
            'cartoon',
            'animation',
            'animated',
            'desenho',
            'animação',
          ]);
    }

    return const {
          'dorama',
          'drama',
          'kdrama',
          'cdrama',
          'jdrama',
        }.contains(type) ||
        _containsAny(label, const [
          'dorama',
          'doramas',
          'kdrama',
          'k-drama',
          'cdrama',
          'c-drama',
          'jdrama',
          'j-drama',
          'korean drama',
          'chinese drama',
          'japanese drama',
          'asian drama',
        ]);
  }

  bool _containsAny(
    String value,
    List<String> terms,
  ) {
    return terms.any(value.contains);
  }

  Movie _movieFromStremio(
    StremioMetaItem item,
  ) {
    final raw = item.raw;

    final description = _firstText(
      raw,
      const [
        'description',
        'overview',
        'summary',
        'plot',
      ],
    );

    final rating = double.tryParse(
      item.imdbRating.replaceAll(',', '.'),
    );

    final releaseYear = int.tryParse(
      RegExp(r'\d{4}')
              .firstMatch(item.releaseInfo)
              ?.group(0) ??
          '',
    );

    final imdbId = _extractImdbId(item.id, raw);

    return Movie(
      id: item.id,
      imdbId: imdbId,
      title: item.name,
      type: item.type,
      overview: description,
      posterUrl: item.poster,
      bannerUrl: item.background,
      imdbRating: rating,
      releaseYear: releaseYear,
      genres: item.genres,
    );
  }

  String _firstText(
    Map<String, dynamic> raw,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = raw[key];

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  String? _extractImdbId(
    String id,
    Map<String, dynamic> raw,
  ) {
    final candidates = <Object?>[
      raw['imdb_id'],
      raw['imdbId'],
      id,
    ];

    for (final candidate in candidates) {
      if (candidate is! String) {
        continue;
      }

      final match = RegExp(
        r'tt\d+',
        caseSensitive: false,
      ).firstMatch(candidate);

      if (match != null) {
        return match.group(0);
      }
    }

    return null;
  }

  void _addUnique(
    List<Movie> movies,
    Set<String> seen,
    Movie movie,
  ) {
    final normalizedTitle = movie.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    final category = movie.type.toLowerCase() == 'movie'
        ? 'movie'
        : 'series';

    final key = movie.imdbId != null
        ? '$category:${movie.imdbId}'
        : '$category:$normalizedTitle';

    if (seen.add(key)) {
      movies.add(movie);
    }
  }

  @override
  void dispose() {
    if (_ownsService) {
      _cinemeta.close();
    }

    super.dispose();
  }

  void _retryMovies() {
    setState(() {
      _movies = _loadCategory(_HomeCategory.movies);
    });
  }

  void _retrySeries() {
    setState(() {
      _series = _loadCategory(_HomeCategory.series);
    });
  }

  void _retryAnime() {
    setState(() {
      _anime = _loadCategory(_HomeCategory.anime);
    });
  }

  void _retryCartoons() {
    setState(() {
      _cartoons = _loadCategory(_HomeCategory.cartoons);
    });
  }

  void _retryDoramas() {
    setState(() {
      _doramas = _loadCategory(_HomeCategory.doramas);
    });
  }

  void _refreshAllCatalogs() {
    setState(_loadCatalogs);
  }

  void _selectNavigationItem(int index) {
    setState(() {
      _selectedNavigationIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _homeAppBar(context),
      body: IndexedStack(
        index: _selectedNavigationIndex,
        children: [
          _homeContent(),
          SearchScreen(
            showAppBar: false,
            addonRepository: widget.addonRepository,
            catalogRepository: widget.catalogRepository,
            streamRepository: widget.streamRepository,
          ),
          SettingsScreen(
            showAppBar: false,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
            themeLoaded: widget.themeLoaded,
            addonRepository: widget.addonRepository,
            catalogRepository: widget.catalogRepository,
            streamRepository: widget.streamRepository,
            playbackProgressService:
                widget.playbackProgressService,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _homeAppBar(
    BuildContext context,
  ) {
    return AppBar(
      toolbarHeight: 66,
      titleSpacing: 12,
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_creation_outlined,
            color: Color(0xFF29B6F6),
          ),
          SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Cine Mobile',
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Atualizar catálogos',
          onPressed: _refreshAllCatalogs,
          icon: const Icon(Icons.refresh),
        ),
        SizedBox(
          width: MediaQuery.sizeOf(context).width < 450
              ? MediaQuery.sizeOf(context).width * 0.27
              : MediaQuery.sizeOf(context).width * 0.36,
          child: Tooltip(
            message: 'Buscar',
            child: TextField(
              readOnly: true,
              onTap: () => Navigator.pushNamed(
                context,
                SearchScreen.routeName,
              ),
              decoration: const InputDecoration(
                hintText: 'Buscar',
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white54,
                ),
                isDense: true,
                filled: true,
                fillColor: Color(0xFF131C2D),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(24),
                  ),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Perfil e configurações',
          onPressed: () => _selectNavigationItem(2),
          icon: const Icon(
            Icons.account_circle_outlined,
            color: Colors.white,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            children: [
              _navButton('INÍCIO', 0),
              _navButton('DESCOBRIR', 1),
              _navButton('CONFIGURAÇÕES', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton(
    String label,
    int index,
  ) {
    final selected =
        _selectedNavigationIndex == index;

    final compact =
        MediaQuery.sizeOf(context).width < 450;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? const Color(0xFF1565C0)
            : const Color(0xFF131C2D),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _selectNavigationItem(index),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 17,
              vertical: 9,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white60,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 10 : 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeContent() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _featuredBanner(),
        ContinueWatchingSection(
          service: widget.playbackProgressService,
        ),
        _catalogSection(
          title: 'FILMES POPULARES',
          future: _movies,
          onRetry: _retryMovies,
          onViewAll: () => _selectNavigationItem(1),
        ),
        _catalogSection(
          title: 'FILMES EM DESTAQUE',
          future: _movies,
          onRetry: _retryMovies,
          featured: true,
          onViewAll: () => _selectNavigationItem(1),
        ),
        _catalogSection(
          title: 'SÉRIES POPULARES',
          future: _series,
          onRetry: _retrySeries,
          onViewAll: () => _selectNavigationItem(1),
        ),
        _catalogSection(
          title: 'SÉRIES EM DESTAQUE',
          future: _series,
          onRetry: _retrySeries,
          featured: true,
          onViewAll: () => _selectNavigationItem(1),
        ),
        _catalogSection(
          title: 'ANIMES',
          future: _anime,
          onRetry: _retryAnime,
          onViewAll: () => _selectNavigationItem(1),
        ),
        _catalogSection(
          title: 'DORAMAS',
          future: _doramas,
          onRetry: _retryDoramas,
          onViewAll: () => _selectNavigationItem(1),
        ),
        _catalogSection(
          title: 'DESENHOS',
          future: _cartoons,
          onRetry: _retryCartoons,
          onViewAll: () => _selectNavigationItem(1),
        ),
      ],
    );
  }

  Widget _featuredBanner() {
    return FutureBuilder<List<Movie>>(
      future: _movies,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return HeroBanner(
            title: 'Destaque',
            subtitle:
                'Não foi possível carregar os filmes.',
            actionLabel: 'Tentar novamente',
            onAction: _retryMovies,
          );
        }

        if (!snapshot.hasData) {
          return const HeroBanner(
            title: 'Destaque',
            subtitle: 'Carregando filmes...',
          );
        }

        final movies = snapshot.data!;

        if (movies.isEmpty) {
          return const HeroBanner(
            title: 'Cine Mobile',
            subtitle:
                'Descubra filmes e séries para assistir.',
          );
        }

        final featured = movies.first;

        return HeroBanner(
          title: featured.title,
          subtitle: featured.overview.isNotEmpty
              ? featured.overview
              : 'Filme em destaque'
                  '${featured.releaseYear == null ? '' : ' · ${featured.releaseYear}'}',
          backgroundImage: featured.bannerUrl ??
              featured.posterUrl ??
              (featured.fallbackPoster.isEmpty
                  ? null
                  : featured.fallbackPoster),
          actionLabel: 'Ver detalhes',
          onAction: () => MovieCard(
            movie: featured,
            cinemetaService: _cinemeta,
            addonRepository: widget.addonRepository,
            catalogRepository: widget.catalogRepository,
            streamRepository: widget.streamRepository,
            playbackProgressService:
                widget.playbackProgressService,
          ).showDetails(context),
        );
      },
    );
  }

  Widget _catalogSection({
    required String title,
    required Future<List<Movie>> future,
    required VoidCallback onRetry,
    bool featured = false,
    VoidCallback? onViewAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge,
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('Ver tudo'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Movie>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _CatalogMessage(
                  message:
                      'Falha ao carregar o catálogo: ${snapshot.error}',
                  onRetry: onRetry,
                );
              }

              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 210,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final movies = [...snapshot.data!];

              if (featured) {
                movies.sort(
                  (first, second) =>
                      (second.imdbRating ?? 0).compareTo(
                    first.imdbRating ?? 0,
                  ),
                );
              }

              if (movies.isEmpty) {
                return const SizedBox(
                  height: 72,
                  child: Center(
                    child: Text(
                      'Nenhum título encontrado.',
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 270,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: movies.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      MovieCard(
                    movie: movies[index],
                    cinemetaService: _cinemeta,
                    addonRepository:
                        widget.addonRepository,
                    catalogRepository:
                        widget.catalogRepository,
                    streamRepository:
                        widget.streamRepository,
                    playbackProgressService:
                        widget.playbackProgressService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

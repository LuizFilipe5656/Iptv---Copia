import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/cinemeta_service.dart';
import '../widgets/movie_card.dart';
import '../services/anime_catalog_service.dart';
import '../services/anime_stremio_adapter.dart';
import '../models/addon.dart';
import '../models/stremio_addon_manifest.dart';
import '../models/stremio_meta_item.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import 'stremio_details_screen.dart';
import 'stream_sources_sheet.dart';
import '../services/dorama_catalog_service.dart';
import '../services/external_episode_service.dart';

enum AddonCategory {
  movies,
  series,
  anime,
  cartoons,
  doramas,
  combinedSeries,
}

class AddonCategoryScreen extends StatefulWidget {
  const AddonCategoryScreen({
    super.key,
    required this.category,
    this.addonRepository,
    this.catalogRepository,
    this.streamRepository,
  });

  final AddonCategory category;
  final AddonRepository? addonRepository;
  final CatalogRepository? catalogRepository;
  final StreamRepository? streamRepository;

  @override
  State<AddonCategoryScreen> createState() => _AddonCategoryScreenState();
}

class _CatalogEntry {
  const _CatalogEntry({
    required this.addon,
    required this.item,
    this.movie,
  });

  final Addon addon;
  final StremioMetaItem item;
  final Movie? movie;
}

class _AddonCategoryScreenState extends State<AddonCategoryScreen> {
  static const cyan = Color(0xFF29B6F6);
  static const background = Color(0xFF07101F);

  late final AddonRepository addons =
      widget.addonRepository ?? AddonRepository();

  late final DoramaCatalogService doramaService = DoramaCatalogService();
  late final CinemetaService cinemetaService = CinemetaService();
  bool loadingMoreSeries = false;
  bool hasMoreSeries = true;
  int seriesSkip = 0;
  String? seriesLoadError;

  late final CatalogRepository catalogs =
      widget.catalogRepository ?? CatalogRepository();

  late final StreamRepository streams =
      widget.streamRepository ?? StreamRepository(addonRepository: addons);
  late final AnimeCatalogService animeService = AnimeCatalogService();
  final List<_CatalogEntry> items = [];
  final Set<String> seen = {};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _genre = 'Todos';
  String _sort = 'Padrão';
  int? _yearFrom;
  int? _yearTo;

  int? _itemYear(StremioMetaItem item) {
    final raw = item.raw;
    final value = raw['releaseInfo'] ?? raw['year'] ?? raw['released'];
    final match = RegExp(r'(19|20)\\d{2}').firstMatch(value?.toString() ?? '');
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  List<_CatalogEntry> get visibleItems {
    final q = normalize(_query.trim());
    final result = items.where((entry) {
      final item = entry.item;
      if (q.isNotEmpty &&
          !normalize('${item.name} ${item.description}').contains(q)) {
        return false;
      }
      if (_genre != 'Todos' &&
          !normalize(item.genres.join(' ')).contains(normalize(_genre))) {
        return false;
      }
      if (_yearFrom != null || _yearTo != null) {
        final year = _itemYear(item);
        if (year == null ||
            (_yearFrom != null && year < _yearFrom!) ||
            (_yearTo != null && year > _yearTo!)) return false;
      }
      return true;
    }).toList();
    if (_sort == 'A-Z') {
      result.sort((a, b) => normalize(a.item.name).compareTo(normalize(b.item.name)));
    } else if (_sort == 'Z-A') {
      result.sort((a, b) => normalize(b.item.name).compareTo(normalize(a.item.name)));
    } else if (_sort == 'Mais recentes') {
      result.sort((a, b) => (_itemYear(b.item) ?? 0).compareTo(_itemYear(a.item) ?? 0));
    }
    return result;
  }

  Future<void> _openCategoryFilters() async {
    final genres = items.expand((e) => e.item.genres).where((e) => e.trim().isNotEmpty).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    String genre = _genre;
    String sort = _sort;
    final from = TextEditingController(text: _yearFrom?.toString() ?? '');
    final to = TextEditingController(text: _yearTo?.toString() ?? '');
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF101A2D),
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, updateSheet) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filtrar categoria', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 18),
                    const Text('Gênero', style: TextStyle(color: cyan)),
                    DropdownButtonFormField<String>(
                      value: genres.contains(genre) || genre == 'Todos' ? genre : 'Todos',
                      dropdownColor: const Color(0xFF101A2D),
                      style: const TextStyle(color: Colors.white),
                      items: ['Todos', ...genres].map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => updateSheet(() => genre = v ?? 'Todos'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Ano de lançamento', style: TextStyle(color: cyan)),
                    Row(children: [
                      Expanded(child: TextField(controller: from, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'De'))),
                      const SizedBox(width: 14),
                      Expanded(child: TextField(controller: to, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Até'))),
                    ]),
                    const SizedBox(height: 16),
                    const Text('Ordenar', style: TextStyle(color: cyan)),
                    DropdownButtonFormField<String>(
                      value: sort,
                      dropdownColor: const Color(0xFF101A2D),
                      style: const TextStyle(color: Colors.white),
                      items: ['Padrão', 'A-Z', 'Z-A', 'Mais recentes'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                      onChanged: (v) => updateSheet(() => sort = v ?? 'Padrão'),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      TextButton(onPressed: () {
                        setState(() { _genre = 'Todos'; _sort = 'Padrão'; _yearFrom = null; _yearTo = null; });
                        Navigator.pop(sheetContext);
                      }, child: const Text('Limpar')),
                      const Spacer(),
                      FilledButton(onPressed: () {
                        final first = int.tryParse(from.text.trim());
                        final last = int.tryParse(to.text.trim());
                        if ((first != null && (first < 1900 || first > 2100)) ||
                            (last != null && (last < 1900 || last > 2100)) ||
                            (first != null && last != null && first > last)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confira o intervalo de anos.')));
                          return;
                        }
                        setState(() { _genre = genre; _sort = sort; _yearFrom = first; _yearTo = last; });
                        Navigator.pop(sheetContext);
                      }, child: const Text('Aplicar')),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      from.dispose();
      to.dispose();
    }
  }

  bool loading = false;
  int failures = 0;
  int checkedCatalogs = 0;
  int generation = 0;

  String get title => switch (widget.category) {
        AddonCategory.movies => 'Filmes',
        AddonCategory.series => 'Séries',
        AddonCategory.anime => 'Animes',
        AddonCategory.cartoons => 'Desenhos',
        AddonCategory.doramas => 'Doramas',
        AddonCategory.combinedSeries => 'Séries',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    generation++;
    _searchController.dispose();
    if (widget.addonRepository == null) addons.close();
    if (widget.catalogRepository == null) catalogs.close();
    if (widget.streamRepository == null) streams.close();
    doramaService.close();
    cinemetaService.close();
    animeService.close();
    super.dispose();
  }

  String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp('[áàâãä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll('ç', 'c');
  }

  bool hasAny(String value, List<String> terms) {
    final text = normalize(value);
    return terms.any((term) => text.contains(term));
  }

  bool isAnime(String text) => hasAny(text, [
        'anime',
        'animes',
        'japanese animation',
        'animacao japonesa',
        'myanimelist',
        'anilist',
      ]);

  bool isCartoon(String text) => hasAny(text, [
        'cartoon',
        'cartoons',
        'animation',
        'animated',
        'animacao',
        'desenho',
        'desenhos',
        'kids',
        'infantil',
      ]);

  bool isDorama(String text) => hasAny(text, [
        'dorama',
        'doramas',
        'k-drama',
        'kdrama',
        'j-drama',
        'jdrama',
        'c-drama',
        'cdrama',
        'korean drama',
        'japanese drama',
        'chinese drama',
        'drama coreano',
        'drama japones',
        'drama chines',
        'asian drama',
        'drama asiatico',
      ]);

  bool isMovie(String type) =>
      normalize(type) == 'movie' || normalize(type) == 'film';

  bool isSeries(String type) =>
      normalize(type) == 'series' ||
      normalize(type) == 'tv' ||
      normalize(type) == 'show';

  bool catalogIsRelevant(
    Addon addon,
    StremioCatalog catalog,
  ) {
    final type = normalize(catalog.type);

    if (!isMovie(type) &&
        !isSeries(type) &&
        type != 'anime' &&
        type != 'channel') {
      return false;
    }

    if (type == 'channel') return false;

    final label = '${catalog.name} ${catalog.id} '
        '${addon.name}';

    final anime = isAnime(label);
    final cartoon = isCartoon(label);
    final dorama = isDorama(label);

    switch (widget.category) {
      case AddonCategory.anime:
        return type == 'anime' || anime || isMovie(type) || isSeries(type);

      case AddonCategory.cartoons:
        return cartoon || isMovie(type) || isSeries(type);

      case AddonCategory.doramas:
        return dorama || isSeries(type);

      case AddonCategory.movies:
        return isMovie(type);

      case AddonCategory.series:
        return isSeries(type);
      case AddonCategory.combinedSeries:
        return isSeries(type);
    }
  }

  bool matches(
    Addon addon,
    StremioCatalog catalog,
    StremioMetaItem item,
  ) {
    final catalogLabel = normalize(
      '${catalog.name} ${catalog.id}',
    );
    final addonLabel = normalize(addon.name);
    final itemType = normalize(item.type);
    final genres = normalize(item.genres.join(' '));
    final itemName = normalize(item.name);
    final specializedAnimeCatalog = isAnime(catalogLabel);
    final specializedCartoonCatalog =
        isCartoon(catalogLabel) && !specializedAnimeCatalog;
    final specializedDoramaCatalog = isDorama(catalogLabel);
    final specializedAnimeAddon = isAnime(addonLabel);
    final specializedCartoonAddon =
        isCartoon(addonLabel) && !specializedAnimeAddon;
    final specializedDoramaAddon = isDorama(addonLabel);
    final animeMetadata =
        itemType == 'anime' || isAnime(genres) || isAnime(itemName);
    final cartoonMetadata = isCartoon(genres) || isCartoon(itemName);
    final doramaMetadata = isDorama(genres) || isDorama(itemName);
    final anime =
        animeMetadata || specializedAnimeCatalog || specializedAnimeAddon;
    final dorama =
        doramaMetadata || specializedDoramaCatalog || specializedDoramaAddon;
    final cartoon = !anime &&
        !dorama &&
        (cartoonMetadata ||
            specializedCartoonCatalog ||
            specializedCartoonAddon);
    switch (widget.category) {
      case AddonCategory.anime:
        return anime;
      case AddonCategory.cartoons:
        return cartoon;
      case AddonCategory.doramas:
        return dorama;
      case AddonCategory.movies:
        return isMovie(item.type) && !anime && !cartoon && !dorama;
      case AddonCategory.series:
        return isSeries(item.type) && !anime && !cartoon && !dorama;
      case AddonCategory.combinedSeries:
        return isSeries(item.type) && !anime;
    }
  }

  Map<String, String>? catalogExtras(
    StremioCatalog catalog,
  ) {
    final result = <String, String>{};

    for (final extra in catalog.extra) {
      if (!extra.isRequired) continue;

      final key = normalize(extra.name);

      // Catálogos de pesquisa precisam de um termo.
      // Não fazemos pesquisas arbitrárias nesta tela.
      if (key == 'search' || key == 'query' || key == 'q') {
        return null;
      }

      // Só preenche automaticamente quando existe
      // exatamente uma opção válida.
      if (extra.options.length == 1) {
        result[extra.name] = extra.options.first;
      } else {
        return null;
      }
    }

    // Usa filtros de gênero quando disponíveis.
    if (widget.category == AddonCategory.anime ||
        widget.category == AddonCategory.cartoons) {
      for (final extra in catalog.extra) {
        if (normalize(extra.name) != 'genre') continue;

        final wanted = widget.category == AddonCategory.anime
            ? ['anime']
            : ['animation', 'animacao', 'cartoon'];

        for (final option in extra.options) {
          if (hasAny(option, wanted)) {
            result[extra.name] = option;
            break;
          }
        }
      }
    }

    return result;
  }


  void _addCinemetaMovies(List<Movie> movies) {
    final source = Addon(id: 'catalog_cinemeta', name: 'Cinemeta');
    final batch = <_CatalogEntry>[];
    for (final movie in movies) {
      final key = 'series|${movie.id}';
      if (!seen.add(key)) continue;
      final item = StremioMetaItem.fromJson({
        'id': movie.id,
        'type': 'series',
        'name': movie.title,
        'description': movie.overview,
        'poster': movie.posterUrl,
        'year': movie.releaseYear,
        'genres': movie.genres,
      });
      batch.add(_CatalogEntry(addon: source, item: item, movie: movie));
    }
    if (mounted && batch.isNotEmpty) {
      setState(() => items.addAll(batch));
    }
  }

  Future<void> _loadMoreSeries() async {
    if (loadingMoreSeries || !hasMoreSeries) return;
    setState(() {
      loadingMoreSeries = true;
      seriesLoadError = null;
    });
    try {
      final next = await cinemetaService.seriesPage(seriesSkip);
      if (!mounted) return;
      final before = seen.length;
      _addCinemetaMovies(next);
      seriesSkip += next.length;
      setState(() {
        hasMoreSeries = next.isNotEmpty && seen.length > before;
      });
    } catch (error) {
      if (mounted) setState(() => seriesLoadError = error.toString());
    } finally {
      if (mounted) setState(() => loadingMoreSeries = false);
    }
  }

  Future<void> _load() async {
    final currentGeneration = ++generation;
    setState(() {
      loading = true;
      failures = 0;
      checkedCatalogs = 0;
      items.clear();
      seen.clear();
      seriesSkip = 0;
      hasMoreSeries = true;
      seriesLoadError = null;
    });
    if (widget.category == AddonCategory.combinedSeries) {
      // Fetch the initial Cinemeta page without blocking addon loading.
      _loadMoreSeries();
    }
    try {
      final installed = await addons
          .getInstalledAddons()
          .timeout(const Duration(seconds: 20));
      debugPrint('ADDONS INSTALADOS: ${installed.length}');
      // Catalogos independentes: nao representam addons de reproducao.
      if (widget.category == AddonCategory.doramas ||
          widget.category == AddonCategory.combinedSeries) {
        try {
          final doramas = await doramaService.getPopularDoramas();
          if (!mounted || currentGeneration != generation) return;
          final source = Addon(
            id: 'catalog_tvmaze',
            name: 'TVMaze (catÃ¡logo)',
          );
          final batch = <_CatalogEntry>[];
          for (final item in doramas) {
            final key = '${item.type}|${item.id}';
            if (seen.add(key)) {
              batch.add(_CatalogEntry(addon: source, item: item));
            }
          }
          if (batch.isNotEmpty) setState(() => items.addAll(batch));
          debugPrint('[cine-catalog] TVMaze: ${batch.length} doramas');
        } catch (error) {
          failures++;
          debugPrint('[cine-catalog] Erro TVMaze: $error');
        }
      } else if (widget.category == AddonCategory.anime) {
        try {
          final animes = await animeService.getPopularAnimes();
          if (!mounted || currentGeneration != generation) return;
          final batch = <_CatalogEntry>[];
          for (final anime in animes) {
            final item = AnimeStremioAdapter.convert(anime);
            final key = '${item.type}|${item.id}';
            if (seen.add(key)) {
              batch.add(_CatalogEntry(
                addon: Addon(
                  id: 'catalog_${anime.source.toLowerCase()}',
                  name: '${anime.source} (catÃ¡logo)',
                ),
                item: item,
              ));
            }
          }
          if (batch.isNotEmpty) setState(() => items.addAll(batch));
          debugPrint('[cine-catalog] Anime: ${batch.length} tÃ­tulos');
        } catch (error) {
          failures++;
          debugPrint('[cine-catalog] Erro Anime: $error');
        }
      }
      for (final addon in installed) {
        if (!mounted || currentGeneration != generation) return;
        StremioAddonManifest manifest;
        try {
          manifest = await addons
              .getManifest(addon)
              .timeout(const Duration(seconds: 15));
          debugPrint(
            'MANIFEST OK: ${addon.name} | '
            '${manifest.catalogs.length} catalogos',
          );
        } catch (error) {
          failures++;
          debugPrint(
            'ERRO MANIFEST: ${addon.name} | $error',
          );
          continue;
        }
        final relevant = manifest.catalogs
            .where((catalog) => catalogIsRelevant(addon, catalog))
            .toList();
        relevant.sort((a, b) {
          int score(StremioCatalog catalog) {
            final text = '${catalog.name} ${catalog.id}';
            return switch (widget.category) {
              AddonCategory.anime => isAnime(text) ? 0 : 1,
              AddonCategory.cartoons => isCartoon(text) ? 0 : 1,
              AddonCategory.doramas => isDorama(text) ? 0 : 1,
              _ => 0,
            };
          }

          return score(a).compareTo(score(b));
        });
        debugPrint(
          'ADDON: ${addon.name} | '
          'Catalogos relevantes: ${relevant.length}',
        );
        for (final catalog in relevant) {
          if (!mounted || currentGeneration != generation) return;
          final extra = catalogExtras(catalog);
          if (extra == null) {
            debugPrint(
              'CATALOGO IGNORADO: ${addon.name} | '
              '${catalog.name} | extras obrigatorios',
            );
            continue;
          }
          checkedCatalogs++;
          try {
            final results = await catalogs
                .getCatalog(
                  addon: addon,
                  catalog: catalog,
                  extra: extra,
                )
                .timeout(const Duration(seconds: 15));
            final batch = <_CatalogEntry>[];
            var approved = 0;
            for (final item in results) {
              if (!matches(addon, catalog, item)) {
                if (results.indexOf(item) < 5) {
                  debugPrint(
                    '[cine-filter] REJEITADO | '
                    'categoria=${widget.category.name} | '
                    'addon=${addon.name} | '
                    'catalogo=${catalog.name} | '
                    'titulo=${item.name} | '
                    'tipo=${item.type} | '
                    'generos=${item.genres.join(", ")}',
                  );
                }
                continue;
              }
              approved++;
              final key = '${item.type}|${item.id}';
              if (seen.add(key)) {
                batch.add(
                  _CatalogEntry(
                    addon: addon,
                    item: item,
                  ),
                );
              }
            }
            debugPrint(
              'CATALOGO OK: ${addon.name} | '
              '${catalog.name} | '
              'Recebidos: ${results.length} | '
              'Aprovados: $approved',
            );
            if (batch.isNotEmpty &&
                mounted &&
                currentGeneration == generation) {
              setState(() => items.addAll(batch));
            }
          } catch (error) {
            failures++;
            debugPrint(
              'ERRO CATALOGO: ${addon.name} | '
              '${catalog.name} | $error',
            );
          }
        }
      }
    } catch (error) {
      failures++;
      debugPrint('ERRO GERAL ADDONS: $error');
    } finally {
      if (mounted && currentGeneration == generation) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> openDetails(_CatalogEntry entry) async {
    var item = entry.item;

    try {
      if (!item.id.startsWith('tvmaze:') && !item.id.startsWith('mal:')) {
        final manifest = await addons.getManifest(entry.addon);

        if (manifest.supportsResource(
          'meta',
          item.type,
          item.id,
        )) {
          item = await catalogs.getMeta(
            addon: entry.addon,
            type: item.type,
            id: item.id,
            fallback: item,
          );
        }
      }
    } catch (_) {
      // Mantém os metadados do catálogo.
    }

    // Titulos externos nao possuem manifesto de addon Stremio.
    // Carrega episodios usando o identificador original (tvmaze:/mal:).
    if (item.id.startsWith('tvmaze:') || item.id.startsWith('mal:')) {
      item = await ExternalEpisodeService.enrich(item);
    }
    if (!mounted) return;

    final selectedItem = item;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StremioDetailsScreen(
          item: selectedItem,
          catalogAddon: entry.addon,
          addonRepository: addons,
          catalogRepository: catalogs,
          streamRepository: streams,
          streamAvailability: _hasStream(
            selectedItem,
          ),
          onWatch: (context) => _showSources(context, selectedItem),
        ),
      ),
    );
  }

  Future<bool> _hasStream(
    StremioMetaItem item,
  ) async {
    try {
      final installed = await addons.getInstalledAddons();

      for (final addon in installed) {
        try {
          final manifest = await addons.getManifest(addon);
          debugPrint(
              'MANIFEST OK: ${addon.name} - ${manifest.catalogs.length} catalogos');

          if (manifest.supportsResource(
            'stream',
            item.type,
            item.id,
          )) {
            return true;
          }
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  Future<void> _showSources(
    BuildContext context,
    StremioMetaItem item,
  ) async {
    try {
      final installed = await addons.getInstalledAddons();

      if (!context.mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => StremioSourcesSheet(
          item: item,
          addons: installed,
          repository: streams,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Falha ao consultar fontes: $error',
          ),
        ),
      );
    }
  }

  Widget buildPoster(StremioMetaItem item) {
    final url = item.poster;

    if (url == null || url.isEmpty) {
      return const Center(
        child: Icon(
          Icons.movie_outlined,
          color: cyan,
          size: 42,
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      cacheWidth: 320,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget buildCard(_CatalogEntry entry) {
    if (entry.movie != null) {
      return MovieCard(
        movie: entry.movie!,
        cinemetaService: cinemetaService,
        addonRepository: addons,
        catalogRepository: catalogs,
        streamRepository: streams,
      );
    }
    return InkWell(
      onTap: () => openDetails(entry),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                color: const Color(0xFF101C30),
                child: buildPoster(entry.item),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            entry.item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            entry.addon.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: cyan,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1728),
        foregroundColor: cyan,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Atualizar catálogos',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar em $title',
                  prefixIcon: const Icon(Icons.search, color: cyan),
                  suffixIcon: _query.isEmpty ? null : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () { _searchController.clear(); setState(() => _query = ''); },
                  ),
                  filled: true,
                  fillColor: const Color(0xFF101C30),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              )),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Filtrar categoria',
                onPressed: _openCategoryFilters,
                icon: const Icon(Icons.tune),
              ),
            ]),
          ),
          if (loading)
            const LinearProgressIndicator(
              color: cyan,
              minHeight: 2,
            ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                4,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${visibleItems.length} de ${items.length} títulos'
                  '${loading ? ' · carregando...' : ''}',
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            loading ? Icons.sync : Icons.video_library_outlined,
                            color: cyan,
                            size: 52,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            loading
                                ? 'Buscando $title nos addons...'
                                : 'Nenhum título encontrado em $title.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          if (!loading) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Catálogos consultados: '
                              '$checkedCatalogs\n'
                              'Falhas: $failures\n'
                              'Confira se seus addons '
                              'publicam catálogos '
                              'compatíveis.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white60,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextButton.icon(
                              onPressed: _load,
                              icon: const Icon(
                                Icons.refresh,
                              ),
                              label: const Text(
                                'Tentar novamente',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : visibleItems.isEmpty
                    ? const Center(child: Text('Nenhum título corresponde à busca ou aos filtros.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)))
                : GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.48,
                    ),
                    itemCount: visibleItems.length,
                    itemBuilder: (context, index) => buildCard(visibleItems[index]),
                  ),
          ),
          if (widget.category == AddonCategory.combinedSeries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: loadingMoreSeries
                  ? const CircularProgressIndicator()
                  : hasMoreSeries
                      ? TextButton.icon(
                          onPressed: _loadMoreSeries,
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Carregar mais séries'),
                        )
                      : const Text('Fim das páginas disponíveis'),
            ),
          if (widget.category == AddonCategory.combinedSeries &&
              seriesLoadError != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Falha na paginação: $seriesLoadError'),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../models/stremio_meta_item.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import '../services/cinemeta_service.dart';
import '../widgets/movie_card.dart';
import '../widgets/search_bar.dart';
import 'stremio_details_screen.dart';
import 'stream_sources_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.addonRepository,
    this.catalogRepository,
    this.streamRepository,
    this.showAppBar = true,
    this.initialQuery = '',
    this.autoSearch = true,
  });

  static const routeName = '/search';
  final bool showAppBar;
  final String initialQuery;
  final bool autoSearch;
  final AddonRepository? addonRepository;
  final CatalogRepository? catalogRepository;
  final StreamRepository? streamRepository;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final CinemetaService _cinemeta = CinemetaService();
  late final TextEditingController _queryController;
  Timer? _debounce;
  Future<List<Movie>>? _results;
  Future<AddonCatalogSearchResponse>? _stremioResults;
  Set<String> _selectedTypes = {'movie', 'series', 'anime', 'cartoon'};
  Set<String> _selectedGenres = {};
  int? _yearFrom;
  int? _yearTo;
  double _minimumRating = 0;
  String? _status;
  String _sortOrder = 'popular';

  static const _types = {
    'movie': 'Filmes',
    'series': 'Séries',
    'anime': 'Animes',
    'cartoon': 'Desenhos',
  };
  static const _genres = [
    'Ação',
    'Aventura',
    'Comédia',
    'Drama',
    'Terror',
    'Ficção Científica',
    'Romance',
    'Suspense',
    'Fantasia',
    'Mistério',
    'Família',
    'Infantil',
    'Documentário',
    'Crime',
  ];
  static const _genreAliases = {
    'acao': {'action'},
    'aventura': {'adventure'},
    'comedia': {'comedy'},
    'drama': {'drama'},
    'terror': {'horror', 'terror'},
    'ficcaocientifica': {'sciencefiction', 'scifi'},
    'romance': {'romance'},
    'suspense': {'thriller', 'suspense'},
    'fantasia': {'fantasy'},
    'misterio': {'mystery'},
    'familia': {'family'},
    'infantil': {'children', 'kids', 'child'},
    'documentario': {'documentary'},
    'crime': {'crime'},
  };

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _search(widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _cinemeta.close();
    super.dispose();
  }

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        if (widget.addonRepository != null &&
            widget.catalogRepository != null) {
          _results = null;
          _stremioResults = _searchStremioAddons(query);
        } else {
          if (query.trim().isEmpty) {
            _results = Future.wait([
              _cinemeta.popularMovies(),
              _cinemeta.popularSeries(),
            ]).then((results) => [...results[0], ...results[1]]);
          } else {
            _results = Future.wait([
              _cinemeta.searchMovies(query),
              _cinemeta.searchSeries(query),
            ]).then((results) => [...results[0], ...results[1]]);
          }
          _stremioResults = null;
        }
      });
    });
  }

  Future<AddonCatalogSearchResponse> _searchStremioAddons(
    String query,
  ) async {
    final addonRepository = widget.addonRepository!;
    final catalogRepository = widget.catalogRepository!;
    final addons = await addonRepository.getContentMetadataProviders();
    final types = <String>{
      if (_selectedTypes.contains('movie')) 'movie',
      if (_selectedTypes.any((type) => type != 'movie')) 'series',
    };
    final catalogFilters = <String, String>{
      if (_selectedGenres.length == 1) 'genre': _selectedGenres.single,
      if (_yearFrom != null && _yearTo == _yearFrom)
        'year': '$_yearFrom',
      if (_status != null) 'status': _status!,
    };
    final response = await catalogRepository.searchAcrossAddons(
      addons: addons,
      query: query,
      loadManifest: addonRepository.getManifest,
      types: types,
      catalogFilters: catalogFilters,
    );
    final matching = response.results.where(_matchesFilters).toList();
    _sortResults(matching);
    return AddonCatalogSearchResponse(
      results: List.unmodifiable(matching),
      errors: response.errors,
    );
  }

  bool _matchesFilters(AddonCatalogSearchResult result) {
    final item = result.item;
    final type = item.type.toLowerCase();
    final genres = item.genres.map(_normalize).toSet();
    final country = item.raw['country']?.toString().toLowerCase() ?? '';
    final isAnime = genres.contains('anime') ||
        country.contains('japan') ||
        country == 'jp';
    final isCartoon = genres.contains('animation') && !isAnime;
    final matchesType = _selectedTypes.any((selected) {
      switch (selected) {
        case 'movie':
          return type == 'movie';
        case 'series':
          return type == 'series' && !isAnime && !isCartoon;
        case 'anime':
          return type == 'anime' || (type == 'series' && isAnime);
        case 'cartoon':
          return type == 'cartoon' || (type == 'series' && isCartoon);
        default:
          return false;
      }
    });
    if (!matchesType) return false;

    final itemGenres = genres;
    if (_selectedGenres.isNotEmpty &&
        !_selectedGenres.any((genre) {
          final normalized = _normalize(genre);
          final aliases = _genreAliases[normalized] ?? {normalized};
          return itemGenres.any(
            (itemGenre) => aliases.any(
              (alias) =>
                  itemGenre.contains(alias) || alias.contains(itemGenre),
            ),
          );
        })) {
      return false;
    }
    final year = int.tryParse(item.year);
    if (_yearFrom != null && (year == null || year < _yearFrom!)) return false;
    if (_yearTo != null && (year == null || year > _yearTo!)) return false;
    final rating = double.tryParse(item.imdbRating);
    if (_minimumRating > 0 &&
        (rating == null || rating < _minimumRating)) {
      return false;
    }
    if (_status != null) {
      final status = (item.raw['status'] ?? '').toString().toLowerCase();
      final matchesStatus = switch (_status) {
        'Em andamento' => status.contains('running') ||
            status.contains('continuing') ||
            status.contains('em andamento'),
        'Finalizada' =>
          status.contains('ended') ||
          status.contains('finished') ||
          status.contains('finalizada'),
        'Lançamento' =>
          status.contains('new') ||
          status.contains('premiere') ||
          status.contains('lançamento'),
        _ => true,
      };
      if (!matchesStatus) return false;
    }
    return true;
  }

  void _sortResults(List<AddonCatalogSearchResult> results) {
    switch (_sortOrder) {
      case 'recent':
        results.sort(
          (first, second) =>
              _yearNumber(second.item).compareTo(_yearNumber(first.item)),
        );
        break;
      case 'rating':
        results.sort(
          (first, second) =>
              _rating(second.item).compareTo(_rating(first.item)),
        );
        break;
      case 'alphabetical':
        results.sort(
          (first, second) => first.item.name
              .toLowerCase()
              .compareTo(second.item.name.toLowerCase()),
        );
        break;
    }
  }

  int _yearNumber(StremioMetaItem item) => int.tryParse(item.year) ?? 0;

  double _rating(StremioMetaItem item) =>
      double.tryParse(item.imdbRating) ?? 0;

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  Future<void> _openFilters() async {
    var types = Set<String>.from(_selectedTypes);
    var genres = Set<String>.from(_selectedGenres);
    var yearFrom = _yearFrom;
    var yearTo = _yearTo;
    var minimumRating = _minimumRating;
    var status = _status;
    var sortOrder = _sortOrder;
    final yearFromController =
        TextEditingController(text: yearFrom?.toString() ?? '');
    final yearToController =
        TextEditingController(text: yearTo?.toString() ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filtros'),
          content: SizedBox(
            width: 520,
            height: MediaQuery.sizeOf(context).height * 0.58,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _filterHeading('TIPO'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in _types.entries)
                        FilterChip(
                          label: Text(entry.value),
                          selected: types.contains(entry.key),
                          onSelected: (selected) => setDialogState(() {
                            if (selected) {
                              types.add(entry.key);
                            } else {
                              types.remove(entry.key);
                            }
                          }),
                        ),
                    ],
                  ),
                  _filterHeading('GÊNEROS'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final genre in _genres)
                        FilterChip(
                          label: Text(genre),
                          selected: genres.contains(genre),
                          onSelected: (selected) => setDialogState(() {
                            if (selected) {
                              genres.add(genre);
                            } else {
                              genres.remove(genre);
                            }
                          }),
                        ),
                    ],
                  ),
                  _filterHeading('ANO'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: yearFromController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'De',
                            hintText: 'Ano inicial',
                          ),
                          onChanged: (value) =>
                              yearFrom = int.tryParse(value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: yearToController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Até',
                            hintText: 'Ano final',
                          ),
                          onChanged: (value) => yearTo = int.tryParse(value),
                        ),
                      ),
                    ],
                  ),
                  _filterHeading('AVALIAÇÃO IMDb · ${minimumRating.toStringAsFixed(1)}+'),
                  Slider(
                    value: minimumRating,
                    min: 0,
                    max: 10,
                    divisions: 20,
                    label: minimumRating.toStringAsFixed(1),
                    onChanged: (value) =>
                        setDialogState(() => minimumRating = value),
                  ),
                  _filterHeading('STATUS'),
                  DropdownButtonFormField<String?>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Situação',
                    ),
                    items: const [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Qualquer status'),
                      ),
                      DropdownMenuItem(
                        value: 'Em andamento',
                        child: Text('Em andamento'),
                      ),
                      DropdownMenuItem(
                        value: 'Finalizada',
                        child: Text('Finalizada'),
                      ),
                      DropdownMenuItem(
                        value: 'Lançamento',
                        child: Text('Lançamento'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => status = value),
                  ),
                  _filterHeading('ORDENAR POR'),
                  DropdownButtonFormField<String>(
                    initialValue: sortOrder,
                    items: const [
                      DropdownMenuItem(
                        value: 'popular',
                        child: Text('Mais Popular'),
                      ),
                      DropdownMenuItem(
                        value: 'recent',
                        child: Text('Mais Recente'),
                      ),
                      DropdownMenuItem(
                        value: 'rating',
                        child: Text('Melhor Avaliado'),
                      ),
                      DropdownMenuItem(
                        value: 'alphabetical',
                        child: Text('Ordem Alfabética'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => sortOrder = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => setDialogState(() {
                types = {'movie', 'series', 'anime', 'cartoon'};
                genres.clear();
                yearFrom = null;
                yearTo = null;
                yearFromController.clear();
                yearToController.clear();
                minimumRating = 0;
                status = null;
                sortOrder = 'popular';
              }),
              child: const Text('Limpar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    yearFromController.dispose();
    yearToController.dispose();
    if (result == true && mounted) {
      setState(() {
        _selectedTypes = types;
        _selectedGenres = genres;
        _yearFrom = yearFrom;
        _yearTo = yearTo;
        _minimumRating = minimumRating;
        _status = status;
        _sortOrder = sortOrder;
      });
      _search(_queryController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('Descobrir')) : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SearchField(
              controller: _queryController,
              onChanged: _search,
              onSubmitted: _search,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _openFilters,
                icon: const Icon(Icons.tune),
                label: const Text('FILTROS'),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _SearchResults(
                results: _results,
                stremioResults: _stremioResults,
                addonRepository: widget.addonRepository,
                catalogRepository: widget.catalogRepository,
                streamRepository: widget.streamRepository,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterHeading(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.stremioResults,
    required this.addonRepository,
    required this.catalogRepository,
    required this.streamRepository,
  });

  final Future<List<Movie>>? results;
  final Future<AddonCatalogSearchResponse>? stremioResults;
  final AddonRepository? addonRepository;
  final CatalogRepository? catalogRepository;
  final StreamRepository? streamRepository;

  @override
  Widget build(BuildContext context) {
    final future = results;
    final stremioFuture = stremioResults;
    if (future == null && stremioFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      children: [
        if (future != null)
          FutureBuilder<List<Movie>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Falha ao buscar filmes e séries: ${snapshot.error}',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final movies = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FILMES E SÉRIES',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (movies.isEmpty)
                    const Text('Nenhum resultado no catálogo.'),
                  if (movies.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: movies.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisExtent: 270,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) => MovieCard(
                        movie: movies[index],
                        addonRepository: addonRepository,
                        catalogRepository: catalogRepository,
                        streamRepository: streamRepository,
                      ),
                    ),
                ],
              );
            },
          ),
        if (stremioFuture != null &&
            addonRepository != null &&
            streamRepository != null)
          FutureBuilder<AddonCatalogSearchResponse>(
            future: stremioFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    'Falha na busca dos catálogos: ${snapshot.error}',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final response = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'RESULTADOS',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (response.results.isEmpty)
                    const Text(
                      'Nenhum resultado encontrado nos catálogos disponíveis.',
                    ),
                  if (response.results.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: response.results.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        mainAxisExtent: 300,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final result = response.results[index];
                        return _DiscoverResultCard(
                          result: result,
                          onTap: () => _openStremioItem(
                            context,
                            result,
                            addonRepository!,
                            streamRepository!,
                          ),
                        );
                      },
                    ),
                  if (response.errors.isNotEmpty)
                    Text(
                      'Alguns catálogos não responderam; os demais resultados '
                      'foram mantidos.',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Future<void> _openStremioItem(
    BuildContext context,
    AddonCatalogSearchResult result,
    AddonRepository addons,
    StreamRepository streams,
  ) async {
    var item = result.item;
    try {
      item = await enrichStremioSeriesItem(
        item,
        sourceAddon: result.addon,
        addonRepository: addons,
        catalogRepository: catalogRepository,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao carregar episódios: $error')),
        );
      }
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StremioDetailsScreen(
          item: item,
          catalogAddon: result.addon,
          streamAvailability: _hasStreamProvider(
            result.item.type,
            result.item.id,
            addons,
          ),
          addonRepository: addons,
          catalogRepository: catalogRepository,
          streamRepository: streams,
          onWatch: (detailsContext) async {
            try {
              final installed = await addons.getInstalledAddons();
              if (!detailsContext.mounted) return;
              await showModalBottomSheet<void>(
                context: detailsContext,
                isScrollControlled: true,
                builder: (_) => StremioSourcesSheet(
                  item: item,
                  addons: installed,
                  repository: streams,
                ),
              );
            } catch (error) {
              if (detailsContext.mounted) {
                ScaffoldMessenger.of(detailsContext).showSnackBar(
                  SnackBar(content: Text('Falha ao buscar fontes: $error')),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Future<bool> _hasStreamProvider(
    String type,
    String id,
    AddonRepository repository,
  ) async {
    final addons = await repository.getInstalledAddons();
    final supported = await Future.wait(addons.map((addon) async {
      try {
        final manifest = await repository.getManifest(addon);
        return manifest.supportsResource('stream', type, id);
      } catch (_) {
        return true;
      }
    }));
    return supported.any((value) => value);
  }
}

class _DiscoverResultCard extends StatelessWidget {
  const _DiscoverResultCard({
    required this.result,
    required this.onTap,
  });

  final AddonCatalogSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = result.item;
    final year = item.year;
    final genres = item.genres.map((genre) => genre.toLowerCase()).toSet();
    final country = item.raw['country']?.toString().toLowerCase() ?? '';
    final isAnime = genres.contains('anime') || country.contains('japan');
    final isCartoon = genres.contains('animation') && !isAnime;
    final displayType = item.type == 'movie'
        ? 'Filme'
        : isAnime
            ? 'Anime'
            : isCartoon
                ? 'Desenho'
                : 'Série';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: item.poster == null
                    ? const ColoredBox(
                        color: Color(0xFF10192D),
                        child: Icon(Icons.movie_outlined, size: 44),
                      )
                    : CachedNetworkImage(
                        imageUrl: item.poster!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF10192D),
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      Text(displayType),
                      if (year.isNotEmpty) Text(year),
                      if (item.imdbRating.isNotEmpty)
                        Text('★ ${item.imdbRating}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

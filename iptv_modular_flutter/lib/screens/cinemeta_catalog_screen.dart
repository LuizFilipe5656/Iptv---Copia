import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import '../services/cinemeta_service.dart';
import '../services/playback_progress_service.dart';
import '../widgets/movie_card.dart';

typedef CinemetaCatalogLoader = Future<List<Movie>> Function(
  CinemetaService service,
);

class CinemetaCatalogScreen extends StatefulWidget {
  const CinemetaCatalogScreen({
    super.key,
    required this.title,
    required this.loadCatalog,
    this.showAppBar = true,
    this.cinemetaService,
    this.addonRepository,
    this.catalogRepository,
    this.streamRepository,
    this.playbackProgressService,
  });

  final String title;
  final CinemetaCatalogLoader loadCatalog;
  final bool showAppBar;
  final CinemetaService? cinemetaService;
  final AddonRepository? addonRepository;
  final CatalogRepository? catalogRepository;
  final StreamRepository? streamRepository;
  final PlaybackProgressService? playbackProgressService;

  @override
  State<CinemetaCatalogScreen> createState() => _CinemetaCatalogScreenState();
}

class _CinemetaCatalogScreenState extends State<CinemetaCatalogScreen> {
  late final CinemetaService _cinemeta;
  late final bool _ownsService;
  late Future<List<Movie>> _catalog;
  final _searchController = TextEditingController();
  String _query = '';
  String _genre = 'Todos';
  String _order = 'original';
  int? _yearStart;
  int? _yearEnd;
  final List<Movie> _loaded = [];
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _loadMoreError;
  Future<List<Movie>>? _remoteSearch;
  String _remoteTerm = '';

  String get _contentType => widget.title.toLowerCase().contains('sér') ? 'series' : 'movie';

  void _searchOnline() {
    final term = _searchController.text.trim();
    setState(() {
      _query = term;
      _remoteTerm = term;
      _remoteSearch = term.isEmpty ? null :
          (_contentType == 'series' ? _cinemeta.searchSeries(term) : _cinemeta.searchMovies(term));
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _remoteTerm.isNotEmpty) return;
    setState(() { _loadingMore = true; _loadMoreError = null; });
    try {
      final next = _contentType == 'series'
          ? await _cinemeta.seriesPage(_loaded.length)
          : await _cinemeta.moviesPage(_loaded.length);
      if (!mounted) return;
      final known = _loaded.map((m) => m.id).toSet();
      setState(() {
        _loaded.addAll(next.where((m) => known.add(m.id)));
        _hasMore = next.isNotEmpty && next.length >= 40;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loadMoreError = error.toString(); _loadingMore = false; });
    }
  }


  String _genres(Movie movie) {
    try {
      final dynamic value = (movie as dynamic).genres;
      if (value is Iterable) return value.join(', ');
      return value?.toString() ?? '';
    } catch (_) {
      try {
        return (movie as dynamic).genre?.toString() ?? '';
      } catch (_) {
        return '';
      }
    }
  }

  int? _year(Movie movie) {
    try {
      final dynamic value = (movie as dynamic).year;
      return int.tryParse(value?.toString().substring(0, 4) ?? '');
    } catch (_) {
      return null;
    }
  }

  List<Movie> _visible(List<Movie> movies) {
    final query = _query.trim().toLowerCase();
    final result = movies.where((movie) {
      if (query.isNotEmpty && !movie.title.toLowerCase().contains(query)) return false;
      if (_genre != 'Todos' && !_genres(movie).toLowerCase().contains(_genre.toLowerCase())) return false;
      final year = _year(movie);
      if (_yearStart != null && (year == null || year < _yearStart!)) return false;
      if (_yearEnd != null && (year == null || year > _yearEnd!)) return false;
      return true;
    }).toList();
    if (_order == 'az') result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (_order == 'za') result.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
    if (_order == 'recentes') result.sort((a, b) => (_year(b) ?? 0).compareTo(_year(a) ?? 0));
    return result;
  }

  Future<void> _filters(List<Movie> movies) async {
    final genres = <String>{};
    for (final movie in movies) {
      for (final genre in _genres(movie).split(',')) {
        if (genre.trim().isNotEmpty) genres.add(genre.trim());
      }
    }
    final options = ['Todos', ...genres.toList()..sort()];
    var genre = options.contains(_genre) ? _genre : 'Todos';
    var order = _order;
    final start = TextEditingController(text: _yearStart?.toString() ?? '');
    final end = TextEditingController(text: _yearEnd?.toString() ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Filtros', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: genre,
                decoration: const InputDecoration(labelText: 'Gênero'),
                items: options.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => update(() => genre = v ?? 'Todos'),
              ),
              DropdownButtonFormField<String>(
                initialValue: order,
                decoration: const InputDecoration(labelText: 'Ordenar por'),
                items: const [
                  DropdownMenuItem(value: 'original', child: Text('Padrão')),
                  DropdownMenuItem(value: 'az', child: Text('Título A–Z')),
                  DropdownMenuItem(value: 'za', child: Text('Título Z–A')),
                  DropdownMenuItem(value: 'recentes', child: Text('Mais recentes')),
                ],
                onChanged: (v) => update(() => order = v ?? 'original'),
              ),
              Row(children: [
                Expanded(child: TextField(controller: start, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ano inicial'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: end, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ano final'))),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                TextButton(onPressed: () {
                  setState(() { _genre = 'Todos'; _order = 'original'; _yearStart = null; _yearEnd = null; });
                  Navigator.pop(sheetContext);
                }, child: const Text('Limpar')),
                const Spacer(),
                FilledButton(onPressed: () {
                  setState(() {
                    _genre = genre; _order = order;
                    _yearStart = int.tryParse(start.text.trim());
                    _yearEnd = int.tryParse(end.text.trim());
                  });
                  Navigator.pop(sheetContext);
                }, child: const Text('Aplicar')),
              ]),
            ]),
          ),
        ),
      ),
    );
    // Controllers are local to this modal.
  }


  @override
  void initState() {
    super.initState();
    _ownsService = widget.cinemetaService == null;
    _cinemeta = widget.cinemetaService ?? CinemetaService();
    _catalog = widget.loadCatalog(_cinemeta);
    _catalog.then((items) {
      if (mounted) setState(() { _loaded.clear(); _loaded.addAll(items); _hasMore = items.isNotEmpty; });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_ownsService) {
      _cinemeta.close();
    }
    super.dispose();
  }

  void _retry() {
    setState(() {
      _loaded.clear(); _hasMore = true; _remoteSearch = null; _remoteTerm = '';
      _catalog = widget.loadCatalog(_cinemeta);
      _catalog.then((items) {
        if (mounted) setState(() { _loaded.addAll(items); _hasMore = items.isNotEmpty; });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: Text(widget.title)) : null,
      body: FutureBuilder<List<Movie>>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Falha ao carregar ${widget.title.toLowerCase()} do '
                      'Cinemeta: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_loaded.isEmpty && snapshot.data!.isNotEmpty && !_loadingMore) {
            // Initial page is rendered immediately, even before the state callback.
          }
          final movies = _loaded.isEmpty ? snapshot.data! : _loaded;
          return FutureBuilder<List<Movie>>(
            future: _remoteSearch,
            builder: (context, remoteSnapshot) {
              final catalog = _remoteTerm.isEmpty ? movies : (remoteSnapshot.data ?? <Movie>[]);
              final visible = _visible(catalog);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchOnline(),
                        onChanged: (value) {
                          if (value.isEmpty) {
                            setState(() { _query = ''; _remoteTerm = ''; _remoteSearch = null; });
                          } else {
                            setState(() => _query = value);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Pesquisar em ${widget.title.toLowerCase()}',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() { _query = ''; _remoteTerm = ''; _remoteSearch = null; });
                                  },
                                ),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Pesquisar em todo o Cinemeta',
                      icon: const Icon(Icons.travel_explore),
                      onPressed: _searchOnline,
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Filtros',
                      icon: const Icon(Icons.tune),
                      onPressed: () => _filters(catalog),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_remoteTerm.isEmpty ? '${visible.length} de ${movies.length} títulos carregados' : '${visible.length} resultados da busca online'),
                ),
              ),
              if (_remoteTerm.isNotEmpty && remoteSnapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(),
              if (remoteSnapshot.hasError && _remoteTerm.isNotEmpty)
                Padding(padding: const EdgeInsets.all(8), child: Text('Erro na busca: ${remoteSnapshot.error}')),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('Nenhum título encontrado com estes filtros.'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: visible.length,
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisExtent: 270,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) => MovieCard(
                          movie: visible[index],
                          cinemetaService: _cinemeta,
                          addonRepository: widget.addonRepository,
                          catalogRepository: widget.catalogRepository,
                          streamRepository: widget.streamRepository,
                          playbackProgressService: widget.playbackProgressService,
                        ),
                      ),
              ),
              if (_remoteTerm.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _loadingMore
                      ? const CircularProgressIndicator()
                      : _hasMore
                          ? TextButton.icon(
                              onPressed: _loadMore,
                              icon: const Icon(Icons.expand_more),
                              label: const Text('Carregar mais títulos'),
                            )
                          : const Text('Fim dos resultados disponíveis'),
                ),
              if (_loadMoreError != null && _remoteTerm.isEmpty)
                Text('Falha ao carregar: $_loadMoreError'),
            ],
          );
            },
          );
        },
      ),
    );
  }
}

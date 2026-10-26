import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../models/stremio_meta_item.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import '../services/cinemeta_service.dart';
import '../services/content_metadata_service.dart';
import '../services/watchhub_service.dart';
import '../services/youtube_service.dart';
import '../services/favorites_service.dart';
import '../services/playback_progress_service.dart';
import '../services/series_metadata_service.dart';
import '../widgets/favorite_button.dart';
import 'season_screen.dart';
import 'search_screen.dart';
import 'stream_sources_sheet.dart';
import 'watchhub_screen.dart';

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({
    super.key,
    required this.title,
    required this.type,
    this.movie,
    this.cinemetaService,
    this.youtubeService,
    this.watchhubService,
    this.watchhubOpenUrl,
    this.favoritesService,
    this.addonRepository,
    this.catalogRepository,
    this.streamRepository,
    this.playbackProgressService,
  });

  final String title;
  final String type;
  final Movie? movie;
  final CinemetaService? cinemetaService;
  final YoutubeService? youtubeService;
  final WatchhubService? watchhubService;
  final Future<bool> Function(Uri url)? watchhubOpenUrl;
  final FavoritesService? favoritesService;
  final AddonRepository? addonRepository;
  final CatalogRepository? catalogRepository;
  final StreamRepository? streamRepository;
  final PlaybackProgressService? playbackProgressService;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  late final CinemetaService _cinemeta;
  late final bool _ownsService;

  Future<_ContentDetails?>? _details;

  final GlobalKey _seasonsKey = GlobalKey();

  bool get _isEpisodic {
    final type = widget.type.trim().toLowerCase();

    return isEpisodicContentType(type) ||
        const {
          'anime',
          'cartoon',
          'dorama',
          'drama',
          'kdrama',
          'cdrama',
          'jdrama',
          'tv',
        }.contains(type);
  }

  @override
  void initState() {
    super.initState();

    _ownsService = widget.cinemetaService == null;
    _cinemeta = widget.cinemetaService ?? CinemetaService();

    _details = _loadDetails();
  }

  bool _isImdbId(String id) {
    return RegExp(
      r'^tt\d+$',
      caseSensitive: false,
    ).hasMatch(id.trim());
  }

  String? _validImdbId(Movie movie) {
    final imdbId = movie.imdbId;

    if (imdbId != null && _isImdbId(imdbId)) {
      return imdbId;
    }

    if (_isImdbId(movie.id)) {
      return movie.id;
    }

    return null;
  }

  Future<Movie?> _findInitialMovie() async {
    if (widget.movie != null) {
      debugPrint(
        '[details] Conteúdo recebido do catálogo: '
        '${widget.movie!.title} '
        '(${widget.movie!.id})',
      );

      return widget.movie;
    }

    try {
      final matches = _isEpisodic
          ? await _cinemeta.searchSeries(widget.title)
          : await _cinemeta.searchMovies(widget.title);

      if (matches.isNotEmpty) {
        return matches.first;
      }
    } catch (error) {
      debugPrint(
        '[details] Busca inicial Cinemeta falhou: $error',
      );
    }

    return null;
  }

  Future<Movie> _enrichWithAddons(Movie movie) async {
    final addonRepository = widget.addonRepository;
    final catalogRepository = widget.catalogRepository;

    if (addonRepository == null || catalogRepository == null) {
      debugPrint(
        '[details] Repositórios de addons indisponíveis.',
      );

      return movie;
    }

    try {
      final enriched = await ContentMetadataService(
        addonRepository: addonRepository,
        catalogRepository: catalogRepository,
      ).enrich(
        content: movie,
        type: widget.type,
      );

      debugPrint(
        '[details] Metadados consultados nos addons: '
        '${movie.title}',
      );

      return enriched;
    } catch (error) {
      debugPrint(
        '[details] Falha no enriquecimento dos addons: '
        '$error',
      );

      return movie;
    }
  }

  Future<SeriesMetadata?> _loadCinemetaSeries(
    Movie movie,
  ) async {
    final imdbId = _validImdbId(movie);

    if (imdbId == null) {
      debugPrint(
        '[details] Sem ID IMDb. '
        'Cinemeta não será obrigatório.',
      );

      return null;
    }

    try {
      return await _cinemeta.seriesMetadata(imdbId);
    } catch (error) {
      debugPrint(
        '[details] Falha ao consultar episódios '
        'no Cinemeta: $error',
      );

      return null;
    }
  }

  Future<Movie> _loadCinemetaMovie(
    Movie movie,
  ) async {
    final imdbId = _validImdbId(movie);

    if (imdbId == null) {
      return movie;
    }

    // Evita substituir dados existentes dos addons
    // quando o conteúdo já possui informações suficientes.
    if (movie.overview.isNotEmpty && movie.posterUrl != null) {
      return movie;
    }

    try {
      final result = await _cinemeta.details(
        'movie',
        imdbId,
      );

      if (result == null) {
        return movie;
      }

      // Preserva o conteúdo original quando há
      // metadados úteis vindos dos addons.
      if (movie.overview.isNotEmpty ||
          movie.posterUrl != null ||
          movie.bannerUrl != null) {
        return movie;
      }

      return result;
    } catch (error) {
      debugPrint(
        '[details] Cinemeta filmes indisponível: $error',
      );

      return movie;
    }
  }

  Future<_ContentDetails?> _loadDetails() async {
    var movie = await _findInitialMovie();

    if (movie == null) {
      debugPrint(
        '[details] Conteúdo não localizado: '
        '${widget.title}',
      );

      return null;
    }

    debugPrint(
      '[details] Iniciando carregamento: '
      '${movie.title}',
    );

    debugPrint(
      '[details] Tipo: ${widget.type}',
    );

    debugPrint(
      '[details] ID original: ${movie.id}',
    );

    debugPrint(
      '[details] IMDb: ${movie.imdbId}',
    );

    // Primeiro aproveita os metadados do catálogo
    // e tenta enriquecer com os addons.
    movie = await _enrichWithAddons(movie);

    if (_isEpisodic) {
      return _loadSeriesDetails(movie);
    }

    // Cinemeta complementa os filmes quando possível.
    movie = await _loadCinemetaMovie(movie);

    return _ContentDetails(movie, null);
  }

  Future<_ContentDetails> _loadSeriesDetails(
    Movie movie,
  ) async {
    debugPrint(
      '[series] Carregando temporadas de '
      '${movie.title}',
    );

    final cinemetaMetadata = await _loadCinemetaSeries(movie);

    var metadata = SeriesMetadata(
      series: movie,
      episodes: cinemetaMetadata?.episodes ?? const [],
    );

    final addonRepository = widget.addonRepository;
    final catalogRepository = widget.catalogRepository;

    if (addonRepository != null && catalogRepository != null) {
      try {
        metadata = await SeriesMetadataService(
          addonRepository: addonRepository,
          catalogRepository: catalogRepository,
        ).load(
          series: movie,
          type: widget.type,
          fallback: metadata,
        );

        debugPrint(
          '[series] Consulta de episódios '
          'dos addons concluída.',
        );
      } catch (error) {
        debugPrint(
          '[series] Falha ao carregar episódios '
          'dos addons: $error',
        );
      }
    }

    debugPrint(
      '[series] Série: ${metadata.series.title}',
    );

    debugPrint(
      '[series] ID: ${metadata.series.id}',
    );

    debugPrint(
      '[series] Temporadas: '
      '${metadata.seasons.length}',
    );

    debugPrint(
      '[series] Episódios: '
      '${metadata.episodes.length}',
    );

    return _ContentDetails(
      metadata.series,
      metadata,
    );
  }

  @override
  void dispose() {
    if (_ownsService) {
      _cinemeta.close();
    }

    super.dispose();
  }

  void _retry() {
    setState(() {
      _details = _loadDetails();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ContentDetails?>(
      future: _details,
      builder: (context, snapshot) {
        return _detailsScaffold(
          snapshot.data,
          isLoading: !snapshot.hasData && !snapshot.hasError,
          error: snapshot.error,
          notFound: snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError &&
              snapshot.data == null,
        );
      },
    );
  }

  Widget _detailsScaffold(
    _ContentDetails? content, {
    bool isLoading = false,
    Object? error,
    bool notFound = false,
  }) {
    final movie = content?.movie ?? widget.movie;
    final metadata = content?.seriesMetadata;

    final bannerUrl = movie?.bannerUrl ?? movie?.posterUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        title: Text(movie?.title ?? widget.title),
        actions: [
          IconButton(
            tooltip: 'Atualizar detalhes',
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 300,
            width: double.infinity,
            child: bannerUrl == null || bannerUrl.isEmpty
                ? const ColoredBox(
                    color: Color(0xFF10192D),
                    child: Center(
                      child: Icon(
                        Icons.movie_outlined,
                        size: 64,
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: bannerUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const ColoredBox(
                      color: Color(0xFF10192D),
                    ),
                    errorWidget: (context, url, imageError) => const ColoredBox(
                      color: Color(0xFF10192D),
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
          ),
          if (movie?.posterUrl != null && movie!.posterUrl != bannerUrl)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: movie.posterUrl!,
                    width: 120,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const ColoredBox(
                      color: Color(0xFF10192D),
                    ),
                    errorWidget: (context, url, imageError) => const SizedBox(
                      width: 120,
                      height: 180,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (movie != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                0,
              ),
              child: Text(
                movie.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  _contentTypeLabel(),
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
                if (movie?.releaseYear != null)
                  Text(
                    '${movie!.releaseYear}',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                if (movie?.imdbRating != null)
                  Text(
                    'IMDb ${movie!.imdbRating!.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                if (metadata != null)
                  Text(
                    '${metadata.seasons.length} '
                    'temporadas · '
                    '${metadata.episodes.length} '
                    'episódios',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
          if (movie?.genres.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                12,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final genre in movie!.genres)
                    Chip(
                      label: Text(genre),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Text(
              movie?.overview.isNotEmpty == true
                  ? movie!.overview
                  : 'Sinopse não disponível.',
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Falha ao carregar os detalhes: '
                    '$error',
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  TextButton(
                    onPressed: _retry,
                    child: const Text(
                      'Tentar novamente',
                    ),
                  ),
                ],
              ),
            )
          else if (notFound)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Não foi possível encontrar '
                    '"${widget.title}".',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                  TextButton(
                    onPressed: _retry,
                    child: const Text(
                      'Tentar novamente',
                    ),
                  ),
                ],
              ),
            ),
          if (movie != null && !isLoading && error == null && !notFound)
            _contentActions(
              context,
              movie,
              metadata,
            ),
          if (_isEpisodic &&
              movie != null &&
              !isLoading &&
              error == null &&
              !notFound)
            _seasonList(
              metadata,
              key: _seasonsKey,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _contentTypeLabel() {
    final type = widget.type.toLowerCase();

    if (type.contains('anime')) {
      return 'Anime';
    }

    if (type.contains('dorama') || type.contains('drama')) {
      return 'Dorama';
    }

    if (type.contains('cartoon')) {
      return 'Desenho';
    }

    if (_isEpisodic) {
      return 'Série';
    }

    return 'Filme';
  }

  Widget _contentActions(
    BuildContext context,
    Movie movie,
    SeriesMetadata? metadata,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FavoriteButton(
            movie: movie,
            service: widget.favoritesService,
          ),
          ElevatedButton.icon(
            onPressed: () => _openTrailer(context, movie),
            icon: const Icon(
              Icons.smart_display,
            ),
            label: const Text('Trailer'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WatchhubScreen(
                  movie: movie,
                  service: widget.watchhubService,
                  openUrl: widget.watchhubOpenUrl,
                ),
              ),
            ),
            icon: const Icon(Icons.language),
            label: const Text('WatchHub'),
          ),
          ElevatedButton.icon(
            onPressed: _isEpisodic
                ? () => _showSeasons(
                      context,
                      metadata,
                    )
                : widget.addonRepository != null &&
                        widget.streamRepository != null
                    ? () => _showMovieSources(
                          context,
                          movie,
                        )
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SearchScreen(
                              initialQuery: movie.title,
                              autoSearch: false,
                            ),
                          ),
                        ),
            icon: const Icon(
              Icons.play_circle,
            ),
            label: const Text('Assistir'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMovieSources(
    BuildContext context,
    Movie movie,
  ) async {
    final addons = widget.addonRepository;
    final streams = widget.streamRepository;

    if (addons == null || streams == null) {
      return;
    }

    try {
      final installed = await addons.getInstalledAddons();

      if (!context.mounted) {
        return;
      }

      // Preserva o ID próprio do addon quando
      // não há um ID IMDb válido.
      final contentId = _validImdbId(movie) ?? movie.id;

      debugPrint(
        '[streams] Filme: ${movie.title}',
      );

      debugPrint(
        '[streams] Content ID: $contentId',
      );

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => StremioSourcesSheet(
          item: StremioMetaItem(
            id: contentId,
            type: 'movie',
            name: movie.title,
            poster: movie.posterUrl,
          ),
          addons: installed,
          repository: streams,
          playbackContentId: contentId,
          contentTitle: movie.title,
          posterUrl: movie.posterUrl,
          progressService: widget.playbackProgressService,
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha ao carregar fontes: $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showSeasons(
    BuildContext context,
    SeriesMetadata? metadata,
  ) async {
    final seasonContext = _seasonsKey.currentContext;

    if (metadata?.seasons.isNotEmpty == true && seasonContext != null) {
      await Scrollable.ensureVisible(
        seasonContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Nenhuma temporada encontrada '
          'para este conteúdo.',
        ),
      ),
    );
  }

  Future<void> _openTrailer(
    BuildContext context,
    Movie movie,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final query = [
      movie.title,
      if (movie.releaseYear != null) movie.releaseYear.toString(),
    ].join(' ');

    try {
      final opened =
          await (widget.youtubeService ?? const ExternalYoutubeService())
              .openSearch(
        query,
        category: YoutubeVideoCategory.officialTrailer,
      );

      if (!opened && context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir o YouTube.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Falha ao abrir o trailer '
              'no YouTube: $error',
            ),
          ),
        );
      }
    }
  }

  Widget _seasonList(
    SeriesMetadata? metadata, {
    Key? key,
  }) {
    if (metadata == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Nenhuma temporada encontrada '
          'para este conteúdo.',
          style: TextStyle(
            color: Colors.white70,
          ),
        ),
      );
    }

    if (metadata.episodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Nenhum episódio disponível '
          'nos provedores consultados.',
          style: TextStyle(
            color: Colors.white70,
          ),
        ),
      );
    }

    debugPrint(
      '[series] series id=${metadata.series.id}, '
      'meta id=${metadata.series.imdbId}, '
      'seasons found=${metadata.seasons.length}, '
      'episodes found=${metadata.episodes.length}',
    );

    return SeriesSeasonsSection(
      key: key,
      series: metadata.series,
      episodes: metadata.episodes,
      addonRepository: widget.addonRepository,
      streamRepository: widget.streamRepository,
      playbackProgressService: widget.playbackProgressService,
    );
  }
}

class _ContentDetails {
  const _ContentDetails(
    this.movie,
    this.seriesMetadata,
  );

  final Movie movie;
  final SeriesMetadata? seriesMetadata;
}

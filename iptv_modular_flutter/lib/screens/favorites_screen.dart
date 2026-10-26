import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import '../services/cinemeta_service.dart';
import '../services/favorites_service.dart';
import '../services/playback_progress_service.dart';
import 'details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    this.service,
    this.cinemetaService,
    this.addonRepository,
    this.catalogRepository,
    this.streamRepository,
    this.playbackProgressService,
  });

  final FavoritesService? service;
  final CinemetaService? cinemetaService;
  final AddonRepository? addonRepository;
  final CatalogRepository? catalogRepository;
  final StreamRepository? streamRepository;
  final PlaybackProgressService? playbackProgressService;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final FavoritesService _favorites;
  late Future<List<Movie>> _items;

  @override
  void initState() {
    super.initState();
    _favorites = widget.service ?? FavoritesService();
    _items = _favorites.getFavorites();
  }

  void _reload() {
    setState(() => _items = _favorites.getFavorites());
  }

  Future<void> _openDetails(Movie movie) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DetailsScreen(
          title: movie.title,
          type: movie.type,
          movie: movie,
          cinemetaService: widget.cinemetaService,
          favoritesService: _favorites,
          addonRepository: widget.addonRepository,
          catalogRepository: widget.catalogRepository,
          streamRepository: widget.streamRepository,
          playbackProgressService: widget.playbackProgressService,
        ),
      ),
    );
    if (mounted) {
      _reload();
    }
  }

  Future<void> _remove(Movie movie) async {
    try {
      await _favorites.remove(movie);
      if (mounted) {
        _reload();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao remover favorito: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: FutureBuilder<List<Movie>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _FavoritesMessage(
              message: 'Falha ao carregar favoritos: ${snapshot.error}',
              action: _reload,
              actionLabel: 'Tentar novamente',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final movies = snapshot.data!;
          if (movies.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_border, size: 56),
                    SizedBox(height: 16),
                    Text(
                      'Você ainda não tem favoritos.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Abra os detalhes de um filme ou série e toque em '
                      '"Adicionar aos favoritos".',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: movies.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return ListTile(
                leading: Icon(
                  movie.type == 'series'
                      ? Icons.video_library_outlined
                      : Icons.movie_outlined,
                ),
                title: Text(movie.title),
                subtitle: Text(movie.type == 'series' ? 'Série' : 'Filme'),
                trailing: IconButton(
                  tooltip: 'Remover ${movie.title} dos favoritos',
                  onPressed: () => _remove(movie),
                  icon: const Icon(Icons.star, color: Colors.amber),
                ),
                onTap: () => _openDetails(movie),
              );
            },
          );
        },
      ),
    );
  }
}

class _FavoritesMessage extends StatelessWidget {
  const _FavoritesMessage({
    required this.message,
    required this.action,
    required this.actionLabel,
  });

  final String message;
  final VoidCallback action;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: action,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

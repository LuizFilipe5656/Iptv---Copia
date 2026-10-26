import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import '../screens/details_screen.dart';
import '../services/cinemeta_service.dart';
import '../services/playback_progress_service.dart';
import '../services/youtube_service.dart';
import '../services/watchhub_service.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
    this.youtubeService,
    this.watchhubService,
    this.watchhubOpenUrl,
    this.cinemetaService,
    this.addonRepository,
    this.catalogRepository,
    this.streamRepository,
    this.playbackProgressService,
  });

  final Movie movie;
  final YoutubeService? youtubeService;
  final WatchhubService? watchhubService;
  final Future<bool> Function(Uri url)? watchhubOpenUrl;
  final CinemetaService? cinemetaService;
  final AddonRepository? addonRepository;
  final CatalogRepository? catalogRepository;
  final StreamRepository? streamRepository;
  final PlaybackProgressService? playbackProgressService;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDetails(context),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 170,
          height: 255,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildPoster(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Text(
                  movie.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPoster() {
    final primaryUrl = movie.posterUrl?.trim() ?? '';
    final fallbackUrl = movie.fallbackPoster.trim();
    final urls = <String>[];
    if (primaryUrl.isNotEmpty) {
      urls.add(primaryUrl);
    }
    if (fallbackUrl.isNotEmpty && !urls.contains(fallbackUrl)) {
      urls.add(fallbackUrl);
    }
    if (urls.isEmpty) {
      return _posterPlaceholder();
    }
    return _buildPosterWithFallback(urls, 0);
  }
  Widget _buildPosterWithFallback(List<String> urls, int index) {
    if (index >= urls.length) {
      return _posterPlaceholder();
    }
    return CachedNetworkImage(
      imageUrl: urls[index],
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) {
        return const Center(child: CircularProgressIndicator());
      },
      errorWidget: (context, url, error) {
        debugPrint('Falha ao carregar poster: $url');
        return _buildPosterWithFallback(urls, index + 1);
      },
    );
  }  Widget _posterPlaceholder() {
    return Container(
      color: const Color(0xFF10192D),
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          size: 48,
          color: Colors.white54,
        ),
      ),
    );
  }

  void showDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailsScreen(
          title: movie.title,
          type: movie.type,
          movie: movie,
          cinemetaService: cinemetaService,
          addonRepository: addonRepository,
          catalogRepository: catalogRepository,
          streamRepository: streamRepository,
          playbackProgressService: playbackProgressService,
          youtubeService: youtubeService,
          watchhubService: watchhubService,
          watchhubOpenUrl: watchhubOpenUrl,
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';

import 'cinemeta_catalog_screen.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import '../services/cinemeta_service.dart';
import '../services/playback_progress_service.dart';

class MoviesScreen extends StatelessWidget {
  const MoviesScreen({
    super.key,
    this.showAppBar = true,
    this.cinemetaService,
    this.addonRepository,
    this.catalogRepository,
    this.streamRepository,
    this.playbackProgressService,
  });

  static const routeName = '/movies';
  final bool showAppBar;
  final CinemetaService? cinemetaService;
  final AddonRepository? addonRepository;
  final CatalogRepository? catalogRepository;
  final StreamRepository? streamRepository;
  final PlaybackProgressService? playbackProgressService;

  @override
  Widget build(BuildContext context) {
    return CinemetaCatalogScreen(
      title: 'Filmes',
      loadCatalog: (service) => service.popularMovies(),
      showAppBar: showAppBar,
      cinemetaService: cinemetaService,
      addonRepository: addonRepository,
      catalogRepository: catalogRepository,
      streamRepository: streamRepository,
      playbackProgressService: playbackProgressService,
    );
  }
}

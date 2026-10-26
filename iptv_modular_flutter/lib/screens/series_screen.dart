import 'package:flutter/material.dart';

import 'addon_category_screen.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import '../services/playback_progress_service.dart';

class SeriesScreen extends StatelessWidget {
  const SeriesScreen({
    super.key,
    this.addonRepository,
    this.catalogRepository,
    this.streamRepository,
    this.playbackProgressService,
  });

  final AddonRepository? addonRepository;
  final CatalogRepository? catalogRepository;
  final StreamRepository? streamRepository;
  final PlaybackProgressService? playbackProgressService;

  static const routeName = '/series';

  @override
  Widget build(BuildContext context) {
    return AddonCategoryScreen(
      category: AddonCategory.combinedSeries,
      addonRepository: addonRepository,
      catalogRepository: catalogRepository,
      streamRepository: streamRepository,
    );
  }
}

import 'package:flutter/material.dart';

import '../models/addon.dart';
import '../models/movie.dart';
import '../models/stremio_meta_item.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import '../services/cinemeta_service.dart';
import '../services/content_metadata_service.dart';
import '../services/series_metadata_service.dart';
import 'season_screen.dart';

Future<StremioMetaItem> enrichStremioSeriesItem(
  StremioMetaItem item, {
  Addon? sourceAddon,
  AddonRepository? addonRepository,
  CatalogRepository? catalogRepository,
}) async {
  final episodic = isEpisodicContentType(item.type);
  if (!episodic && item.type != 'movie') return item;
  var episodes = sourceAddon?.id == 'cinemeta'
      ? <SeriesEpisode>[]
      : _parseEpisodes(item.raw['videos']);
  var series = Movie(
    id: item.id,
    imdbId: item.id,
    title: item.name,
    type: item.type,
    overview: item.description,
    posterUrl: item.poster,
    bannerUrl: item.background,
    genres: item.genres,
  );

  if (addonRepository != null && catalogRepository != null) {
    try {
      series = await ContentMetadataService(
        addonRepository: addonRepository,
        catalogRepository: catalogRepository,
      ).enrich(content: series, type: item.type);
    } catch (error) {
      debugPrint(
        '[metadata] Addon metadata lookup failed for "${item.name}" '
        '(id=${item.id}): $error',
      );
    }
  }

  if (episodic && addonRepository != null && catalogRepository != null) {
    try {
      final metadata = await SeriesMetadataService(
        addonRepository: addonRepository,
        catalogRepository: catalogRepository,
      ).load(
        series: series,
        type: item.type,
        fallback: SeriesMetadata(series: series, episodes: episodes),
      );
      episodes = metadata.episodes;
    } catch (error) {
      debugPrint(
        '[series] Addon episode lookup failed for "${item.name}" '
        '(id=${item.id}): $error',
      );
    }
  }

  if (!episodic) {
    return StremioMetaItem.fromJson({
      ...item.raw,
      'description':
          series.overview.isNotEmpty ? series.overview : item.description,
      'poster': item.poster ?? series.posterUrl,
      'background': item.background ?? series.bannerUrl,
      'genres': item.raw['genres'] ?? series.genres,
      'imdbRating': item.imdbRating.isEmpty
          ? series.imdbRating?.toString() ?? ''
          : item.imdbRating,
    });
  }
  _logEpisodeData(item, episodes);
  if (episodic && episodes.isEmpty) {
    return StremioMetaItem.fromJson({
      ...item.raw,
      'description':
          series.overview.isNotEmpty ? series.overview : item.description,
      'poster': item.poster ?? series.posterUrl,
      'background': item.background ?? series.bannerUrl,
      'genres': item.raw['genres'] ?? series.genres,
      'imdbRating': item.imdbRating.isEmpty
          ? series.imdbRating?.toString() ?? ''
          : item.imdbRating,
    });
  }
  return StremioMetaItem.fromJson({
    ...item.raw,
    'poster': item.poster ?? series.posterUrl,
    'genres': item.raw['genres'] ?? series.genres,
    'background': item.background ?? series.bannerUrl,
    'description':
        series.overview.isNotEmpty ? series.overview : item.description,
    'imdbRating': item.imdbRating.isEmpty
        ? series.imdbRating?.toString() ?? ''
        : item.imdbRating,
    'videos': [
      for (final episode in episodes)
        {
          'id': episode.id,
          'title': episode.title,
          'season': episode.season,
          'episode': episode.episode,
          'overview': episode.overview,
          'thumbnail': episode.thumbnailUrl,
          if (episode.runtime != null) 'runtime': episode.runtime,
          if (episode.kind != null) 'type': episode.kind,
        },
    ],
  });
}

class StremioDetailsScreen extends StatelessWidget {
  const StremioDetailsScreen({
    super.key,
    required this.item,
    required this.catalogAddon,
    required this.onWatch,
    this.streamAvailability,
    this.addonRepository,
    this.catalogRepository,
    this.streamRepository,
  });

  final StremioMetaItem item;
  final Addon catalogAddon;
  final Future<void> Function(BuildContext context) onWatch;
  final Future<bool>? streamAvailability;
  final AddonRepository? addonRepository;
  final CatalogRepository? catalogRepository;
  final StreamRepository? streamRepository;

  List<SeriesEpisode> get _episodes {
    return _parseEpisodes(item.raw['videos']);
  }

  List<String> get _genres {
    final value = item.raw['genres'];
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
  }

  String get _year {
    final year = item.raw['year'];
    if (year != null) {
      return year.toString();
    }
    final match = RegExp(r'\b\d{4}\b').firstMatch(item.releaseInfo);
    return match?.group(0) ?? item.releaseInfo;
  }

  @override
  Widget build(BuildContext context) {
    final banner = item.background ?? item.poster;
    final episodes = _episodes;
    final isSeries = isEpisodicContentType(item.type);
    final series = Movie(
      id: item.id,
      imdbId: item.id,
      title: item.name,
      type: item.type,
      overview: item.description,
      posterUrl: item.poster,
      bannerUrl: item.background,
    );
    if (isSeries) _logEpisodeData(item, episodes);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Detalhes'),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (banner != null)
                    Image.network(
                      banner,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: Color(0xFF10192D)),
                    )
                  else
                    const ColoredBox(color: Color(0xFF10192D)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 132,
                        height: 198,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: item.poster == null
                              ? const ColoredBox(
                                  color: Color(0xFF10192D),
                                  child: Icon(Icons.movie_outlined, size: 44),
                                )
                              : Image.network(
                                  item.poster!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(
                                    color: Color(0xFF10192D),
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(
                              [
                                if (_year.isNotEmpty) _year,
                                item.type,
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (item.imdbRating.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text(item.imdbRating),
                                ],
                              ),
                            ],
                            if (isSeries) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${episodes.length} episódios · '
                                '${SeriesMetadata(series: series, episodes: episodes).seasons.length} temporadas',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Catálogo: ${catalogAddon.name}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_genres.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final genre in _genres) Chip(label: Text(genre)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Sinopse',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    item.description.isEmpty
                        ? 'Sinopse não fornecida pelo catálogo.'
                        : item.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (isSeries) ...[
                    const SizedBox(height: 16),
                    SeriesSeasonsSection(
                      series: series,
                      episodes: episodes,
                      addonRepository: addonRepository,
                      streamRepository: streamRepository,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!isSeries && streamAvailability == null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => onWatch(context),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Assistir'),
                      ),
                    )
                  else if (!isSeries)
                    FutureBuilder<bool>(
                      future: streamAvailability,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }

                        if (!snapshot.data!) {
                          return const Text(
                            'Este addon fornece metadados ou catálogo, mas não fornece fontes de reprodução.',
                          );
                        }
                        return SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => onWatch(context),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Assistir'),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<SeriesEpisode> _parseEpisodes(Object? rawVideos) {
  if (rawVideos is! List) return const [];
  final episodes = <SeriesEpisode>[];
  for (final video in rawVideos) {
    if (video is! Map<String, dynamic>) {
      debugPrint('[series] Ignoring invalid episode payload: $video');
      continue;
    }
    final episode = SeriesEpisode.tryFromJson(video);
    if (episode != null) episodes.add(episode);
  }
  return List.unmodifiable(episodes);
}

void _logEpisodeData(StremioMetaItem item, List<SeriesEpisode> episodes) {
  final seasons = SeriesMetadata(
    series: Movie(
      id: item.id,
      title: item.name,
      type: item.type,
    ),
    episodes: episodes,
  ).seasons;
  debugPrint(
    '[series] series id=${item.id}, meta id=${item.raw['id']}, '
    'seasons found=${seasons.length}, episodes found=${episodes.length}',
  );
  if (episodes.isEmpty) {
    debugPrint(
      '[series] No valid seasons for series id=${item.id}; '
      'received videos=${item.raw['videos']}',
    );
  }
}

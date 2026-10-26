import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../repositories/addon_repository.dart';
import '../repositories/stream_repository.dart';
import '../services/playback_progress_service.dart';
import '../services/cinemeta_service.dart';
import 'episode_screen.dart';

class SeasonScreen extends StatelessWidget {
  const SeasonScreen({
    super.key,
    required this.series,
    required this.season,
    required this.episodes,
    this.allEpisodes,
    this.heading,
    this.addonRepository,
    this.streamRepository,
    this.playbackProgressService,
  });

  final Movie series;
  final int season;
  final List<SeriesEpisode> episodes;
  final List<SeriesEpisode>? allEpisodes;
  final String? heading;
  final AddonRepository? addonRepository;
  final StreamRepository? streamRepository;
  final PlaybackProgressService? playbackProgressService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        title: Text(
          heading ??
              (season == 0 ? 'Especiais · Temporada 0' : 'Temporada $season'),
        ),
      ),
      body: episodes.isEmpty
          ? const Center(
              child: Text('Nenhum episódio disponível nesta temporada.'),
            )
          : ListView.builder(
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final episode = episodes[index];
                final orderedEpisodes = [...?allEpisodes]
                  ..sort((first, second) {
                    final seasonOrder = first.season.compareTo(second.season);
                    return seasonOrder != 0
                        ? seasonOrder
                        : first.episode.compareTo(second.episode);
                  });
                final currentIndex = orderedEpisodes.indexWhere(
                  (item) =>
                      item.season == episode.season &&
                      item.episode == episode.episode,
                );
                final nextEpisode = currentIndex >= 0 &&
                        currentIndex + 1 < orderedEpisodes.length
                    ? orderedEpisodes[currentIndex + 1]
                    : null;
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: episode.thumbnailUrl == null
                        ? CircleAvatar(child: Text('${episode.episode}'))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              episode.thumbnailUrl!,
                              width: 88,
                              height: 58,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => CircleAvatar(
                                child: Text('${episode.episode}'),
                              ),
                            ),
                          ),
                    title: Text(
                      episode.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        'Episódio '
                            '${episode.episode.toString().padLeft(2, '0')}',
                        if (episode.runtime?.isNotEmpty == true)
                          episode.runtime!,
                        if (episode.overview.isNotEmpty) episode.overview,
                      ].join(' · '),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: episode.overview.isNotEmpty,
                    trailing: const Icon(Icons.play_circle_outline),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EpisodeScreen(
                          series: series,
                          episode: episode,
                          nextEpisode: nextEpisode,
                          allEpisodes: orderedEpisodes,
                          addonRepository: addonRepository,
                          streamRepository: streamRepository,
                          playbackProgressService: playbackProgressService,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SeriesSeasonsSection extends StatelessWidget {
  const SeriesSeasonsSection({
    super.key,
    required this.series,
    required this.episodes,
    this.addonRepository,
    this.streamRepository,
    this.playbackProgressService,
  });

  final Movie series;
  final List<SeriesEpisode> episodes;
  final AddonRepository? addonRepository;
  final StreamRepository? streamRepository;
  final PlaybackProgressService? playbackProgressService;

  @override
  Widget build(BuildContext context) {
    final seasons = SeriesMetadata(series: series, episodes: episodes).seasons;
    final regularSeasons = seasons.entries.where((entry) => entry.key > 0);
    final specials = seasons[0] ?? const <SeriesEpisode>[];
    if (regularSeasons.isEmpty && specials.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Nenhuma temporada encontrada para este conteúdo.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Temporadas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        for (final entry in regularSeasons)
          _seasonTile(
            context,
            season: entry.key,
            episodes: entry.value,
            title: 'Temporada ${entry.key}',
          ),
        if (specials.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Especiais · Temporada 0',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (final category in const ['Especiais', 'OVAs', 'OADs', 'Extras'])
            if (specials.any((episode) => episode.specialCategory == category))
              _seasonTile(
                context,
                season: 0,
                episodes: specials
                    .where((episode) => episode.specialCategory == category)
                    .toList(growable: false),
                title: category,
              ),
        ],
      ],
    );
  }

  Widget _seasonTile(
    BuildContext context, {
    required int season,
    required List<SeriesEpisode> episodes,
    required String title,
  }) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        '${episodes.length} ${episodes.length == 1 ? 'episódio' : 'episódios'}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SeasonScreen(
            series: series,
            season: season,
            heading: season == 0 ? title : null,
            episodes: episodes,
            allEpisodes: this.episodes,
            addonRepository: addonRepository,
            streamRepository: streamRepository,
            playbackProgressService: playbackProgressService,
          ),
        ),
      ),
    );
  }
}

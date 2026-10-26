import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../screens/player_screen.dart';
import '../services/playback_progress_service.dart';

class ContinueWatchingSection extends StatefulWidget {
  const ContinueWatchingSection({
    super.key,
    this.service,
  });

  final PlaybackProgressService? service;

  @override
  State<ContinueWatchingSection> createState() =>
      _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState extends State<ContinueWatchingSection> {
  late final PlaybackProgressService _progress;
  late Future<List<PlaybackProgress>> _items;

  @override
  void initState() {
    super.initState();
    _progress = widget.service ?? PlaybackProgressService();
    _items = _progress.getProgress();
  }

  void _reload() {
    setState(() => _items = _progress.getProgress());
  }

  Future<void> _resume(PlaybackProgress item) async {
    await Navigator.pushNamed<void>(
      context,
      PlayerScreen.routeName,
      arguments: PlayerLaunchRequest(
        url: item.url,
        contentId: item.contentId,
        contentType: item.contentType,
        contentTitle: item.title,
        season: item.season,
        episode: item.episode,
        episodeTitle: item.episodeTitle,
        posterUrl: item.posterUrl,
        startPositionMilliseconds: item.positionMilliseconds,
        progressService: _progress,
      ),
    );
    if (mounted) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlaybackProgress>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(context),
                Text(
                  'Falha ao carregar o progresso: ${snapshot.error}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }
        final items = snapshot.data;
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heading(context),
              if (items != null && items.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 154,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final episodeName = item.episodeTitle;
                      final episodeText = item.episodeLabel.isEmpty
                          ? ''
                          : '${item.episodeLabel}'
                              '${episodeName == null || episodeName.isEmpty ? '' : ' · $episodeName'}';
                      return SizedBox(
                        width: 320,
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _resume(item),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: item.posterUrl == null
                                        ? const SizedBox(
                                            width: 72,
                                            height: 108,
                                            child: ColoredBox(
                                              color: Color(0xFF10192D),
                                              child: Icon(Icons.movie_outlined),
                                            ),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: item.posterUrl!,
                                            width: 72,
                                            height: 108,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                const SizedBox(
                                              width: 72,
                                              height: 108,
                                              child: ColoredBox(
                                                color: Color(0xFF10192D),
                                                child:
                                                    Icon(Icons.movie_outlined),
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (episodeText.isNotEmpty)
                                          Text(
                                            episodeText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: item.progressFraction,
                                          minHeight: 4,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.progressPercentage == null
                                              ? 'Tempo salvo: ${item.formattedPosition}'
                                              : '${item.progressPercentage}% assistido · '
                                                  '${item.formattedPosition} salvo',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _heading(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'CONTINUAR ASSISTINDO',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
}

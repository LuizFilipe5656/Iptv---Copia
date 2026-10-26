import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/addon.dart';
import '../models/stremio_meta_item.dart';
import '../models/stremio_stream.dart';
import '../repositories/stream_repository.dart';
import '../services/playback_progress_service.dart';
import 'player_screen.dart';

class StremioSourcesSheet extends StatefulWidget {
  const StremioSourcesSheet({
    super.key,
    required this.item,
    required this.addons,
    required this.repository,
    this.playbackContentId,
    this.contentTitle,
    this.season,
    this.episode,
    this.episodeTitle,
    this.posterUrl,
    this.progressService,
    this.nextEpisodeTitle,
    this.onNextEpisode,
  });

  final StremioMetaItem item;
  final List<Addon> addons;
  final StreamRepository repository;
  final String? playbackContentId;
  final String? contentTitle;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final String? posterUrl;
  final PlaybackProgressService? progressService;
  final String? nextEpisodeTitle;
  final Future<void> Function()? onNextEpisode;

  @override
  State<StremioSourcesSheet> createState() => _SourcesSheetState();
}

class _SourcesSheetState extends State<StremioSourcesSheet> {
  late Future<StreamRepositoryResult> _result;

  @override
  void initState() {
    super.initState();
    _result = _load();
  }

  Future<StreamRepositoryResult> _load() => widget.repository.getStreams(
        type: widget.item.type,
        contentId: widget.item.id,
        addons: widget.addons,
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: FutureBuilder<StreamRepositoryResult>(
          future: _result,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _SourcesMessage(
                message: 'Falha ao buscar fontes: ${snapshot.error}',
                onRetry: () => setState(() => _result = _load()),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final result = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (result.streams.isEmpty)
                    Text(
                      result.compatibleProviderCount == 0
                          ? 'Este addon fornece metadados ou catálogo, mas não fornece fontes de reprodução.'
                          : 'Nenhuma fonte de vídeo foi retornada.',
                    ),
                  for (final stream in result.streams)
                    _streamTile(context, stream, result.subtitles),
                  if (result.subtitles.isNotEmpty) ...[
                    const Divider(),
                    Text('Legendas',
                        style: Theme.of(context).textTheme.titleMedium),
                    for (final subtitle in result.subtitles)
                      ListTile(
                        leading: const Icon(Icons.subtitles_outlined),
                        title: Text(
                            subtitle.lang.isEmpty ? 'Legenda' : subtitle.lang),
                        subtitle: Text(subtitle.addonName),
                      ),
                  ],
                  for (final entry in result.errors.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (result.compatibleProviderCount == 0 &&
                      result.errors.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Nenhum addon instalado declara suporte a streams '
                        'para este tipo de conteúdo/ID.',
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _streamTile(
    BuildContext context,
    StremioStream stream,
    List<StremioSubtitle> subtitles,
  ) {
    final direct = stream.isDirectUrl;
    final externalUri = Uri.tryParse(stream.externalUrl ?? '');
    final external = externalUri != null &&
        const {'http', 'https'}.contains(externalUri.scheme) &&
        externalUri.host.isNotEmpty;
    return ListTile(
      leading: Icon(
        direct
            ? Icons.play_circle_outline
            : external
                ? Icons.open_in_new
                : Icons.cloud_download_outlined,
      ),
      title: Text(stream.displayTitle),
      subtitle: Text(
        direct
            ? stream.addonName
            : external
                ? '${stream.addonName} · Abrir no serviço externo'
                : '${stream.addonName} · Requer cliente BitTorrent/debrid; '
                    'não é uma URL reproduzível diretamente.',
      ),
      enabled: direct || external,
      onTap: direct
          ? () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.pushNamed(
                PlayerScreen.routeName,
                arguments: PlayerLaunchRequest(
                  url: stream.url!,
                  contentId: widget.playbackContentId ?? widget.item.id,
                  contentType: widget.item.type,
                  contentTitle: widget.contentTitle ?? widget.item.name,
                  season: widget.season,
                  episode: widget.episode,
                  episodeTitle: widget.episodeTitle,
                  posterUrl: widget.posterUrl ?? widget.item.poster,
                  progressService: widget.progressService,
                  nextEpisodeTitle: widget.nextEpisodeTitle,
                  addonSubtitles: subtitles,
                  onNextEpisode: widget.onNextEpisode,
                ),
              );
            }
          : external
              ? () async {
                  try {
                    final opened = await launchUrl(
                      externalUri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (opened || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Não foi possível abrir o link externo.'),
                      ),
                    );
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Falha ao abrir link externo: $error'),
                        ),
                      );
                    }
                  }
                }
              : null,
    );
  }
}

class _SourcesMessage extends StatelessWidget {
  const _SourcesMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, maxLines: 4, overflow: TextOverflow.ellipsis),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
}

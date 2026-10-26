import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

import '../models/stremio_stream.dart';
import '../models/subtitle_track.dart';
import '../services/playback_progress_service.dart';
import '../services/subtitles_service.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.url,
    this.contentId,
    this.contentType = 'movie',
    this.contentTitle,
    this.season,
    this.episode,
    this.episodeTitle,
    this.posterUrl,
    this.startPositionMilliseconds,
    this.progressService,
    this.nextEpisodeTitle,
    this.onNextEpisode,
    this.subtitlesService,
    this.addonSubtitles = const [],
    this.isLocalFile = false,
  });

  static const routeName = '/player';

  final String url;
  final String? contentId;
  final String contentType;
  final String? contentTitle;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final String? posterUrl;
  final int? startPositionMilliseconds;
  final PlaybackProgressService? progressService;
  final String? nextEpisodeTitle;
  final Future<void> Function()? onNextEpisode;
  final SubtitlesService? subtitlesService;
  final List<StremioSubtitle> addonSubtitles;
  final bool isLocalFile;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class PlayerLaunchRequest {
  const PlayerLaunchRequest({
    required this.url,
    required this.contentId,
    this.contentType = 'movie',
    this.contentTitle,
    this.season,
    this.episode,
    this.episodeTitle,
    this.posterUrl,
    this.startPositionMilliseconds,
    this.progressService,
    this.nextEpisodeTitle,
    this.onNextEpisode,
    this.addonSubtitles = const [],
    this.isLocalFile = false,
  });

  final String url;
  final String contentId;
  final String contentType;
  final String? contentTitle;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final String? posterUrl;
  final int? startPositionMilliseconds;
  final PlaybackProgressService? progressService;
  final String? nextEpisodeTitle;
  final Future<void> Function()? onNextEpisode;
  final List<StremioSubtitle> addonSubtitles;
  final bool isLocalFile;
}

class _PlayerScreenState extends State<PlayerScreen> {
  BetterPlayerController? _player;
  late final SubtitlesService? _subtitles;
  late final bool _ownsSubtitlesService;
  late final PlaybackProgressService _progress;
  String? _subtitleError;
  String? _progressError;
  Duration _resumePosition = Duration.zero;
  Duration _lastSavedPosition = Duration.zero;
  bool _playbackFinished = false;
  bool _nextEpisodePromptShown = false;

  @override
  void initState() {
    super.initState();
    _ownsSubtitlesService =
        !widget.isLocalFile && widget.subtitlesService == null;
    _subtitles = widget.isLocalFile
        ? null
        : widget.subtitlesService ?? OpenSubtitlesService();
    _progress = widget.progressService ?? PlaybackProgressService();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    var tracks = <SubtitleTrack>[];
    PlaybackProgress? savedProgress;
    if (!widget.isLocalFile && widget.contentId != null) {
      try {
        tracks = await _subtitles!.searchSubtitles(
          widget.contentId!,
          type: widget.contentType,
        );
      } catch (error) {
        _subtitleError = error.toString();
      }
      try {
        savedProgress = await _progress.getProgressFor(
          contentId: widget.contentId!,
          season: widget.season,
          episode: widget.episode,
        );
      } catch (error) {
        _progressError = error.toString();
      }
    }

    if (!mounted) {
      return;
    }
    _resumePosition = Duration(
      milliseconds: widget.startPositionMilliseconds ??
          savedProgress?.positionMilliseconds ??
          0,
    );

    final preferredTrackIndex = tracks.indexWhere(
      (track) => track.language == SubtitleLanguage.ptBr,
    );
    final selectedTrackIndex = preferredTrackIndex >= 0
        ? preferredTrackIndex
        : tracks.isEmpty
            ? -1
            : 0;
    final source = PlayerDataSource(
      widget.isLocalFile ? DataSourceType.file : DataSourceType.network,
      widget.url,
      videoFormat: widget.contentType == 'tv' &&
          Uri.tryParse(widget.url)?.path.toLowerCase().endsWith('.m3u8') == true
          ? VideoFormat.hls
          : null,
      subtitles: [
        for (var index = 0; index < tracks.length; index++)
          PlayerSubtitlesSource(
            type: PlayerSubtitlesSourceType.network,
            urls: [tracks[index].url.toString()],
            name: '${tracks[index].language.label} â€” ${tracks[index].name}',
            selectedByDefault: index == selectedTrackIndex,
          ),
        for (final subtitle in widget.addonSubtitles)
          PlayerSubtitlesSource(
            type: PlayerSubtitlesSourceType.network,
            urls: [subtitle.url],
            name:
                '${subtitle.lang.isEmpty ? 'Legenda' : subtitle.lang} â€” ${subtitle.addonName}',
          ),
      ],
    );
    final player = BetterPlayerController(
      PlayerConfiguration(
        autoPlay: true,
        aspectRatio: 16 / 9,
        translations: [PlayerTranslations.portuguese()],
        controlsConfiguration: const PlayerControlsConfiguration(
          enablePlayPause: true,
          enableFullscreen: true,
          enableAudioTracks: true,
          enableSubtitles: true,
          enableQualities: true,
          enableOverflowMenu: true,
          showControls: true,
          showControlsOnInitialize: true,
        ),
      ),
      betterPlayerDataSource: source,
    );
    player.addEventsListener(_handlePlayerEvent);

    setState(() => _player = player);
  }

  void _handlePlayerEvent(PlayerEvent event) {
    switch (event.betterPlayerEventType) {
      case PlayerEventType.initialized:
        if (_resumePosition > Duration.zero) {
          unawaited(_seekToSavedPosition());
        }
        break;
      case PlayerEventType.progress:
        final position = event.parameters?['progress'];
        final duration = event.parameters?['duration'];
        if (position is Duration &&
            position - _lastSavedPosition >= const Duration(seconds: 15)) {
          _lastSavedPosition = position;
          unawaited(
            _persistProgress(
              position: position,
              duration: duration is Duration ? duration : null,
            ),
          );
        }
        break;
      case PlayerEventType.pause:
      case PlayerEventType.seekTo:
        final value = _player?.videoPlayerValue;
        final position = value?.position;
        final duration = value?.duration;
        if (position != null) {
          _lastSavedPosition = position;
          unawaited(_persistProgress(position: position, duration: duration));
        }
        break;
      case PlayerEventType.finished:
        _playbackFinished = true;
        unawaited(_removeProgress());
        if (widget.onNextEpisode != null && !_nextEpisodePromptShown) {
          _nextEpisodePromptShown = true;
          unawaited(_offerNextEpisode());
        }
        break;
      default:
        break;
    }
  }

  Future<void> _seekToSavedPosition() async {
    try {
      await _player?.seekTo(_resumePosition);
    } catch (error) {
      _showProgressError(error);
    }
  }

  Future<void> _persistProgress({
    required Duration position,
    Duration? duration,
  }) async {
    final contentId = widget.contentId;
    if (widget.isLocalFile ||
        contentId == null ||
        contentId.isEmpty ||
        position <= Duration.zero ||
        _playbackFinished) {
      return;
    }

    try {
      await _progress.save(
        PlaybackProgress(
          contentId: contentId,
          title: widget.contentTitle ?? contentId,
          contentType: widget.contentType,
          url: widget.url,
          positionMilliseconds: position.inMilliseconds,
          updatedAtMilliseconds: DateTime.now().millisecondsSinceEpoch,
          season: widget.season,
          episode: widget.episode,
          episodeTitle: widget.episodeTitle,
          durationMilliseconds: duration?.inMilliseconds,
          posterUrl: widget.posterUrl,
        ),
      );
      if (mounted && _progressError != null) {
        setState(() => _progressError = null);
      }
    } catch (error) {
      _showProgressError(error);
    }
  }

  Future<void> _removeProgress() async {
    final contentId = widget.contentId;
    if (widget.isLocalFile || contentId == null || contentId.isEmpty) {
      return;
    }

    try {
      final progress = await _progress.getProgressFor(
        contentId: contentId,
        season: widget.season,
        episode: widget.episode,
      );
      if (progress != null) {
        await _progress.remove(progress);
      }
    } catch (error) {
      _showProgressError(error);
    }
  }

  Future<void> _offerNextEpisode() async {
    final nextEpisode = widget.onNextEpisode;
    if (nextEpisode == null || !mounted) return;
    final watchNext = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('PrÃ³ximo EpisÃ³dio'),
        content: Text(
          widget.nextEpisodeTitle == null
              ? 'Deseja assistir ao prÃ³ximo episÃ³dio agora?'
              : 'Deseja assistir a "${widget.nextEpisodeTitle}" agora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Depois'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Assistir Agora'),
          ),
        ],
      ),
    );
    if (watchNext != true || !mounted) return;
    Navigator.of(context).pop();
    await nextEpisode();
  }

  void _showProgressError(Object error) {
    if (!mounted) {
      return;
    }
    setState(() => _progressError = error.toString());
  }

  @override
  void dispose() {
    final player = _player;
    if (player != null) {
      player.removeEventsListener(_handlePlayerEvent);
      final value = player.videoPlayerValue;
      if (value != null && !_playbackFinished) {
        unawaited(
          _persistProgress(position: value.position, duration: value.duration),
        );
      }
    }
    _player?.dispose();
    if (_ownsSubtitlesService) {
      _subtitles!.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ExoPlayer')),
      body: _player == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: BetterPlayer(controller: _player!)),
                if (_subtitleError != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'NÃ£o foi possÃ­vel carregar as legendas: $_subtitleError',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_progressError != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'NÃ£o foi possÃ­vel salvar/retomar o progresso: '
                      '$_progressError',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../models/subtitle_track.dart';
import '../services/subtitles_service.dart';

class SubtitlesScreen extends StatefulWidget {
  const SubtitlesScreen({
    super.key,
    required this.movie,
    this.service,
  });

  final Movie movie;
  final SubtitlesService? service;

  @override
  State<SubtitlesScreen> createState() => _SubtitlesScreenState();
}

class _SubtitlesScreenState extends State<SubtitlesScreen> {
  late final SubtitlesService _subtitles;
  late final bool _ownsService;
  late Future<List<SubtitleTrack>> _tracks;

  @override
  void initState() {
    super.initState();
    _ownsService = widget.service == null;
    _subtitles = widget.service ?? OpenSubtitlesService();
    _tracks = _loadTracks();
  }

  Future<List<SubtitleTrack>> _loadTracks() {
    return _subtitles.searchSubtitles(
      widget.movie.imdbId ?? widget.movie.id,
      type: widget.movie.type,
    );
  }

  @override
  void dispose() {
    if (_ownsService) {
      _subtitles.close();
    }
    super.dispose();
  }

  void _retry() {
    setState(() => _tracks = _loadTracks());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legendas — OpenSubtitles')),
      body: FutureBuilder<List<SubtitleTrack>>(
        future: _tracks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Falha ao buscar legendas no OpenSubtitles: '
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tracks = snapshot.data!;
          if (tracks.isEmpty) {
            return const Center(
              child: Text('Nenhuma legenda PT-BR, EN ou ES encontrada.'),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  widget.movie.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'As legendas também ficam disponíveis no menu Legendas do player.',
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: tracks.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return ListTile(
                      leading: const Icon(Icons.subtitles_outlined),
                      title: Text(track.name),
                      subtitle: Text(track.language.label),
                      trailing: const Icon(Icons.check_circle_outline),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

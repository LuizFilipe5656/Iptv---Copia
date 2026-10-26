import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/subtitle_track.dart';

abstract interface class SubtitlesService {
  Future<List<SubtitleTrack>> searchSubtitles(
    String contentId, {
    String type = 'movie',
    SubtitleLanguage? language,
  });

  void close();
}

class OpenSubtitlesService implements SubtitlesService {
  OpenSubtitlesService({
    http.Client? client,
    Uri? baseUri,
  }) : _client = client ?? http.Client(),
       _baseUri = baseUri ?? Uri.https('opensubtitles-v3.strem.io', ''),
       _ownsClient = client == null;

  final http.Client _client;
  final Uri _baseUri;
  final bool _ownsClient;

  @override
  Future<List<SubtitleTrack>> searchSubtitles(
    String contentId, {
    String type = 'movie',
    SubtitleLanguage? language,
  }) async {
    if (type != 'movie' && type != 'series') {
      throw ArgumentError.value(type, 'type', 'Use movie ou series.');
    }
    if (contentId.trim().isEmpty) {
      throw ArgumentError.value(
        contentId,
        'contentId',
        'O ID do conteúdo não pode ser vazio.',
      );
    }

    final base = _baseUri.toString().replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse(
      '$base/subtitles/$type/${Uri.encodeComponent(contentId.trim())}.json',
    );
    final response = await _client.get(uri).timeout(
      const Duration(seconds: 12),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'OpenSubtitles retornou HTTP ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> || decoded['subtitles'] is! List) {
      throw const FormatException(
        'Resposta inválida de legendas do OpenSubtitles.',
      );
    }

    final tracks = <SubtitleTrack>[];
    for (final entry in decoded['subtitles'] as List) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException(
          'Legenda inválida na resposta do OpenSubtitles.',
        );
      }

      final code = entry['lang'];
      if (code is! String) {
        continue;
      }
      final trackLanguage = SubtitleLanguage.fromCode(code);
      if (trackLanguage == null ||
          (language != null && trackLanguage != language)) {
        continue;
      }
      tracks.add(SubtitleTrack.fromJson(entry));
    }

    return tracks;
  }

  @override
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

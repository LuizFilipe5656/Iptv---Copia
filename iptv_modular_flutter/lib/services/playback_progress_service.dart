import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/continue_watching.dart';
import 'local_storage_service.dart';

class PlaybackProgress {
  const PlaybackProgress({
    required this.contentId,
    required this.title,
    required this.contentType,
    required this.url,
    required this.positionMilliseconds,
    required this.updatedAtMilliseconds,
    this.season,
    this.episode,
    this.episodeTitle,
    this.durationMilliseconds,
    this.posterUrl,
  });

  factory PlaybackProgress.fromJson(Map<String, dynamic> json) {
    final contentId = json['contentId'];
    final title = json['title'];
    final contentType = json['contentType'];
    final url = json['url'];
    final position = json['positionMilliseconds'];
    final updatedAt = json['updatedAtMilliseconds'];
    if (contentId is! String ||
        contentId.isEmpty ||
        title is! String ||
        title.isEmpty ||
        contentType is! String ||
        url is! String ||
        position is! int ||
        updatedAt is! int) {
      throw const FormatException('Progresso de reprodução inválido.');
    }

    return PlaybackProgress(
      contentId: contentId,
      title: title,
      contentType: contentType,
      url: url,
      positionMilliseconds: position,
      updatedAtMilliseconds: updatedAt,
      season: json['season'] as int?,
      episode: json['episode'] as int?,
      episodeTitle: json['episodeTitle'] as String?,
      durationMilliseconds: json['durationMilliseconds'] as int?,
      posterUrl: json['posterUrl'] as String?,
    );
  }

  final String contentId;
  final String title;
  final String contentType;
  final String url;
  final int positionMilliseconds;
  final int updatedAtMilliseconds;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final int? durationMilliseconds;
  final String? posterUrl;

  String get key => '$contentId:${season ?? 0}:${episode ?? 0}';

  String get episodeLabel {
    if (season == null || episode == null) {
      return '';
    }
    if (season == 0) {
      return 'Especial ${episode.toString().padLeft(2, '0')}';
    }
    return 'T$season E$episode';
  }

  int? get progressPercentage {
    final duration = durationMilliseconds;
    if (duration == null || duration <= 0) return null;
    return (positionMilliseconds / duration * 100).round().clamp(0, 100);
  }

  double? get progressFraction {
    final percentage = progressPercentage;
    return percentage == null ? null : percentage / 100;
  }

  String get formattedPosition {
    final totalSeconds = positionMilliseconds ~/ 1000;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final minutes = (totalSeconds ~/ 60) % 60;
    final hours = totalSeconds ~/ 3600;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
    }
    return '$minutes:$seconds';
  }

  ContinueWatching get continueWatching => ContinueWatching(
        contentId: contentId,
        title: title,
        position: positionMilliseconds,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMilliseconds),
      );

  Map<String, dynamic> toJson() => {
        'contentId': contentId,
        'title': title,
        'contentType': contentType,
        'url': url,
        'positionMilliseconds': positionMilliseconds,
        'updatedAtMilliseconds': updatedAtMilliseconds,
        'season': season,
        'episode': episode,
        'episodeTitle': episodeTitle,
        'durationMilliseconds': durationMilliseconds,
        'posterUrl': posterUrl,
      };
}

class PlaybackProgressService {
  PlaybackProgressService({SharedPreferences? preferences})
      : _preferences = preferences;

  static const _storageKey = 'playback_progress';
  static const _maximumEntries = 30;
  final SharedPreferences? _preferences;

  Future<List<PlaybackProgress>> getProgress() async {
    final values = await LocalStorageService.getStringList(
      _storageKey,
      fallback: _preferences,
    );
    final items = values.map((value) {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Progresso de reprodução inválido.');
      }
      return PlaybackProgress.fromJson(decoded);
    }).toList()
      ..sort(
        (first, second) =>
            second.updatedAtMilliseconds.compareTo(first.updatedAtMilliseconds),
      );
    return List.unmodifiable(items);
  }

  Future<PlaybackProgress?> getProgressFor({
    required String contentId,
    int? season,
    int? episode,
  }) async {
    final key = '$contentId:${season ?? 0}:${episode ?? 0}';
    for (final progress in await getProgress()) {
      if (progress.key == key) {
        return progress;
      }
    }
    return null;
  }

  Future<void> save(PlaybackProgress progress) async {
    final entries = (await getProgress())
        .where((entry) => entry.key != progress.key)
        .toList()
      ..add(
        PlaybackProgress(
          contentId: progress.contentId,
          title: progress.title,
          contentType: progress.contentType,
          url: progress.url,
          positionMilliseconds: progress.positionMilliseconds,
          updatedAtMilliseconds: DateTime.now().millisecondsSinceEpoch,
          season: progress.season,
          episode: progress.episode,
          episodeTitle: progress.episodeTitle,
          durationMilliseconds: progress.durationMilliseconds,
          posterUrl: progress.posterUrl,
        ),
      );
    entries.sort(
      (first, second) =>
          second.updatedAtMilliseconds.compareTo(first.updatedAtMilliseconds),
    );
    final saved = await LocalStorageService.setStringList(
      _storageKey,
      entries
          .take(_maximumEntries)
          .map((entry) => jsonEncode(entry.toJson()))
          .toList(growable: false),
      fallback: _preferences,
    );
    if (!saved) {
      throw StateError('Não foi possível salvar o progresso de reprodução.');
    }
  }

  Future<void> remove(PlaybackProgress progress) async {
    final entries =
        (await getProgress()).where((entry) => entry.key != progress.key);
    final saved = await LocalStorageService.setStringList(
      _storageKey,
      entries.map((entry) => jsonEncode(entry.toJson())).toList(),
      fallback: _preferences,
    );
    if (!saved) {
      throw StateError('Não foi possível remover o progresso de reprodução.');
    }
  }

  Future<void> clearHistory() async {
    final saved = await LocalStorageService.setStringList(
      _storageKey,
      const [],
      fallback: _preferences,
    );
    if (!saved) {
      throw StateError('Não foi possível limpar o histórico de reprodução.');
    }
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/movie.dart';
import '../utils/localized_text.dart';

class CinemetaService {
  CinemetaService({
    http.Client? client,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _baseUri = baseUri ?? Uri.https('v3-cinemeta.strem.io', ''),
        _ownsClient = client == null;

  final http.Client _client;
  final Uri _baseUri;
  final bool _ownsClient;

  Future<List<Movie>> popularMovies() => _catalog('movie');

  Future<List<Movie>> moviesPage(int skip) => _catalog('movie', skip: skip);

  Future<List<Movie>> popularSeries() => _catalog('series');

  Future<List<Movie>> seriesPage(int skip) => _catalog('series', skip: skip);

  Future<List<Movie>> popularAnime() => _catalog('series', genre: 'Anime');

  Future<List<Movie>> popularCartoons() =>
      _catalog('series', genre: 'Animation');

  Future<List<Movie>> searchMovies(String query) => _search('movie', query);

  Future<List<Movie>> searchSeries(String query) => _search('series', query);

  Future<Movie?> movieDetails(String id) => details('movie', id);

  Future<Movie?> seriesDetails(String id) => details('series', id);

  Future<SeriesMetadata?> seriesMetadata(String id) async {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'O ID da série não pode ser vazio.');
    }
    final uri = _uri('/meta/series/${Uri.encodeComponent(id.trim())}.json');
    final Map<String, dynamic> json;
    try {
      json = await _getJson(uri);
    } on FormatException catch (error) {
      debugPrint(
        '[series] Invalid metadata response for series id=$id: $error',
      );
      return null;
    }
    final meta = json['meta'];
    if (meta == null) {
      debugPrint(
        '[series] series id=$id, meta id=null, seasons found=0, '
        'episodes found=0; received response=$json',
      );
      return null;
    }
    if (meta is! Map<String, dynamic>) {
      debugPrint(
        '[series] Invalid meta for series id=$id; received meta=$meta',
      );
      return null;
    }

    final metaId = meta['id'] is String ? meta['id'] as String : null;
    debugPrint('[series] series id=$id, meta id=$metaId');

    final Movie movie;
    try {
      movie = Movie.fromCinemetaJson(meta);
    } on FormatException catch (error) {
      debugPrint('[series] Ignoring invalid series metadata: $error; $meta');
      return null;
    }
    final rawVideos = meta['videos'];
    if (rawVideos != null && rawVideos is! List) {
      debugPrint(
        '[series] Invalid videos payload for series id=$id, '
        'meta id=$metaId: $rawVideos',
      );
    }
    final episodes = <SeriesEpisode>[];
    for (final entry in rawVideos as List? ?? const []) {
      if (entry is! Map<String, dynamic>) {
        debugPrint(
          '[series] Ignoring non-object episode for series id=$id, '
          'meta id=$metaId: $entry',
        );
        continue;
      }
      final episode = SeriesEpisode.tryFromJson(entry);
      if (episode != null) {
        episodes.add(episode);
      }
    }
    final metadata = SeriesMetadata(
      series: movie,
      episodes: List.unmodifiable(episodes),
    );
    debugPrint(
      '[series] series id=$id, meta id=$metaId, '
      'seasons found=${metadata.seasons.length}, '
      'episodes found=${metadata.episodes.length}',
    );
    if (metadata.episodes.isEmpty) {
      debugPrint(
        '[series] No valid episodes for series id=$id; '
        'received videos=$rawVideos',
      );
    }
    return metadata;
  }

  Future<Movie?> details(String type, String id) async {
    _validateType(type);
    if (id.trim().isEmpty) {
      throw ArgumentError.value(
          id, 'id', 'O ID do conteúdo não pode ser vazio.');
    }
    final json = await _getJson(
      _uri('/meta/$type/${Uri.encodeComponent(id)}.json'),
    );
    final meta = json['meta'];
    if (meta == null) {
      return null;
    }
    if (meta is! Map<String, dynamic>) {
      throw const FormatException('Resposta inválida de detalhes do Cinemeta.');
    }
    return Movie.fromCinemetaJson(meta);
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<List<Movie>> _catalog(String type, {String? genre, int skip = 0}) async {
    _validateType(type);
    final path = genre == null
        ? '/catalog/$type/top.json'
        : '/catalog/$type/top/genre=${Uri.encodeComponent(genre)}.json';
    final pagedPath = skip > 0 ? path.replaceFirst('.json', '/skip=$skip.json') : path;
    final json = await _getJson(_uri(pagedPath));
    final metas = json['metas'];
    if (metas is! List) {
      throw const FormatException(
          'Resposta de catálogo do Cinemeta sem metas.');
    }
    return metas.map((meta) {
      if (meta is! Map<String, dynamic>) {
        throw const FormatException(
            'Metadado inválido no catálogo do Cinemeta.');
      }
      return Movie.fromCinemetaJson(meta);
    }).toList(growable: false);
  }

  Future<List<Movie>> _search(String type, String query) async {
    _validateType(type);
    if (query.trim().isEmpty) {
      return const [];
    }
    final encodedQuery = Uri.encodeComponent(query.trim());
    final json = await _getJson(
      _uri('/catalog/$type/top/search=$encodedQuery.json'),
    );
    final metas = json['metas'];
    if (metas is! List) {
      throw const FormatException('Resposta de busca do Cinemeta sem metas.');
    }
    return metas.map((meta) {
      if (meta is! Map<String, dynamic>) {
        throw const FormatException('Metadado inválido na busca do Cinemeta.');
      }
      return Movie.fromCinemetaJson(meta);
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Cinemeta retornou HTTP ${response.statusCode}.',
        uri,
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Resposta JSON inválida do Cinemeta.');
    }
    return decoded;
  }

  Uri _uri(String path) {
    final base = _baseUri.toString().replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
  }

  void _validateType(String type) {
    if (type != 'movie' && type != 'series') {
      throw ArgumentError.value(type, 'type', 'Use movie ou series.');
    }
  }
}

class SeriesMetadata {
  const SeriesMetadata({
    required this.series,
    required this.episodes,
  });

  final Movie series;
  final List<SeriesEpisode> episodes;

  Map<int, List<SeriesEpisode>> get seasons {
    final grouped = <int, List<SeriesEpisode>>{};
    for (final episode in episodes) {
      grouped.putIfAbsent(episode.season, () => []).add(episode);
    }
    final seasonNumbers = grouped.keys.toList()..sort();
    return Map.unmodifiable({
      for (final season in seasonNumbers)
        season: List<SeriesEpisode>.unmodifiable(
          grouped[season]!..sort((a, b) => a.episode.compareTo(b.episode)),
        ),
    });
  }
}

class SeriesEpisode {
  const SeriesEpisode({
    required this.id,
    required this.title,
    required this.season,
    required this.episode,
    this.overview = '',
    this.thumbnailUrl,
    this.runtime,
    this.kind,
  });

  factory SeriesEpisode.fromJson(Map<String, dynamic> json) {
    final episode = tryFromJson(json);
    if (episode == null) {
      throw const FormatException(
        'Episódio Cinemeta precisa de id, title, season e episode válidos.',
      );
    }
    return episode;
  }

  static SeriesEpisode? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final season = json['season'];
    final episode = json['episode'];
    if (id is! String ||
        id.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        season is! num ||
        episode is! num) {
      debugPrint(
        '[series] Ignoring episode with missing or invalid id/title/season/'
        'episode: $json',
      );
      return null;
    }

    return SeriesEpisode(
      id: id,
      title: title,
      season: season.toInt(),
      episode: episode.toInt(),
      overview: localizedText(
            json,
            fields: const ['overview', 'description', 'summary', 'plot'],
          )?.text ??
          '',
      thumbnailUrl:
          json['thumbnail'] is String ? json['thumbnail'] as String : null,
      runtime: json['runtime']?.toString(),
      kind: json['type'] is String
          ? json['type'] as String
          : json['kind'] is String
              ? json['kind'] as String
              : json['category'] is String
                  ? json['category'] as String
                  : null,
    );
  }

  final String id;
  final String title;
  final int season;
  final int episode;
  final String overview;
  final String? thumbnailUrl;
  final String? runtime;
  final String? kind;

  String get specialCategory {
    final label = '${kind ?? ''} $title'.toLowerCase();
    if (RegExp(r'\bova\b').hasMatch(label)) return 'OVAs';
    if (RegExp(r'\boad\b').hasMatch(label)) return 'OADs';
    if (RegExp(r'\b(extra|bonus|omake)\b').hasMatch(label)) return 'Extras';
    return 'Especiais';
  }
}

bool isEpisodicContentType(String type) =>
    const {'series', 'anime', 'cartoon'}.contains(type.toLowerCase());

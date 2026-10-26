import '../utils/localized_text.dart';

class Movie {
  const Movie({
    required this.id,
    required this.title,
    this.type = 'movie',
    this.overview = '',
    this.posterUrl,
    this.bannerUrl,
    this.imdbId,
    this.imdbRating,
    this.releaseYear,
    this.genres = const [],
    this.updatedAt,
  });

  factory Movie.fromCinemetaJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['imdb_id'];
    final title = json['name'];
    if (id is! String || id.isEmpty || title is! String || title.isEmpty) {
      throw const FormatException(
          'Metadado Cinemeta precisa de id e name válidos.');
    }

    final ratingValue = json['imdbRating'];
    final yearValue = json['year'] ?? json['releaseInfo'];
    final parsedYear = yearValue is String
        ? int.tryParse(RegExp(r'\d{4}').firstMatch(yearValue)?.group(0) ?? '')
        : yearValue is num
            ? yearValue.toInt()
            : null;

    final overview = localizedText(
      json,
      fields: const ['description', 'overview', 'summary', 'plot'],
    );
    return Movie(
      id: id,
      title: title,
      type: json['type'] as String? ?? 'movie',
      overview: overview?.text ?? '',
      posterUrl: json['poster'] as String?,
      bannerUrl: json['background'] as String?,
      imdbId: json['imdb_id'] as String? ?? id,
      imdbRating: ratingValue is num
          ? ratingValue.toDouble()
          : ratingValue is String
              ? double.tryParse(ratingValue)
              : null,
      releaseYear: parsedYear,
      genres: json['genres'] is List
          ? (json['genres'] as List).whereType<String>().toList()
          : const [],
      updatedAt: json['updated_at'] as String?,
    );
  }

  final String id;
  final String title;
  final String type;
  final String overview;
  final String? posterUrl;
  final String? bannerUrl;
  final String? imdbId;
  final double? imdbRating;
  final int? releaseYear;
  final List<String> genres;
  final String? updatedAt;

  String get fallbackPoster {
    if (imdbId == null) {
      return '';
    }

    return 'https://images.metahub.space/poster/medium/$imdbId/img';
  }
}

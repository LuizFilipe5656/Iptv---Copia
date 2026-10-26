import 'package:url_launcher/url_launcher.dart';

enum YoutubeVideoCategory {
  officialTrailer('Trailer Oficial'),
  clips('Clipes'),
  lives('Lives');

  const YoutubeVideoCategory(this.label);

  final String label;
}

abstract interface class YoutubeService {
  Uri searchUri(String query, {YoutubeVideoCategory category});

  Future<bool> openSearch(
    String query, {
    YoutubeVideoCategory category,
  });
}

class ExternalYoutubeService implements YoutubeService {
  const ExternalYoutubeService();

  @override
  Uri searchUri(
    String query, {
    YoutubeVideoCategory category = YoutubeVideoCategory.officialTrailer,
  }) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw ArgumentError.value(query, 'query', 'A busca não pode ser vazia.');
    }

    final searchQuery = switch (category) {
      YoutubeVideoCategory.officialTrailer => '$normalizedQuery trailer oficial',
      YoutubeVideoCategory.clips => '$normalizedQuery clipes',
      YoutubeVideoCategory.lives => normalizedQuery,
    };

    return Uri.https(
      'www.youtube.com',
      '/results',
      {
        'search_query': searchQuery,
        if (category == YoutubeVideoCategory.lives) 'sp': 'EgJAAQ==',
      },
    );
  }

  @override
  Future<bool> openSearch(
    String query, {
    YoutubeVideoCategory category = YoutubeVideoCategory.officialTrailer,
  }) {
    return launchUrl(
      searchUri(query, category: category),
      mode: LaunchMode.externalApplication,
    );
  }
}

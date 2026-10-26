import 'dart:convert';
import 'package:http/http.dart' as http;

class AnimeCatalogItem {
  const AnimeCatalogItem({
    required this.id,
    required this.title,
    required this.source,
    this.poster,
    this.description,
    this.year,
    this.malId,
    this.anilistId,
  });
  final String id;
  final String title;
  final String source;
  final String? poster;
  final String? description;
  final int? year;
  final int? malId;
  final int? anilistId;
}

class AnimeCatalogService {
  AnimeCatalogService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;
  final http.Client _client;
  final bool _ownsClient;
  Future<List<AnimeCatalogItem>> getPopularAnimes() async {
    try {
      final results = await _getAniList();
      if (results.isNotEmpty) return results;
    } catch (error) {
      print('ANILIST ERRO: $error');
    }
    try {
      return await _getJikan();
    } catch (error) {
      print('JIKAN ERRO: $error');
      return [];
    }
  }

  Future<List<AnimeCatalogItem>> _getAniList() async {
    const query = r'''
query {
  Page(page: 1, perPage: 30) {
    media(type: ANIME, sort: POPULARITY_DESC, isAdult: false) {
      id
      idMal
      title {
        romaji
        english
        native
      }
      description(asHtml: false)
      coverImage {
        extraLarge
        large
      }
      startDate {
        year
      }
    }
  }
}
''';
    final response = await _client
        .post(
          Uri.parse('https://graphql.anilist.co'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'query': query}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('AniList HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final media = decoded['data']['Page']['media'] as List;
    return media.whereType<Map>().map((item) {
      final titles = item['title'] as Map? ?? {};
      final cover = item['coverImage'] as Map? ?? {};
      final startDate = item['startDate'] as Map? ?? {};
      final id = item['id'] as int;
      return AnimeCatalogItem(
        id: 'anilist:$id',
        anilistId: id,
        malId: item['idMal'] as int?,
        title: (titles['english'] ??
                titles['romaji'] ??
                titles['native'] ??
                'Sem título')
            .toString(),
        source: 'AniList',
        poster: (cover['extraLarge'] ?? cover['large'])?.toString(),
        description: item['description']?.toString(),
        year: startDate['year'] as int?,
      );
    }).toList();
  }

  Future<List<AnimeCatalogItem>> _getJikan() async {
    final response = await _client
        .get(
          Uri.parse('https://api.jikan.moe/v4/top/anime'),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Jikan HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final data = decoded['data'] as List;
    return data.whereType<Map>().map((item) {
      final images = item['images'] as Map? ?? {};
      final jpg = images['jpg'] as Map? ?? {};
      final malId = item['mal_id'] as int;
      return AnimeCatalogItem(
        id: 'mal:$malId',
        malId: malId,
        title:
            (item['title_english'] ?? item['title'] ?? 'Sem título').toString(),
        source: 'Jikan',
        poster: (jpg['large_image_url'] ?? jpg['image_url'])?.toString(),
        description: item['synopsis']?.toString(),
        year: item['year'] as int?,
      );
    }).toList();
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

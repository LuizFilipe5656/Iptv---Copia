import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/stremio_meta_item.dart';

class DoramaCatalogService {
  DoramaCatalogService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;
  final http.Client _client;
  final bool _ownsClient;
  Future<List<StremioMetaItem>> getPopularDoramas() async {
    final queries = <String>[
      'Korean drama',
      'Japanese drama',
      'Chinese drama',
      'K-drama',
    ];
    final items = <StremioMetaItem>[];
    final seen = <String>{};
    for (final query in queries) {
      try {
        final uri = Uri.https(
          'api.tvmaze.com',
          '/search/shows',
          {'q': query},
        );
        final response =
            await _client.get(uri).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          debugPrint(
            'TVMAZE HTTP ${response.statusCode}: $query',
          );
          continue;
        }
        final decoded = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        if (decoded is! List) {
          continue;
        }
        for (final result in decoded) {
          if (result is! Map) {
            continue;
          }
          final show = result['show'];
          if (show is! Map) {
            continue;
          }
          final id = show['id'];
          final name = show['name'];
          if (id == null || name == null) {
            continue;
          }
          final key = id.toString();
          if (!seen.add(key)) {
            continue;
          }
          final imageData = show['image'];
          final images = imageData is Map ? imageData : <String, dynamic>{};
          final summary = (show['summary'] ?? '')
              .toString()
              .replaceAll(RegExp(r'<[^>]*>'), '');
          final premiered = (show['premiered'] ?? '').toString();
          items.add(
            StremioMetaItem.fromJson({
              'id': 'tvmaze:$key',
              'type': 'series',
              'name': name.toString(),
              'description': summary,
              'poster': images['original'] ?? images['medium'],
              'background': images['original'] ?? images['medium'],
              'releaseInfo': premiered,
              'year': premiered.length >= 4 ? premiered.substring(0, 4) : '',
              'genres': <String>['Dorama'],
              'source': 'TVmaze',
              'tvmazeId': id,
            }),
          );
        }
      } catch (error) {
        debugPrint(
          'ERRO TVMAZE ($query): $error',
        );
      }
    }
    debugPrint(
      'DORAMAS TVMAZE: ${items.length} titulos',
    );
    return items;
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

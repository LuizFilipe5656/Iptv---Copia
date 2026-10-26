import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/watchhub_offer.dart';

abstract interface class WatchhubService {
  Future<List<WatchhubOffer>> availabilityFor(
    String contentId, {
    String type = 'movie',
  });

  void close();
}

class HttpWatchhubService implements WatchhubService {
  HttpWatchhubService({
    http.Client? client,
    Uri? baseUri,
  }) : _client = client ?? http.Client(),
       _baseUri = baseUri ?? Uri.https('watchhub.strem.io', ''),
       _ownsClient = client == null;

  final http.Client _client;
  final Uri _baseUri;
  final bool _ownsClient;

  @override
  Future<List<WatchhubOffer>> availabilityFor(
    String contentId, {
    String type = 'movie',
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
      '$base/stream/$type/${Uri.encodeComponent(contentId.trim())}.json',
    );
    final response = await _client.get(uri).timeout(
      const Duration(seconds: 12),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'WatchHub retornou HTTP ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> || decoded['streams'] is! List) {
      throw const FormatException('Resposta inválida de disponibilidade WatchHub.');
    }

    final offers = <WatchhubOffer>[];
    for (final entry in decoded['streams'] as List) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Oferta inválida na resposta WatchHub.');
      }
      offers.add(WatchhubOffer.fromJson(entry));
    }
    return offers;
  }

  @override
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

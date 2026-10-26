import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/addon.dart';
import '../models/stremio_stream.dart';
import '../services/local_storage_service.dart';
import '../utils/stremio_cache_key.dart';
import 'addon_repository.dart';

class StreamRepository {
  StreamRepository({
    required AddonRepository addonRepository,
    http.Client? client,
  })  : _addonRepository = addonRepository,
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  static const _cacheDuration = Duration(minutes: 5);
  final AddonRepository _addonRepository;
  final http.Client _client;
  final bool _ownsClient;
  final Map<String, StreamRepositoryResult> _memoryCache = {};
  final Map<String, DateTime> _cacheDates = {};

  Future<StreamRepositoryResult> getStreams({
    required String type,
    required String contentId,
    required Iterable<Addon> addons,
  }) async {
    if (type.trim().isEmpty || contentId.trim().isEmpty) {
      throw ArgumentError('type e contentId sÃ£o obrigatÃ³rios.');
    }
    final providers = addons.where((addon) => addon.enabled).toList();
    final responses = await Future.wait(providers.map((addon) async {
      try {
        final manifest = await _addonRepository.getManifest(addon);
        final normalizedType = type.toLowerCase().trim();
        const episodicTypes = {
          'series',
          'anime',
          'cartoon',
          'tv',
          'dorama',
          'drama',
          'kdrama',
          'cdrama',
          'jdrama',
        };
        final candidateTypes = <String>[
          normalizedType,
          if (episodicTypes.contains(normalizedType) &&
              normalizedType != 'series')
            'series',
        ];
        final streamTypes = candidateTypes
            .where((candidate) =>
                manifest.supportsResource('stream', candidate, contentId))
            .toList();
        final subtitleTypes = candidateTypes
            .where((candidate) =>
                manifest.supportsResource('subtitles', candidate, contentId))
            .toList();
        final hasStreams = streamTypes.isNotEmpty;
        final hasSubtitles = subtitleTypes.isNotEmpty;
        if (!hasStreams && !hasSubtitles) {
          return _ProviderStreamResult.empty();
        }
        final streams = <StremioStream>[];
        final subtitles = <StremioSubtitle>[];
        if (hasStreams) {
          final result =
              await _fetchStreams(addon, streamTypes.first, contentId);
          streams.addAll(result);
        }
        if (hasSubtitles) {
          subtitles.addAll(
              await _fetchSubtitles(addon, subtitleTypes.first, contentId));
        }
        return _ProviderStreamResult(
          streams: streams,
          subtitles: subtitles,
          compatible: true,
        );
      } catch (error) {
        return _ProviderStreamResult(error: error, addonName: addon.name);
      }
    }));
    final allStreams = responses.expand((result) => result.streams).toList();
    final allSubtitles =
        responses.expand((result) => result.subtitles).toList();
    final errors = <String, Object>{
      for (final result in responses)
        if (result.error != null) result.addonName!: result.error!,
    };
    return StreamRepositoryResult(
      streams: List.unmodifiable(allStreams),
      subtitles: List.unmodifiable(allSubtitles),
      errors: Map.unmodifiable(errors),
      compatibleProviderCount:
          responses.where((result) => result.compatible).length,
    );
  }

  Future<List<StremioStream>> _fetchStreams(
    Addon addon,
    String type,
    String contentId,
  ) async {
    final key = _cacheKey(
      'stream',
      addon.id,
      addon.manifestUrl,
      type,
      contentId,
    );
    final cached = _memoryCache[key] ?? await _readCache(key);
    if (cached != null && _isFresh(key)) {
      return cached.streams;
    }
    try {
      final uri = _endpoint(
        addon.manifestUrl,
        'stream',
        type,
        contentId,
      );
      final response = await _client.get(uri).timeout(
            const Duration(seconds: 20),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw http.ClientException(
          'Streams de ${addon.name} respondeu HTTP ${response.statusCode}.',
          uri,
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['streams'] is! List) {
        throw const FormatException(
          'Resposta de streams invÃ¡lida: esperado um objeto com streams.',
        );
      }
      final streams = (decoded['streams'] as List).map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('Entrada invÃ¡lida na resposta streams.');
        }
        return StremioStream.fromJson(
          entry,
          addonId: addon.id,
          addonName: addon.name,
        );
      }).toList(growable: false);
      final result = StreamRepositoryResult(
        streams: List.unmodifiable(streams),
        subtitles: const [],
        errors: const {},
        compatibleProviderCount: 1,
      );
      await _writeCache(key, result);
      return result.streams;
    } catch (_) {
      if (cached != null) {
        return cached.streams;
      }
      rethrow;
    }
  }

  Future<List<StremioSubtitle>> _fetchSubtitles(
    Addon addon,
    String type,
    String contentId,
  ) async {
    final key = _cacheKey(
      'subtitles',
      addon.id,
      addon.manifestUrl,
      type,
      contentId,
    );
    final cached = _memoryCache[key] ?? await _readCache(key);
    if (cached != null && _isFresh(key)) {
      return cached.subtitles;
    }
    try {
      final uri = _endpoint(
        addon.manifestUrl,
        'subtitles',
        type,
        contentId,
      );
      final response = await _client.get(uri).timeout(
            const Duration(seconds: 20),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw http.ClientException(
          'Legendas de ${addon.name} respondeu HTTP ${response.statusCode}.',
          uri,
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['subtitles'] is! List) {
        throw const FormatException(
          'Resposta de legendas invÃ¡lida: esperado subtitles.',
        );
      }
      final subtitles = (decoded['subtitles'] as List).map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('Entrada invÃ¡lida de legenda.');
        }
        return StremioSubtitle.fromJson(
          entry,
          addonId: addon.id,
          addonName: addon.name,
        );
      }).toList(growable: false);
      final result = StreamRepositoryResult(
        streams: const [],
        subtitles: List.unmodifiable(subtitles),
        errors: const {},
        compatibleProviderCount: 1,
      );
      await _writeCache(key, result);
      return result.subtitles;
    } catch (_) {
      if (cached != null) {
        return cached.subtitles;
      }
      rethrow;
    }
  }

  Uri _endpoint(
    String manifestUrl,
    String resource,
    String type,
    String contentId,
  ) {
    final manifestUri = Uri.tryParse(manifestUrl);
    if (manifestUri == null ||
        !const {'http', 'https'}.contains(manifestUri.scheme) ||
        manifestUri.host.isEmpty) {
      throw ArgumentError.value(manifestUrl, 'manifestUrl', 'URL invÃ¡lida.');
    }
    var base = manifestUri.toString().split(RegExp(r'[?#]')).first;
    if (base.endsWith('/manifest.json')) {
      base = base.substring(0, base.length - 'manifest.json'.length);
    } else if (!base.endsWith('/')) {
      base = '$base/';
    }
    final safeId = contentId.split(':').map(Uri.encodeComponent).join(':');
    return Uri.parse(
      '$base$resource/${Uri.encodeComponent(type)}/$safeId.json',
    );
  }

  Future<StreamRepositoryResult?> _readCache(String key) async {
    final encoded = await LocalStorageService.getString(key);
    if (encoded == null) {
      return null;
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic> ||
        decoded['savedAt'] is! int ||
        decoded['streams'] is! List ||
        decoded['subtitles'] is! List) {
      throw const FormatException('Cache de streams invÃ¡lido.');
    }
    final streams = (decoded['streams'] as List).map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Stream invÃ¡lido no cache.');
      }
      return StremioStream.fromJson(
        entry,
        addonId: entry['addonId'] as String? ?? '',
        addonName: entry['addonName'] as String? ?? '',
      );
    }).toList(growable: false);
    final subtitles = (decoded['subtitles'] as List).map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Legenda invÃ¡lida no cache.');
      }
      return StremioSubtitle.fromJson(
        entry,
        addonId: entry['addonId'] as String? ?? '',
        addonName: entry['addonName'] as String? ?? '',
      );
    }).toList(growable: false);
    final result = StreamRepositoryResult(
      streams: List.unmodifiable(streams),
      subtitles: List.unmodifiable(subtitles),
      errors: const {},
      compatibleProviderCount: 1,
    );
    _memoryCache[key] = result;
    _cacheDates[key] = DateTime.fromMillisecondsSinceEpoch(
      decoded['savedAt'] as int,
    );
    return result;
  }

  Future<void> _writeCache(
    String key,
    StreamRepositoryResult result,
  ) async {
    final saved = await LocalStorageService.setString(
      key,
      jsonEncode({
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'streams': result.streams
            .map((stream) => {
                  'addonId': stream.addonId,
                  'addonName': stream.addonName,
                  'title': stream.title,
                  'name': stream.name,
                  'url': stream.url,
                  'externalUrl': stream.externalUrl,
                  'infoHash': stream.infoHash,
                  'fileIdx': stream.fileIndex,
                  'behaviorHints': stream.behaviorHints,
                })
            .toList(),
        'subtitles': result.subtitles
            .map((subtitle) => {
                  'addonId': subtitle.addonId,
                  'addonName': subtitle.addonName,
                  'url': subtitle.url,
                  'lang': subtitle.lang,
                  'id': subtitle.id,
                })
            .toList(),
      }),
    );
    if (!saved) {
      throw StateError('NÃ£o foi possÃ­vel salvar streams no cache local.');
    }
    _memoryCache[key] = result;
    _cacheDates[key] = DateTime.now();
  }

  bool _isFresh(String key) {
    final date = _cacheDates[key];
    return date != null && DateTime.now().difference(date) < _cacheDuration;
  }

  String _cacheKey(
    String resource,
    String addonId,
    String manifestUrl,
    String type,
    String contentId,
  ) =>
      stremioCacheKey(
        'stremio_$resource',
        '$addonId|$manifestUrl|$type|$contentId',
      );

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

class StreamRepositoryResult {
  const StreamRepositoryResult({
    required this.streams,
    required this.subtitles,
    required this.errors,
    required this.compatibleProviderCount,
  });

  final List<StremioStream> streams;
  final List<StremioSubtitle> subtitles;
  final Map<String, Object> errors;
  final int compatibleProviderCount;
}

class _ProviderStreamResult {
  const _ProviderStreamResult({
    this.streams = const [],
    this.subtitles = const [],
    this.compatible = false,
    this.error,
    this.addonName,
  });

  factory _ProviderStreamResult.empty() => const _ProviderStreamResult();

  final List<StremioStream> streams;
  final List<StremioSubtitle> subtitles;
  final bool compatible;
  final Object? error;
  final String? addonName;
}

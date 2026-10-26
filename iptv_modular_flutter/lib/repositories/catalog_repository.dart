import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/addon.dart';
import '../models/stremio_addon_manifest.dart';
import '../models/stremio_meta_item.dart';
import '../services/local_storage_service.dart';
import '../utils/stremio_cache_key.dart';

class CatalogRepository {
  CatalogRepository({http.Client? client}) : _client = client ?? http.Client(), _ownsClient = client == null;
  static const _cacheDuration = Duration(hours: 6);
  final http.Client _client;
  final bool _ownsClient;
  final Map<String, List<StremioMetaItem>> _memoryCache = {};
  final Map<String, DateTime> _cacheDates = {};

  Future<StremioMetaItem> getMeta({required Addon addon, required String type, required String id, StremioMetaItem? fallback}) async {
    final key = stremioCacheKey('stremio_meta', '${addon.id}|${addon.manifestUrl}|$type|$id');
    final cached = await _readMetaCache(key);
    try {
      final base = _baseFromManifestUri(_validateUrl(addon.manifestUrl));
      final uri = Uri.parse('$base/meta/${Uri.encodeComponent(type)}/${_encodeContentId(id)}.json');
      final response = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) throw http.ClientException('Metadados de ${addon.name} responderam HTTP ${response.statusCode}.', uri);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['meta'] is! Map<String, dynamic>) throw const FormatException('Resposta de metadados inválida: esperado meta.');
      final item = StremioMetaItem.fromJson(decoded['meta'] as Map<String, dynamic>);
      await _writeMetaCache(key, item);
      return item;
    } catch (_) {
      if (cached != null) return cached;
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  Future<AddonCatalogSearchResponse> searchAcrossAddons({required Iterable<Addon> addons, required String query, required Future<StremioAddonManifest> Function(Addon) loadManifest, Set<String>? types, Map<String, String> catalogFilters = const {}}) async {
    final normalized = query.trim(); final isSearching = normalized.isNotEmpty; final searchTerms = const {'search', 'query', 'q'};
    final addonResults = await Future.wait(addons.where((a) => a.enabled).map((addon) async {
      try {
        final manifest = await loadManifest(addon);
        final catalogs = manifest.catalogs.where((c) { if (types != null && !types.contains(c.type)) return false; if (!isSearching) return true; final hasSearch = c.extra.any((e) => searchTerms.contains(e.name.toLowerCase())); return hasSearch || manifest.catalogs.length <= 20; }).toList();
        final catalogResults = await Future.wait(catalogs.map((catalog) async {
          final supportsSearch = isSearching && catalog.extra.any((e) => searchTerms.contains(e.name.toLowerCase()));
          final parameters = <String, String>{};
          for (final extra in catalog.extra) {
            if (isSearching && searchTerms.contains(extra.name.toLowerCase())) { parameters[extra.name] = normalized; continue; }
            for (final filter in catalogFilters.entries) { if (filter.key.toLowerCase() != extra.name.toLowerCase()) continue; final v = _filterValueForExtra(extra.name, filter.value, extra.options); if (v != null) parameters[extra.name] = v; break; }
          }
          try {
            final items = await getCatalog(addon: addon, catalog: catalog, extra: parameters);
            final matches = !isSearching ? items : supportsSearch ? items : items.where((i) => i.name.toLowerCase().contains(normalized.toLowerCase()) || i.description.toLowerCase().contains(normalized.toLowerCase()));
            return (results: matches.map((item) => AddonCatalogSearchResult(addon: addon, item: item)).toList(), error: null as Object?);
          } catch (error) {
            try {
              final items = await getCatalog(addon: addon, catalog: catalog, extra: const {});
              final term = normalized.toLowerCase();
              final matches = !isSearching ? items : items.where((i) => i.name.toLowerCase().contains(term) || i.description.toLowerCase().contains(term));
              return (results: matches.map((item) => AddonCatalogSearchResult(addon: addon, item: item)).toList(), error: null as Object?);
            } catch (fallbackError) { return (results: <AddonCatalogSearchResult>[], error: fallbackError); }
          }
        }));
        return (results: catalogResults.expand((r) => r.results).toList(), errors: <String, Object>{for (var i = 0; i < catalogResults.length; i++) if (catalogResults[i].error != null) '${addon.name} · ${catalogs[i].name}': catalogResults[i].error!});
      } catch (error) { return (results: <AddonCatalogSearchResult>[], errors: <String, Object>{addon.name: error}); }
    }));
    final results = addonResults.expand((r) => r.results).toList();
    final errors = <String, Object>{for (final r in addonResults) ...r.errors};
    final deduplicated = <String, AddonCatalogSearchResult>{}; for (final r in results) { deduplicated.putIfAbsent('${r.item.type}|${r.item.id}', () => r); }
    return AddonCatalogSearchResponse(results: List.unmodifiable(deduplicated.values), errors: Map.unmodifiable(errors));
  }

  String? _filterValueForExtra(String name, String requestedValue, List<String> options) {
    if (name.toLowerCase() == 'year') return requestedValue; if (options.isEmpty) return null;
    final requested = _normalizeFilterValue(requestedValue);
    final aliases = switch (requested) { 'acao' => {'action'}, 'aventura' => {'adventure'}, 'comedia' => {'comedy'}, 'terror' => {'horror'}, 'ficcaocientifica' => {'sciencefiction', 'scifi'}, 'suspense' => {'thriller'}, 'fantasia' => {'fantasy'}, 'misterio' => {'mystery'}, 'familia' => {'family'}, 'infantil' => {'children', 'child', 'kids'}, 'documentario' => {'documentary'}, 'emandamento' => {'running', 'continuing'}, 'finalizada' => {'ended', 'finished'}, 'lancamento' => {'new', 'premiere'}, _ => <String>{}, };
    for (final option in options) { final n = _normalizeFilterValue(option); if (n == requested || aliases.contains(n)) return option; } return null;
  }
  String _normalizeFilterValue(String value) => value.toLowerCase().replaceAll('á', 'a').replaceAll('à', 'a').replaceAll('ã', 'a').replaceAll('â', 'a').replaceAll('é', 'e').replaceAll('ê', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ô', 'o').replaceAll('õ', 'o').replaceAll('ú', 'u').replaceAll('ç', 'c').replaceAll(RegExp(r'[^a-z0-9]'), '');
  Future<List<StremioMetaItem>> getCatalog({required Addon addon, required StremioCatalog catalog, Map<String, String> extra = const {}}) async {
    final cacheKey = _cacheKey(addon.id, addon.manifestUrl, catalog.type, catalog.id, extra);
    final cached = _memoryCache[cacheKey] ?? await _readCache(cacheKey); if (cached != null && _cacheIsFresh(cacheKey)) return cached;
    try {
      final manifestUri = _validateUrl(addon.manifestUrl); final base = _baseFromManifestUri(manifestUri); final path = 'catalog/${Uri.encodeComponent(catalog.type)}/${Uri.encodeComponent(catalog.id)}.json'; final endpoint = Uri.parse('$base$path'); final uri = extra.isEmpty ? endpoint : endpoint.replace(queryParameters: extra);
      final response = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) throw http.ClientException('Catálogo ${catalog.name} de ${addon.name} respondeu HTTP ${response.statusCode}.', uri);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)); if (decoded is! Map<String, dynamic> || decoded['metas'] is! List) throw const FormatException('Resposta de catálogo inválida.');
      final items = (decoded['metas'] as List).map((entry) { if (entry is! Map<String, dynamic>) throw const FormatException('Item inválido.'); return StremioMetaItem.fromJson(entry); }).toList();
      await _writeCache(cacheKey, items); _memoryCache[cacheKey] = items; return List.unmodifiable(items);
    } catch (error) { if (cached != null) return cached; rethrow; }
  }
  Future<List<StremioMetaItem>?> _readCache(String key) async { final encoded = await LocalStorageService.getString(key); if (encoded == null) return null; final decoded = jsonDecode(encoded); if (decoded is! Map<String, dynamic> || decoded['items'] is! List || decoded['savedAt'] is! int) throw const FormatException('Cache inválido.'); final items = (decoded['items'] as List).map((e) { if (e is! Map<String, dynamic>) throw const FormatException('Item inválido.'); return StremioMetaItem.fromJson(e); }).toList(); _memoryCache[key] = List.unmodifiable(items); _cacheDates[key] = DateTime.fromMillisecondsSinceEpoch(decoded['savedAt'] as int); return _memoryCache[key]; }
  Future<StremioMetaItem?> _readMetaCache(String key) async { final encoded = await LocalStorageService.getString(key); if (encoded == null) return null; final decoded = jsonDecode(encoded); if (decoded is! Map<String, dynamic>) throw const FormatException('Cache de metadados inválido.'); return StremioMetaItem.fromJson(decoded); }
  Future<void> _writeMetaCache(String key, StremioMetaItem item) async { final saved = await LocalStorageService.setString(key, jsonEncode(item.raw)); if (!saved) throw StateError('Não foi possível salvar metadados em cache.'); }
  Future<void> _writeCache(String key, List<StremioMetaItem> items) async { final saved = await LocalStorageService.setString(key, jsonEncode({'savedAt': DateTime.now().millisecondsSinceEpoch, 'items': items.map((i) => i.raw).toList()})); if (!saved) throw StateError('Não foi possível salvar o catálogo em cache.'); _cacheDates[key] = DateTime.now(); }
  bool _cacheIsFresh(String key) { final savedAt = _cacheDates[key]; return savedAt != null && DateTime.now().difference(savedAt) < _cacheDuration; }
  String _cacheKey(String addonId, String manifestUrl, String type, String catalogId, Map<String, String> extra) => stremioCacheKey('stremio_catalog', '$addonId|$manifestUrl|$type|$catalogId|${jsonEncode(extra)}');
  Uri _validateUrl(String value) { final uri = Uri.tryParse(value); if (uri == null || !const {'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) throw ArgumentError.value(value, 'manifestUrl', 'Manifest URL inválida.'); return uri; }
  String _baseFromManifestUri(Uri uri) { var base = uri.toString().split(RegExp(r'[?#]')).first; if (base.endsWith('/manifest.json')) base = base.substring(0, base.length - 'manifest.json'.length); else if (!base.endsWith('/')) base = '$base/'; return base; }
  String _encodeContentId(String id) => id.split(':').map(Uri.encodeComponent).join(':');
  void close() { if (_ownsClient) _client.close(); }
}
class AddonCatalogSearchResult { const AddonCatalogSearchResult({required this.addon, required this.item}); final Addon addon; final StremioMetaItem item; }
class AddonCatalogSearchResponse { const AddonCatalogSearchResponse({required this.results, required this.errors}); final List<AddonCatalogSearchResult> results; final Map<String, Object> errors; }
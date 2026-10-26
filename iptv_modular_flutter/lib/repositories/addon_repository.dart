import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/addon.dart';
import '../models/stremio_addon_manifest.dart';
import '../services/local_storage_service.dart';
import '../utils/stremio_cache_key.dart';

class AddonRepository {
  AddonRepository({
    AssetBundle? bundle,
    SharedPreferences? preferences,
    http.Client? client,
  })  : _bundle = bundle ?? rootBundle,
        _client = client ?? http.Client(),
        _ownsClient = client == null,
        _preferences = preferences;

  static const defaultAddonsAsset = 'assets/default_addons.json';
  static const installedAddonsKey = 'installed_addon_status';
  static const customAddonsKey = 'custom_addons';
  static const addonConfigurationKey = 'stremio_addon_configuration';
  static const configuredAddonUrlsKey = 'configured_addon_manifest_urls';
  static const _legacyAddonCleanupKey = 'legacy_torrentio_cleanup_v1';
  static const _legacyTvAddonCleanupKey = 'legacy_stremio_tv_cleanup_v1';
  static const supportedFixedAddonIds = {
    'cinemeta',
    'youtube',
    'public_domain_movies',
    'opensubtitles_v3',
    'froststream',
    'fenixflix',
    'comet.elfhosted.com',
    'pw.ers.netflix-catalog',
    'tmdb-addon',
    'marvel-addon',
    'aiometadata',
    'scplus',
    'streamasia',
  };
  static final _backgroundProviders = [
    Addon(
      id: 'community.tvplay.ipfs',
      name: 'TVPlay IPFS',
      url: 'https://tvplay.megaembed-frost.workers.dev/manifest.json',
      fixed: false,
    ),
    Addon(
      id: 'org.aistreams.v2',
      name: 'AI Streams v2',
      url: 'https://www.aistreams.org/manifest.json',
      fixed: false,
    ),
    Addon(
      id: 'catalogo-iptv-production',
      name: 'Catálogo IPTV',
      url: 'https://catalogo-iptv-production.up.railway.app/manifest.json',
      fixed: false,
    ),
    Addon(
      id: 'org.fayallc.animee.1',
      name: 'Animee',
      url: 'https://animee.stravo.site/local/manifest.json',
      fixed: false,
    ),
    Addon(
      id: 'com.zorak.plotcard',
      name: 'PlotCard',
      url: 'https://addons.zrk.app/plotcard/manifest.json',
      fixed: false,
    ),
    Addon(
      id: 'com.zorak.marquee',
      name: 'Marquee',
      url: 'https://addons.zrk.app/marquee/manifest.json',
      fixed: false,
    ),
  ];
  static const _validVersionPattern =
      r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$';

  final AssetBundle _bundle;
  final http.Client _client;
  final bool _ownsClient;
  final SharedPreferences? _preferences;
  final Map<String, StremioAddonManifest> _manifestMemoryCache = {};

  Future<StremioAddonManifest> getManifest(Addon addon) async {
    final cacheKey = _manifestCacheKey(addon);
    final cached =
        _manifestMemoryCache[cacheKey] ?? await _readCachedManifest(cacheKey);
    try {
      return await _downloadManifest(addon, cacheKey);
    } catch (error) {
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<StremioAddonManifest> refreshManifest(Addon addon) =>
      _downloadManifest(addon, _manifestCacheKey(addon));

  Future<StremioAddonManifest> _downloadManifest(
    Addon addon,
    String cacheKey,
  ) async {
    final uri = _validateManifestUrl(addon.manifestUrl);
    final response = await _client.get(uri).timeout(
          const Duration(seconds: 15),
        );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Manifest de ${addon.name} respondeu HTTP ${response.statusCode}.',
        uri,
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('O manifest precisa ser um objeto JSON.');
    }
    final manifest = StremioAddonManifest.fromJson(decoded);
    await _writeCachedManifest(cacheKey, decoded);
    _manifestMemoryCache[cacheKey] = manifest;
    return manifest;
  }

  Future<List<Addon>> getInstalledAddons() async =>
      (await getAllAddons()).where((addon) => addon.enabled).toList();

  Future<List<Addon>> getContentMetadataProviders() async {
    final providers = await getInstalledAddons();
    final providerIds = providers.map((addon) => addon.id).toSet();
    providers.addAll(
      _backgroundProviders.where((addon) => providerIds.add(addon.id)),
    );
    return List.unmodifiable(providers);
  }

  Future<Map<String, String>> getAddonConfiguration(String addonId) async {
    final encoded = await LocalStorageService.getString(
      addonConfigurationKey,
      fallback: _preferences,
    );
    if (encoded == null) return const {};
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Configurações de addons inválidas.');
    }
    final values = decoded[addonId];
    if (values == null) return const {};
    if (values is! Map<String, dynamic> ||
        values.values.any((value) => value is! String)) {
      throw FormatException('Configuração inválida para o addon $addonId.');
    }
    return values.cast<String, String>();
  }

  Future<void> saveAddonConfiguration(
    String addonId,
    Map<String, String> configuration,
  ) async {
    final encoded = await LocalStorageService.getString(
      addonConfigurationKey,
      fallback: _preferences,
    );
    final Map<String, dynamic> stored;
    if (encoded == null) {
      stored = {};
    } else {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Configurações de addons inválidas.');
      }
      stored = decoded;
    }
    stored[addonId] = configuration;
    final saved = await LocalStorageService.setString(
      addonConfigurationKey,
      jsonEncode(stored),
      fallback: _preferences,
    );
    if (!saved) {
      throw StateError('Não foi possível salvar a configuração do addon.');
    }
  }

  Future<void> installConfiguredAddon({
    required Addon addon,
    required String manifestUrl,
    required Map<String, String> configuration,
  }) async {
    final uri = _validateManifestUrl(manifestUrl);
    final configuredAddon = Addon(
      id: addon.id,
      name: addon.name,
      version: addon.version,
      author: addon.author,
      url: uri.toString(),
      description: addon.description,
      enabled: true,
      fixed: addon.fixed,
    );
    final manifest = await refreshManifest(configuredAddon);
    if (manifest.resources.isEmpty) {
      throw FormatException(
        'O manifest configurado precisa declarar ao menos um resource.',
      );
    }
    if (!RegExp(_validVersionPattern).hasMatch(manifest.version)) {
      throw FormatException(
        'O manifest configurado precisa declarar uma versão válida (ex.: 1.0.0).',
      );
    }

    await saveAddonConfiguration(addon.id, configuration);
    await _saveConfiguredManifest(
      addon: addon,
      configuredAddonId: manifest.id,
      manifestUrl: uri.toString(),
    );
    if (!addon.fixed) {
      await _setAddonEnabled(addon.id, true);
    }
  }

  Future<List<Addon>> getAllAddons() async {
    await _removeLegacyTorrentioData();
    await _removeLegacyStremioTvData();
    final source = await _bundle.loadString(defaultAddonsAsset);
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException(
        'Formato inválido para o catálogo de addons fixos.',
      );
    }
    final addons = decoded.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Entrada inválida no catálogo fixo.');
      }
      return Addon.fromJson(entry);
    }).toList();
    final defaultIds = addons.map((addon) => addon.id).toSet();
    if (addons.any((addon) => !addon.fixed) ||
        defaultIds.length != addons.length ||
        defaultIds.length != supportedFixedAddonIds.length ||
        !defaultIds.containsAll(supportedFixedAddonIds)) {
      throw const FormatException(
        'Os addons fixos precisam corresponder aos addons oficiais suportados.',
      );
    }

    final customEncoded = await LocalStorageService.getString(
      customAddonsKey,
      fallback: _preferences,
    );
    if (customEncoded != null) {
      final customDecoded = jsonDecode(customEncoded);
      if (customDecoded is! List) {
        throw const FormatException('Lista de addons personalizados inválida.');
      }
      final fixedIds = addons.map((addon) => addon.id).toSet();
      for (final entry in customDecoded) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException(
            'Entrada inválida de addon personalizado.',
          );
        }
        final custom = Addon.fromJson(entry);
        if (custom.fixed) {
          throw FormatException(
            'O addon personalizado "${custom.id}" não pode marcar-se como fixo.',
          );
        }
        if (!fixedIds.add(custom.id)) {
          throw FormatException(
            'O ID "${custom.id}" pertence a um addon fixo.',
          );
        }
        addons.add(custom);
      }
    }

    final configuredUrlsEncoded = await LocalStorageService.getString(
      configuredAddonUrlsKey,
      fallback: _preferences,
    );
    if (configuredUrlsEncoded != null) {
      final decodedUrls = jsonDecode(configuredUrlsEncoded);
      if (decodedUrls is! Map<String, dynamic>) {
        throw const FormatException(
          'Instalações configuradas de addons inválidas.',
        );
      }
      for (var index = 0; index < addons.length; index++) {
        final addon = addons[index];
        final record =
            _configuredManifestRecord(addon.id, decodedUrls[addon.id]);
        if (record != null) {
          addons[index] = _copyAddon(
            addon,
            url: record['configuredManifestUrl']!,
            configuredAddonId: record['configuredAddonId']!,
            configuredManifestUrl: record['configuredManifestUrl']!,
          );
        }
      }
    }

    final statusEncoded = await LocalStorageService.getString(
      installedAddonsKey,
      fallback: _preferences,
    );
    if (statusEncoded != null) {
      final statuses = jsonDecode(statusEncoded);
      if (statuses is! Map<String, dynamic> ||
          statuses.values.any((value) => value is! bool)) {
        throw const FormatException(
          'Estado de instalação de addons inválido.',
        );
      }
      for (final addon in addons.where((item) => !item.fixed)) {
        final enabled = statuses[addon.id];
        if (enabled is bool) {
          addon.enabled = enabled;
        }
      }
    }
    return List.unmodifiable(addons);
  }

  Future<void> _removeLegacyTorrentioData() async {
    if (await LocalStorageService.getString(
          _legacyAddonCleanupKey,
          fallback: _preferences,
        ) ==
        'true') {
      return;
    }

    final customEncoded = await LocalStorageService.getString(
      customAddonsKey,
      fallback: _preferences,
    );
    if (customEncoded != null) {
      final decoded = jsonDecode(customEncoded);
      if (decoded is! List) {
        throw const FormatException('Lista de addons personalizados inválida.');
      }
      final filtered = decoded.where((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException(
            'Entrada inválida de addon personalizado.',
          );
        }
        return !_isTorrentioData(entry);
      }).toList();
      if (filtered.length != decoded.length) {
        await _writeLocalValue(
          customAddonsKey,
          jsonEncode(filtered),
          'Não foi possível remover o addon legado.',
        );
      }
    }

    await _removeMapEntries(
      installedAddonsKey,
      'Estado de instalação de addons inválido.',
      (key, _) => _containsTorrentio(key),
    );
    await _removeMapEntries(
      addonConfigurationKey,
      'Configurações de addons inválidas.',
      (key, value) => _containsTorrentio(key) || _isTorrentioData(value),
    );
    await _removeMapEntries(
      configuredAddonUrlsKey,
      'Instalações configuradas de addons inválidas.',
      (key, value) => _containsTorrentio(key) || _isTorrentioData(value),
    );

    await LocalStorageService.removeEntriesWhere(
      (key, _) => const {
        'stremio_manifest_',
        'stremio_catalog_',
        'stremio_meta_',
        'stremio_stream_',
        'stremio_subtitles_',
      }.any(key.startsWith),
      fallback: _preferences,
    );
    await _writeLocalValue(
      _legacyAddonCleanupKey,
      'true',
      'Não foi possível registrar a migração de addons legados.',
    );
  }

  Future<void> _removeLegacyStremioTvData() async {
    if (await LocalStorageService.getString(
          _legacyTvAddonCleanupKey,
          fallback: _preferences,
        ) ==
        'true') {
      return;
    }

    bool isStremioTv(Object? value) {
      if (value is String) {
        final normalized = value.toLowerCase();
        return normalized.contains('community.stremio-iptv') ||
            normalized.contains('stremio-iptv') ||
            normalized.contains('ryann-devv.github.io');
      }
      if (value is Map) {
        return value.entries.any(
          (entry) => isStremioTv(entry.key) || isStremioTv(entry.value),
        );
      }
      if (value is Iterable) return value.any(isStremioTv);
      return false;
    }

    final customEncoded = await LocalStorageService.getString(
      customAddonsKey,
      fallback: _preferences,
    );
    if (customEncoded != null) {
      final decoded = jsonDecode(customEncoded);
      if (decoded is! List) {
        throw const FormatException('Lista de addons personalizados inválida.');
      }
      final filtered = decoded.where((entry) => !isStremioTv(entry)).toList();
      if (filtered.length != decoded.length) {
        await _writeLocalValue(
          customAddonsKey,
          jsonEncode(filtered),
          'Não foi possível remover o addon Stremio TV legado.',
        );
      }
    }

    for (final storageKey in [
      installedAddonsKey,
      addonConfigurationKey,
      configuredAddonUrlsKey,
    ]) {
      await _removeMapEntries(
        storageKey,
        'Dados de instalação de addons inválidos.',
        (key, value) => isStremioTv(key) || isStremioTv(value),
      );
    }

    await LocalStorageService.removeEntriesWhere(
      (key, _) => const {
        'stremio_manifest_',
        'stremio_catalog_',
        'stremio_meta_',
        'stremio_stream_',
        'stremio_subtitles_',
      }.any(key.startsWith),
      fallback: _preferences,
    );
    await _writeLocalValue(
      _legacyTvAddonCleanupKey,
      'true',
      'Não foi possível registrar a remoção do addon Stremio TV.',
    );
  }

  Future<void> _removeMapEntries(
    String storageKey,
    String invalidDataMessage,
    bool Function(String key, Object? value) shouldRemove,
  ) async {
    final encoded = await LocalStorageService.getString(
      storageKey,
      fallback: _preferences,
    );
    if (encoded == null) return;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(invalidDataMessage);
    }
    final filtered = Map<String, dynamic>.fromEntries(
      decoded.entries.where(
        (entry) => !shouldRemove(entry.key, entry.value),
      ),
    );
    if (filtered.length != decoded.length) {
      await _writeLocalValue(
        storageKey,
        jsonEncode(filtered),
        'Não foi possível limpar dados antigos de addons.',
      );
    }
  }

  Future<void> _writeLocalValue(
    String key,
    String value,
    String failureMessage,
  ) async {
    if (!await LocalStorageService.setString(
      key,
      value,
      fallback: _preferences,
    )) {
      throw StateError(failureMessage);
    }
  }

  bool _isTorrentioData(Object? value) {
    if (value is String) return _containsTorrentio(value);
    if (value is Map) {
      return value.entries.any(
        (entry) =>
            _containsTorrentio(entry.key.toString()) ||
            _isTorrentioData(entry.value),
      );
    }
    if (value is Iterable) {
      return value.any(_isTorrentioData);
    }
    return false;
  }

  bool _containsTorrentio(String value) =>
      value.toLowerCase().contains('torrentio');

  Addon _copyAddon(
    Addon addon, {
    required String url,
    String? configuredAddonId,
    String? configuredManifestUrl,
  }) =>
      Addon(
        id: addon.id,
        name: addon.name,
        version: addon.version,
        author: addon.author,
        url: url,
        description: addon.description,
        enabled: addon.enabled,
        fixed: addon.fixed,
        configuredAddonId: configuredAddonId ?? addon.configuredAddonId,
        configuredManifestUrl:
            configuredManifestUrl ?? addon.configuredManifestUrl,
      );

  Map<String, String>? _configuredManifestRecord(
    String originalAddonId,
    Object? value,
  ) {
    if (value is String) {
      return {
        'originalAddonId': originalAddonId,
        'configuredAddonId': originalAddonId,
        'configuredManifestUrl': value,
      };
    }
    if (value is! Map<String, dynamic>) {
      if (value == null) return null;
      throw const FormatException('Registro de instalação de addon inválido.');
    }
    final originalId = value['originalAddonId'];
    final configuredId = value['configuredAddonId'];
    final manifestUrl = value['configuredManifestUrl'];
    if (originalId != originalAddonId ||
        configuredId is! String ||
        configuredId.trim().isEmpty ||
        manifestUrl is! String ||
        manifestUrl.trim().isEmpty) {
      throw const FormatException('Registro de instalação de addon inválido.');
    }
    return {
      'originalAddonId': originalId as String,
      'configuredAddonId': configuredId,
      'configuredManifestUrl': manifestUrl,
    };
  }

  Future<void> _saveConfiguredManifest({
    required Addon addon,
    required String configuredAddonId,
    required String manifestUrl,
  }) async {
    final encoded = await LocalStorageService.getString(
      configuredAddonUrlsKey,
      fallback: _preferences,
    );
    final Map<String, dynamic> records;
    if (encoded == null) {
      records = {};
    } else {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Instalações configuradas de addons inválidas.',
        );
      }
      records = decoded;
    }
    records[addon.id] = {
      'originalAddonId': addon.id,
      'configuredAddonId': configuredAddonId,
      'configuredManifestUrl': manifestUrl,
    };
    final saved = await LocalStorageService.setString(
      configuredAddonUrlsKey,
      jsonEncode(records),
      fallback: _preferences,
    );
    if (!saved) {
      throw StateError('Não foi possível salvar os dados de instalação.');
    }

    if (addon.fixed) return;
    final customEncoded = await LocalStorageService.getString(
      customAddonsKey,
      fallback: _preferences,
    );
    if (customEncoded == null) {
      throw StateError('O addon personalizado não está instalado.');
    }
    final customDecoded = jsonDecode(customEncoded);
    if (customDecoded is! List) {
      throw const FormatException('Lista de addons personalizados inválida.');
    }
    var found = false;
    final updated = customDecoded.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException(
          'Entrada inválida de addon personalizado.',
        );
      }
      if (entry['id'] != addon.id) return entry;
      found = true;
      return {
        ...entry,
        'url': manifestUrl,
        'configuredAddonId': configuredAddonId,
        'configuredManifestUrl': manifestUrl,
        'enabled': true,
      };
    }).toList();
    if (!found) {
      throw StateError('O addon personalizado não está instalado.');
    }
    final customSaved = await LocalStorageService.setString(
      customAddonsKey,
      jsonEncode(updated),
      fallback: _preferences,
    );
    if (!customSaved) {
      throw StateError('Não foi possível salvar o addon configurado.');
    }
  }

  Future<void> _setAddonEnabled(String addonId, bool enabled) async {
    final encoded = await LocalStorageService.getString(
      installedAddonsKey,
      fallback: _preferences,
    );
    final Map<String, dynamic> statuses;
    if (encoded == null) {
      statuses = {};
    } else {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic> ||
          decoded.values.any((value) => value is! bool)) {
        throw const FormatException('Estado de instalação inválido.');
      }
      statuses = decoded;
    }
    statuses[addonId] = enabled;
    final saved = await LocalStorageService.setString(
      installedAddonsKey,
      jsonEncode(statuses),
      fallback: _preferences,
    );
    if (!saved) {
      throw StateError('Não foi possível instalar o addon configurado.');
    }
  }

  Future<void> saveAllAddons(Iterable<Addon> addons) async {
    final catalogSource = await _bundle.loadString(defaultAddonsAsset);
    final decodedCatalog = jsonDecode(catalogSource);
    if (decodedCatalog is! List) {
      throw const FormatException(
        'Formato inválido para o catálogo de addons fixos.',
      );
    }
    final bundledIds = decodedCatalog
        .whereType<Map<String, dynamic>>()
        .map((entry) => entry['id'])
        .whereType<String>()
        .toSet();
    final custom = <Addon>[];
    final statuses = <String, bool>{};
    for (final addon in addons) {
      if (bundledIds.contains(addon.id)) {
        if (!addon.fixed) {
          statuses[addon.id] = addon.enabled;
        }
        continue;
      }
      if (addon.fixed) {
        throw StateError(
            'Um addon personalizado não pode ser marcado como fixo.');
      }
      custom.add(addon);
      statuses[addon.id] = addon.enabled;
    }
    final statusesSaved = await LocalStorageService.setString(
      installedAddonsKey,
      jsonEncode(statuses),
      fallback: _preferences,
    );
    final customSaved = await LocalStorageService.setString(
      customAddonsKey,
      jsonEncode(custom.map(_addonToJson).toList()),
      fallback: _preferences,
    );
    if (!statusesSaved || !customSaved) {
      throw StateError('Não foi possível salvar os addons.');
    }
  }

  Map<String, dynamic> _addonToJson(Addon addon) => {
        'id': addon.id,
        'name': addon.name,
        'version': addon.version,
        'author': addon.author,
        'url': addon.url,
        'description': addon.description,
        'enabled': addon.enabled,
        'fixed': false,
        if (addon.configuredAddonId != null)
          'configuredAddonId': addon.configuredAddonId,
        if (addon.configuredManifestUrl != null)
          'configuredManifestUrl': addon.configuredManifestUrl,
      };

  Uri _validateManifestUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        value,
        'manifestUrl',
        'Informe uma URL HTTP ou HTTPS válida.',
      );
    }
    if (uri.host == '127.0.0.1' ||
        uri.host == 'localhost' ||
        uri.host == '::1') {
      throw StateError(
        'O addon Local Files é local ao dispositivo e não expõe um servidor Stremio acessível pelo app.',
      );
    }
    return uri;
  }

  Future<StremioAddonManifest?> _readCachedManifest(String cacheKey) async {
    final encoded = await LocalStorageService.getString(
      cacheKey,
      fallback: _preferences,
    );
    if (encoded == null) {
      return null;
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Manifest em cache inválido.');
    }
    return StremioAddonManifest.fromJson(decoded);
  }

  Future<void> _writeCachedManifest(
    String cacheKey,
    Map<String, dynamic> manifest,
  ) async {
    final saved = await LocalStorageService.setString(
      cacheKey,
      jsonEncode(manifest),
      fallback: _preferences,
    );
    if (!saved) {
      throw StateError('Não foi possível salvar o manifest no cache local.');
    }
  }

  String _manifestCacheKey(Addon addon) =>
      stremioCacheKey('stremio_manifest', '${addon.id}|${addon.manifestUrl}');

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

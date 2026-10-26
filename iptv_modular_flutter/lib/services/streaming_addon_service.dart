import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/addon.dart';
import '../models/stremio_addon_manifest.dart';
import '../repositories/addon_repository.dart';

abstract interface class StreamingAddonService {
  Future<List<Addon>> loadCatalog();

  Future<List<Addon>> loadInstalledAddons();

  Future<List<Addon>> getInstalledAddons();

  Future<Addon> importFromUrl(
    String manifestUrl, {
    String? name,
  });

  Future<Addon> addFromUrl(
    String manifestUrl, {
    String? name,
  });

  Future<Addon> update(String addonId);

  Future<void> setEnabled(String addonId, bool enabled);

  Future<void> enable(String addonId);

  Future<void> disable(String addonId);

  Future<void> remove(String addonId);

  Future<StremioAddonManifest> getManifest(Addon addon);

  bool isValidManifestUrl(String manifestUrl);

  void close();
}

class DefaultStreamingAddonService implements StreamingAddonService {
  DefaultStreamingAddonService({
    AddonRepository? repository,
    http.Client? client,
    SharedPreferences? preferences,
  })  : _repository = repository ?? AddonRepository(
          client: client,
          preferences: preferences,
        ),
        _client = client ?? http.Client();

  final AddonRepository _repository;
  final http.Client _client;

  @override
  Future<List<Addon>> loadCatalog() async => _repository.getAllAddons();

  @override
  Future<List<Addon>> loadInstalledAddons() async =>
      (await loadCatalog()).where((addon) => addon.enabled).toList();

  @override
  Future<List<Addon>> getInstalledAddons() => loadInstalledAddons();

  @override
  Future<Addon> importFromUrl(
    String manifestUrl, {
    String? name,
  }) => addFromUrl(manifestUrl, name: name);

  @override
  Future<Addon> addFromUrl(
    String manifestUrl, {
    String? name,
  }) async {
    final normalizedUrl = manifestUrl.trim();
    if (!isValidManifestUrl(normalizedUrl)) {
      throw ArgumentError.value(
        manifestUrl,
        'manifestUrl',
        'Informe uma URL HTTP ou HTTPS válida para o manifest do addon.',
      );
    }

    final repositoryAddons = await loadCatalog();
    final existing = repositoryAddons.any(
      (addon) => addon.manifestUrl == normalizedUrl,
    );
    if (existing) {
      throw ArgumentError.value(
        normalizedUrl,
        'manifestUrl',
        'Este addon já está instalado.',
      );
    }

    final manifest = await _fetchManifest(normalizedUrl);
    final addon = Addon(
      id: manifest.id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : manifest.name,
      version: manifest.version,
      author: '',
      url: normalizedUrl,
      description: manifest.description,
      enabled: true,
      fixed: false,
    );

    final custom = await _repository.getAllAddons();
    final hasDuplicateId = custom.any((entry) => entry.id == addon.id);
    if (hasDuplicateId) {
      throw ArgumentError.value(
        addon.id,
        'manifest.id',
        'Este addon já está instalado.',
      );
    }

    final next = [...custom, addon];
    await _repository.saveAllAddons(next);
    return addon;
  }

  @override
  Future<Addon> update(String addonId) async {
    final addons = await loadCatalog();
    final index = addons.indexWhere((addon) => addon.id == addonId);
    if (index < 0) {
      throw ArgumentError.value(addonId, 'addonId', 'Addon não encontrado.');
    }
    final current = addons[index];
    if (current.url.trim().isEmpty) {
      throw StateError('Este addon não possui URL de manifest para atualizar.');
    }

    final manifest = await _fetchManifest(current.url);
    final updated = Addon(
      id: current.id,
      name: current.name,
      version: manifest.version,
      author: current.author,
      url: current.url,
      description: manifest.description,
      enabled: current.enabled,
      fixed: current.fixed,
      configuredAddonId: current.configuredAddonId,
      configuredManifestUrl: current.configuredManifestUrl,
    );
    final next = List<Addon>.from(addons)..[index] = updated;
    await _repository.saveAllAddons(next);
    return updated;
  }

  @override
  Future<void> setEnabled(String addonId, bool enabled) async {
    final addons = await loadCatalog();
    final index = addons.indexWhere((addon) => addon.id == addonId);
    if (index < 0) {
      throw ArgumentError.value(addonId, 'addonId', 'Addon não encontrado.');
    }
    final addon = addons[index];
    if (addon.fixed) {
      throw StateError('Addons fixos do sistema são somente leitura.');
    }

    final updated = Addon(
      id: addon.id,
      name: addon.name,
      version: addon.version,
      author: addon.author,
      url: addon.url,
      description: addon.description,
      enabled: enabled,
      fixed: addon.fixed,
      configuredAddonId: addon.configuredAddonId,
      configuredManifestUrl: addon.configuredManifestUrl,
    );
    final next = List<Addon>.from(addons);
    next[index] = updated;
    await _repository.saveAllAddons(next);
  }

  @override
  Future<void> enable(String addonId) => setEnabled(addonId, true);

  @override
  Future<void> disable(String addonId) => setEnabled(addonId, false);

  @override
  Future<void> remove(String addonId) async {
    final addons = await loadCatalog();
    final index = addons.indexWhere((addon) => addon.id == addonId);
    if (index < 0) {
      throw ArgumentError.value(addonId, 'addonId', 'Addon não encontrado.');
    }
    final addon = addons[index];
    if (addon.fixed) {
      throw StateError('Addons fixos do sistema não podem ser removidos.');
    }

    final next = List<Addon>.from(addons)..removeAt(index);
    await _repository.saveAllAddons(next);
  }

  @override
  Future<StremioAddonManifest> getManifest(Addon addon) => _repository.getManifest(addon);

  @override
  void close() => _repository.close();

  @override
  bool isValidManifestUrl(String manifestUrl) {
    final uri = Uri.tryParse(manifestUrl.trim());
    return uri != null &&
        const {'http', 'https'}.contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  Future<StremioAddonManifest> _fetchManifest(String manifestUrl) async {
    final uri = Uri.parse(manifestUrl.trim());
    final response = await _client.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'O manifest respondeu com HTTP ${response.statusCode}.',
        uri,
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('O manifest deve ser um objeto JSON.');
    }
    return StremioAddonManifest.fromJson(decoded);
  }
}

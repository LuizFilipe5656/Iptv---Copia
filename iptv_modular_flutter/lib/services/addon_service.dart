import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/addon.dart';
import '../repositories/addon_repository.dart';
import 'local_storage_service.dart';

class AddonService {
  AddonService({
    AddonRepository? repository,
    AssetBundle? bundle,
    SharedPreferences? preferences,
    http.Client? client,
  })  : _repository = repository ??
            AddonRepository(bundle: bundle, preferences: preferences),
        _preferences = preferences,
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  final AddonRepository _repository;
  final SharedPreferences? _preferences;
  final http.Client _client;
  final bool _ownsClient;
  final Map<String, Addon> _addons = {};
  static const _installedAddonsKey = AddonRepository.installedAddonsKey;

  List<Addon> get addons => List.unmodifiable(_addons.values);

  Future<List<Addon>> loadCatalog() async {
    final catalog = await _repository.getAllAddons();
    _addons
      ..clear()
      ..addEntries(catalog.map((addon) => MapEntry(addon.id, addon)));
    return List.unmodifiable(catalog);
  }

  Future<Addon> importFromUrl(
    String manifestUrl, {
    String? name,
  }) async {
    if (name != null && name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Informe o nome do addon.');
    }
    final uri = Uri.tryParse(manifestUrl.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        manifestUrl,
        'manifestUrl',
        'Informe uma URL HTTP ou HTTPS válida para o manifest.',
      );
    }

    final response = await _client.get(uri).timeout(
          const Duration(seconds: 20),
        );
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
    final addon = Addon.fromJson({
      ...decoded,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'url': uri.toString(),
      'enabled': true,
      'fixed': false,
    });
    await loadCatalog();
    if (_addons.containsKey(addon.id)) {
      throw ArgumentError.value(
        addon.id,
        'manifest.id',
        'Este addon já está instalado.',
      );
    }
    _addons[addon.id] = addon;
    await saveAddons();
    return addon;
  }

  Future<Addon> addFromUrl(String manifestUrl) => importFromUrl(manifestUrl);

  Future<Addon> update(String id) async {
    final catalog = await loadCatalog();
    final current = catalog.where((addon) => addon.id == id).firstOrNull;
    if (current == null) {
      throw ArgumentError.value(id, 'id', 'Addon não encontrado.');
    }
    if (current.url.isEmpty) {
      throw StateError('Este addon não possui URL de manifest para atualizar.');
    }
    final manifest = await _fetchManifest(current.url);
    if (manifest.id != current.installedAddonId) {
      throw FormatException(
        'O manifest retornou o ID ${manifest.id}, '
        'esperado ${current.installedAddonId}.',
      );
    }
    final updated = Addon(
      id: current.originalAddonId,
      name: manifest.name,
      version: manifest.version,
      author: current.author,
      url: current.manifestUrl,
      description: manifest.description,
      enabled: current.enabled,
      fixed: current.fixed,
      configuredAddonId: current.configuredAddonId ??
          (manifest.id == current.id ? null : manifest.id),
      configuredManifestUrl: current.configuredManifestUrl,
    );
    _addons[id] = updated;
    await saveAddons();
    return updated;
  }

  Future<Addon> _fetchManifest(String manifestUrl) async {
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        manifestUrl,
        'manifestUrl',
        'URL do manifest inválida.',
      );
    }
    final response = await _client.get(uri).timeout(
          const Duration(seconds: 15),
        );
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
    return Addon.fromJson({...decoded, 'url': uri.toString()});
  }

  Future<void> activate(String id) => setInstalled(id, true);

  Future<void> deactivate(String id) => setInstalled(id, false);

  Future<void> removeAddon(String id) async {
    final catalog = await loadCatalog();
    final addon = catalog.where((item) => item.id == id).firstOrNull;
    if (addon == null) {
      throw ArgumentError.value(id, 'id', 'Addon não encontrado.');
    }
    if (addon.fixed) {
      throw StateError('Addons fixos do sistema não podem ser removidos.');
    }
    final customEncoded = await LocalStorageService.getString(
      AddonRepository.customAddonsKey,
      fallback: _preferences,
    );
    final customDecoded =
        customEncoded == null ? const <dynamic>[] : jsonDecode(customEncoded);
    if (customDecoded is! List) {
      throw const FormatException('Lista de addons personalizados inválida.');
    }
    final isCustom = customDecoded.any(
      (entry) => entry is Map<String, dynamic> && entry['id'] == id,
    );
    if (!isCustom) {
      await deactivate(id);
      return;
    }
    _addons.remove(id);
    try {
      await saveAddons();
      final statuses = await _readStatuses()
        ..remove(id);
      final statusSaved = await LocalStorageService.setString(
        _installedAddonsKey,
        jsonEncode(statuses),
        fallback: _preferences,
      );
      if (!statusSaved) {
        throw StateError('Não foi possível limpar o estado do addon removido.');
      }
    } catch (_) {
      _addons[id] = addon;
      rethrow;
    }
  }

  Future<void> saveAddons() async {
    await _repository.saveAllAddons(_addons.values);
  }

  Future<void> setInstalled(String id, bool installed) async {
    final catalog = await loadCatalog();
    if (!catalog.any((addon) => addon.id == id)) {
      throw ArgumentError.value(id, 'id', 'Addon não encontrado no catálogo.');
    }
    final addon = _addons[id];
    if (addon?.fixed ?? false) {
      throw StateError('Addons fixos do sistema são somente leitura.');
    }
    final statuses = await _readStatuses();
    statuses[id] = installed;
    final saved = await LocalStorageService.setString(
      _installedAddonsKey,
      jsonEncode(statuses),
      fallback: _preferences,
    );
    if (!saved) {
      throw StateError('Não foi possível salvar o estado do addon.');
    }
    if (addon != null) {
      addon.enabled = installed;
    }
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<Map<String, bool>> _readStatuses() async {
    final encoded = await LocalStorageService.getString(
      _installedAddonsKey,
      fallback: _preferences,
    );
    if (encoded == null) {
      return {};
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic> ||
        decoded.values.any((value) => value is! bool)) {
      throw const FormatException('Estado de instalação de addons inválido.');
    }
    return decoded.map((key, value) => MapEntry(key, value as bool));
  }

  void register(Addon addon) {
    if (_addons.containsKey(addon.id)) {
      throw ArgumentError.value(addon.id, 'addon.id', 'ID já registrado');
    }
    _addons[addon.id] = addon;
  }

  bool unregister(String id) {
    if (_addons[id]?.fixed ?? false) {
      throw StateError('Addons fixos do sistema não podem ser removidos.');
    }
    return _addons.remove(id) != null;
  }
}

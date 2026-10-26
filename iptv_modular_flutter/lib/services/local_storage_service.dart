import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  LocalStorageService._();

  static const _boxName = 'iptv_local_storage';
  static const _migratedKeys = {
    'favorite_titles',
    'playback_progress',
    'custom_addons',
    'installed_addon_status',
    'stremio_addon_configuration',
    'configured_addon_manifest_urls',
  };
  static const _removedFeatureKeys = {
    'manual_stream_sources',
    'streaming_addons',
    'last_channel',
    'live_tv_favorites',
    'live_tv_history',
  };
  static Future<void>? _initialization;

  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(_boxName);
    final preferences = await SharedPreferences.getInstance();
    for (final key in _removedFeatureKeys) {
      await box.delete(key);
      await preferences.remove(key);
    }
    for (final key in _migratedKeys) {
      if (box.containsKey(key) || !preferences.containsKey(key)) {
        continue;
      }
      final value = preferences.get(key);
      if (value is String) {
        await box.put(key, value);
      } else if (value is List<String>) {
        await box.put(key, jsonEncode(value));
      } else if (value is Map) {
        await box.put(key, jsonEncode(value));
      }
    }
  }

  static bool get isInitialized => Hive.isBoxOpen(_boxName);

  static Future<String?> getString(
    String key, {
    SharedPreferences? fallback,
  }) async {
    if (isInitialized) {
      return Hive.box<String>(_boxName).get(key);
    }
    return (fallback ?? await SharedPreferences.getInstance()).getString(key);
  }

  static Future<bool> setString(
    String key,
    String value, {
    SharedPreferences? fallback,
  }) async {
    if (isInitialized) {
      await Hive.box<String>(_boxName).put(key, value);
      return true;
    }
    return (fallback ?? await SharedPreferences.getInstance())
        .setString(key, value);
  }

  static Future<bool> removeString(
    String key, {
    SharedPreferences? fallback,
  }) async {
    if (isInitialized) {
      await Hive.box<String>(_boxName).delete(key);
      return true;
    }
    return (fallback ?? await SharedPreferences.getInstance()).remove(key);
  }

  static Future<void> removeEntriesWhere(
    bool Function(String key, String value) predicate, {
    SharedPreferences? fallback,
  }) async {
    if (isInitialized) {
      final box = Hive.box<String>(_boxName);
      final keysToRemove = <String>[];
      for (final key in box.keys.whereType<String>()) {
        final value = box.get(key);
        if (value != null && predicate(key, value)) {
          keysToRemove.add(key);
        }
      }
      if (keysToRemove.isNotEmpty) {
        await box.deleteAll(keysToRemove);
      }
    }

    final preferences = fallback ?? await SharedPreferences.getInstance();
    final preferenceKeysToRemove = <String>[];
    for (final key in preferences.getKeys()) {
      final value = preferences.get(key);
      if (value is String && predicate(key, value)) {
        preferenceKeysToRemove.add(key);
      }
    }
    if (preferenceKeysToRemove.isNotEmpty) {
      for (final key in preferenceKeysToRemove) {
        await preferences.remove(key);
      }
    }
  }

  static Future<List<String>> getStringList(
    String key, {
    SharedPreferences? fallback,
  }) async {
    if (!isInitialized) {
      return (fallback ?? await SharedPreferences.getInstance())
              .getStringList(key) ??
          const [];
    }
    final encoded = Hive.box<String>(_boxName).get(key);
    if (encoded == null) {
      return const [];
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! List || decoded.any((value) => value is! String)) {
      throw FormatException('Lista local inválida para "$key".');
    }
    return decoded.cast<String>();
  }

  static Future<bool> setStringList(
    String key,
    List<String> values, {
    SharedPreferences? fallback,
  }) async {
    if (isInitialized) {
      await Hive.box<String>(_boxName).put(key, jsonEncode(values));
      return true;
    }
    return (fallback ?? await SharedPreferences.getInstance())
        .setStringList(key, values);
  }
}

import '../models/addon.dart';
import '../models/stremio_addon_manifest.dart';
import '../repositories/addon_repository.dart';

class AddonConfigurationService {
  const AddonConfigurationService(this._repository);

  final AddonRepository _repository;

  Map<String, String> initialValues({
    required Addon addon,
    required StremioAddonManifest manifest,
    required Map<String, String> savedValues,
  }) {
    final values = <String, String>{
      for (final field in manifest.configuration) field.key: field.defaultValue,
    };
    values.addAll(_readUrlConfiguration(addon.manifestUrl));
    values.addAll(savedValues);
    if (manifest.configuration.isEmpty) {
      return values;
    }
    return {
      for (final field in manifest.configuration)
        field.key: values[field.key] ?? field.defaultValue,
    };
  }

  String buildManifestUrl({
    required String currentManifestUrl,
    required StremioAddonManifest manifest,
    required Map<String, String> values,
  }) {
    final uri = Uri.tryParse(currentManifestUrl.trim());
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        currentManifestUrl,
        'currentManifestUrl',
        'URL do manifest inválida.',
      );
    }

    final segments = uri.pathSegments.toList();
    if (segments.isNotEmpty && segments.last == 'manifest.json') {
      segments.removeLast();
    } else {
      throw ArgumentError.value(
        currentManifestUrl,
        'currentManifestUrl',
        'O URL precisa terminar em manifest.json.',
      );
    }
    if (segments.isNotEmpty && segments.last.contains('=')) {
      segments.removeLast();
    }

    final configuredValues = <String, String>{};
    if (manifest.configuration.isEmpty) {
      for (final entry in values.entries) {
        final key = entry.key.trim();
        final value = entry.value.trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          configuredValues[key] = value;
        }
      }
    }
    for (final field in manifest.configuration) {
      final value = values[field.key]?.trim() ?? '';
      if (field.isRequired && value.isEmpty) {
        throw ArgumentError.value(
          field.key,
          'configuration',
          '${field.title} é obrigatório.',
        );
      }
      if (value.isNotEmpty) {
        configuredValues[field.key] = value;
      }
    }

    if (configuredValues.isNotEmpty) {
      final pathValues = configuredValues.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('|');
      segments.add(pathValues);
    }
    segments.add('manifest.json');
    return uri.replace(pathSegments: segments).toString();
  }

  Future<String> install({
    required Addon addon,
    required StremioAddonManifest manifest,
    required Map<String, String> values,
  }) async {
    final manifestUrl = buildManifestUrl(
      currentManifestUrl: addon.manifestUrl,
      manifest: manifest,
      values: values,
    );
    await _repository.installConfiguredAddon(
      addon: addon,
      manifestUrl: manifestUrl,
      configuration: values,
    );
    return manifestUrl;
  }

  Map<String, String> _readUrlConfiguration(String manifestUrl) {
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null || uri.pathSegments.length < 2) {
      return const {};
    }
    final configSegment = uri.pathSegments[uri.pathSegments.length - 2];
    if (!configSegment.contains('=')) {
      return const {};
    }
    final values = <String, String>{};
    for (final pair in configSegment.split('|')) {
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      values[pair.substring(0, separator)] = pair.substring(separator + 1);
    }
    return values;
  }
}

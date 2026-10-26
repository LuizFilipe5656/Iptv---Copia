class StremioAddonManifest {
  const StremioAddonManifest({
    required this.id,
    required this.name,
    required this.resources,
    required this.types,
    required this.catalogs,
    this.idPrefixes = const [],
    this.version = '',
    this.description = '',
    this.logo,
    this.behaviorHints = const {},
    this.configuration = const [],
  });

  factory StremioAddonManifest.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty) {
      throw const FormatException('Manifest precisa de id e name válidos.');
    }

    final resources = _parseResources(json['resources']);
    final types = _stringList(json['types'], 'types');
    final idPrefixes = _stringList(json['idPrefixes'], 'idPrefixes');
    final catalogs = _parseCatalogs(json['catalogs'], types);
    final behaviorHints = json['behaviorHints'];
    if (behaviorHints != null && behaviorHints is! Map<String, dynamic>) {
      throw const FormatException('behaviorHints do manifest inválido.');
    }
    if (json['version'] != null && json['version'] is! String) {
      throw const FormatException('version do manifest precisa ser texto.');
    }
    if (json['resources'] != null && json['resources'] is! List) {
      throw const FormatException('Manifest resources precisa ser uma lista.');
    }
    final hints = behaviorHints as Map<String, dynamic>? ?? const {};
    return StremioAddonManifest(
      id: id,
      name: name,
      version: json['version'] as String? ?? '',
      description: json['description'] as String? ?? '',
      logo: json['logo'] as String?,
      behaviorHints: Map.unmodifiable(hints),
      configuration: List.unmodifiable(
        _parseConfiguration(
          json['configuration'] ??
              json['config'] ??
              hints['configuration'] ??
              hints['config'],
        ),
      ),
      resources: List.unmodifiable(resources),
      types: List.unmodifiable(types),
      idPrefixes: List.unmodifiable(idPrefixes),
      catalogs: List.unmodifiable(catalogs),
    );
  }

  final String id;
  final String name;
  final String version;
  final String description;
  final String? logo;
  final Map<String, dynamic> behaviorHints;
  final List<StremioAddonConfiguration> configuration;
  final List<StremioAddonResource> resources;
  final List<String> types;
  final List<String> idPrefixes;
  final List<StremioCatalog> catalogs;

  bool supportsResource(String resource, String type, String contentId) {
    final matching = resources.where((item) => item.name == resource);
    if (matching.isEmpty) {
      return false;
    }
    return matching.any((item) => item.supports(type, contentId)) &&
        (types.isEmpty || types.contains(type)) &&
        _matchesPrefix(idPrefixes, contentId);
  }

  bool get hasCatalogs => catalogs.isNotEmpty;
  bool get hasMeta => resources.any((resource) => resource.name == 'meta');
  bool get hasStreams => resources.any((resource) => resource.name == 'stream');
  bool get hasSubtitles =>
      resources.any((resource) => resource.name == 'subtitles');
  bool get isConfigurable =>
      configuration.isNotEmpty || behaviorHints['configurable'] == true;

  static List<StremioAddonConfiguration> _parseConfiguration(Object? value) {
    if (value == null) {
      return const [];
    }
    final entries = value is List
        ? value
        : value is Map<String, dynamic>
            ? value.entries.map((entry) {
                if (entry.value is Map<String, dynamic>) {
                  return {
                    'key': entry.key,
                    ...entry.value as Map<String, dynamic>
                  };
                }
                return {'key': entry.key, 'default': entry.value};
              }).toList()
            : null;
    if (entries == null) {
      throw const FormatException('configuration do manifest inválida.');
    }
    return entries.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Opção de configuração inválida.');
      }
      final key = entry['key'] ?? entry['name'];
      if (key is! String || key.trim().isEmpty) {
        throw const FormatException(
          'Cada configuração precisa de key ou name.',
        );
      }
      final rawOptions = entry['options'];
      if (rawOptions != null && rawOptions is! List) {
        throw const FormatException('Opções de configuração inválidas.');
      }
      final rawDefault = entry['default'];
      return StremioAddonConfiguration(
        key: key,
        title: entry['title'] as String? ?? entry['label'] as String? ?? key,
        type: entry['type'] as String? ?? 'text',
        defaultValue: rawDefault is List
            ? rawDefault.join(',')
            : rawDefault?.toString() ?? '',
        options: (rawOptions as List? ?? const [])
            .map((option) {
              if (option is String) {
                return option;
              }
              if (option is Map<String, dynamic>) {
                return (option['value'] ?? option['name'] ?? '').toString();
              }
              throw const FormatException('Opção de configuração inválida.');
            })
            .where((option) => option.isNotEmpty)
            .toList(growable: false),
        isRequired: entry['required'] == true || entry['isRequired'] == true,
        isMultiple: entry['multiple'] == true,
      );
    }).toList(growable: false);
  }

  static List<StremioAddonResource> _parseResources(Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      throw const FormatException('Manifest resources precisa ser uma lista.');
    }
    return value.map((entry) {
      if (entry is String && entry.trim().isNotEmpty) {
        return StremioAddonResource(name: entry);
      }
      if (entry is! Map<String, dynamic> || entry['name'] is! String) {
        throw const FormatException('Recurso inválido no manifest.');
      }
      final types = _stringList(entry['types'], 'resources.types');
      final prefixes = _stringList(entry['idPrefixes'], 'resources.idPrefixes');
      return StremioAddonResource(
        name: entry['name'] as String,
        types: List.unmodifiable(types),
        idPrefixes: List.unmodifiable(prefixes),
      );
    }).toList();
  }

  static List<StremioCatalog> _parseCatalogs(
    Object? value,
    List<String> manifestTypes,
  ) {
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      throw const FormatException('Manifest catalogs precisa ser uma lista.');
    }
    return value.map((entry) {
      if (entry is! Map<String, dynamic> ||
          entry['id'] is! String ||
          entry['type'] is! String) {
        throw const FormatException('Catálogo inválido no manifest.');
      }
      final rawExtra = entry['extra'];
      if (rawExtra != null && rawExtra is! List) {
        throw const FormatException('O campo extra do catálogo é inválido.');
      }
      final extra = <StremioCatalogExtra>[];
      final extraNames = <String>{};
      for (final item in rawExtra as List? ?? const []) {
        if (item is! Map<String, dynamic> || item['name'] is! String) {
          throw const FormatException('Extra de catálogo inválido.');
        }
        final options = _stringList(item['options'], 'catalog.extra.options');
        final name = item['name'] as String;
        extraNames.add(name);
        extra.add(StremioCatalogExtra(
          name: name,
          isRequired: item['isRequired'] == true,
          options: List.unmodifiable(options),
        ));
      }
      final requiredExtras = entry['extraRequired'];
      if (requiredExtras != null &&
          (requiredExtras is! List ||
              requiredExtras.any((item) => item is! String))) {
        throw const FormatException('extraRequired do catálogo é inválido.');
      }
      for (final required in requiredExtras as List? ?? const []) {
        if (extraNames.add(required as String)) {
          extra.add(StremioCatalogExtra(
            name: required,
            isRequired: true,
          ));
        }
      }
      return StremioCatalog(
        id: entry['id'] as String,
        type: entry['type'] as String,
        name: entry['name'] as String? ?? entry['id'] as String,
        extra: List.unmodifiable(extra),
        types: manifestTypes,
      );
    }).toList();
  }

  static List<String> _stringList(Object? value, String field) {
    if (value == null) {
      return const [];
    }
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('O campo $field precisa ser uma lista de textos.');
    }
    return value.cast<String>();
  }

  static bool _matchesPrefix(List<String> prefixes, String id) =>
      prefixes.isEmpty || prefixes.any(id.startsWith);
}

class StremioAddonConfiguration {
  const StremioAddonConfiguration({
    required this.key,
    required this.title,
    required this.type,
    required this.defaultValue,
    required this.options,
    required this.isRequired,
    this.isMultiple = false,
  });

  final String key;
  final String title;
  final String type;
  final String defaultValue;
  final List<String> options;
  final bool isRequired;
  final bool isMultiple;
}

class StremioAddonResource {
  const StremioAddonResource({
    required this.name,
    this.types = const [],
    this.idPrefixes = const [],
  });

  final String name;
  final List<String> types;
  final List<String> idPrefixes;

  bool supports(String type, String contentId) =>
      (types.isEmpty || types.contains(type)) &&
      StremioAddonManifest._matchesPrefix(idPrefixes, contentId);
}

class StremioCatalog {
  const StremioCatalog({
    required this.id,
    required this.type,
    required this.name,
    this.extra = const [],
    this.types = const [],
  });

  final String id;
  final String type;
  final String name;
  final List<StremioCatalogExtra> extra;
  final List<String> types;
}

class StremioCatalogExtra {
  const StremioCatalogExtra({
    required this.name,
    required this.isRequired,
    this.options = const [],
  });

  final String name;
  final bool isRequired;
  final List<String> options;
}

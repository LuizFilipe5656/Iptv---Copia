class Addon {
  Addon({
    required this.id,
    required this.name,
    this.version = '',
    this.author = '',
    this.url = '',
    this.description = '',
    this.enabled = true,
    this.fixed = false,
    this.configuredAddonId,
    this.configuredManifestUrl,
  });

  factory Addon.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final enabled = json['enabled'];
    final fixed = json['fixed'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty) {
      throw const FormatException('Addon precisa de id e name válidos.');
    }
    if (enabled != null && enabled is! bool) {
      throw const FormatException(
        'O campo enabled do addon precisa ser booleano.',
      );
    }
    if (fixed != null && fixed is! bool) {
      throw const FormatException(
        'O campo fixed do addon precisa ser booleano.',
      );
    }

    return Addon(
      id: id,
      name: name,
      version: json['version'] as String? ?? '',
      author: json['author'] as String? ?? '',
      url: json['url'] as String? ?? json['manifestUrl'] as String? ?? '',
      description: json['description'] as String? ?? '',
      enabled: enabled as bool? ?? true,
      fixed: fixed as bool? ?? false,
      configuredAddonId: json['configuredAddonId'] as String?,
      configuredManifestUrl: json['configuredManifestUrl'] as String?,
    );
  }

  final String id;
  final String name;
  final String version;
  final String author;
  final String url;
  final String description;
  bool enabled;
  final bool fixed;
  final String? configuredAddonId;
  final String? configuredManifestUrl;

  String get manifestUrl => url;
  String get originalAddonId => id;
  String get installedAddonId => configuredAddonId ?? id;
}

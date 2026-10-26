class StremioStream {
  const StremioStream({
    required this.addonId,
    required this.addonName,
    this.title = '',
    this.name = '',
    this.url,
    this.externalUrl,
    this.infoHash,
    this.fileIndex,
    this.behaviorHints = const {},
  });

  factory StremioStream.fromJson(
    Map<String, dynamic> json, {
    required String addonId,
    required String addonName,
  }) {
    final url = json['url'];
    final externalUrl = json['externalUrl'];
    final infoHash = json['infoHash'];
    final name = json['name'];
    final title = json['title'];
    if ((url != null && url is! String) ||
        (externalUrl != null && externalUrl is! String) ||
        (infoHash != null && infoHash is! String) ||
        (name != null && name is! String) ||
        (title != null && title is! String)) {
      throw const FormatException('Stream inválido no addon.');
    }
    final hints = json['behaviorHints'];
    if (hints != null && hints is! Map<String, dynamic>) {
      throw const FormatException('behaviorHints inválido no stream.');
    }
    return StremioStream(
      addonId: addonId,
      addonName: addonName,
      title: title as String? ?? '',
      name: name as String? ?? '',
      url: url as String?,
      externalUrl: externalUrl as String?,
      infoHash: infoHash as String?,
      fileIndex: json['fileIdx'] is int ? json['fileIdx'] as int : null,
      behaviorHints: hints as Map<String, dynamic>? ?? const {},
    );
  }

  final String addonId;
  final String addonName;
  final String title;
  final String name;
  final String? url;
  final String? externalUrl;
  final String? infoHash;
  final int? fileIndex;
  final Map<String, dynamic> behaviorHints;

  String get displayTitle => title.isNotEmpty
      ? title
      : name.isNotEmpty
          ? name
          : infoHash == null
              ? 'Fonte sem título'
              : 'Torrent ${infoHash!.substring(0, infoHash!.length < 8 ? infoHash!.length : 8)}';

  bool get isDirectUrl {
    final uri = Uri.tryParse(url ?? '');
    return uri != null &&
        const {'http', 'https'}.contains(uri.scheme) &&
        uri.host.isNotEmpty;
  }
}

class StremioSubtitle {
  const StremioSubtitle({
    required this.addonId,
    required this.addonName,
    required this.url,
    this.lang = '',
    this.id = '',
  });

  factory StremioSubtitle.fromJson(
    Map<String, dynamic> json, {
    required String addonId,
    required String addonName,
  }) {
    final url = json['url'];
    if (url is! String) {
      throw const FormatException('Legenda sem URL válida.');
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('URL de legenda precisa ser HTTP ou HTTPS.');
    }
    return StremioSubtitle(
      addonId: addonId,
      addonName: addonName,
      url: url,
      lang: json['lang'] as String? ?? '',
      id: json['id']?.toString() ?? '',
    );
  }

  final String addonId;
  final String addonName;
  final String url;
  final String lang;
  final String id;
}

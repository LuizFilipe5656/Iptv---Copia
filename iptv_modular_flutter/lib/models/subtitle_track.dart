enum SubtitleLanguage {
  ptBr('PT-BR'),
  en('EN'),
  es('ES');

  const SubtitleLanguage(this.label);

  final String label;

  static SubtitleLanguage? fromCode(String value) {
    switch (value.toLowerCase().replaceAll('_', '-')) {
      case 'pob':
      case 'pt-br':
      case 'ptbr':
        return SubtitleLanguage.ptBr;
      case 'en':
      case 'eng':
        return SubtitleLanguage.en;
      case 'es':
      case 'spa':
        return SubtitleLanguage.es;
      default:
        return null;
    }
  }
}

class SubtitleTrack {
  const SubtitleTrack({
    required this.id,
    required this.url,
    required this.language,
    required this.name,
  });

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final rawUrl = json['url'];
    final languageCode = json['lang'];
    if (id is! String || rawUrl is! String || languageCode is! String) {
      throw const FormatException(
        'Legenda OpenSubtitles precisa de id, url e lang válidos.',
      );
    }

    final url = Uri.tryParse(rawUrl);
    if (url == null ||
        (url.scheme != 'http' && url.scheme != 'https') ||
        url.host.isEmpty) {
      throw const FormatException('URL de legenda OpenSubtitles inválida.');
    }

    final language = SubtitleLanguage.fromCode(languageCode);
    if (language == null) {
      throw const FormatException('Idioma de legenda não suportado.');
    }

    final fileName = json['subtitleFileName'];
    final releaseName = json['movieReleaseName'];
    final name = fileName is String && fileName.isNotEmpty
        ? fileName
        : releaseName is String && releaseName.isNotEmpty
            ? releaseName
            : language.label;

    return SubtitleTrack(
      id: id,
      url: url,
      language: language,
      name: name,
    );
  }

  final String id;
  final Uri url;
  final SubtitleLanguage language;
  final String name;
}

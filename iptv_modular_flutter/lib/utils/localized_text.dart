class LocalizedText {
  const LocalizedText(this.text, {required this.isPortuguese});

  final String text;
  final bool isPortuguese;
}

LocalizedText? localizedText(
  Map<String, dynamic> json, {
  required List<String> fields,
}) {
  for (final language in const ['pt-br', 'pt']) {
    for (final field in fields) {
      final value = _directLanguageValue(json, field, language);
      if (value != null) {
        return LocalizedText(value, isPortuguese: true);
      }
    }
    for (final containerKey in const [
      'translations',
      'localizations',
      'localized',
    ]) {
      final container = json[containerKey];
      final value = _languageValue(container, fields, language);
      if (value != null) {
        return LocalizedText(value, isPortuguese: true);
      }
    }
  }

  for (final field in fields) {
    final value = _text(json[field]);
    if (value != null) return LocalizedText(value, isPortuguese: false);
  }
  return null;
}

String? _directLanguageValue(
  Map<String, dynamic> json,
  String field,
  String language,
) {
  for (final entry in json.entries) {
    final key = entry.key.toLowerCase().replaceAll('_', '-');
    if (key == '$field.$language' || key == '$field-$language') {
      final value = _text(entry.value);
      if (value != null) return value;
    }
  }
  return _languageValue(json[field], const [], language);
}

String? _languageValue(
  Object? container,
  List<String> fields,
  String language,
) {
  if (container is Map) {
    for (final entry in container.entries) {
      final key = entry.key.toString().toLowerCase().replaceAll('_', '-');
      if (key == language || (language == 'pt' && key.startsWith('pt-'))) {
        final value = fields.isEmpty
            ? _text(entry.value)
            : entry.value is Map
                ? _firstText(entry.value as Map, fields)
                : null;
        if (value != null) return value;
      }
    }
    if (fields.isNotEmpty) return _firstText(container, fields);
  }
  if (container is List) {
    for (final entry in container.whereType<Map>()) {
      final locale =
          (entry['language'] ?? entry['locale'] ?? entry['lang'] ?? '')
              .toString()
              .toLowerCase()
              .replaceAll('_', '-');
      if (locale == language || (language == 'pt' && locale.startsWith('pt-'))) {
        final value = _firstText(entry, fields);
        if (value != null) return value;
      }
    }
  }
  return null;
}

String? _firstText(Map<dynamic, dynamic> values, List<String> fields) {
  for (final field in fields) {
    final value = _text(values[field]);
    if (value != null) return value;
  }
  return null;
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

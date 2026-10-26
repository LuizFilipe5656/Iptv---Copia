import '../utils/localized_text.dart';

class StremioMetaItem {
  const StremioMetaItem({
    required this.id,
    required this.type,
    required this.name,
    this.description = '',
    this.poster,
    this.background,
    this.releaseInfo = '',
    this.imdbRating = '',
    this.raw = const {},
  });

  factory StremioMetaItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final name = json['name'] ?? json['title'];
    if (id is! String ||
        id.trim().isEmpty ||
        type is! String ||
        type.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty) {
      throw const FormatException(
        'Item de catálogo precisa de id, type e name válidos.',
      );
    }
    final description = localizedText(
      json,
      fields: const ['description', 'overview', 'summary', 'plot'],
    );
    return StremioMetaItem(
      id: id,
      type: type,
      name: name,
      description: description?.text ?? '',
      poster: json['poster'] as String?,
      background: json['background'] as String?,
      releaseInfo:
          (json['releaseInfo'] ?? json['release_date'] ?? json['year'] ?? '')
              .toString(),
      imdbRating: (json['imdbRating'] ?? '').toString(),
      raw: Map.unmodifiable(json),
    );
  }

  final String id;
  final String type;
  final String name;
  final String description;
  final String? poster;
  final String? background;
  final String releaseInfo;
  final String imdbRating;
  final Map<String, dynamic> raw;

  String get posterUrl => poster ?? '';
  String get backgroundUrl => background ?? poster ?? '';
  List<String> get genres {
    final value = raw['genres'];
    return value is List ? value.whereType<String>().toList() : const [];
  }

  String get year {
    final value = raw['year'];
    if (value != null) return value.toString();
    final match = RegExp(r'\b\d{4}\b').firstMatch(releaseInfo);
    return match?.group(0) ?? releaseInfo;
  }
}

class ContinueWatching {
  const ContinueWatching({
    required this.contentId,
    required this.title,
    required this.position,
    required this.updatedAt,
  });

  factory ContinueWatching.fromJson(Map<String, dynamic> json) {
    final contentId = json['contentId'];
    final title = json['title'];
    final position = json['position'];
    final updatedAt = json['updatedAt'];
    if (contentId is! String ||
        contentId.isEmpty ||
        title is! String ||
        title.isEmpty ||
        position is! int ||
        updatedAt is! String) {
      throw const FormatException('Dados de Continuar Assistindo inválidos.');
    }
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedUpdatedAt == null) {
      throw const FormatException('Data de reprodução inválida.');
    }

    return ContinueWatching(
      contentId: contentId,
      title: title,
      position: position,
      updatedAt: parsedUpdatedAt,
    );
  }

  final String contentId;
  final String title;
  final int position;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'contentId': contentId,
        'title': title,
        'position': position,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

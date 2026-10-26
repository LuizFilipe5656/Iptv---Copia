enum WatchAvailabilityType {
  subscription('Assinatura'),
  rentOrBuy('Alugar ou comprar'),
  free('Grátis'),
  other('Outros');

  const WatchAvailabilityType(this.label);

  final String label;

  static WatchAvailabilityType fromTitle(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('subscription') ||
        normalized.contains('subscribe')) {
      return WatchAvailabilityType.subscription;
    }
    if (normalized.contains('rent') ||
        normalized.contains('buy') ||
        normalized.contains('purchase')) {
      return WatchAvailabilityType.rentOrBuy;
    }
    if (normalized.contains('free') || normalized.contains('ads')) {
      return WatchAvailabilityType.free;
    }
    return WatchAvailabilityType.other;
  }
}

class WatchhubOffer {
  const WatchhubOffer({
    required this.provider,
    required this.title,
    required this.url,
  });

  factory WatchhubOffer.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    final title = json['title'];
    final rawUrl = json['externalUrl'];
    if (name is! String || name.trim().isEmpty ||
        title is! String || title.trim().isEmpty ||
        rawUrl is! String || rawUrl.trim().isEmpty) {
      throw const FormatException(
        'Oferta WatchHub precisa de name, title e externalUrl.',
      );
    }

    final url = Uri.tryParse(rawUrl);
    if (url == null ||
        (url.scheme != 'https' && url.scheme != 'http') ||
        url.host.isEmpty) {
      throw const FormatException('URL do provedor WatchHub inválida.');
    }

    return WatchhubOffer(provider: name, title: title, url: url);
  }

  final String provider;
  final String title;
  final Uri url;

  WatchAvailabilityType get availabilityType =>
      WatchAvailabilityType.fromTitle(title);
}

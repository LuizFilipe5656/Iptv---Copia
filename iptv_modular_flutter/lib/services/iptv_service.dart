import 'package:http/http.dart' as http;

class IptvSource {
  const IptvSource(this.name, this.url, {this.portugueseOnly = false});
  final String name;
  final String url;
  final bool portugueseOnly;
}

class IptvChannel {
  const IptvChannel({
    required this.name,
    required this.url,
    required this.category,
    this.logo,
  });
  final String name;
  final String url;
  final String category;
  final String? logo;
}

class IptvService {
  static const sources = <IptvSource>[
    IptvSource('Todos', 'https://iptv-org.github.io/iptv/index.m3u'),
    IptvSource('Brasil', 'https://iptv-org.github.io/iptv/countries/br.m3u'),
    IptvSource('Português', 'https://iptv-org.github.io/iptv/languages/por.m3u'),
    IptvSource('Filmes em Português',
        'https://iptv-org.github.io/iptv/categories/movies.m3u',
        portugueseOnly: true),
    IptvSource('Séries em Português',
        'https://iptv-org.github.io/iptv/categories/series.m3u',
        portugueseOnly: true),
    IptvSource('Animações em Português',
        'https://iptv-org.github.io/iptv/categories/animation.m3u',
        portugueseOnly: true),
    IptvSource('Esportes', 'https://iptv-org.github.io/iptv/categories/sports.m3u'),
    IptvSource('Filmes', 'https://iptv-org.github.io/iptv/categories/movies.m3u'),
    IptvSource('Séries', 'https://iptv-org.github.io/iptv/categories/series.m3u'),
    IptvSource('Clássicos', 'https://iptv-org.github.io/iptv/categories/classic.m3u'),
    IptvSource('Infantil', 'https://iptv-org.github.io/iptv/categories/kids.m3u'),
    IptvSource('Notícias', 'https://iptv-org.github.io/iptv/categories/news.m3u'),
    IptvSource('Entretenimento', 'https://iptv-org.github.io/iptv/categories/entertainment.m3u'),
    IptvSource('Documentários', 'https://iptv-org.github.io/iptv/categories/documentary.m3u'),
    IptvSource('Música', 'https://iptv-org.github.io/iptv/categories/music.m3u'),
    IptvSource('Animação', 'https://iptv-org.github.io/iptv/categories/animation.m3u'),
  ];

  static const _portugueseLists = [
    'https://iptv-org.github.io/iptv/countries/br.m3u',
    'https://iptv-org.github.io/iptv/languages/por.m3u',
  ];

  Future<List<IptvChannel>> load(IptvSource source) async {
    Future<String> fetch(String url) async {
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 35));
      if (response.statusCode != 200) {
        throw Exception('Erro HTTP ${response.statusCode}');
      }
      return response.body;
    }

    final content = await fetch(source.url);
    if (!source.portugueseOnly) return parse(content, source.name);

    // A playlist de categoria normalmente não declara idioma/país.
    // Cruzamos por tvg-id e URL com playlists brasileiras/em português.
    final portugueseIds = <String>{};
    final portugueseUrls = <String>{};
    var loadedReferences = 0;
    for (final url in _portugueseLists) {
      try {
        final reference = await fetch(url);
        loadedReferences++;
        portugueseIds.addAll(_collectIds(reference));
        portugueseUrls.addAll(parse(reference, source.name)
            .map((channel) => channel.url.trim()));
      } catch (_) {
        // Uma lista indisponível não impede o uso da outra.
      }
    }
    if (loadedReferences == 0) {
      throw Exception('Não foi possível consultar as listas de referência em português.');
    }
    return parse(content, source.name,
        portugueseOnly: true,
        portugueseIds: portugueseIds,
        portugueseUrls: portugueseUrls);
  }

  static Set<String> _collectIds(String content) {
    final ids = <String>{};
    for (final line in content.split(RegExp(r'\r?\n'))) {
      if (!line.startsWith('#EXTINF:')) continue;
      final id = _attribute(line, 'tvg-id')?.trim().toLowerCase();
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  static String? _attribute(String line, String key) =>
      RegExp('${RegExp.escape(key)}="([^"]*)"', caseSensitive: false)
          .firstMatch(line)
          ?.group(1);

  static bool _portugueseMetadata(String? country, String? language) {
    final countries = (country ?? '')
        .split(RegExp(r'[,;\s]+'))
        .map((value) => value.trim().toUpperCase());
    if (countries.contains('BR') || countries.contains('PT')) return true;

    final languages = (language ?? '')
        .split(RegExp(r'[,;|]+'))
        .map((value) => value.trim().toLowerCase());
    return languages.any((value) =>
        value == 'por' ||
        value == 'pt' ||
        value == 'pt-br' ||
        value == 'pt-pt' ||
        value == 'portuguese' ||
        value == 'português' ||
        value == 'portugues');
  }

  static List<IptvChannel> parse(String content, String category,
      {bool portugueseOnly = false,
      Set<String> portugueseIds = const {},
      Set<String> portugueseUrls = const {}}) {
    final channels = <IptvChannel>[];
    final seen = <String>{};
    String? name, logo, group, country, language, tvgId;
    for (final raw in content.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.startsWith('#EXTINF:')) {
        final comma = line.lastIndexOf(',');
        name = comma >= 0 ? line.substring(comma + 1).trim() : 'Canal';
        logo = _attribute(line, 'tvg-logo');
        group = _attribute(line, 'group-title');
        country = _attribute(line, 'tvg-country');
        language = _attribute(line, 'tvg-language');
        tvgId = _attribute(line, 'tvg-id')?.trim().toLowerCase();
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        final uri = Uri.tryParse(line);
        if (name != null &&
            uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            (!portugueseOnly ||
                _portugueseMetadata(country, language) ||
                (tvgId != null && tvgId.isNotEmpty && portugueseIds.contains(tvgId)) ||
                portugueseUrls.contains(line)) &&
            seen.add(line)) {
          channels.add(IptvChannel(
            name: name,
            url: line,
            logo: logo,
            category: group?.isNotEmpty == true ? group! : category,
          ));
        }
        name = null;
        logo = null;
        group = null;
        country = null;
        language = null;
        tvgId = null;
      }
    }
    return channels;
  }
}

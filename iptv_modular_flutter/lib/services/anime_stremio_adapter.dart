import '../models/stremio_meta_item.dart';
import 'anime_catalog_service.dart';

class AnimeStremioAdapter {
  static StremioMetaItem convert(AnimeCatalogItem anime) {
    final id = anime.malId != null ? 'mal:${anime.malId}' : anime.id;

    final raw = <String, dynamic>{
      'id': id,
      'type': 'series',
      'name': anime.title,
      'description': anime.description ?? '',
      'poster': anime.poster,
      'background': anime.poster,
      'releaseInfo': anime.year?.toString() ?? '',
      'year': anime.year,
      'genres': <String>['Anime'],
      'source': anime.source,
      'anilistId': anime.anilistId,
      'malId': anime.malId,
    };

    return StremioMetaItem.fromJson(raw);
  }

  static List<StremioMetaItem> convertAll(
    List<AnimeCatalogItem> animes,
  ) {
    return animes.map(convert).toList();
  }
}

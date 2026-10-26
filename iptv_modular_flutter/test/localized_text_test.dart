import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_modular_flutter/models/movie.dart';
import 'package:iptv_modular_flutter/models/stremio_meta_item.dart';
import 'package:iptv_modular_flutter/services/cinemeta_service.dart';

void main() {
  test('movie prefers Brazilian Portuguese metadata when present', () {
    final movie = Movie.fromCinemetaJson({
      'id': 'tt123',
      'name': 'Filme',
      'description': 'English synopsis',
      'translations': {
        'pt': {'description': 'Sinopse em português'},
        'pt-BR': {'description': 'Sinopse brasileira'},
      },
    });

    expect(movie.overview, 'Sinopse brasileira');
  });

  test('Stremio metadata supports localized field variants', () {
    final item = StremioMetaItem.fromJson({
      'id': 'tt123',
      'type': 'series',
      'name': 'Série',
      'description_pt': 'Sinopse em português',
      'overview': 'Original synopsis',
    });

    expect(item.description, 'Sinopse em português');
  });

  test('localized episode overview prefers Portuguese before original', () {
    final episode = SeriesEpisode.fromJson({
      'id': 'tt-episode',
      'title': 'Episode',
      'season': 1,
      'episode': 1,
      'overview': {
        'en': 'Original description',
        'pt-BR': 'Resumo em português',
      },
    });

    expect(episode.overview, 'Resumo em português');
  });
}

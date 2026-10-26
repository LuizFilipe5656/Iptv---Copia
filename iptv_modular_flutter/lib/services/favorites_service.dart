import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/movie.dart';
import 'local_storage_service.dart';

class FavoritesService {
  FavoritesService({SharedPreferences? preferences})
      : _preferences = preferences;

  static const _storageKey = 'favorite_titles';
  final SharedPreferences? _preferences;

  Future<List<Movie>> getFavorites() async {
    final values = await LocalStorageService.getStringList(
      _storageKey,
      fallback: _preferences,
    );
    return List.unmodifiable(values.map((value) {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Favorito salvo em formato inválido.');
      }
      return Movie.fromCinemetaJson(decoded);
    }));
  }

  Future<bool> contains(Movie movie) async {
    final favorites = await getFavorites();
    return favorites.any((favorite) => _keyFor(favorite) == _keyFor(movie));
  }

  Future<void> add(Movie movie) async {
    _validate(movie);
    final favorites = (await getFavorites())
        .where((favorite) => _keyFor(favorite) != _keyFor(movie))
        .toList();
    favorites.add(movie);
    await _save(favorites);
  }

  Future<void> remove(Movie movie) async {
    final favorites = (await getFavorites())
        .where((favorite) => _keyFor(favorite) != _keyFor(movie))
        .toList();
    await _save(favorites);
  }

  Future<bool> toggle(Movie movie) async {
    if (await contains(movie)) {
      await remove(movie);
      return false;
    }
    await add(movie);
    return true;
  }

  String _keyFor(Movie movie) => movie.imdbId ?? movie.id;

  void _validate(Movie movie) {
    if (movie.type != 'movie' && movie.type != 'series') {
      throw ArgumentError.value(
        movie.type,
        'movie.type',
        'Favoritos aceitam apenas filmes e séries.',
      );
    }
  }

  Future<void> _save(List<Movie> favorites) async {
    final saved = await LocalStorageService.setStringList(
      _storageKey,
      favorites.map((movie) {
        return jsonEncode({
          'id': movie.id,
          'imdb_id': movie.imdbId,
          'type': movie.type,
          'name': movie.title,
          'description': movie.overview,
          'poster': movie.posterUrl,
          'background': movie.bannerUrl,
          'imdbRating': movie.imdbRating,
          'releaseInfo': movie.releaseYear?.toString(),
        });
      }).toList(growable: false),
      fallback: _preferences,
    );
    if (!saved) {
      throw StateError('Não foi possível salvar os favoritos localmente.');
    }
  }
}

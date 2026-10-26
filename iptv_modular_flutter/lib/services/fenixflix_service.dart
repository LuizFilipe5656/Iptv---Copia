import '../models/movie.dart';

abstract interface class FenixflixService {
  Future<List<Movie>> search(String query);
}

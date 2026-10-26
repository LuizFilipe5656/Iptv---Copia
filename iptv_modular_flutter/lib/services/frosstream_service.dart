import '../models/movie.dart';

abstract interface class FrosstreamService {
  Future<List<Movie>> search(String query);
}

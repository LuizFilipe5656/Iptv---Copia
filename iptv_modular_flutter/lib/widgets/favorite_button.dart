import 'package:flutter/material.dart';

import '../models/movie.dart';
import '../services/favorites_service.dart';

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.movie,
    this.service,
  });

  final Movie movie;
  final FavoritesService? service;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  late final FavoritesService _favorites;
  late Future<bool> _isFavorite;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _favorites = widget.service ?? FavoritesService();
    _isFavorite = _favorites.contains(widget.movie);
  }

  Future<void> _toggle() async {
    setState(() => _updating = true);
    try {
      final isFavorite = await _favorites.toggle(widget.movie);
      if (mounted) {
        setState(() {
          _isFavorite = Future.value(isFavorite);
          _updating = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _updating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao atualizar favoritos: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isFavorite,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Falha ao carregar favorito: ${snapshot.error}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }
        final isFavorite = snapshot.data ?? false;
        return OutlinedButton.icon(
          onPressed: _updating ? null : _toggle,
          icon: _updating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(isFavorite ? Icons.star : Icons.star_border),
          label: Text(isFavorite ? 'Remover dos favoritos' : 'Favoritar'),
        );
      },
    );
  }
}

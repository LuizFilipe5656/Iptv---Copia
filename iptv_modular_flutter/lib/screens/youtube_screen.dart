import 'package:flutter/material.dart';

import '../services/youtube_service.dart';

class YoutubeScreen extends StatefulWidget {
  const YoutubeScreen({
    super.key,
    this.initialQuery = '',
    this.youtubeService,
  });

  static const routeName = '/youtube';

  final String initialQuery;
  final YoutubeService? youtubeService;

  @override
  State<YoutubeScreen> createState() => _YoutubeScreenState();
}

class _YoutubeScreenState extends State<YoutubeScreen> {
  late final TextEditingController _queryController;
  late final YoutubeService _youtube;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _youtube = widget.youtubeService ?? const ExternalYoutubeService();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search(YoutubeVideoCategory category) async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Digite um filme, série ou tema para buscar.')),
      );
      return;
    }

    try {
      final opened = await _youtube.openSearch(query, category: category);
      if (!mounted || opened) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o YouTube.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao abrir o YouTube: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(YoutubeVideoCategory.officialTrailer),
            decoration: const InputDecoration(
              labelText: 'Filme, série ou tema',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          for (final category in YoutubeVideoCategory.values) ...[
            _CategoryTile(
              category: category,
              onTap: () => _search(category),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          const Text(
            'As buscas abrem os resultados oficiais do YouTube no navegador ou app instalado.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onTap,
  });

  final YoutubeVideoCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, subtitle) = switch (category) {
      YoutubeVideoCategory.officialTrailer => (
          Icons.movie_creation_outlined,
          'Encontre trailers oficiais de filmes e séries',
        ),
      YoutubeVideoCategory.clips => (
          Icons.video_library_outlined,
          'Busque cenas, cortes e clipes',
        ),
      YoutubeVideoCategory.lives => (
          Icons.wifi_tethering_outlined,
          'Veja transmissões ao vivo',
        ),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(category.label),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new),
        onTap: onTap,
      ),
    );
  }
}

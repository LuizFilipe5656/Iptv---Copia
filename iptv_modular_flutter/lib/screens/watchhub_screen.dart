import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/movie.dart';
import '../models/watchhub_offer.dart';
import '../services/watchhub_service.dart';

class WatchhubScreen extends StatefulWidget {
  const WatchhubScreen({
    super.key,
    required this.movie,
    this.service,
    this.openUrl,
  });

  final Movie movie;
  final WatchhubService? service;
  final Future<bool> Function(Uri url)? openUrl;

  @override
  State<WatchhubScreen> createState() => _WatchhubScreenState();
}

class _WatchhubScreenState extends State<WatchhubScreen> {
  late final WatchhubService _watchhub;
  late final bool _ownsService;
  late Future<List<WatchhubOffer>> _availability;
  WatchAvailabilityType? _selectedType;
  String? _openError;

  @override
  void initState() {
    super.initState();
    _ownsService = widget.service == null;
    _watchhub = widget.service ?? HttpWatchhubService();
    _availability = _loadAvailability();
  }

  Future<List<WatchhubOffer>> _loadAvailability() {
    return _watchhub.availabilityFor(
      widget.movie.imdbId ?? widget.movie.id,
      type: widget.movie.type,
    );
  }

  @override
  void dispose() {
    if (_ownsService) {
      _watchhub.close();
    }
    super.dispose();
  }

  void _retry() {
    setState(() {
      _openError = null;
      _availability = _loadAvailability();
    });
  }

  Future<void> _openProvider(Uri url) async {
    try {
      final opened = await (widget.openUrl ?? _launchUrl)(url);
      if (!mounted || opened) {
        return;
      }
      setState(
          () => _openError = 'Não foi possível abrir o serviço selecionado.');
    } catch (error) {
      if (mounted) {
        setState(() => _openError = 'Falha ao abrir o serviço: $error');
      }
    }
  }

  Future<bool> _launchUrl(Uri url) {
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onde assistir')),
      body: FutureBuilder<List<WatchhubOffer>>(
        future: _availability,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _WatchhubMessage(
              message:
                  'Falha ao consultar disponibilidade no WatchHub: ${snapshot.error}',
              onRetry: _retry,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final offers = snapshot.data!;
          if (offers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'O WatchHub não encontrou opções de catálogo para este título.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final availableTypes = WatchAvailabilityType.values
              .where((type) =>
                  offers.any((offer) => offer.availabilityType == type))
              .toList(growable: false);
          final filteredOffers = _selectedType == null
              ? offers
              : offers
                  .where((offer) => offer.availabilityType == _selectedType)
                  .toList(growable: false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  widget.movie.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Catálogos e opções informados pelo WatchHub'),
              ),
              if (availableTypes.length > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      _filterChip('Todos', null),
                      for (final type in availableTypes)
                        _filterChip(type.label, type),
                    ],
                  ),
                ),
              if (_openError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    _openError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: filteredOffers.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final offer = filteredOffers[index];
                    return ListTile(
                      leading: const Icon(Icons.open_in_new),
                      title: Text(offer.provider),
                      subtitle: Text(offer.title),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openProvider(offer.url),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, WatchAvailabilityType? type) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _selectedType == type,
        onSelected: (_) => setState(() => _selectedType = type),
      ),
    );
  }
}

class _WatchhubMessage extends StatelessWidget {
  const _WatchhubMessage({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

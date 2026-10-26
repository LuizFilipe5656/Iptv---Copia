import 'package:flutter/material.dart';

import '../models/addon.dart';
import '../models/stremio_addon_manifest.dart';
import '../models/stremio_meta_item.dart';
import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import 'stremio_details_screen.dart';
import 'stream_sources_sheet.dart';

class StremioHomeScreen extends StatefulWidget {
  const StremioHomeScreen({
    super.key,
    required this.addonRepository,
    required this.catalogRepository,
    required this.streamRepository,
    this.header,
  });

  final AddonRepository addonRepository;
  final CatalogRepository catalogRepository;
  final StreamRepository streamRepository;
  final Widget? header;

  @override
  State<StremioHomeScreen> createState() => _StremioHomeScreenState();
}

class _StremioHomeScreenState extends State<StremioHomeScreen> {
  late Future<List<Addon>> _addons;

  @override
  void initState() {
    super.initState();
    _addons = _loadAddons();
  }

  Future<List<Addon>> _loadAddons() =>
      widget.addonRepository.getInstalledAddons();

  void _retry() {
    setState(() => _addons = _loadAddons());
  }

  Future<void> _refresh() async {
    final refresh = _loadAddons();
    setState(() => _addons = refresh);
    await refresh;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Addon>>(
      future: _addons,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Message(
            message: 'Não foi possível carregar os addons: ${snapshot.error}',
            onRetry: _retry,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final providers = snapshot.data!;
        if (providers.isEmpty) {
          return const Center(child: Text('Nenhum addon está instalado.'));
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              if (widget.header != null) widget.header!,
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text(
                  'CATÁLOGOS DOS ADDONS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              for (final addon in providers)
                _AddonSection(
                  addon: addon,
                  addonRepository: widget.addonRepository,
                  catalogRepository: widget.catalogRepository,
                  streamRepository: widget.streamRepository,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AddonSection extends StatefulWidget {
  const _AddonSection({
    required this.addon,
    required this.addonRepository,
    required this.catalogRepository,
    required this.streamRepository,
  });

  final Addon addon;
  final AddonRepository addonRepository;
  final CatalogRepository catalogRepository;
  final StreamRepository streamRepository;

  @override
  State<_AddonSection> createState() => _AddonSectionState();
}

class _AddonSectionState extends State<_AddonSection> {
  late Future<StremioAddonManifest> _manifest;

  @override
  void initState() {
    super.initState();
    _manifest = widget.addonRepository.getManifest(widget.addon);
  }

  void _retry() {
    setState(
        () => _manifest = widget.addonRepository.getManifest(widget.addon));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StremioAddonManifest>(
      future: _manifest,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            title: Text(widget.addon.name),
            subtitle: Text(
              'Não foi possível carregar o manifest: ${snapshot.error}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Tentar novamente',
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
            ),
          );
        }
        if (!snapshot.hasData) {
          return ListTile(
            title: Text(widget.addon.name),
            subtitle: const LinearProgressIndicator(),
          );
        }
        final manifest = snapshot.data!;
        final catalogs = manifest.catalogs.where((catalog) =>
            manifest.types.isEmpty || manifest.types.contains(catalog.type));
        if (catalogs.isEmpty) {
          return ListTile(
            title: Text(manifest.name),
            subtitle: const Text(
              'Este addon não publica catálogos. Seus recursos de stream/legendas '
              'serão consultados ao selecionar um conteúdo compatível.',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                manifest.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            for (final catalog in catalogs)
              _CatalogRow(
                addon: widget.addon,
                catalog: catalog,
                repository: widget.catalogRepository,
                streamRepository: widget.streamRepository,
                addonRepository: widget.addonRepository,
              ),
          ],
        );
      },
    );
  }
}

class _CatalogRow extends StatefulWidget {
  const _CatalogRow({
    required this.addon,
    required this.catalog,
    required this.repository,
    required this.streamRepository,
    required this.addonRepository,
  });

  final Addon addon;
  final StremioCatalog catalog;
  final CatalogRepository repository;
  final StreamRepository streamRepository;
  final AddonRepository addonRepository;

  @override
  State<_CatalogRow> createState() => _CatalogRowState();
}

class _CatalogRowState extends State<_CatalogRow> {
  final Map<String, TextEditingController> _extraControllers = {};
  late Future<List<StremioMetaItem>> _items;

  @override
  void initState() {
    super.initState();
    for (final extra
        in widget.catalog.extra.where((extra) => extra.isRequired)) {
      _extraControllers[extra.name] = TextEditingController();
    }
    _items = _loadItems(const {});
  }

  Future<List<StremioMetaItem>> _loadItems(Map<String, String> extra) {
    return widget.repository.getCatalog(
      addon: widget.addon,
      catalog: widget.catalog,
      extra: extra,
    );
  }

  void _retry() {
    final extra = _extraControllers.map(
      (key, controller) => MapEntry(key, controller.text.trim()),
    );
    setState(() => _items = _loadItems(extra));
  }

  @override
  void dispose() {
    for (final controller in _extraControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requiredExtras = widget.catalog.extra
        .where((extra) => extra.isRequired)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.catalog.name} · ${widget.catalog.type}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (requiredExtras.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final extra in requiredExtras)
                    TextField(
                      controller: _extraControllers[extra.name],
                      decoration: InputDecoration(
                        labelText: extra.name,
                        hintText: extra.options.isEmpty
                            ? 'Informe ${extra.name}'
                            : extra.options.join(', '),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _retry(),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.search),
                      label: const Text('Buscar'),
                    ),
                  ),
                  FutureBuilder<List<StremioMetaItem>>(
                    future: _items,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _Message(
                          message: 'Falha ao buscar: ${snapshot.error}',
                          onRetry: _retry,
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return _itemList(snapshot.data!);
                    },
                  ),
                ],
              ),
            )
          else
            FutureBuilder<List<StremioMetaItem>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _Message(
                    message:
                        'Falha no catálogo ${widget.catalog.name}: ${snapshot.error}',
                    onRetry: _retry,
                  );
                }
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const SizedBox(
                    height: 72,
                    child: Center(child: Text('Nenhum título encontrado.')),
                  );
                }
                return _itemList(items);
              },
            ),
        ],
      ),
    );
  }

  Widget _itemList(List<StremioMetaItem> items) {
    return SizedBox(
      height: 248,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _MetaCard(
          addon: widget.addon,
          item: items[index],
          addons: widget.addonRepository,
          catalogs: widget.repository,
          streams: widget.streamRepository,
        ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.addon,
    required this.item,
    required this.addons,
    required this.catalogs,
    required this.streams,
  });

  final Addon addon;
  final StremioMetaItem item;
  final AddonRepository addons;
  final CatalogRepository catalogs;
  final StreamRepository streams;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: InkWell(
        onTap: () => _openDetails(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.poster == null
                    ? Container(
                        width: double.infinity,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.movie_outlined, size: 42),
                      )
                    : Image.network(
                        item.poster!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              item.releaseInfo.isEmpty ? item.type : item.releaseInfo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetails(BuildContext context) async {
    var details = item;
    try {
      final manifest = await addons.getManifest(addon);
      if (manifest.supportsResource('meta', item.type, item.id)) {
        details = await catalogs.getMeta(
          addon: addon,
          type: item.type,
          id: item.id,
          fallback: item,
        );
      }
      details = await enrichStremioSeriesItem(
        details,
        sourceAddon: addon,
        addonRepository: addons,
        catalogRepository: catalogs,
      );
    } catch (_) {
      details = item;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Metadados adicionais indisponíveis; exibindo dados do catálogo.'),
          ),
        );
      }
    }
    if (!context.mounted) return;
    final streamAvailability = _getStreamAvailability();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StremioDetailsScreen(
          item: details,
          catalogAddon: addon,
          onWatch: _showSources,
          streamAvailability: streamAvailability,
          addonRepository: addons,
          catalogRepository: catalogs,
          streamRepository: streams,
        ),
      ),
    );
  }

  Future<bool> _getStreamAvailability() async {
    final installed = await addons.getInstalledAddons();
    final capabilities = await Future.wait(installed.map((provider) async {
      try {
        final providerManifest = await addons.getManifest(provider);
        return providerManifest.supportsResource(
          'stream',
          item.type,
          item.id,
        );
      } catch (_) {
        return true;
      }
    }));
    return capabilities.any((supports) => supports);
  }

  Future<void> _showSources(BuildContext context) async {
    try {
      final installed = await addons.getInstalledAddons();
      if (!context.mounted) {
        return;
      }
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => StremioSourcesSheet(
          item: item,
          addons: installed,
          repository: streams,
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao consultar addons: $error')),
        );
      }
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, maxLines: 4, overflow: TextOverflow.ellipsis),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/addon.dart';
import '../repositories/addon_repository.dart';
import '../services/cinemeta_service.dart';
import '../services/streaming_addon_service.dart';
import '../services/subtitles_service.dart';
import '../services/addon_service.dart';
import 'addon_details_screen.dart';

class AddonsScreen extends StatefulWidget {
  const AddonsScreen({
    super.key,
    this.addonService,
    this.addonRepository,
    this.streamingAddonService,
    this.cinemetaService,
    this.subtitlesService,
    this.showAppBar = true,
  });

  static const routeName = '/addons';

  final AddonService? addonService;
  final AddonRepository? addonRepository;
  final StreamingAddonService? streamingAddonService;
  final CinemetaService? cinemetaService;
  final SubtitlesService? subtitlesService;
  final bool showAppBar;

  @override
  State<AddonsScreen> createState() => _AddonsScreenState();
}

class _AddonsScreenState extends State<AddonsScreen> {
  late final AddonService _addons;
  late final bool _ownsAddonService;
  late final StreamingAddonService _streamingAddons;
  late final bool _ownsStreamingAddonService;
  late final AddonRepository _addonRepository;
  late final bool _ownsAddonRepository;
  late Future<List<Addon>> _catalog;

  @override
  void initState() {
    super.initState();
    _ownsAddonService = widget.addonService == null;
    _addons = widget.addonService ?? AddonService();
    _ownsAddonRepository = widget.addonRepository == null;
    _addonRepository = widget.addonRepository ?? AddonRepository();
    _ownsStreamingAddonService = widget.streamingAddonService == null;
    _streamingAddons = widget.streamingAddonService ??
        DefaultStreamingAddonService(repository: _addonRepository);
    _catalog = _addons.loadCatalog();
  }

  @override
  void dispose() {
    if (_ownsAddonService) {
      _addons.close();
    }
    if (_ownsStreamingAddonService && !_ownsAddonRepository) {
      _streamingAddons.close();
    }
    if (_ownsAddonRepository) {
      _addonRepository.close();
    }
    super.dispose();
  }

  void _retry() {
    setState(() => _catalog = _addons.loadCatalog());
  }

  Future<void> _showAddonDetails(Addon addon) async {
    final installed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddonDetailsScreen(
          addon: addon,
          repository: _addonRepository,
          onToggle:
              addon.fixed ? null : () => _setInstalled(addon, !addon.enabled),
          onRemove: addon.fixed ? null : () => _removeAddon(addon),
          onUpdate: addon.url.isNotEmpty ? () => _updateAddon(addon) : null,
        ),
      ),
    );
    if (installed == true && mounted) {
      _retry();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Addon instalado com sucesso.')),
      );
    }
  }

  Future<void> _updateAddon(Addon addon) async {
    try {
      await _streamingAddons.update(addon.id);
      if (!mounted) {
        return;
      }
      _retry();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${addon.name} atualizado.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao atualizar addon: $error')),
        );
      }
    }
  }

  Future<void> _importAddon() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final addonDetails = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar Addon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Manifest URL',
                hintText: 'https://addon.example/manifest.json',
              ),
              onSubmitted: (_) => Navigator.pop(
                dialogContext,
                (nameController.text.trim(), urlController.text.trim()),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              (nameController.text.trim(), urlController.text.trim()),
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    nameController.dispose();
    urlController.dispose();
    if (addonDetails == null || addonDetails.$2.isEmpty) {
      return;
    }
    try {
      final installedAddon = await _streamingAddons.importFromUrl(
        addonDetails.$2,
        name: addonDetails.$1,
      );
      if (mounted) {
        _retry();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${installedAddon.name} instalado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao instalar addon JSON: $error')),
        );
      }
    }
  }

  Future<void> _removeAddon(Addon addon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remover ${addon.name}?'),
        content: const Text(
          'Este addon personalizado será removido deste dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _streamingAddons.remove(addon.id);
      if (mounted) {
        _retry();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${addon.name} removido.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao remover addon: $error')),
        );
      }
    }
  }

  Future<void> _setInstalled(Addon addon, bool installed) async {
    try {
      await _streamingAddons.setEnabled(addon.id, installed);
      if (!mounted) {
        return;
      }
      setState(() => addon.enabled = installed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            installed ? '${addon.name} instalado.' : '${addon.name} removido.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao alterar addon: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Add-ons instalados'),
              actions: [
                IconButton(
                  tooltip: 'Adicionar Addon',
                  onPressed: _importAddon,
                  icon: const Icon(Icons.add),
                ),
              ],
            )
          : null,
      body: FutureBuilder<List<Addon>>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CatalogMessage(
              message:
                  'Falha ao carregar o catálogo de addons: ${snapshot.error}',
              onRetry: _retry,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final addons = snapshot.data!;
          final fixedAddons =
              addons.where((addon) => addon.fixed).toList(growable: false);
          final installedAddons = addons
              .where((addon) => !addon.fixed && addon.enabled)
              .toList(growable: false);
          final uninstalledAddons = addons
              .where((addon) => !addon.fixed && !addon.enabled)
              .toList(growable: false);
          return ListView(
            children: [
              if (fixedAddons.isNotEmpty) ...[
                const _AddonSectionHeader(title: 'ADD-ONS FIXOS'),
                for (final addon in fixedAddons) _addonTile(addon),
              ],
              const _AddonSectionHeader(title: 'ADD-ONS INSTALADOS'),
              for (final addon in installedAddons) _addonTile(addon),
              if (uninstalledAddons.isNotEmpty) ...[
                const _AddonSectionHeader(title: 'DISPONÍVEIS'),
                for (final addon in uninstalledAddons) _addonTile(addon),
              ],
              if (addons.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nenhum addon instalado.'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _addonTile(Addon addon) {
    return ListTile(
      leading: Icon(
        Icons.extension_outlined,
        color: addon.enabled
            ? Theme.of(context).colorScheme.primary
            : Colors.white38,
      ),
      title: Text(addon.name),
      subtitle: Text(
        addon.fixed
            ? 'Fixo · protegido pelo sistema'
            : addon.enabled
                ? 'Instalado'
                : 'Não instalado',
      ),
      trailing: Icon(
        addon.enabled ? Icons.check_circle : Icons.cancel_outlined,
        color: addon.enabled ? Colors.green : Colors.white38,
      ),
      onTap: () => _showAddonDetails(addon),
    );
  }
}

class _AddonSectionHeader extends StatelessWidget {
  const _AddonSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({required this.message, required this.onRetry});

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

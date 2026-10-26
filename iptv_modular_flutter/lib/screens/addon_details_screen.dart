import 'package:flutter/material.dart';

import '../models/addon.dart';
import '../models/stremio_addon_manifest.dart';
import '../repositories/addon_repository.dart';
import '../services/addon_configuration_service.dart';
import 'addon_configuration_screen.dart';

class AddonDetailsScreen extends StatefulWidget {
  const AddonDetailsScreen({
    super.key,
    required this.addon,
    required this.repository,
    this.onToggle,
    this.onRemove,
    this.onUpdate,
  });

  final Addon addon;
  final AddonRepository repository;
  final Future<void> Function()? onToggle;
  final Future<void> Function()? onRemove;
  final Future<void> Function()? onUpdate;

  @override
  State<AddonDetailsScreen> createState() => _AddonDetailsScreenState();
}

class _AddonDetailsScreenState extends State<AddonDetailsScreen> {
  late Future<StremioAddonManifest> _manifest;
  late Future<Map<String, String>> _configuration;

  @override
  void initState() {
    super.initState();
    _manifest = widget.repository.getManifest(widget.addon);
    _configuration = widget.repository.getAddonConfiguration(widget.addon.id);
  }

  Future<void> _configure(
    StremioAddonManifest manifest,
    Map<String, String> savedValues,
  ) async {
    final configurationService = AddonConfigurationService(widget.repository);
    final values = configurationService.initialValues(
      addon: widget.addon,
      manifest: manifest,
      savedValues: savedValues,
    );
    final installed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddonConfigurationScreen(
          addon: widget.addon,
          manifest: manifest,
          initialValues: values,
          configurationService: configurationService,
        ),
      ),
    );
    if (installed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do addon')),
      body: FutureBuilder<StremioAddonManifest>(
        future: _manifest,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _failure(snapshot.error!);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _manifestContent(snapshot.data!);
        },
      ),
    );
  }

  Widget _failure(Object error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              Text('Não foi possível carregar os detalhes: $error'),
              TextButton.icon(
                onPressed: () => setState(
                  () => _manifest = widget.repository.getManifest(widget.addon),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );

  Widget _manifestContent(StremioAddonManifest manifest) {
    return FutureBuilder<Map<String, String>>(
      future: _configuration,
      builder: (context, configSnapshot) {
        if (configSnapshot.hasError) {
          return _failure(configSnapshot.error!);
        }
        if (!configSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final config = configSnapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                if (manifest.logo != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Image.network(
                      manifest.logo!,
                      width: 64,
                      height: 64,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.extension, size: 48),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.extension, size: 48),
                  ),
                Expanded(
                  child: Text(
                    manifest.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detail('Versão', manifest.version),
            _detail('Manifest URL', widget.addon.manifestUrl),
            _detail(
              'Descrição',
              manifest.description.isEmpty
                  ? 'Não informada pelo addon.'
                  : manifest.description,
            ),
            const SizedBox(height: 12),
            Text('CAPACIDADES', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _status('Catálogo', manifest.hasCatalogs),
                _status('Metadados', manifest.hasMeta),
                _status('Streams', manifest.hasStreams),
                _status('Legendas', manifest.hasSubtitles),
              ],
            ),
            const SizedBox(height: 12),
            _detail(
              'Recursos',
              manifest.resources.isEmpty
                  ? 'Não declarados'
                  : manifest.resources
                      .map((resource) => resource.name)
                      .join(', '),
            ),
            _detail(
              'Catálogos',
              manifest.catalogs.isEmpty
                  ? 'Nenhum'
                  : manifest.catalogs
                      .map((catalog) => '${catalog.name} (${catalog.type})')
                      .join(', '),
            ),
            _detail(
              'Tipos',
              manifest.types.isEmpty
                  ? 'Não declarados'
                  : manifest.types.join(', '),
            ),
            _detail(
              'Behavior hints',
              manifest.behaviorHints.isEmpty
                  ? 'Nenhum'
                  : manifest.behaviorHints.entries
                      .map((entry) => '${entry.key}: ${entry.value}')
                      .join(', '),
            ),
            if (manifest.isConfigurable) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _configure(manifest, config),
                icon: const Icon(Icons.tune),
                label: const Text('Configurar'),
              ),
            ],
            if (widget.onToggle != null ||
                widget.onUpdate != null ||
                widget.onRemove != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (widget.onToggle != null)
                    OutlinedButton(
                      onPressed: widget.onToggle,
                      child:
                          Text(widget.addon.enabled ? 'Desativar' : 'Ativar'),
                    ),
                  if (widget.onUpdate != null)
                    OutlinedButton(
                      onPressed: widget.onUpdate,
                      child: const Text('Reinstalar'),
                    ),
                  if (widget.onRemove != null)
                    TextButton(
                      onPressed: widget.onRemove,
                      child: const Text('Desinstalar'),
                    ),
                ],
              ),
            ],
            if (manifest.configuration.isNotEmpty)
              _detail(
                'Opções configuráveis',
                manifest.configuration.map((field) => field.title).join(', '),
              ),
            if (!manifest.hasStreams)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Este addon fornece metadados ou catálogo, mas não fornece fontes de reprodução.',
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SelectableText('$label: $value'),
      );

  Widget _status(String label, bool available) => Chip(
        avatar: Icon(
          available ? Icons.check_circle : Icons.remove_circle_outline,
          color: available ? Colors.green : Colors.white54,
          size: 18,
        ),
        label: Text('$label ${available ? 'disponível' : 'indisponível'}'),
      );
}

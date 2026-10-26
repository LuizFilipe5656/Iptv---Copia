import 'package:flutter/material.dart';
import '../services/auth_service.dart';

import '../repositories/addon_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/stream_repository.dart';
import '../screens/favorites_screen.dart';
import '../screens/local_files_screen.dart';
import '../services/favorites_service.dart';
import '../services/playback_progress_service.dart';
import '../widgets/permission_guard.dart';
import 'admin_panel_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.themeMode = ThemeMode.dark,
    this.onThemeModeChanged,
    this.themeLoaded = true,
    this.showAppBar = true,
    this.addonRepository,
    this.catalogRepository,
    this.streamRepository,
    this.playbackProgressService,
  });

  static const routeName = '/settings';

  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode mode)? onThemeModeChanged;
  final bool themeLoaded;
  final bool showAppBar;
  final AddonRepository? addonRepository;
  final CatalogRepository? catalogRepository;
  final StreamRepository? streamRepository;
  final PlaybackProgressService? playbackProgressService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _favorites = FavoritesService();
  final _history = PlaybackProgressService();

  late Future<(int, int)> _localCounts = _loadLocalCounts();

  bool _clearingCache = false;

  Future<(int, int)> _loadLocalCounts() async {
    final results = await Future.wait([
      _favorites.getFavorites(),
      _history.getProgress(),
    ]);

    return (results[0].length, results[1].length);
  }

  void _clearCache() {
    if (_clearingCache) {
      return;
    }

    setState(() => _clearingCache = true);

    try {
      final imageCache = PaintingBinding.instance.imageCache;

      imageCache
        ..clear()
        ..clearLiveImages();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache de imagens em memória limpo.'),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao limpar cache: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _clearingCache = false);
      }
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: const Text(
          'Isso remove os pontos salvos de Continuar Assistindo. '
          'Seus favoritos não serão alterados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _history.clearHistory();

      if (mounted) {
        setState(() => _localCounts = _loadLocalCounts());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Histórico de reprodução limpo.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao limpar histórico: $error'),
          ),
        );
      }
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Cine Mobile',
      applicationVersion: 'Versão de desenvolvimento',
      applicationLegalese: 'Catálogo e reprodução de mídia.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Configurações'),
            )
          : null,
      body: ListView(
        children: [
          _SettingsSection(
            title: 'APLICATIVO',
            children: [
              ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('Favoritos'),
                subtitle: const Text('Filmes e séries salvos.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FavoritesScreen(
                      addonRepository: widget.addonRepository,
                      catalogRepository: widget.catalogRepository,
                      streamRepository: widget.streamRepository,
                      playbackProgressService:
                          widget.playbackProgressService ?? _history,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Sobre'),
                subtitle: const Text('Informações do Cine Mobile.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showAbout,
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('Cache'),
                subtitle: const Text(
                  'Limpar imagens em cache na memória.',
                ),
                trailing: _clearingCache
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _clearingCache ? null : _clearCache,
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Conta'),
                subtitle: const Text('Visualizar informações da conta'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Minha conta'),
                      content: FutureBuilder<Map<String, dynamic>>(
                        future: AuthService.validateCurrentUser(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const SizedBox(
                              height: 48,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snapshot.hasError) {
                            return Text('Não foi possível carregar a conta: ${snapshot.error}');
                          }
                          final profile = snapshot.data ?? {};
                          return SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Nome: ${profile['name'] ?? '-'}'),
                                Text('E-mail: ${profile['email'] ?? '-'}'),
                                Text('Perfil: ${profile['role'] ?? '-'}'),
                                Text('Status: ${profile['status'] ?? '-'}'),
                                Text('Plano: ${profile['plan'] ?? '-'}'),
                                Text('Validade: ${profile['expiration_date'] ?? '-'}'),
                              ],
                            ),
                          );
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Fechar'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Arquivos locais'),
                subtitle: const Text(
                  'Abrir vídeos MP4, MKV e AVI do dispositivo.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(
                  context,
                  LocalFilesScreen.routeName,
                ),
              ),
            ],
          ),

          // Acesso administrativo protegido por permissão.
          PermissionGuard(
            permission: 'app.admin_total',
            child: _SettingsSection(
              title: 'ADMINISTRAÇÃO',
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.blueAccent,
                  ),
                  title: const Text(
                    'Painel Administrativo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  subtitle: const Text(
                    'Gerenciar cargos de usuários e revendedores',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminPanelScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          _SettingsSection(
            title: 'PERSISTÊNCIA LOCAL',
            children: [
              FutureBuilder<(int, int)>(
                future: _localCounts,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('Dados neste dispositivo'),
                      subtitle: Text(
                        'Falha ao carregar os dados: ${snapshot.error}',
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const ListTile(
                      leading: Icon(Icons.storage_outlined),
                      title: Text('Dados neste dispositivo'),
                      subtitle: Text('Carregando dados locais...'),
                    );
                  }

                  final counts = snapshot.data!;

                  return ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('Dados neste dispositivo'),
                    subtitle: Text(
                      'Favoritos: ${counts.$1} · Histórico: ${counts.$2}',
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Limpar histórico'),
                subtitle: const Text('Apagar Continuar Assistindo.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _clearHistory,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Favoritos e histórico são armazenados '
                  'localmente no dispositivo.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }
}

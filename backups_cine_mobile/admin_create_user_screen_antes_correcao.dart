
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_users_screen.dart';
import 'admin_create_user_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() =>
      _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late Future<Map<String, dynamic>> _dashboard;
  bool _testingAuth = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _dashboard = _loadDashboard();
  }

  Future<Map<String, dynamic>> _loadDashboard() async {
    final result = await Supabase.instance.client.rpc(
      'get_admin_dashboard',
    );

    if (result is List && result.isNotEmpty) {
      return Map<String, dynamic>.from(
        result.first as Map,
      );
    }

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    throw StateError(
      'O Supabase não retornou indicadores.',
    );
  }

  void _refresh() {
    if (!mounted) return;

    setState(() {
      _reload();
    });
  }

  Future<void> _openUsers() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminUsersScreen(),
      ),
    );

    if (!mounted) return;
    _refresh();
  }

  Future<void> _openCreateUser() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminCreateUserScreen(),
      ),
    );

    if (!mounted) return;
    _refresh();
  }

  Future<void> _testarAutenticacao() async {
    if (_testingAuth) return;

    final supabase = Supabase.instance.client;

    if (supabase.auth.currentSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhuma sessão ativa. Faça login novamente.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _testingAuth = true;
    });

    String titulo = 'Teste de autenticação';
    String resultado = '';

    try {
      final response = await supabase.functions.invoke(
        'admin-create-user',
        body: <String, dynamic>{},
      );

      resultado =
          'Status HTTP: ${response.status}\n\n'
          'Resposta:\n${response.data}';
    } on FunctionException catch (error) {
      resultado =
          'Status HTTP: ${error.status}\n\n'
          'Resposta:\n${error.details}';
    } catch (error) {
      titulo = 'Falha na comunicação';
      resultado =
          'Não foi possível concluir o teste.\n\n'
          'Detalhes: $error';
    } finally {
      if (mounted) {
        setState(() {
          _testingAuth = false;
        });
      }
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(titulo),
          content: SingleChildScrollView(
            child: SelectableText(resultado),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard(
    String label,
    Object? value,
    IconData icon,
    Color iconColor,
  ) {
    return Card(
      color: const Color(0xFF101B31),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 26,
            ),
            const Spacer(),
            Text(
              '${value ?? 0}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 24,
        bottom: 12,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.lightBlueAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid(
    List<(String, Object?, IconData, Color)> metrics,
    int columns,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 145,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];

        return _metricCard(
          metric.$1,
          metric.$2,
          metric.$3,
          metric.$4,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        title: const Text(
          'Cine Mobile - Administração',
        ),
        backgroundColor: const Color(0xFF101B31),
        actions: [
          IconButton(
            tooltip: 'Atualizar indicadores',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboard,
        builder: (context, snapshot) {
          if (snapshot.connectionState !=
              ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.orangeAccent,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Não foi possível carregar o Dashboard.',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Tentar novamente',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;

          final userMetrics =
              <(String, Object?, IconData, Color)>[
            (
              'Usuários cadastrados',
              data['total_usuarios'],
              Icons.people,
              Colors.lightBlueAccent,
            ),
            (
              'Contas ativas',
              data['total_ativos'],
              Icons.verified_user,
              Colors.greenAccent,
            ),
            (
              'Revendedores',
              data['total_revendedores'],
              Icons.store,
              Colors.amberAccent,
            ),
            (
              'Super administradores',
              data['total_super_admins'],
              Icons.admin_panel_settings,
              Colors.purpleAccent,
            ),
          ];

          final subscriptionMetrics =
              <(String, Object?, IconData, Color)>[
            (
              'Assinaturas vencidas',
              data['total_vencidos'],
              Icons.event_busy,
              Colors.redAccent,
            ),
          ];

          final creditMetrics =
              <(String, Object?, IconData, Color)>[
            (
              'Créditos disponíveis',
              data['total_creditos'],
              Icons.account_balance_wallet,
              Colors.lightBlueAccent,
            ),
            (
              'Créditos utilizados',
              data['total_creditos_utilizados'],
              Icons.payments,
              Colors.orangeAccent,
            ),
            (
              'Créditos adicionados',
              data['total_creditos_adicionados'],
              Icons.add_circle_outline,
              Colors.greenAccent,
            ),
            (
              'Créditos retirados',
              data['total_creditos_retirados'],
              Icons.remove_circle_outline,
              Colors.redAccent,
            ),
            (
              'Total de movimentações',
              data['total_movimentacoes'],
              Icons.history,
              Colors.cyanAccent,
            ),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 550
                          ? 3
                          : 2;

              return RefreshIndicator(
                onRefresh: () async {
                  _refresh();

                  try {
                    await _dashboard;
                  } catch (_) {
                    // O FutureBuilder exibirá o erro.
                  }
                },
                child: SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Visão geral',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Acompanhe usuários, assinaturas '
                        'e movimentações de créditos.',
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),

                      _sectionTitle(
                        'Usuários e revendedores',
                        Icons.people_outline,
                      ),

                      _metricsGrid(
                        userMetrics,
                        columns,
                      ),

                      _sectionTitle(
                        'Assinaturas',
                        Icons.calendar_month,
                      ),

                      _metricsGrid(
                        subscriptionMetrics,
                        columns,
                      ),

                      _sectionTitle(
                        'Controle de créditos',
                        Icons.account_balance_wallet,
                      ),

                      _metricsGrid(
                        creditMetrics,
                        columns,
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openUsers,
                          icon: const Icon(
                            Icons.manage_accounts,
                          ),
                          label: const Text(
                            'Abrir gerenciamento de usuários',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openCreateUser,
                          icon: const Icon(Icons.person_add),
                          label: const Text(
                            'Cadastrar cliente ou revendedor',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _testingAuth
                              ? null
                              : _testarAutenticacao,
                          icon: _testingAuth
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.security),
                          label: Text(
                            _testingAuth
                                ? 'Testando autenticação...'
                                : 'Testar autenticação Supabase',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Colors.lightBlueAccent,
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Card(
                        color: Color(0xFF101B31),
                        child: ListTile(
                          leading: Icon(
                            Icons.info_outline,
                            color: Colors.lightBlueAccent,
                          ),
                          title: Text(
                            'Gerenciamento administrativo',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            'Gerencie usuários, revendedores, '
                            'assinaturas e créditos pelo '
                            'painel administrativo.',
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

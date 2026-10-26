import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_users_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late Future<Map<String, dynamic>> _dashboard;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  // =========================================================
  // CARREGAMENTO DO DASHBOARD
  // =========================================================

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

  // =========================================================
  // NAVEGAÇÃO PARA GERENCIAMENTO DE USUÁRIOS
  // =========================================================

  Future<void> _openUsers() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminUsersScreen(),
      ),
    );

    if (!mounted) return;

    // Atualiza os indicadores ao retornar.
    _refresh();
  }

  // =========================================================
  // CARTÃO DE INDICADOR
  // =========================================================

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

  // =========================================================
  // TÍTULO DE SEÇÃO
  // =========================================================

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

  // =========================================================
  // GRADE RESPONSIVA DE INDICADORES
  // =========================================================

  Widget _metricsGrid(
    List<(String, Object?, IconData, Color)> metrics,
    int columns,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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

  // =========================================================
  // INTERFACE PRINCIPAL
  // =========================================================

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
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboard,
        builder: (context, snapshot) {
          // Carregamento

          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Erro

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
                      'Não foi possível carregar '
                      'o Dashboard.',
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
                      icon: const Icon(
                        Icons.refresh,
                      ),
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

          // =================================================
          // INDICADORES DE USUÁRIOS
          // =================================================

          final userMetrics = <(String, Object?, IconData, Color)>[
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

          // =================================================
          // INDICADORES DE ASSINATURAS
          // =================================================

          final subscriptionMetrics = <(String, Object?, IconData, Color)>[
            (
              'Assinaturas vencidas',
              data['total_vencidos'],
              Icons.event_busy,
              Colors.redAccent,
            ),
          ];

          // =================================================
          // INDICADORES DE CRÉDITOS
          // =================================================

          final creditMetrics = <(String, Object?, IconData, Color)>[
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

          // =================================================
          // LAYOUT RESPONSIVO
          // =================================================

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho

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

                      // Usuários

                      _sectionTitle(
                        'Usuários e revendedores',
                        Icons.people_outline,
                      ),

                      _metricsGrid(
                        userMetrics,
                        columns,
                      ),

                      // Assinaturas

                      _sectionTitle(
                        'Assinaturas',
                        Icons.calendar_month,
                      ),

                      _metricsGrid(
                        subscriptionMetrics,
                        columns,
                      ),

                      // Créditos

                      _sectionTitle(
                        'Controle de créditos',
                        Icons.account_balance_wallet,
                      ),

                      _metricsGrid(
                        creditMetrics,
                        columns,
                      ),

                      const SizedBox(height: 28),

                      // Gerenciamento

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
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Informações

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

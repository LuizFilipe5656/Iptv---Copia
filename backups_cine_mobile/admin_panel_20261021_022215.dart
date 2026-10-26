import 'admin_users_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  void _reload() {
    _dashboard = _loadDashboard();
  }

  Future<Map<String, dynamic>> _loadDashboard() async {
    final result = await Supabase.instance.client.rpc('get_admin_dashboard');
    if (result is List && result.isNotEmpty) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    throw StateError('O Supabase nao retornou indicadores.');
  }

  void _refresh() {
    setState(_reload);
  }

  Widget _metricCard(
    String label,
    Object? value,
    IconData icon,
  ) {
    return Card(
      color: const Color(0xFF101B31),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.lightBlueAccent),
            const SizedBox(height: 12),
            Text(
              '${value ?? 0}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        title: const Text('Cine Mobile - Administracao'),
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
          if (snapshot.connectionState != ConnectionState.done) {
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
                      'Nao foi possivel carregar o Dashboard.',
                      style: TextStyle(color: Colors.white),
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
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final metrics = [
            (
              'Usuarios cadastrados',
              data['total_usuarios'],
              Icons.people,
            ),
            (
              'Contas ativas',
              data['total_ativos'],
              Icons.verified_user,
            ),
            (
              'Revendedores',
              data['total_revendedores'],
              Icons.store,
            ),
            (
              'Assinaturas vencidas',
              data['total_vencidos'],
              Icons.event_busy,
            ),
            (
              'Super administradores',
              data['total_super_admins'],
              Icons.admin_panel_settings,
            ),
            (
              'Creditos registrados',
              data['total_creditos'],
              Icons.toll,
            ),
            (
              'Creditos utilizados',
              data['total_creditos_utilizados'],
              Icons.payments,
            ),
          ];
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 550
                      ? 3
                      : 2;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visao geral',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Indicadores atualizados do Supabase.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    GridView.builder(
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
                        );
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminUsersScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.people),
                      label: const Text('Abrir gerenciamento de usuarios'),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 24),
                    const Card(
                      color: Color(0xFF101B31),
                      child: ListTile(
                        leading: Icon(
                          Icons.construction,
                          color: Colors.lightBlueAccent,
                        ),
                        title: Text(
                          'Gerenciamento de usuarios e revendedores',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Proximo modulo: cadastro, bloqueio, '
                          'renovacao e controle de creditos.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

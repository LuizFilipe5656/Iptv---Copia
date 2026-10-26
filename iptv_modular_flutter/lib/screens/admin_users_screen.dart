import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_renew_dialog.dart';
import 'admin_credits_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _users;

  @override
  void initState() {
    super.initState();

    _users = _loadUsers();

    _searchController.addListener(_updateSearch);
  }

  void _updateSearch() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final result = await Supabase.instance.client.rpc(
      'get_admin_users',
    );

    if (result is! List) {
      throw StateError('Resposta inesperada do Supabase.');
    }

    return result
        .map(
          (item) => Map<String, dynamic>.from(item as Map),
        )
        .toList();
  }

  void _refresh() {
    if (!mounted) return;

    setState(() {
      _users = _loadUsers();
    });
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';

      case 'reseller':
        return 'Revendedor';

      case 'user':
        return 'Usuário';

      default:
        return role;
    }
  }

  String _formatDate(Object? value) {
    if (value == null) {
      return 'Não definida';
    }

    final date = DateTime.tryParse(
      value.toString(),
    )?.toLocal();

    if (date == null) {
      return 'Data inválida';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // =========================================================
  // BLOQUEAR E DESBLOQUEAR USUÁRIOS
  // =========================================================

  Future<void> _changeUserStatus(
    Map<String, dynamic> user,
    String newStatus,
  ) async {
    final userId = user['id']?.toString();

    final name = (user['name'] ?? user['email'] ?? 'Usuário').toString();

    final role = (user['role'] ?? '').toString();

    if (userId == null || userId.isEmpty) {
      return;
    }

    if (role != 'user' && role != 'reseller') {
      return;
    }

    final isBlocking = newStatus == 'BANNED';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isBlocking ? 'Bloquear usuário?' : 'Desbloquear usuário?',
          ),
          content: Text(
            '${isBlocking ? "Bloquear" : "Desbloquear"} '
            'a conta de $name?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'admin_set_user_status',
        params: {
          'p_user_id': userId,
          'p_new_status': newStatus,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBlocking
                ? 'Usuário bloqueado com sucesso.'
                : 'Usuário desbloqueado com sucesso.',
          ),
        ),
      );

      _refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao alterar status: $error',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // =========================================================
  // RENOVAR ASSINATURA
  // =========================================================

  bool _promotingSuperAdmin = false;
  Future<void> _promoteSuperAdmin(
    Map<String, dynamic> user,
  ) async {
    if (_promotingSuperAdmin) return;
    final userId = user['id']?.toString();
    final role = user['role']?.toString() ?? '';
    final status = user['status']?.toString() ?? '';
    final name = (user['name'] ?? user['email'] ?? 'Usuário').toString();
    if (userId == null ||
        userId.isEmpty ||
        !['user', 'reseller'].contains(role) ||
        status != 'ACTIVE') {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tornar Super Admin?'),
        content: Text(
          'Deseja conceder acesso administrativo a $name?\n\n'
          'Essa pessoa poderá gerenciar usuários e '
          'atribuir permissões administrativas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar promoção'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _promotingSuperAdmin = true);
    try {
      await Supabase.instance.client.rpc(
        'admin_promote_super_admin',
        params: {'p_user_id': userId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name agora é Super Admin.'),
          backgroundColor: Colors.green,
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao promover usuário: $error',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _promotingSuperAdmin = false);
      }
    }
  }

  Future<void> _openRenewDialog(
    Map<String, dynamic> user,
  ) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AdminRenewDialog(
          user: user,
        );
      },
    );

    if (!mounted || updated != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Assinatura renovada com sucesso.',
        ),
      ),
    );

    _refresh();
  }

  // =========================================================
  // GERENCIAR CRÉDITOS DO REVENDEDOR
  // =========================================================

  Future<void> _openCreditsScreen(
    Map<String, dynamic> user,
  ) async {
    final role = (user['role'] ?? '').toString();

    if (role != 'reseller') {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return AdminCreditsScreen(
            reseller: user,
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    // Atualiza o saldo ao voltar para a lista.
    _refresh();
  }

  // =========================================================
  // CARD DE CADA USUÁRIO
  // =========================================================

  Widget _userCard(
    Map<String, dynamic> user,
  ) {
    final name = (user['name'] ?? '').toString().trim();

    final email = (user['email'] ?? '').toString();

    final role = (user['role'] ?? '').toString();

    final status = (user['status'] ?? '').toString();

    final plan = (user['plan'] ?? '').toString();

    final isActive = status == 'ACTIVE';

    final canManageAccount = role == 'user' || role == 'reseller';

    final isReseller = role == 'reseller';

    final canPromote = canManageAccount && isActive;

    return Card(
      color: const Color(0xFF101B31),
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome e e-mail

            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF1E88E5),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Sem nome' : name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(
              height: 24,
              color: Colors.white24,
            ),

            // Perfil e status

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    _roleLabel(role),
                  ),
                ),
                Chip(
                  avatar: Icon(
                    isActive ? Icons.check_circle : Icons.block,
                    size: 18,
                    color: isActive ? Colors.green : Colors.red,
                  ),
                  label: Text(status),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // =================================================
            // BOTÕES ADMINISTRATIVOS
            // =================================================

            if (canManageAccount)
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Renovar assinatura

                    OutlinedButton.icon(
                      onPressed: () {
                        _openRenewDialog(user);
                      },
                      icon: const Icon(
                        Icons.calendar_month,
                      ),
                      label: const Text(
                        'Renovar',
                      ),
                    ),

                    // Bloquear ou desbloquear

                    OutlinedButton.icon(
                      onPressed: () {
                        _changeUserStatus(
                          user,
                          isActive ? 'BANNED' : 'ACTIVE',
                        );
                      },
                      icon: Icon(
                        isActive ? Icons.block : Icons.lock_open,
                      ),
                      label: Text(
                        isActive ? 'Bloquear' : 'Desbloquear',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isActive ? Colors.redAccent : Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ),

            // =================================================
            // BOTÃO DE CRÉDITOS - SOMENTE REVENDEDORES
            // =================================================

            if (isReseller) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _openCreditsScreen(user);
                  },
                  icon: const Icon(
                    Icons.account_balance_wallet,
                  ),
                  label: const Text(
                    'Gerenciar créditos',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // =================================================
            // INFORMAÇÕES DO USUÁRIO
            // =================================================

            if (canPromote) ...[
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _promotingSuperAdmin
                      ? null
                      : () => _promoteSuperAdmin(user),
                  icon: const Icon(
                    Icons.admin_panel_settings,
                  ),
                  label: const Text(
                    'Tornar Super Admin',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Plano: ${plan.isEmpty ? "Não definido" : plan}',
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Vencimento: '
              '${_formatDate(user["expiration_date"])}',
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Créditos: ${user["credits"] ?? 0} | '
              'Utilizados: ${user["credits_used"] ?? 0}',
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // LIMPEZA
  // =========================================================

  @override
  void dispose() {
    _searchController.removeListener(
      _updateSearch,
    );

    _searchController.dispose();

    super.dispose();
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
          'Gerenciar Usuários',
        ),
        backgroundColor: const Color(0xFF101B31),
        actions: [
          IconButton(
            tooltip: 'Atualizar usuários',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Campo de pesquisa

          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Pesquisar nome ou e-mail',
                hintStyle: const TextStyle(
                  color: Colors.white54,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                ),
                filled: true,
                fillColor: const Color(0xFF101B31),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Lista de usuários

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _users,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Erro ao carregar usuários:\n'
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  );
                }

                final query = _searchController.text.trim().toLowerCase();

                final filtered = (snapshot.data ?? []).where(
                  (user) {
                    final name = (user['name'] ?? '').toString().toLowerCase();

                    final email =
                        (user['email'] ?? '').toString().toLowerCase();

                    return name.contains(query) || email.contains(query);
                  },
                ).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum usuário encontrado.',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    16,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _userCard(
                      filtered[index],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final result = await Supabase.instance.client.rpc('get_admin_users');
    if (result is! List) {
      throw StateError('Resposta inesperada do Supabase.');
    }
    return result
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  void _refresh() {
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
        return 'Usuario';
      default:
        return role;
    }
  }

  String _formatDate(Object? value) {
    if (value == null) return 'Nao definida';
    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return 'Data invalida';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _changeUserStatus(
    Map<String, dynamic> user,
    String newStatus,
  ) async {
    final userId = user['id']?.toString();
    final name = (user['name'] ?? user['email'] ?? 'Usuario').toString();
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
          title:
              Text(isBlocking ? 'Bloquear usuario?' : 'Desbloquear usuario?'),
          content: Text(
            '${isBlocking ? "Bloquear" : "Desbloquear"} a conta de $name?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
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
                ? 'Usuario bloqueado com sucesso.'
                : 'Usuario desbloqueado com sucesso.',
          ),
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao alterar status: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _userCard(Map<String, dynamic> user) {
    final name = (user['name'] ?? '').toString().trim();
    final email = (user['email'] ?? '').toString();
    final role = (user['role'] ?? '').toString();
    final status = (user['status'] ?? '').toString();
    final plan = (user['plan'] ?? '').toString();
    final isActive = status == 'ACTIVE';
    return Card(
      color: const Color(0xFF101B31),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF1E88E5),
                  child: Icon(Icons.person, color: Colors.white),
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
            const Divider(height: 24, color: Colors.white24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(_roleLabel(role))),
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
            if (role == 'user' || role == 'reseller')
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _changeUserStatus(
                    user,
                    isActive ? 'BANNED' : 'ACTIVE',
                  ),
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
              ),
            const SizedBox(height: 8),
            Text(
              'Plano: ${plan.isEmpty ? "Nao definido" : plan}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'Vencimento: ${_formatDate(user["expiration_date"])}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'Creditos: ${user["credits"] ?? 0} | '
              'Utilizados: ${user["credits_used"] ?? 0}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_updateSearch);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        title: const Text('Gerenciar Usuarios'),
        backgroundColor: const Color(0xFF101B31),
        actions: [
          IconButton(
            tooltip: 'Atualizar usuarios',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Pesquisar nome ou e-mail',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFF101B31),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
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
                        'Erro ao carregar usuarios:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                }
                final query = _searchController.text.trim().toLowerCase();
                final filtered = snapshot.data!.where((user) {
                  final name = (user['name'] ?? '').toString().toLowerCase();
                  final email = (user['email'] ?? '').toString().toLowerCase();
                  return name.contains(query) || email.contains(query);
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum usuario encontrado.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _userCard(filtered[index]);
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

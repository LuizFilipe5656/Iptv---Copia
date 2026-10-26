import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _emailController = TextEditingController();
  String _selectedRole = 'admin';
  String _statusMessage = '';

  Future<void> _assignRole() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _statusMessage = 'Digite um e-mail válido.');
      return;
    }

    try {
      await AuthService.setUserRole(email, _selectedRole);
      setState(() {
        _statusMessage = 'Cargo "$_selectedRole" atribuído com sucesso para $email!';
        _emailController.clear();
      });
    } catch (e) {
      setState(() => _statusMessage = 'Erro ao atribuir cargo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        title: const Text('Painel Administrativo (Master Admin)'),
        backgroundColor: const Color(0xFF101B31),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gerenciamento de Cargos e Permissões',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Atribua cargos administrativos ou de revendedor para os usuários cadastrados no sistema.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF101B31),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Atribuir Cargo a Usuário',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'E-mail do Usuário',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF050B18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Selecione o Cargo:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    dropdownColor: const Color(0xFF101B31),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF050B18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'master_admin', child: Text('Master Admin')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'reseller', child: Text('Revendedor (Reseller)')),
                      DropdownMenuItem(value: 'user', child: Text('Usuário Comum')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedRole = value);
                    },
                  ),
                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _statusMessage.contains('sucesso') ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _assignRole,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Salvar Alteração de Cargo', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

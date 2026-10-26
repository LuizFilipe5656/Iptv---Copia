import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';

class AdminCreateUserScreen extends StatefulWidget {
  const AdminCreateUserScreen({super.key});

  @override
  State<AdminCreateUserScreen> createState() =>
      _AdminCreateUserScreenState();
}

class _AdminCreateUserScreenState
    extends State<AdminCreateUserScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  String _role = 'user';
  String _plan = 'FREE';
  DateTime? _expirationDate;
  bool _showPassword = false;
  bool _saving = false;
  String? _error;

  Future<void> _createAccount() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_expirationDate == null) {
      setState(() => _error = 'Selecione o vencimento.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-account',
        body: {
          'name': _name.text.trim(),
          'username': _username.text.trim().toLowerCase(),
          'email': _email.text.trim().toLowerCase(),
          'password': _password.text,
          'role': _role,
          'plan': _plan,
          'expiration_date': DateTime.utc(
            _expirationDate!.year, _expirationDate!.month,
            _expirationDate!.day, 23, 59, 59,
          ).toIso8601String(),
        },
      );
      if (response.status != 201) {
        final data = response.data;
        throw Exception(data is Map ? (data['error'] ?? 'Erro ao cadastrar conta.') : 'Erro ao cadastrar conta.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta criada com sucesso!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _expirationDate = selected;
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      appBar: AppBar(
        title: const Text('Cadastrar conta'),
        backgroundColor: const Color(0xFF101B31),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              color: const Color(0xFF101B31),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.person_add,
                        size: 48,
                        color: Colors.lightBlueAccent,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Novo cliente ou revendedor',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _name,
                        decoration: _decoration(
                          'Nome completo',
                          Icons.person,
                        ),
                        validator: (value) {
                          if ((value?.trim().length ?? 0) < 2) {
                            return 'Informe o nome';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _username,
                        decoration: _decoration(
                          'Nome de usuário',
                          Icons.alternate_email,
                        ),
                        validator: (value) {
                          if (!RegExp(
                            r'^[a-zA-Z0-9_]{3,30}$',
                          ).hasMatch(value?.trim() ?? '')) {
                            return 'Use 3 a 30 letras, números ou _';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _decoration(
                          'E-mail',
                          Icons.email,
                        ),
                        validator: (value) {
                          if (!RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(value?.trim() ?? '')) {
                            return 'Informe um e-mail válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        decoration: _decoration(
                          'Senha inicial',
                          Icons.lock,
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if ((value?.length ?? 0) < 8) {
                            return 'Mínimo de 8 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _role,
                        decoration: _decoration(
                          'Cargo',
                          Icons.admin_panel_settings,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'user',
                            child: Text('Cliente'),
                          ),
                          DropdownMenuItem(
                            value: 'reseller',
                            child: Text('Revendedor'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _role = value);
                        },
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _plan,
                        decoration: _decoration(
                          'Plano',
                          Icons.workspace_premium,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'FREE',
                            child: Text('FREE'),
                          ),
                          DropdownMenuItem(
                            value: 'PREMIUM',
                            child: Text('PREMIUM'),
                          ),
                          DropdownMenuItem(
                            value: 'DIAMANTE',
                            child: Text('DIAMANTE'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _plan = value);
                        },
                      ),
                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          _expirationDate == null
                              ? 'Selecionar vencimento'
                              : 'Vencimento: ${_formatDate(_expirationDate!)}',
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _createAccount,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.person_add),
                        label: Text(_saving ? 'Criando conta...' : 'Criar conta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

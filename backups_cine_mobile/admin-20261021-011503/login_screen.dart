import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.cinemetaService,
    required this.addonRepository,
    required this.catalogRepository,
    required this.streamRepository,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.themeLoaded,
  });

  final dynamic cinemetaService;
  final dynamic addonRepository;
  final dynamic catalogRepository;
  final dynamic streamRepository;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeModeChanged;
  final bool themeLoaded;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Preencha o e-mail e a senha.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await AuthService.login(email, password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            cinemetaService: widget.cinemetaService,
            addonRepository: widget.addonRepository,
            catalogRepository: widget.catalogRepository,
            streamRepository: widget.streamRepository,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
            themeLoaded: widget.themeLoaded,
          ),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRegisterDialog() {
    final regEmailController = TextEditingController();
    final regPassController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101B31),
        title: const Text('Registrar Conta', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: regEmailController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'E-mail', labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: regPassController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Senha', labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await AuthService.register(regEmailController.text.trim(), regPassController.text.trim());
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Conta registrada com sucesso! Faça login.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                );
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final recEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101B31),
        title: const Text('Esqueci minha senha', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: recEmailController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'E-mail cadastrado', labelStyle: TextStyle(color: Colors.white70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await AuthService.forgotPassword(recEmailController.text.trim());
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('E-mail de recuperação enviado com sucesso!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B18),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF1E88E5),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/cine_mobile_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Cine Mobile Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Faça login para acessar o sistema. O login é obrigatório no primeiro acesso e após atualizações do aplicativo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF101B31),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF101B31),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Entrar',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _showRegisterDialog,
                        child: const Text('Registrar conta', style: TextStyle(color: Color(0xFF29B6F6))),
                      ),
                      TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text('Esqueci minha senha', style: TextStyle(color: Color(0xFF29B6F6))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

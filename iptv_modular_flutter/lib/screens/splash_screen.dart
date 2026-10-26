import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
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
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final forceLogin = await AuthService.shouldForceLogin();

    if (!mounted) return;

    // Verificar se usuário está ativo no Supabase (se for admin)
    if (!forceLogin) {
      final permissionService = context.read<PermissionService>();
      await permissionService.refresh();

      // Se usuário era admin mas foi desativado, forçar logout
      if (permissionService.isAdmin && !permissionService.isUserActive) {
        await AuthService.logout();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoginScreen(
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
        return;
      }
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => forceLogin
            ? LoginScreen(
                cinemetaService: widget.cinemetaService,
                addonRepository: widget.addonRepository,
                catalogRepository: widget.catalogRepository,
                streamRepository: widget.streamRepository,
                themeMode: widget.themeMode,
                onThemeModeChanged: widget.onThemeModeChanged,
                themeLoaded: widget.themeLoaded,
              )
            : HomeScreen(
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final fade = Curves.easeOutCubic.transform(
          (_controller.value).clamp(0.0, 1.0),
        );
        final lift = (1 - fade) * 24;

        return Scaffold(
          backgroundColor: const Color(0xFF050B18),
          body: SafeArea(
            child: Center(
              child: Transform.translate(
                offset: Offset(0, lift),
                child: Opacity(
                  opacity: fade,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF1E88E5),
                              blurRadius: 22,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/cine_mobile_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Cine Mobile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF29B6F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

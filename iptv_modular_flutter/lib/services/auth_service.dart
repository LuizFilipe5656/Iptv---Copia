
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const String _keyLastVersion = 'last_login_app_version';

  static Future<String> _getAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  // Verifica se precisa solicitar login novamente.
  static Future<bool> shouldForceLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final currentVersion = await _getAppVersion();
    final savedVersion = prefs.getString(_keyLastVersion);

    if (savedVersion != currentVersion) {
      await logout();
      return true;
    }

    if (_client.auth.currentSession == null) {
      return true;
    }

    try {
      await validateCurrentUser();
      return false;
    } catch (_) {
      await logout();
      return true;
    }
  }

  // Consulta o perfil real do usuário no Supabase.
  static Future<Map<String, dynamic>> validateCurrentUser() async {
    final user = _client.auth.currentUser;

    if (user == null || _client.auth.currentSession == null) {
      throw Exception('Sessão expirada. Faça login novamente.');
    }

    final Map<String, dynamic>? profile;

    try {
      profile = await _client
          .from('users')
          .select(
            'id, name, email, role, status, plan, expiration_date',
          )
          .eq('id', user.id)
          .maybeSingle();
    } on PostgrestException {
      throw Exception(
        'Não foi possível verificar sua conta. '
        'Confira a conexão ou entre em contato com o suporte.',
      );
    }

    if (profile == null) {
      throw Exception(
        'Conta não encontrada ou sem permissão de consulta.',
      );
    }

    final role =
        profile['role']?.toString().trim().toLowerCase() ?? '';

    final status =
        profile['status']?.toString().trim().toUpperCase() ?? '';

    if (status != 'ACTIVE') {
      throw Exception(
        'Sua conta está desativada. Entre em contato com o suporte.',
      );
    }

    if (role == 'user') {
      final rawDate = profile['expiration_date']?.toString();
      final expirationDate =
          rawDate == null ? null : DateTime.tryParse(rawDate);

      if (expirationDate == null) {
        throw Exception(
          'Não foi possível identificar a validade da assinatura.',
        );
      }

      if (!expirationDate
          .toUtc()
          .isAfter(DateTime.now().toUtc())) {
        throw Exception(
          'Sua assinatura está vencida. '
          'Entre em contato com seu revendedor para renovar.',
        );
      }
    } else if (role != 'admin' &&
        role != 'master_admin' &&
        role != 'super_admin' &&
        role != 'reseller') {
      throw Exception(
        'Este perfil não está autorizado a acessar o aplicativo.',
      );
    }

    return profile;
  }

  // Login por nome de usuário. O e-mail não é consultado pelo aplicativo.
  // A Edge Function autentica as credenciais no Supabase Auth e devolve
  // apenas o refresh token para estabelecer a sessão oficial no cliente.
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final normalizedUsername = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.-]{3,40}$').hasMatch(normalizedUsername) ||
        password.isEmpty) {
      throw Exception('Informe um usuário válido e sua senha.');
    }

    try {
      final response = await _client.functions.invoke(
        'login-username',
        body: {'username': normalizedUsername, 'password': password},
      );
      if (response.status != 200 || response.data is! Map) {
        throw Exception('Usuário ou senha inválidos, ou limite de tentativas atingido.');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      final refreshToken = data['refresh_token'];
      if (refreshToken is! String || refreshToken.isEmpty) {
        throw Exception('Não foi possível iniciar a sessão.');
      }
      final session = await _client.auth.setSession(refreshToken);
      if (session.user == null || session.session == null) {
        throw Exception('Não foi possível iniciar a sessão.');
      }
      try {
        final profile = await validateCurrentUser();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyLastVersion, await _getAppVersion());
        return profile;
      } catch (_) {
        await logout();
        rethrow;
      }
    } on FunctionException {
      throw Exception('Usuário ou senha inválidos, ou limite de tentativas atingido.');
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Retorna o cargo registrado no banco.
  static Future<String> getCurrentUserRole() async {
    final profile = await validateCurrentUser();
    return profile['role']?.toString() ?? 'user';
  }

  // Cadastro exclusivo pelo painel administrativo.
  static Future<void> register(
    String email,
    String password,
  ) async {
    throw Exception(
      'Novas contas devem ser criadas pelo painel administrativo.',
    );
  }

  // Recuperação de senha.
  static Future<void> forgotPassword(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw Exception('Informe seu e-mail.');
    }

    try {
      await _client.auth.resetPasswordForEmail(normalizedEmail);
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // Cargos não podem ser alterados pelo celular.
  static Future<void> setUserRole(
    String email,
    String newRole,
  ) async {
    throw Exception(
      'Permissões devem ser alteradas pelo painel administrativo.',
    );
  }

  // Encerra a sessão.
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_keyLastVersion);

    // Limpa os dados usados pelo login antigo.
    await prefs.remove('is_logged_in');
    await prefs.remove('user_email');
    await prefs.remove('user_role');

    await _client.auth.signOut();
  }
}

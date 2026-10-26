import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_service.dart';
import '../config/supabase_config.dart';

class PermissionService extends ChangeNotifier {
  final AdminService _adminService = AdminService();
  Map<String, dynamic>? _currentAdmin;
  List<String> _permissions = [];
  String _role = '';
  bool _isActive = false;
  StreamSubscription? _adminSubscription;

  // Getters
  Map<String, dynamic>? get currentAdmin => _currentAdmin;
  List<String> get permissions => _permissions;
  String get role => _role;
  bool get isActive => _isActive;
  bool get isAdmin => _currentAdmin != null;

  // ============================================
  // INICIALIZAR SERVIÇO
  // ============================================
  Future<void> initialize() async {
    final admin = await _adminService.getCurrentAdmin();
    if (admin != null) {
      _updateAdminData(admin);
      _subscribeToAdminChanges();
    }
  }

  // ============================================
  // ATUALIZAR DADOS DO ADMIN
  // ============================================
  void _updateAdminData(Map<String, dynamic> admin) {
    _currentAdmin = admin;
    _role = admin['role'] as String? ?? '';
    _isActive = admin['is_active'] as bool? ?? false;
    _permissions = (admin['permissions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    notifyListeners();
  }

  // ============================================
  // ESCUTAR MUDANÇAS EM TEMPO REAL
  // ============================================
  void _subscribeToAdminChanges() {
    _adminSubscription?.cancel();
    _adminSubscription = _adminService.streamCurrentAdmin().listen((admin) {
      if (admin != null) {
        _updateAdminData(admin);
      } else {
        // Admin foi deletado ou desativado
        _currentAdmin = null;
        _permissions = [];
        _role = '';
        _isActive = false;
        notifyListeners();
      }
    });
  }

  // ============================================
  // VERIFICAR SE TEM PERMISSÃO ESPECÍFICA
  // ============================================
  bool hasPermission(String permission) {
    // Super admin tem todas as permissões
    if (_role == SupabaseConfig.roleSuperAdmin) {
      return true;
    }

    return _permissions.contains(permission);
  }

  // ============================================
  // VERIFICAR SE TEM ALGUMA DAS PERMISSÕES
  // ============================================
  bool hasAnyPermission(List<String> permissions) {
    if (_role == SupabaseConfig.roleSuperAdmin) {
      return true;
    }

    return permissions.any((perm) => _permissions.contains(perm));
  }

  // ============================================
  // VERIFICAR SE TEM TODAS AS PERMISSÕES
  // ============================================
  bool hasAllPermissions(List<String> permissions) {
    if (_role == SupabaseConfig.roleSuperAdmin) {
      return true;
    }

    return permissions.every((perm) => _permissions.contains(perm));
  }

  // ============================================
  // VERIFICAR SE TEM ROLE ESPECÍFICO
  // ============================================
  bool hasRole(String role) {
    return _role == role;
  }

  // ============================================
  // VERIFICAR SE ESTÁ ATIVO
  // ============================================
  bool get isUserActive => _isActive;

  // ============================================
  // FORÇAR RECARREGAMENTO DE DADOS
  // ============================================
  Future<void> refresh() async {
    final admin = await _adminService.getCurrentAdmin();
    if (admin != null) {
      _updateAdminData(admin);
    }
  }

  // ============================================
  // LIMPAR RECURSOS
  // ============================================
  @override
  void dispose() {
    _adminSubscription?.cancel();
    super.dispose();
  }

  // ============================================
  // VERIFICAR SE PODE ACESSAR ÁREA DE ADMIN
  // ============================================
  bool get canAccessAdminPanel {
    return _isActive && (
      _role == SupabaseConfig.roleSuperAdmin ||
      _role == SupabaseConfig.roleAdmin ||
      hasPermission(SupabaseConfig.permissionAdminTotal)
    );
  }

  // ============================================
  // VERIFICAR SE PODE BLOQUEAR USUÁRIO
  // ============================================
  bool get canBlockUser {
    return _isActive && hasPermission(SupabaseConfig.permissionBloquearUsuario);
  }

  // ============================================
  // VERIFICAR SE PODE GERENCIAR ADMINS
  // ============================================
  bool get canManageAdmins {
    return _isActive && hasPermission(SupabaseConfig.permissionGerenciarAdmins);
  }

  // ============================================
  // VERIFICAR SE PODE GERENCIAR FINANCEIRO
  // ============================================
  bool get canManageFinance {
    return _isActive && hasPermission(SupabaseConfig.permissionGerenciarFinanceiro);
  }

  // ============================================
  // VERIFICAR SE PODE GERENCIAR SUPORTE
  // ============================================
  bool get canManageSupport {
    return _isActive && hasPermission(SupabaseConfig.permissionGerenciarSuporte);
  }
}

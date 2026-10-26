class SupabaseConfig {
  static const String supabaseUrl = 'https://ewiyubfwxyztvzbldqlq.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_gCS_QOv2acwDb-LWlCNtjg_JDly-2ik';

  // Permissões disponíveis no sistema
  static const String permissionAcessoBasico = 'app.acesso_basico';
  static const String permissionAdminTotal = 'app.admin_total';
  static const String permissionBloquearUsuario = 'app.bloquear_usuario';
  static const String permissionGerenciarAdmins = 'app.gerenciar_admins';
  static const String permissionGerenciarFinanceiro = 'app.gerenciar_financeiro';
  static const String permissionGerenciarSuporte = 'app.gerenciar_suporte';

  // Roles disponíveis
  static const String roleSuperAdmin = 'super_admin';
  static const String roleAdmin = 'admin';
  static const String roleSuporte = 'suporte';
  static const String roleFinanceiro = 'financeiro';

  // Lista de permissões por role (padrão)
  static Map<String, List<String>> get defaultPermissionsByRole => {
        roleSuperAdmin: [
          permissionAcessoBasico,
          permissionAdminTotal,
          permissionBloquearUsuario,
          permissionGerenciarAdmins,
          permissionGerenciarFinanceiro,
          permissionGerenciarSuporte,
        ],
        roleAdmin: [
          permissionAcessoBasico,
          permissionAdminTotal,
          permissionBloquearUsuario,
        ],
        roleSuporte: [
          permissionAcessoBasico,
          permissionGerenciarSuporte,
        ],
        roleFinanceiro: [
          permissionAcessoBasico,
          permissionGerenciarFinanceiro,
        ],
      };
}

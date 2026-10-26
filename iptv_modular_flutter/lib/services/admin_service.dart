import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AdminService {
  final SupabaseClient _client = Supabase.instance.client;

  // ============================================
  // CRIAR ADMIN VIA EDGE FUNCTION
  // ============================================
  Future<Map<String, dynamic>> createAdmin({
    required String email,
    required String password,
    required String name,
    required String role,
    List<String>? permissions,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-admin',
        body: {
          'email': email,
          'password': password,
          'name': name,
          'role': role,
          'permissions': permissions ?? SupabaseConfig.defaultPermissionsByRole[role],
        },
      );

      if (response.status != 200) {
        throw Exception('Erro ao criar admin: ${response.data?.toString() ?? 'Erro desconhecido'}');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Erro ao criar admin: $e');
    }
  }

  // ============================================
  // LISTAR ADMINS EM TEMPO REAL
  // ============================================
  Stream<List<Map<String, dynamic>>> streamAdmins() {
    return _client
        .from('admins')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  // ============================================
  // OBTER ADMIN POR ID
  // ============================================
  Future<Map<String, dynamic>?> getAdminById(String adminId) async {
    try {
      final response = await _client
          .from('admins')
          .select()
          .eq('id', adminId)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Erro ao buscar admin: $e');
    }
  }

  // ============================================
  // OBTER PRÓPRIO REGISTRO DE ADMIN
  // ============================================
  Future<Map<String, dynamic>?> getCurrentAdmin() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('admins')
          .select()
          .eq('id', userId)
          .eq('is_active', true)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Erro ao buscar admin atual: $e');
    }
  }

  // ============================================
  // ATUALIZAR ROLE E PERMISSÕES
  // ============================================
  Future<void> updateRole({
    required String adminId,
    required String newRole,
    List<String>? newPermissions,
  }) async {
    try {
      final permissions = newPermissions ?? SupabaseConfig.defaultPermissionsByRole[newRole];

      final error = await _client
          .from('admins')
          .update({
            'role': newRole,
            'permissions': permissions,
          })
          .eq('id', adminId);

      if (error != null) {
        throw Exception('Erro ao atualizar role: ${error.message}');
      }
    } catch (e) {
      throw Exception('Erro ao atualizar role: $e');
    }
  }

  // ============================================
  // ATUALIZAR APENAS PERMISSÕES
  // ============================================
  Future<void> updatePermissions({
    required String adminId,
    required List<String> newPermissions,
  }) async {
    try {
      final error = await _client
          .from('admins')
          .update({
            'permissions': newPermissions,
          })
          .eq('id', adminId);

      if (error != null) {
        throw Exception('Erro ao atualizar permissões: ${error.message}');
      }
    } catch (e) {
      throw Exception('Erro ao atualizar permissões: $e');
    }
  }

  // ============================================
  // ATIVAR/DESATIVAR ADMIN
  // ============================================
  Future<void> toggleActive({
    required String adminId,
    required bool isActive,
  }) async {
    try {
      final error = await _client
          .from('admins')
          .update({
            'is_active': isActive,
          })
          .eq('id', adminId);

      if (error != null) {
        throw Exception('Erro ao atualizar status: ${error.message}');
      }
    } catch (e) {
      throw Exception('Erro ao atualizar status: $e');
    }
  }

  // ============================================
  // DELETAR ADMIN
  // ============================================
  Future<void> deleteAdmin(String adminId) async {
    try {
      // Primeiro deleta da tabela admins
      final adminError = await _client
          .from('admins')
          .delete()
          .eq('id', adminId);

      if (adminError != null) {
        throw Exception('Erro ao deletar admin: ${adminError.message}');
      }

      // Depois deleta do auth.users (via Edge Function ou admin service role)
      // Nota: Isso requer que você tenha uma Edge Function para deletar usuário do auth
      // ou use service_role key no backend
      await _client.functions.invoke('delete-user', body: {'userId': adminId});
    } catch (e) {
      throw Exception('Erro ao deletar admin: $e');
    }
  }

  // ============================================
  // ESCUTAR MUDANÇAS DO PRÓPRIO ADMIN EM TEMPO REAL
  // ============================================
  Stream<Map<String, dynamic>?> streamCurrentAdmin() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value(null);
    }

    return _client
        .from('admins')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  // ============================================
  // VERIFICAR SE USUÁRIO É ADMIN
  // ============================================
  Future<bool> isAdmin(String userId) async {
    try {
      final response = await _client
          .from('admins')
          .select('id')
          .eq('id', userId)
          .eq('is_active', true)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // LISTAR ADMINS POR ROLE
  // ============================================
  Future<List<Map<String, dynamic>>> getAdminsByRole(String role) async {
    try {
      final response = await _client
          .from('admins')
          .select()
          .eq('role', role)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return response as List<Map<String, dynamic>>;
    } catch (e) {
      throw Exception('Erro ao buscar admins por role: $e');
    }
  }
}

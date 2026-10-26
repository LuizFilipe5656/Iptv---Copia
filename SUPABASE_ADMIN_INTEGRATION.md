# Integração Supabase - Sistema de Admins

Este documento descreve como configurar e usar o sistema de gerenciamento de admins vinculado ao Supabase.

## 📋 Visão Geral

O sistema permite gerenciar administradores do app Flutter via painel Next.js, com sincronização em tempo real. Todas as alterações feitas no painel admin são refletidas instantaneamente no app do usuário final.

## 🗄️ Passo 1: Configurar Banco de Dados Supabase

### 1.1 Executar o SQL

No painel do Supabase, vá em **SQL Editor** e execute o arquivo `supabase_admins_setup.sql`:

```bash
# Copie o conteúdo do arquivo e cole no SQL Editor do Supabase
```

Isso criará:
- Tabela `public.admins` com RLS habilitado
- Triggers automáticos para criar registros quando usuário é criado
- Políticas de segurança para que apenas super_admins possam gerenciar outros admins
- Funções auxiliares para verificar permissões

### 1.2 Verificar Edge Function `create-admin`

A Edge Function `create-admin` já deve estar implantada. Verifique se está com:
- ✅ Verify JWT with legacy secret = ON (verde)

Se não existir, crie a função:

```typescript
// supabase/functions/create-admin/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  try {
    const { email, password, name, role, permissions } = await req.json()

    // Criar usuário no auth
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    const { data: { user }, error: authError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name, role, permissions }
    })

    if (authError) throw authError

    // O trigger handle_new_user criará o registro na tabela admins automaticamente
    return new Response(
      JSON.stringify({ success: true, user }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

### 1.3 Criar Edge Function `delete-user`

Crie a Edge Function para deletar usuários:

```bash
cd cine-mobile-admin
supabase functions deploy delete-user
```

O código já está em `cine-mobile-admin/supabase/functions/delete-user/index.ts`

## 📱 Passo 2: Configurar App Flutter

### 2.1 Instalar dependências

```bash
cd iptv_modular_flutter
flutter pub get
```

### 2.2 Configurar Supabase

O arquivo `lib/config/supabase_config.dart` já está configurado com suas credenciais.

### 2.3 Arquivos criados

- `lib/config/supabase_config.dart` - Configurações e constantes
- `lib/services/admin_service.dart` - Serviço para gerenciar admins
- `lib/services/permission_service.dart` - Serviço para verificar permissões
- `lib/widgets/permission_guard.dart` - Widgets para proteger UI por permissão

### 2.4 Alterações feitas

- `pubspec.yaml` - Adicionado `supabase_flutter: ^2.5.0`
- `lib/main.dart` - Inicialização do Supabase e PermissionService
- `lib/screens/settings_screen.dart` - Painel admin protegido por permissão
- `lib/screens/splash_screen.dart` - Verificação de status do admin em tempo real

## 🖥️ Passo 3: Configurar Painel Admin Next.js

### 3.1 Instalar dependências

```bash
cd cine-mobile-admin
npm install
```

### 3.2 Adicionar componentes UI

Os seguintes componentes foram criados:
- `src/components/ui/select.tsx` - Componente Select
- `src/components/ui/checkbox.tsx` - Componente Checkbox

### 3.3 Nova página de gerenciamento

A página `/admin/admins` foi criada em `src/app/admin/admins/page.tsx`

### 3.4 Link no painel principal

O botão "Gerenciar Admins" foi adicionado na página `/admin`

## 🚀 Passo 4: Como Usar

### 4.1 Criar o primeiro Super Admin

No painel do Supabase, você pode criar o primeiro super admin via SQL:

```sql
-- Depois de executar o setup.sql, crie o primeiro admin
-- Isso deve ser feito via Edge Function ou manualmente no painel
```

Ou use a Edge Function diretamente:

```typescript
const { data, error } = await supabase.functions.invoke('create-admin', {
  body: {
    email: 'admin@seudominio.com',
    password: 'senha_segura',
    name: 'Super Admin',
    role: 'super_admin',
    permissions: ['app.admin_total', 'app.bloquear_usuario', 'app.gerenciar_admins']
  }
})
```

### 4.2 Gerenciar Admins via Painel

1. Acesse o painel admin: `http://localhost:3000/admin`
2. Clique em "Gerenciar Admins"
3. Clique em "Novo Admin" para criar um novo administrador
4. Preencha email, senha, nome, cargo e permissões
5. Clique em "Criar Admin"

### 4.3 Editar Permissões

1. Na lista de admins, clique no ícone de escudo
2. Altere o cargo e/ou permissões
3. Clique em "Salvar Alterações"

### 4.4 Ativar/Desativar Admin

1. Clique no ícone de energia (Power/PowerOff)
2. O admin será ativado/desativado instantaneamente
3. No app Flutter, o usuário será deslogado automaticamente se for desativado

### 4.5 Deletar Admin

1. Clique no ícone de lixeira
2. Confirme a ação
3. O admin será deletado do auth e da tabela admins

## 🔐 Sistema de Permissões

### Permissões disponíveis

- `app.acesso_basico` - Acesso básico ao app
- `app.admin_total` - Acesso total ao painel admin
- `app.bloquear_usuario` - Pode bloquear/desbloquear usuários
- `app.gerenciar_admins` - Pode gerenciar outros admins
- `app.gerenciar_financeiro` - Acesso ao módulo financeiro
- `app.gerenciar_suporte` - Acesso ao módulo de suporte

### Roles e permissões padrão

| Role | Permissões Padrão |
|------|------------------|
| super_admin | Todas as permissões |
| admin | acesso_basico, admin_total, bloquear_usuario |
| suporte | acesso_basico, gerenciar_suporte |
| financeiro | acesso_basico, gerenciar_financeiro |

## 📱 No App Flutter

### Usar PermissionGuard

```dart
import '../widgets/permission_guard.dart';
import '../config/supabase_config.dart';

// Só mostra o botão se tiver permissão
PermissionGuard(
  permission: SupabaseConfig.permissionBloquearUsuario,
  child: ElevatedButton(
    onPressed: () => bloquearUsuario(),
    child: Text('Bloquear Usuário'),
  ),
)

// Verifica múltiplas permissões (todas)
AllPermissionsGuard(
  permissions: [
    SupabaseConfig.permissionAdminTotal,
    SupabaseConfig.permissionGerenciarAdmins,
  ],
  child: AdminPanel(),
)

// Verifica se tem alguma das permissões
AnyPermissionGuard(
  permissions: [
    SupabaseConfig.permissionGerenciarFinanceiro,
    SupabaseConfig.permissionGerenciarSuporte,
  ],
  child: SettingsButton(),
)

// Verifica role
RoleGuard(
  role: SupabaseConfig.roleSuperAdmin,
  child: SuperAdminPanel(),
)

// Verifica se usuário está ativo
ActiveUserGuard(
  onInactive: () => logout(),
  child: ProtectedContent(),
)
```

### Verificar permissões no código

```dart
final permissionService = context.read<PermissionService>();

if (permissionService.hasPermission('app.bloquear_usuario')) {
  // Usuário pode bloquear
}

if (permissionService.canAccessAdminPanel) {
  // Usuário pode acessar painel admin
}

if (permissionService.isAdmin) {
  // Usuário é admin
}
```

## 🔄 Sincronização em Tempo Real

O sistema usa recursos de real-time do Supabase:

1. **Painel Next.js**: Subscribe a mudanças na tabela `admins` via PostgreSQL changes
2. **App Flutter**: Stream de dados do próprio admin via `streamCurrentAdmin()`
3. **Deslog automático**: Se `is_active` mudar para `false`, o app detecta e desloga o usuário

## ⚠️ Notas Importantes

1. **Nunca use service_role key no app Flutter** - Use apenas anon_key
2. **Edge Functions são necessárias** para criar/deletar usuários no auth
3. **RLS é essencial** para segurança - As políticas estão configuradas
4. **Super admin não pode ser deletado** por outros admins (verificação no código)
5. **Master admin local** (no auth_service.dart) ainda funciona para bypass

## 🐛 Troubleshooting

### Erro: "Admin não encontrado no Supabase"

- Verifique se o SQL foi executado corretamente
- Verifique se o trigger `handle_new_user` está funcionando
- Verifique se o usuário existe em `auth.users`

### Permissões não funcionando

- Verifique se o `PermissionService` foi inicializado no `main.dart`
- Verifique se o usuário está logado no Supabase
- Verifique se `is_active` está `true` na tabela `admins`

### Painel admin não aparece

- Verifique se o usuário tem a permissão `app.admin_total`
- Verifique se o usuário está ativo na tabela `admins`
- Verifique se o `PermissionGuard` está sendo usado corretamente

## 📞 Suporte

Para mais informações, consulte:
- Documentação Supabase: https://supabase.com/docs
- Documentação supabase_flutter: https://supabase.com/docs/guides/auth/flutter

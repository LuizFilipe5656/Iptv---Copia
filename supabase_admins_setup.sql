-- ============================================
-- SETUP DA TABELA ADMINS NO SUPABASE
-- ============================================

-- Criar a tabela public.admins
CREATE TABLE IF NOT EXISTS public.admins (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    name TEXT,
    role TEXT NOT NULL CHECK (role IN ('super_admin', 'admin', 'suporte', 'financeiro')) DEFAULT 'admin',
    permissions TEXT[] DEFAULT ARRAY[]::TEXT[],
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_admins_email ON public.admins(email);
CREATE INDEX IF NOT EXISTS idx_admins_role ON public.admins(role);
CREATE INDEX IF NOT EXISTS idx_admins_is_active ON public.admins(is_active);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER admins_updated_at
    BEFORE UPDATE ON public.admins
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- ============================================
-- POLÍTICAS RLS (ROW LEVEL SECURITY)
-- ============================================

-- Habilitar RLS
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;

-- Política: Qualquer usuário autenticado pode ler seu próprio registro
CREATE POLICY "Users can view own admin record"
    ON public.admins
    FOR SELECT
    USING (auth.uid() = id);

-- Política: Super admin pode ler todos os registros
CREATE POLICY "Super admin can view all admins"
    ON public.admins
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE id = auth.uid() AND role = 'super_admin' AND is_active = true
        )
    );

-- Política: Super admin pode inserir novos admins
CREATE POLICY "Super admin can insert admins"
    ON public.admins
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE id = auth.uid() AND role = 'super_admin' AND is_active = true
        )
    );

-- Política: Super admin pode atualizar admins
CREATE POLICY "Super admin can update admins"
    ON public.admins
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE id = auth.uid() AND role = 'super_admin' AND is_active = true
        )
    );

-- Política: Super admin pode deletar admins
CREATE POLICY "Super admin can delete admins"
    ON public.admins
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE id = auth.uid() AND role = 'super_admin' AND is_active = true
        )
    );

-- ============================================
-- TRIGGER PARA CRIAR REGISTRO NO CADASTRO
-- ============================================

-- Função para criar registro na tabela admins quando usuário é criado no auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.admins (id, email, name, role, permissions, is_active)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', 'Admin'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'admin'),
        COALESCE(NEW.raw_user_meta_data->>'permissions', ARRAY[]::TEXT[]),
        true
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger que chama a função quando um usuário é criado
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- DADOS INICIAIS (Opcional - para teste)
-- ============================================

-- Nota: O super admin inicial deve ser criado via Edge Function create-admin
-- Exemplo de como usar a Edge Function:
-- supabase.functions.invoke('create-admin', {
--   body: {
--     email: 'admin@seudominio.com',
--     password: 'senha_segura',
--     name: 'Super Admin',
--     role: 'super_admin',
--     permissions: ['app.admin_total', 'app.bloquear_usuario', 'app.gerenciar_admins']
--   }
-- })

-- ============================================
-- FUNÇÕES AUXILIARES
-- ============================================

-- Função para verificar se usuário tem permissão específica
CREATE OR REPLACE FUNCTION public.has_permission(user_id UUID, permission TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.admins
        WHERE id = user_id
        AND is_active = true
        AND permission = ANY(permissions)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para verificar role do usuário
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT role FROM public.admins
        WHERE id = user_id AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

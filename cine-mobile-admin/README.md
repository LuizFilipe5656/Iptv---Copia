# Cine Mobile Admin

Painel administrativo completo para gerenciamento de usuários, revendedores e créditos do Cine Mobile.

## Stack Tecnológica

- **Next.js 14** - App Router
- **TypeScript** - Tipagem estática
- **Tailwind CSS** - Estilização
- **Shadcn UI** - Componentes UI
- **Supabase** - Backend e autenticação
- **Lucide React** - Ícones
- **React Hook Form** - Formulários
- **Zod** - Validação
- **Context API** - Gerenciamento de estado

## Configuração

### 1. Instalar dependências

```bash
npm install
```

### 2. Configurar Supabase

1. Crie um projeto no [Supabase](https://supabase.com)
2. Copie a URL e a ANON KEY
3. Crie o arquivo `.env.local` com:

```env
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url_here
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

### 3. Executar SQL no Supabase

Execute o arquivo `supabase.sql` no SQL Editor do Supabase para criar a tabela `users` e configurar as políticas RLS.

### 4. Criar primeiro admin

Após configurar o Supabase, você precisará criar o primeiro usuário admin manualmente no SQL Editor:

```sql
-- Criar usuário admin
INSERT INTO public.users (id, email, name, role, status, credits)
VALUES (
  'your-user-id-from-auth',
  'admin@cine-mobile.com',
  'Admin',
  'admin',
  'ACTIVE',
  999999
);
```

Ou você pode registrar um usuário normal e depois atualizar o role para 'admin' no painel.

## Executar o projeto

```bash
npm run dev
```

Acesse `http://localhost:3000`

## Estrutura do Projeto

```
cine-mobile-admin/
├── src/
│   ├── app/
│   │   ├── admin/          # Painel administrativo
│   │   ├── reseller/       # Painel revendedor
│   │   ├── login/          # Página de login
│   │   ├── register/       # Página de registro
│   │   ├── layout.tsx      # Layout principal
│   │   ├── page.tsx        # Página inicial
│   │   └── globals.css     # Estilos globais
│   ├── components/
│   │   ├── ui/             # Componentes Shadcn UI
│   │   ├── layout/         # Componentes de layout (RouteGuard, AdminRoute, ResellerRoute)
│   │   └── lib/            # Utilitários
│   ├── contexts/
│   │   └── AuthContext.tsx # Contexto de autenticação
│   ├── lib/
│   │   └── supabase.ts     # Cliente Supabase
│   └── types/
│       └── user.ts         # Tipos TypeScript
├── package.json
├── tsconfig.json
├── tailwind.config.ts
├── postcss.config.js
├── next.config.js
├── .env.local
└── supabase.sql
```

## Funcionalidades

### Painel Admin (`/admin`)

- Dashboard com estatísticas:
  - Total de usuários
  - Total de revendedores
  - Total de clientes
  - Total de créditos distribuídos
- Tabela de usuários com:
  - Filtros por role (Todos, Admins, Resellers, Users)
  - Busca por email em tempo real
  - Ações:
    - Tornar Admin
    - Tornar Revendedor (com créditos iniciais)
    - Adicionar Créditos (apenas revendedores)
    - Banir/Desbanir usuário

### Painel Revendedor (`/reseller`)

- Dashboard com:
  - Créditos disponíveis
  - Total de clientes
  - Clientes ativos
- Criar novo cliente:
  - Nome, Email, Senha
  - Plano
  - Dias de expiração
  - Consome 1 crédito do revendedor
- Tabela de clientes (apenas criados pelo revendedor):
  - Adicionar 30 dias
  - Banir/Desbanir cliente

### Autenticação

- Login (`/login`)
- Registro (`/register`)
- Proteção de rotas:
  - `RouteGuard` - Usuário autenticado
  - `AdminRoute` - Apenas admins
  - `ResellerRoute` - Admins e revendedores

## Design

- **Tema**: Escuro moderno estilo SaaS
- **Background**: #05070A
- **Primary**: #0066FF
- **Cards**: #0D1117
- **Bordas**: #1B2330

## RLS (Row Level Security)

### Admin
- Pode SELECT, INSERT, UPDATE, DELETE em toda tabela users

### Reseller
- Pode SELECT, INSERT, UPDATE apenas onde `created_by = auth.uid()` ou `id = auth.uid()`

### User
- Pode visualizar apenas onde `id = auth.uid()`
- Pode atualizar apenas onde `id = auth.uid()`

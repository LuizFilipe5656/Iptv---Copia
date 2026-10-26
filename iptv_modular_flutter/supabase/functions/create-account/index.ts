import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Método não permitido.' }, 405);
  const url = Deno.env.get('SUPABASE_URL');
  const anon = Deno.env.get('SUPABASE_ANON_KEY');
  const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anon || !service) return json({ error: 'Configuração indisponível.' }, 500);
  const bearer = req.headers.get('Authorization') ?? '';
  const token = bearer.startsWith('Bearer ') ? bearer.slice(7) : '';
  if (!token) return json({ error: 'Sessão necessária.' }, 401);
  const authClient = createClient(url, anon, { auth: { persistSession: false } });
  const { data: callerData, error: callerError } = await authClient.auth.getUser(token);
  if (callerError || !callerData.user) return json({ error: 'Sessão inválida.' }, 401);
  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: actor, error: actorError } = await admin.from('users')
    .select('id,role,status').eq('id', callerData.user.id).maybeSingle();
  if (actorError || !actor || actor.status !== 'ACTIVE' || !['super_admin', 'reseller'].includes(actor.role)) {
    return json({ error: 'Sem permissão para criar contas.' }, 403);
  }
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: 'JSON inválido.' }, 400); }
  const name = String(body.name ?? '').trim();
  const username = String(body.username ?? '').trim().toLowerCase();
  const email = String(body.email ?? '').trim().toLowerCase();
  const password = String(body.password ?? '');
  const role = String(body.role ?? '');
  const plan = String(body.plan ?? '');
  const expiration = String(body.expiration_date ?? '');
  const date = new Date(expiration);
  if (name.length < 2 || name.length > 120 || !/^[a-z0-9_]{3,30}$/.test(username) ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || password.length < 8 ||
      !['user', 'reseller'].includes(role) || !['FREE', 'PREMIUM', 'DIAMANTE'].includes(plan) ||
      !Number.isFinite(date.getTime()) || date.getTime() <= Date.now()) {
    return json({ error: 'Confira os campos e o vencimento.' }, 400);
  }
  if (actor.role === 'reseller' && role !== 'user') {
    return json({ error: 'Revendedores só podem cadastrar clientes.' }, 403);
  }
  const { data: existing, error: lookupError } = await admin.from('users')
    .select('id').eq('username', username).limit(1);
  if (lookupError) return json({ error: 'Não foi possível verificar o usuário.' }, 500);
  if (existing?.length) return json({ error: 'Nome de usuário já utilizado.' }, 409);
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email, password, email_confirm: true,
  });
  if (createError || !created.user) {
    return json({ error: 'Não foi possível criar a conta. Verifique se o e-mail já está cadastrado.' }, 409);
  }
  const userId = created.user.id;
  // Upsert cobre projetos com trigger que já insere public.users ao criar auth.users.
  const { error: profileError } = await admin.from('users').upsert({
    id: userId, email, name, username, role, plan,
    expiration_date: date.toISOString(), status: 'ACTIVE',
    created_by: callerData.user.id,
  }, { onConflict: 'id' });
  if (profileError) {
    await admin.auth.admin.deleteUser(userId);
    if (profileError.code === '23505') return json({ error: 'Nome de usuário ou e-mail já cadastrado.' }, 409);
    return json({ error: 'Não foi possível salvar o cadastro.' }, 500);
  }
  return json({ success: true, id: userId }, 201);
});

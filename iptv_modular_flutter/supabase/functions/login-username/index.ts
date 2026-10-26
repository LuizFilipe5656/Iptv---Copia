import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
};
const fail = () => new Response(JSON.stringify({ error: 'Credenciais inválidas ou limite de tentativas atingido.' }), {
  status: 401, headers: { ...headers, 'Content-Type': 'application/json' },
});
serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers });
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405, headers });
  try {
    const payload = await req.json();
    const username = typeof payload.username === 'string' ? payload.username.trim().toLowerCase() : '';
    const password = typeof payload.password === 'string' ? payload.password : '';
    if (!/^[a-z0-9_.-]{3,40}$/.test(username) || password.length < 1 || password.length > 1024) return fail();
    // Contador atômico no banco, inclusive para usuários inexistentes.
    const { data: allowed, error: limitError } = await admin.rpc('allow_username_login_attempt', { p_username: username });
    if (limitError || allowed !== true) return fail();
    const { data: account, error } = await admin.from('users').select('email').eq('username', username).maybeSingle();
    if (error || !account?.email) return fail();
    const auth = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data, error: authError } = await auth.auth.signInWithPassword({ email: account.email, password });
    if (authError || !data.session?.refresh_token) return fail();
    return new Response(JSON.stringify({ refresh_token: data.session.refresh_token }), {
      status: 200, headers: { ...headers, 'Content-Type': 'application/json' },
    });
  } catch (_) { return fail(); }
});


import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

export const runtime = 'nodejs'

export async function POST(request: NextRequest) {
  try {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL
    const publicKey =
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

    if (!url || !publicKey || !serviceKey) {
      return NextResponse.json(
        { error: 'Supabase não configurado no servidor.' },
        { status: 500 }
      )
    }

    // Identifica o solicitante usando seu token de sessão.
    const authorization = request.headers.get('authorization')
    const token = authorization?.startsWith('Bearer ')
      ? authorization.slice(7)
      : null

    if (!token) {
      return NextResponse.json(
        { error: 'Sessão não informada.' },
        { status: 401 }
      )
    }

    const authClient = createClient(url, publicKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    })

    const {
      data: { user: requester },
      error: authError,
    } = await authClient.auth.getUser(token)

    if (authError || !requester) {
      return NextResponse.json(
        { error: 'Sessão inválida.' },
        { status: 401 }
      )
    }

    // Este cliente é exclusivo do servidor.
    const adminClient = createClient(url, serviceKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    })

    const { data: master, error: masterError } =
      await adminClient
        .from('users')
        .select('id, role, status')
        .eq('id', requester.id)
        .single()

    if (
      masterError ||
      master?.role !== 'super_admin' ||
      master.status !== 'ACTIVE'
    ) {
      return NextResponse.json(
        { error: 'Apenas o Admin Master pode criar revendedores.' },
        { status: 403 }
      )
    }

    let body: unknown

    try {
      body = await request.json()
    } catch {
      return NextResponse.json(
        { error: 'Dados inválidos.' },
        { status: 400 }
      )
    }

    if (!body || typeof body !== 'object') {
      return NextResponse.json(
        { error: 'Dados inválidos.' },
        { status: 400 }
      )
    }

    const fields = body as Record<string, unknown>
    const name =
      typeof fields.name === 'string'
        ? fields.name.trim()
        : ''
    const email =
      typeof fields.email === 'string'
        ? fields.email.trim().toLowerCase()
        : ''
    const password =
      typeof fields.password === 'string'
        ? fields.password
        : ''
    const credits = fields.credits

    if (
      name.length < 2 ||
      name.length > 120 ||
      email.length > 254 ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
      password.length < 8 ||
      password.length > 128 ||
      typeof credits !== 'number' ||
      !Number.isSafeInteger(credits) ||
      credits < 0 ||
      credits > 1000000
    ) {
      return NextResponse.json(
        {
          error:
            'Informe nome, e-mail válido, senha de 8 a 128 caracteres e créditos entre 0 e 1.000.000.',
        },
        { status: 400 }
      )
    }

    // Cria a conta sem trocar a sessão do Master.
    // O trigger existente criará primeiro o perfil como user.
    const { data: created, error: createError } =
      await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { name },
      })

    if (createError || !created.user) {
      return NextResponse.json(
        {
          error: createError?.message ||
            'Não foi possível criar a conta.',
        },
        { status: 400 }
      )
    }

    const newUserId = created.user.id

    // O trigger já criou o perfil. Agora o servidor
    // atribui o cargo de revendedor.
    const { data: profile, error: profileError } =
      await adminClient
        .from('users')
        .update({
          role: 'reseller',
          name,
          credits,
          created_by: requester.id,
          status: 'ACTIVE',
        })
        .eq('id', newUserId)
        .eq('role', 'user')
        .select('id, email, role, credits')
        .single()

    if (profileError || !profile) {
      // Compensação: evita deixar uma conta incompleta
      // caso a atualização do perfil falhe.
      const { error: rollbackError } =
        await adminClient.auth.admin.deleteUser(newUserId)

      console.error(
        'Erro ao configurar revendedor:',
        profileError?.message,
        'Rollback:',
        rollbackError?.message
      )

      return NextResponse.json(
        {
          error:
            'Não foi possível configurar o perfil do revendedor. Verifique os logs do servidor.',
        },
        { status: 500 }
      )
    }

    const { error: auditError } = await adminClient
      .from('audit_logs')
      .insert({
        actor_id: requester.id,
        target_user_id: newUserId,
        action: 'CREATE_RESELLER',
        details: {
          initial_credits: credits,
        },
      })

    if (auditError) {
      // Não apagamos a conta já criada por uma falha
      // posterior de auditoria; informamos a situação.
      console.error('Falha na auditoria:', auditError.message)

      return NextResponse.json(
        {
          error:
            'Revendedor criado, mas o registro de auditoria falhou. Verifique o servidor antes de repetir.',
          created: true,
        },
        { status: 500 }
      )
    }

    return NextResponse.json(
      {
        message: 'Revendedor criado com sucesso.',
        reseller: profile,
      },
      { status: 201 }
    )
  } catch (error) {
    console.error('Erro na criação de revendedor:', error)

    return NextResponse.json(
      { error: 'Erro interno do servidor.' },
      { status: 500 }
    )
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL
    const publicKey =
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

    if (!url || !publicKey || !serviceKey) {
      return NextResponse.json(
        { error: 'Supabase não configurado.' },
        { status: 500 }
      )
    }

    const authorization = request.headers.get('authorization')
    const token = authorization?.startsWith('Bearer ')
      ? authorization.slice(7)
      : null

    if (!token) {
      return NextResponse.json(
        { error: 'Sessão não informada.' },
        { status: 401 }
      )
    }

    const authClient = createClient(url, publicKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    })

    const {
      data: { user: requester },
      error: authError,
    } = await authClient.auth.getUser(token)

    if (authError || !requester) {
      return NextResponse.json(
        { error: 'Sessão inválida.' },
        { status: 401 }
      )
    }

    const adminClient = createClient(url, serviceKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    })

    const { data: master, error: masterError } =
      await adminClient
        .from('users')
        .select('role, status')
        .eq('id', requester.id)
        .single()

    if (
      masterError ||
      master?.role !== 'super_admin' ||
      master.status !== 'ACTIVE'
    ) {
      return NextResponse.json(
        { error: 'Acesso permitido somente ao Master.' },
        { status: 403 }
      )
    }

    const body = await request.json()
    const resellerId = body?.resellerId
    const amount = body?.amount

    if (
      typeof resellerId !== 'string' ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(resellerId) ||
      typeof amount !== 'number' ||
      !Number.isSafeInteger(amount) ||
      amount <= 0 ||
      amount > 1000000
    ) {
      return NextResponse.json(
        { error: 'Revendedor ou quantidade inválida.' },
        { status: 400 }
      )
    }

    const { data: newBalance, error: creditError } =
      await adminClient.rpc(
        'master_add_reseller_credits',
        {
          p_reseller_id: resellerId,
          p_amount: amount,
        }
      )

    if (creditError) {
      return NextResponse.json(
        { error: creditError.message },
        { status: 400 }
      )
    }

    const { error: auditError } = await adminClient
      .from('audit_logs')
      .insert({
        actor_id: requester.id,
        target_user_id: resellerId,
        action: 'ADD_RESELLER_CREDITS',
        details: {
          amount,
          new_balance: newBalance,
        },
      })

    if (auditError) {
      console.error('Falha na auditoria de créditos:', auditError)

      return NextResponse.json(
        {
          error:
            'Créditos adicionados, mas a auditoria falhou. Atualize a página antes de tentar novamente.',
          updated: true,
        },
        { status: 500 }
      )
    }

    return NextResponse.json({
      message: 'Créditos adicionados com sucesso.',
      credits: newBalance,
    })
  } catch (error) {
    console.error('Erro ao adicionar créditos:', error)

    return NextResponse.json(
      { error: 'Erro interno do servidor.' },
      { status: 500 }
    )
  }
}

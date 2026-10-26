
import { NextRequest, NextResponse } from 'next/server'
import { createClient, SupabaseClient } from '@supabase/supabase-js'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function jsonError(message: string, status: number) {
  return NextResponse.json({ error: message }, { status })
}

async function getContext(request: NextRequest) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL

  const publicKey =
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY

  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

  if (!url || !publicKey || !serviceKey) {
    return {
      error: jsonError('Supabase não configurado no servidor.', 500),
    }
  }

  const authorization = request.headers.get('authorization')

  const token = authorization?.startsWith('Bearer ')
    ? authorization.slice(7)
    : null

  if (!token) {
    return {
      error: jsonError('Sessão não informada.', 401),
    }
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
    return {
      error: jsonError('Sessão inválida.', 401),
    }
  }

  const adminClient = createClient(url, serviceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  })

  const { data: reseller, error: resellerError } =
    await adminClient
      .from('users')
      .select('id, role, status, credits')
      .eq('id', requester.id)
      .single()

  if (
    resellerError ||
    reseller?.role !== 'reseller' ||
    reseller.status !== 'ACTIVE'
  ) {
    return {
      error: jsonError(
        'Acesso permitido somente a revendedores ativos.',
        403
      ),
    }
  }

  return {
    adminClient,
    reseller,
    requester,
  }
}

type AdminClient = SupabaseClient

async function getOperation(
  adminClient: AdminClient,
  requestId: string
) {
  return adminClient
    .from('reseller_client_operations')
    .select(
      'request_id, reseller_id, client_email, client_id, auth_user_id, status, credit_charged'
    )
    .eq('request_id', requestId)
    .maybeSingle()
}

// GET - Consultar clientes do revendedor
export async function GET(request: NextRequest) {
  try {
    const context = await getContext(request)

    if (context.error) return context.error

    const { adminClient, requester, reseller } = context

    const { data: clients, error } = await adminClient
      .from('users')
      .select(
        'id, name, email, plan, expiration_date, status, created_at'
      )
      .eq('created_by', requester.id)
      .eq('role', 'user')
      .order('created_at', { ascending: false })

    if (error) {
      console.error('Erro ao consultar clientes:', error)

      return jsonError(
        'Não foi possível consultar os clientes.',
        500
      )
    }

    return NextResponse.json({
      clients: clients || [],
      credits: reseller.credits,
    })
  } catch (error) {
    console.error('Erro no GET de clientes:', error)

    return jsonError('Erro interno do servidor.', 500)
  }
}

// POST - Criar cliente com reserva de crédito
export async function POST(request: NextRequest) {
  try {
    const context = await getContext(request)

    if (context.error) return context.error

    const { adminClient, requester } = context

    let body: Record<string, unknown>

    try {
      body = await request.json()
    } catch {
      return jsonError('JSON inválido.', 400)
    }

    if (
      !body ||
      typeof body !== 'object' ||
      Array.isArray(body)
    ) {
      return jsonError('Dados inválidos.', 400)
    }

    const requestId =
      typeof body.requestId === 'string'
        ? body.requestId.trim()
        : ''

    const name =
      typeof body.name === 'string'
        ? body.name.trim()
        : ''

    const email =
      typeof body.email === 'string'
        ? body.email.trim().toLowerCase()
        : ''

    const password =
      typeof body.password === 'string'
        ? body.password
        : ''

    const plan =
      typeof body.plan === 'string'
        ? body.plan.trim().toUpperCase()
        : ''

    const days = Number(body.days)

    if (!uuidPattern.test(requestId)) {
      return jsonError(
        'Identificador de operação inválido.',
        400
      )
    }

    if (
      !emailPattern.test(email) ||
      email.length > 254
    ) {
      return jsonError('E-mail inválido.', 400)
    }

    // Consultar operações já existentes
    const { data: existing, error: lookupError } =
      await getOperation(adminClient, requestId)

    if (lookupError) {
      console.error(
        'Erro ao consultar operação:',
        lookupError
      )

      return jsonError(
        'Não foi possível consultar a operação.',
        500
      )
    }

    if (existing) {
      if (
        existing.reseller_id !== requester.id ||
        existing.client_email !== email
      ) {
        return jsonError(
          'Identificador de operação já utilizado.',
          409
        )
      }

      if (existing.status === 'COMPLETED') {
        return NextResponse.json({
          status: 'COMPLETED',
          clientId: existing.client_id,
          message: 'Cliente já cadastrado nesta operação.',
        })
      }

      if (existing.status === 'FAILED') {
        return NextResponse.json(
          {
            status: 'FAILED',
            error:
              'Esta operação foi encerrada. Inicie um novo cadastro.',
          },
          { status: 409 }
        )
      }

      // Não repetir a criação de usuários
      return NextResponse.json(
        {
          status: existing.status,
          message:
            'Operação em andamento ou interrompida. ' +
            'Aguarde a verificação antes de tentar outro cadastro.',
        },
        { status: 202 }
      )
    }

    // Validar dados do novo cliente
    if (
      name.length < 2 ||
      name.length > 150
    ) {
      return jsonError('Informe um nome válido.', 400)
    }

    if (
      password.length < 8 ||
      password.length > 72
    ) {
      return jsonError(
        'A senha deve ter entre 8 e 72 caracteres.',
        400
      )
    }

    if (!plan || plan.length > 50) {
      return jsonError('Plano inválido.', 400)
    }

    if (
      !Number.isSafeInteger(days) ||
      days < 1 ||
      days > 3650
    ) {
      return jsonError(
        'A validade deve estar entre 1 e 3650 dias.',
        400
      )
    }

    // 1. Reservar exatamente um crédito
    const { error: reserveError } =
      await adminClient.rpc(
        'reseller_reserve_client_operation',
        {
          p_reseller_id: requester.id,
          p_request_id: requestId,
          p_client_email: email,
        }
      )

    if (reserveError) {
      console.error(
        'Erro ao reservar crédito:',
        reserveError
      )

      return jsonError(
        'Não foi possível reservar o crédito. ' +
        'Verifique o saldo e a operação antes de tentar novamente.',
        409
      )
    }

    // 2. Iniciar processamento
    const processingToken = crypto.randomUUID()

    const { data: started, error: startError } =
      await adminClient.rpc(
        'reseller_start_client_operation',
        {
          p_reseller_id: requester.id,
          p_request_id: requestId,
          p_processing_token: processingToken,
        }
      )

    if (startError || started !== true) {
      console.error(
        'Não foi possível iniciar a operação:',
        startError
      )

      return NextResponse.json(
        {
          status: 'PENDING',
          message:
            'Crédito possivelmente reservado. ' +
            'A operação precisa ser verificada.',
        },
        { status: 202 }
      )
    }

    // 3. Criar usuário no Supabase Auth
    const { data: authData, error: createError } =
      await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          name,
          reseller_id: requester.id,
          client_request_id: requestId,
        },
      })

    if (createError || !authData.user) {
      console.error(
        'Falha na criação Auth da operação:',
        requestId,
        createError
      )

      // Não devolver créditos automaticamente.
      // O resultado da criação pode ser incerto.
      return NextResponse.json(
        {
          status: 'PROCESSING',
          message:
            'Não foi possível confirmar a criação da conta. ' +
            'A operação precisa ser verificada.',
        },
        { status: 202 }
      )
    }

    const authUserId = authData.user.id

    // 4. Registrar o usuário Auth
    const { data: recorded, error: recordError } =
      await adminClient.rpc(
        'reseller_record_client_auth',
        {
          p_reseller_id: requester.id,
          p_request_id: requestId,
          p_auth_user_id: authUserId,
          p_processing_token: processingToken,
        }
      )

    if (recordError || recorded !== true) {
      console.error(
        'Falha ao registrar Auth:',
        requestId,
        recordError
      )

      return NextResponse.json(
        {
          status: 'PROCESSING',
          message:
            'Conta Auth criada, mas o cadastro ainda ' +
            'precisa de verificação.',
        },
        { status: 202 }
      )
    }

    // 5. Atualizar perfil criado pelo gatilho
    const expirationDate = new Date(
      Date.now() + days * 24 * 60 * 60 * 1000
    ).toISOString()

    const { data: profile, error: profileError } =
      await adminClient
        .from('users')
        .update({
          name,
          email,
          plan,
          expiration_date: expirationDate,
          status: 'ACTIVE',
          role: 'user',
          created_by: requester.id,
          credits: 0,
        })
        .eq('id', authUserId)
        .eq('role', 'user')
        .is('created_by', null)
        .select('id')
        .maybeSingle()

    if (profileError || !profile) {
      console.error(
        'Falha ao atualizar perfil:',
        requestId,
        profileError
      )

      return NextResponse.json(
        {
          status: 'PROCESSING',
          message:
            'Conta criada, mas o perfil ainda ' +
            'precisa de verificação.',
        },
        { status: 202 }
      )
    }

    // 6. Finalizar operação sem cobrar novamente
    const { data: credits, error: chargeError } =
      await adminClient.rpc(
        'reseller_charge_client_operation',
        {
          p_reseller_id: requester.id,
          p_request_id: requestId,
          p_client_id: authUserId,
          p_client_email: email,
          p_processing_token: processingToken,
        }
      )

    if (chargeError) {
      console.error(
        'Falha ao finalizar operação:',
        requestId,
        chargeError
      )

      return NextResponse.json(
        {
          status: 'PROCESSING',
          message:
            'Cliente criado, mas a finalização ' +
            'precisa ser verificada.',
        },
        { status: 202 }
      )
    }

    return NextResponse.json(
      {
        status: 'COMPLETED',
        clientId: authUserId,
        credits,
        message: 'Cliente criado com sucesso.',
      },
      { status: 201 }
    )
  } catch (error) {
    console.error(
      'Erro inesperado no POST:',
      error
    )

    return jsonError(
      'Erro interno. Verifique a operação antes de reenviar.',
      500
    )
  }
}

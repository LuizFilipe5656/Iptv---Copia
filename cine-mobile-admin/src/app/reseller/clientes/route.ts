
import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
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
      return NextResponse.json(
        {
          error: 'Acesso permitido somente a revendedores ativos.',
        },
        { status: 403 }
      )
    }

    const { data: clients, error: clientsError } =
      await adminClient
        .from('users')
        .select(
          'id, name, email, plan, expiration_date, status, created_at'
        )
        .eq('created_by', requester.id)
        .eq('role', 'user')
        .order('created_at', { ascending: false })

    if (clientsError) {
      console.error('Erro ao consultar clientes:', clientsError)

      return NextResponse.json(
        {
          error: 'Não foi possível consultar os clientes.',
        },
        { status: 500 }
      )
    }

    return NextResponse.json({
      clients: clients || [],
      credits: reseller.credits,
    })
  } catch (error) {
    console.error('Erro na API de clientes:', error)

    return NextResponse.json(
      { error: 'Erro interno do servidor.' },
      { status: 500 }
    )
  }
}

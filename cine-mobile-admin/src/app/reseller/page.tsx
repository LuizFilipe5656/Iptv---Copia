
'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import { useAuth } from '@/contexts/AuthContext'
import { supabase } from '@/lib/supabase'
import { ResellerRoute } from '@/components/layout/ResellerRoute'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import {
  Users,
  Wallet,
  Plus,
  Calendar,
  Ban,
  ShieldCheck,
  RefreshCw,
} from 'lucide-react'
import type { User } from '@/types/user'

type Client = User

type ClientsResponse = {
  clients?: Client[]
  credits?: number
  error?: string
}

type CreateResponse = {
  status?: 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED'
  clientId?: string
  credits?: number
  message?: string
  error?: string
}

const initialCreateData = {
  name: '',
  email: '',
  password: '',
  plan: 'FREE',
  days: '30',
}

export default function ResellerPage() {
  const { user } = useAuth()

  const [clients, setClients] = useState<Client[]>([])
  const [credits, setCredits] = useState(0)
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)

  const [modalOpen, setModalOpen] = useState(false)
  const [createData, setCreateData] = useState(initialCreateData)
  const [creating, setCreating] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [operationStatus, setOperationStatus] = useState('')

  // Mantém o mesmo identificador quando uma operação
  // precisa ser consultada novamente.
  const requestIdRef = useRef<string | null>(null)

  // Impede novas tentativas automáticas quando o
  // resultado da criação não foi confirmado.
  const operationNeedsReviewRef = useRef(false)

  const getAccessToken = async () => {
    const {
      data: { session },
      error: sessionError,
    } = await supabase.auth.getSession()

    if (sessionError || !session?.access_token) {
      throw new Error(
        'Sua sessão expirou. Faça login novamente.'
      )
    }

    return session.access_token
  }

  const fetchClients = useCallback(async () => {
    if (!user?.id) {
      setLoading(false)
      return
    }

    try {
      const token = await getAccessToken()

      const response = await fetch('/api/reseller/clients', {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
        },
        cache: 'no-store',
      })

      const data: ClientsResponse = await response.json()

      if (!response.ok) {
        throw new Error(
          data.error || 'Não foi possível consultar os clientes.'
        )
      }

      setClients(data.clients || [])
      setCredits(Number(data.credits ?? 0))
    } catch (err) {
      console.error('Erro ao consultar clientes:', err)

      setError(
        err instanceof Error
          ? err.message
          : 'Erro ao consultar clientes.'
      )
    } finally {
      setLoading(false)
    }
  }, [user?.id])

  useEffect(() => {
    void fetchClients()
  }, [fetchClients])

  const refreshClients = async () => {
    setRefreshing(true)
    await fetchClients()
    setRefreshing(false)
  }

  const handleModalChange = (open: boolean) => {
    if (creating) return

    setModalOpen(open)

    if (open) {
      setError('')
      setSuccess('')
      return
    }

    // Uma operação incerta não deve ser esquecida
    // nem substituída por outra automaticamente.
    if (!operationNeedsReviewRef.current) {
      requestIdRef.current = null
      setOperationStatus('')
      setCreateData(initialCreateData)
    }
  }

  const createClient = async () => {
    if (creating) return

    setError('')
    setSuccess('')

    if (operationNeedsReviewRef.current) {
      setError(
        'Existe um cadastro com resultado pendente de verificação. ' +
        'Não inicie outra tentativa até que a operação seja conferida.'
      )
      return
    }

    const name = createData.name.trim()
    const email = createData.email.trim().toLowerCase()
    const password = createData.password
    const plan = createData.plan.trim().toUpperCase()
    const days = Number(createData.days)

    if (name.length < 2 || name.length > 150) {
      setError('Informe um nome válido.')
      return
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setError('Informe um e-mail válido.')
      return
    }

    if (password.length < 8 || password.length > 72) {
      setError('A senha deve ter entre 8 e 72 caracteres.')
      return
    }

    if (!plan || plan.length > 50) {
      setError('Informe um plano válido.')
      return
    }

    if (
      !Number.isSafeInteger(days) ||
      days < 1 ||
      days > 3650
    ) {
      setError('Informe uma validade entre 1 e 3650 dias.')
      return
    }

    if (credits < 1) {
      setError('Você não possui créditos suficientes.')
      return
    }

    setCreating(true)

    // O identificador é gerado uma única vez.
    const requestId =
      requestIdRef.current || crypto.randomUUID()

    requestIdRef.current = requestId

    // A partir do envio, uma falha de rede pode
    // deixar o resultado da operação desconhecido.
    operationNeedsReviewRef.current = true

    try {
      const token = await getAccessToken()

      const response = await fetch('/api/reseller/clients', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          requestId,
          name,
          email,
          password,
          plan,
          days,
        }),
      })

      const data: CreateResponse = await response.json()

      if (data.status === 'COMPLETED' && response.ok) {
        operationNeedsReviewRef.current = false
        requestIdRef.current = null
        setOperationStatus('COMPLETED')

        setSuccess(
          data.message || 'Cliente criado com sucesso.'
        )

        setCreateData(initialCreateData)

        if (typeof data.credits === 'number') {
          setCredits(data.credits)
        }

        await fetchClients()
        return
      }

      if (
        data.status === 'PENDING' ||
        data.status === 'PROCESSING' ||
        response.status === 202
      ) {
        setOperationStatus(data.status || 'PENDING')

        setError(
          (data.message || 'Cadastro aguardando verificação.') +
          ' Não tente cadastrar novamente com outro identificador.'
        )

        await fetchClients()
        return
      }

      if (data.status === 'FAILED') {
        setOperationStatus('FAILED')
        setError(
          data.error ||
          'A operação foi encerrada e precisa ser verificada.'
        )
        await fetchClients()
        return
      }

      // Erros de validação anteriores à reserva podem
      // ser corrigidos. Erros após o envio exigem cuidado.
      if (
        response.status === 400 ||
        response.status === 401 ||
        response.status === 403
      ) {
        operationNeedsReviewRef.current = false
        requestIdRef.current = null
      }

      setError(
        data.error ||
        'Não foi possível confirmar o cadastro. ' +
        'Verifique a operação antes de tentar novamente.'
      )

      await fetchClients()
    } catch (err) {
      console.error('Erro no cadastro:', err)

      setOperationStatus('PENDING')
      setError(
        'A conexão falhou ou a resposta não pôde ser confirmada. ' +
        'O cadastro pode ter sido iniciado. ' +
        'Não faça uma nova tentativa antes de verificar a operação.'
      )

      await fetchClients()
    } finally {
      setCreating(false)
    }
  }

  // Ações existentes preservadas.
  // Antes da produção, devem ser migradas para
  // endpoints de servidor com autorização e
  // validação de propriedade do cliente.

  const addDays = async (clientId: string) => {
    try {
      const client = clients.find((c) => c.id === clientId)
      if (!client) return

      const expiration = new Date(client.expiration_date)

      if (Number.isNaN(expiration.getTime())) {
        throw new Error('Data de expiração inválida.')
      }

      const newExpiration = new Date(
        Math.max(expiration.getTime(), Date.now()) +
          30 * 24 * 60 * 60 * 1000
      ).toISOString()

      const { error: updateError } = await supabase
        .from('users')
        .update({ expiration_date: newExpiration })
        .eq('id', clientId)
        .eq('created_by', user?.id)
        .eq('role', 'user')

      if (updateError) throw updateError

      await fetchClients()
    } catch (err) {
      console.error('Erro ao renovar cliente:', err)
      setError('Não foi possível renovar o cliente.')
    }
  }

  const banClient = async (clientId: string) => {
    try {
      const { error: updateError } = await supabase
        .from('users')
        .update({ status: 'BANNED' })
        .eq('id', clientId)
        .eq('created_by', user?.id)
        .eq('role', 'user')

      if (updateError) throw updateError

      await fetchClients()
    } catch (err) {
      console.error('Erro ao bloquear cliente:', err)
      setError('Não foi possível bloquear o cliente.')
    }
  }

  const unbanClient = async (clientId: string) => {
    try {
      const { error: updateError } = await supabase
        .from('users')
        .update({ status: 'ACTIVE' })
        .eq('id', clientId)
        .eq('created_by', user?.id)
        .eq('role', 'user')

      if (updateError) throw updateError

      await fetchClients()
    } catch (err) {
      console.error('Erro ao desbloquear cliente:', err)
      setError('Não foi possível desbloquear o cliente.')
    }
  }

  if (loading) {
    return (
      <ResellerRoute>
        <div className="min-h-screen flex items-center justify-center bg-background">
          <div className="text-foreground">
            Carregando...
          </div>
        </div>
      </ResellerRoute>
    )
  }

  return (
    <ResellerRoute>
      <div className="min-h-screen bg-background p-8">
        <div className="max-w-7xl mx-auto">

          <div className="mb-8">
            <h1 className="text-3xl font-bold text-foreground">
              Painel Revendedor
            </h1>
            <p className="text-muted-foreground mt-2">
              Gerencie seus clientes
            </p>
          </div>

          {error && !modalOpen && (
            <div className="mb-6 rounded-md border border-destructive/40 p-4 text-sm text-destructive">
              {error}
            </div>
          )}

          <Card className="border-border bg-card mb-8">
            <CardHeader className="flex flex-row items-center justify-between gap-4">
              <div className="flex items-center gap-4">
                <Wallet className="h-8 w-8 text-primary" />
                <CardTitle className="text-2xl">
                  {credits} Créditos Disponíveis
                </CardTitle>
              </div>

              <div className="flex gap-2">
                <Button
                  variant="outline"
                  onClick={refreshClients}
                  disabled={refreshing}
                  title="Atualizar clientes e créditos"
                >
                  <RefreshCw
                    className={`h-4 w-4 ${
                      refreshing ? 'animate-spin' : ''
                    }`}
                  />
                </Button>

                <Dialog
                  open={modalOpen}
                  onOpenChange={handleModalChange}
                >
                  <DialogTrigger asChild>
                    <Button>
                      <Plus className="w-4 h-4 mr-2" />
                      Criar Cliente
                    </Button>
                  </DialogTrigger>

                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>
                        Criar Novo Cliente
                      </DialogTitle>

                      <DialogDescription>
                        Preencha os dados do cliente.
                        O cadastro utiliza 1 crédito.
                      </DialogDescription>
                    </DialogHeader>

                    <div className="space-y-4 py-4">
                      <div className="space-y-2">
                        <Label htmlFor="name">Nome</Label>
                        <Input
                          id="name"
                          value={createData.name}
                          disabled={creating || operationNeedsReviewRef.current}
                          onChange={(e) =>
                            setCreateData((previous) => ({
                              ...previous,
                              name: e.target.value,
                            }))
                          }
                          placeholder="Nome do cliente"
                        />
                      </div>

                      <div className="space-y-2">
                        <Label htmlFor="email">E-mail</Label>
                        <Input
                          id="email"
                          type="email"
                          value={createData.email}
                          disabled={creating || operationNeedsReviewRef.current}
                          onChange={(e) =>
                            setCreateData((previous) => ({
                              ...previous,
                              email: e.target.value,
                            }))
                          }
                          placeholder="cliente@email.com"
                        />
                      </div>

                      <div className="space-y-2">
                        <Label htmlFor="password">Senha</Label>
                        <Input
                          id="password"
                          type="password"
                          value={createData.password}
                          disabled={creating || operationNeedsReviewRef.current}
                          onChange={(e) =>
                            setCreateData((previous) => ({
                              ...previous,
                              password: e.target.value,
                            }))
                          }
                          placeholder="Mínimo de 8 caracteres"
                        />
                      </div>

                      <div className="space-y-2">
                        <Label htmlFor="plan">Plano</Label>
                        <Input
                          id="plan"
                          value={createData.plan}
                          disabled={creating || operationNeedsReviewRef.current}
                          onChange={(e) =>
                            setCreateData((previous) => ({
                              ...previous,
                              plan: e.target.value,
                            }))
                          }
                          placeholder="FREE"
                        />
                      </div>

                      <div className="space-y-2">
                        <Label htmlFor="days">
                          Dias de Expiração
                        </Label>
                        <Input
                          id="days"
                          type="number"
                          min="1"
                          max="3650"
                          value={createData.days}
                          disabled={creating || operationNeedsReviewRef.current}
                          onChange={(e) =>
                            setCreateData((previous) => ({
                              ...previous,
                              days: e.target.value,
                            }))
                          }
                        />
                      </div>

                      {operationStatus &&
                        operationStatus !== 'COMPLETED' && (
                          <div className="rounded-md border p-3 text-sm">
                            Operação: {operationStatus}
                            {requestIdRef.current && (
                              <div className="mt-2 break-all text-xs text-muted-foreground">
                                ID: {requestIdRef.current}
                              </div>
                            )}
                          </div>
                        )}

                      {error && (
                        <div className="text-sm text-destructive">
                          {error}
                        </div>
                      )}

                      {success && (
                        <div className="text-sm text-green-500">
                          {success}
                        </div>
                      )}
                    </div>

                    <DialogFooter>
                      <Button
                        variant="outline"
                        disabled={creating}
                        onClick={() => handleModalChange(false)}
                      >
                        Fechar
                      </Button>

                      <Button
                        onClick={createClient}
                        disabled={
                          creating ||
                          credits < 1 ||
                          operationNeedsReviewRef.current ||
                          operationStatus === 'COMPLETED'
                        }
                      >
                        {creating
                          ? 'Criando...'
                          : operationNeedsReviewRef.current
                          ? 'Aguardando verificação'
                          : 'Criar Cliente'}
                      </Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>
              </div>
            </CardHeader>
          </Card>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
            <Card className="border-border bg-card">
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  Total Clientes
                </CardTitle>
                <Users className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-foreground">
                  {clients.length}
                </div>
              </CardContent>
            </Card>

            <Card className="border-border bg-card">
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  Clientes Ativos
                </CardTitle>
                <ShieldCheck className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-foreground">
                  {
                    clients.filter(
                      (client) => client.status === 'ACTIVE'
                    ).length
                  }
                </div>
              </CardContent>
            </Card>
          </div>

          <Card className="border-border bg-card">
            <CardHeader>
              <CardTitle>Meus Clientes</CardTitle>
            </CardHeader>

            <CardContent className="p-0">
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-border">
                      <th className="text-left p-4 text-sm font-medium text-muted-foreground">
                        Nome
                      </th>
                      <th className="text-left p-4 text-sm font-medium text-muted-foreground">
                        E-mail
                      </th>
                      <th className="text-left p-4 text-sm font-medium text-muted-foreground">
                        Plano
                      </th>
                      <th className="text-left p-4 text-sm font-medium text-muted-foreground">
                        Expiração
                      </th>
                      <th className="text-left p-4 text-sm font-medium text-muted-foreground">
                        Status
                      </th>
                      <th className="text-left p-4 text-sm font-medium text-muted-foreground">
                        Data Criação
                      </th>
                      <th className="text-left p-4 text-sm font-medium text-muted-foreground">
                        Ações
                      </th>
                    </tr>
                  </thead>

                  <tbody>
                    {clients.map((client) => (
                      <tr
                        key={client.id}
                        className="border-b border-border hover:bg-muted/50"
                      >
                        <td className="p-4 text-sm text-foreground">
                          {client.name || '-'}
                        </td>

                        <td className="p-4 text-sm text-foreground">
                          {client.email}
                        </td>

                        <td className="p-4 text-sm text-muted-foreground">
                          {client.plan}
                        </td>

                        <td className="p-4 text-sm text-muted-foreground">
                          {client.expiration_date
                            ? new Date(
                                client.expiration_date
                              ).toLocaleDateString('pt-BR')
                            : '-'}
                        </td>

                        <td className="p-4">
                          <span
                            className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${
                              client.status === 'ACTIVE'
                                ? 'bg-green-500/20 text-green-500 border border-green-500/30'
                                : 'bg-red-500/20 text-red-500 border border-red-500/30'
                            }`}
                          >
                            {client.status}
                          </span>
                        </td>

                        <td className="p-4 text-sm text-muted-foreground">
                          {client.created_at
                            ? new Date(
                                client.created_at
                              ).toLocaleDateString('pt-BR')
                            : '-'}
                        </td>

                        <td className="p-4">
                          <div className="flex gap-2">
                            <Button
                              size="sm"
                              variant="outline"
                              title="Adicionar 30 dias"
                              onClick={() => addDays(client.id)}
                            >
                              <Calendar className="w-4 h-4" />
                            </Button>

                            {client.status === 'ACTIVE' ? (
                              <Button
                                size="sm"
                                variant="outline"
                                title="Bloquear cliente"
                                onClick={() => banClient(client.id)}
                              >
                                <Ban className="w-4 h-4" />
                              </Button>
                            ) : (
                              <Button
                                size="sm"
                                variant="outline"
                                title="Desbloquear cliente"
                                onClick={() => unbanClient(client.id)}
                              >
                                <ShieldCheck className="w-4 h-4" />
                              </Button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>

                {clients.length === 0 && (
                  <div className="p-8 text-center text-muted-foreground">
                    Nenhum cliente encontrado.
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </ResellerRoute>
  )
}


'use client'

import { useCallback, useEffect, useState } from 'react'
import Link from 'next/link'
import { AdminRoute } from '@/components/layout/AdminRoute'
import { useAuth } from '@/contexts/AuthContext'
import { supabase } from '@/lib/supabase'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import type { User } from '@/types/user'

export default function ManageResellersPage() {
  return (
    <AdminRoute>
      <ResellersContent />
    </AdminRoute>
  )
}

function ResellersContent() {
  const { user } = useAuth()

  const [resellers, setResellers] = useState<User[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [addingCredits, setAddingCredits] = useState(false)

  const [showForm, setShowForm] = useState(false)
  const [selectedResellerId, setSelectedResellerId] =
    useState<string | null>(null)

  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [credits, setCredits] = useState('0')
  const [creditAmount, setCreditAmount] = useState('1')

  const loadResellers = useCallback(async () => {
    if (user?.role !== 'super_admin') {
      setLoading(false)
      return
    }

    setLoading(true)

    const { data, error: fetchError } = await supabase
      .from('users')
      .select('*')
      .eq('role', 'reseller')
      .order('created_at', { ascending: false })

    if (fetchError) {
      setError(fetchError.message)
    } else {
      setResellers((data ?? []) as User[])
    }

    setLoading(false)
  }, [user?.role])

  useEffect(() => {
    void loadResellers()
  }, [loadResellers])

  async function getAccessToken() {
    const { data, error: sessionError } =
      await supabase.auth.getSession()

    if (sessionError || !data.session) {
      throw new Error('Sessão expirada. Faça login novamente.')
    }

    return data.session.access_token
  }

  async function handleCreate(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()

    if (saving) return

    const initialCredits = Number(credits)

    if (
      !Number.isSafeInteger(initialCredits) ||
      initialCredits < 0
    ) {
      setError('Informe uma quantidade válida de créditos.')
      return
    }

    setSaving(true)
    setError('')
    setSuccess('')

    try {
      const token = await getAccessToken()

      const response = await fetch('/api/admin/resellers', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          name: name.trim(),
          email: email.trim(),
          password,
          credits: initialCredits,
        }),
      })

      const result = await response.json()

      if (!response.ok) {
        if (result.created) {
          await loadResellers()
        }

        throw new Error(
          result.error || 'Não foi possível criar o revendedor.'
        )
      }

      setSuccess('Revendedor criado com sucesso!')
      setName('')
      setEmail('')
      setPassword('')
      setCredits('0')
      setShowForm(false)

      await loadResellers()
    } catch (err) {
      setError(
        err instanceof Error ? err.message : 'Erro inesperado.'
      )
    } finally {
      setSaving(false)
    }
  }

  async function handleAddCredits(reseller: User) {
    if (addingCredits) return

    const amount = Number(creditAmount)

    if (
      !Number.isSafeInteger(amount) ||
      amount < 1 ||
      amount > 1000000
    ) {
      setError('Informe um número inteiro entre 1 e 1.000.000.')
      return
    }

    const currentCredits = Number(reseller.credits ?? 0)

    const confirmed = window.confirm(
      `Adicionar ${amount} crédito(s) para ${reseller.email}?\n\n` +
        `Saldo atual: ${currentCredits}\n` +
        `Saldo previsto: ${currentCredits + amount}`
    )

    if (!confirmed) return

    setAddingCredits(true)
    setError('')
    setSuccess('')

    try {
      const token = await getAccessToken()

      const response = await fetch('/api/admin/resellers', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          resellerId: reseller.id,
          amount,
        }),
      })

      const result = await response.json()

      if (!response.ok) {
        await loadResellers()

        throw new Error(
          result.error ||
            'Não foi possível confirmar a operação. Verifique o saldo antes de tentar novamente.'
        )
      }

      setSuccess(
        `${amount} crédito(s) adicionado(s) para ${reseller.email}.`
      )
      setSelectedResellerId(null)
      setCreditAmount('1')

      await loadResellers()
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : 'Erro inesperado ao adicionar créditos.'
      )
    } finally {
      setAddingCredits(false)
    }
  }

  const totalCredits = resellers.reduce(
    (sum, reseller) => sum + Number(reseller.credits ?? 0),
    0
  )

  if (user?.role !== 'super_admin') {
    return (
      <div className="min-h-screen bg-background p-8 text-foreground">
        Acesso permitido apenas ao Master.
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-background p-6 text-foreground md:p-8">
      <div className="mx-auto max-w-7xl space-y-6">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div>
            <h1 className="text-3xl font-bold">
              Gerenciar Revendedores
            </h1>
            <p className="mt-2 text-muted-foreground">
              Cadastre revendedores e gerencie seus créditos.
            </p>
          </div>

          <div className="flex gap-2">
            <Link href="/admin">
              <Button variant="outline">
                Voltar ao Painel
              </Button>
            </Link>

            <Button
              onClick={() => {
                setShowForm(!showForm)
                setError('')
                setSuccess('')
              }}
            >
              {showForm ? 'Fechar' : '+ Novo Revendedor'}
            </Button>
          </div>
        </div>

        {error && (
          <div
            role="alert"
            className="rounded-lg border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-500"
          >
            {error}
          </div>
        )}

        {success && (
          <div
            role="status"
            className="rounded-lg border border-green-500/40 bg-green-500/10 p-4 text-sm text-green-500"
          >
            {success}
          </div>
        )}

        {showForm && (
          <Card>
            <CardHeader>
              <CardTitle>Cadastrar Revendedor</CardTitle>
            </CardHeader>

            <CardContent>
              <form
                onSubmit={handleCreate}
                className="grid gap-4 md:grid-cols-2"
              >
                <div className="space-y-2">
                  <label htmlFor="reseller-name">
                    Nome
                  </label>
                  <Input
                    id="reseller-name"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    required
                    disabled={saving}
                  />
                </div>

                <div className="space-y-2">
                  <label htmlFor="reseller-email">
                    E-mail
                  </label>
                  <Input
                    id="reseller-email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                    disabled={saving}
                  />
                </div>

                <div className="space-y-2">
                  <label htmlFor="reseller-password">
                    Senha inicial
                  </label>
                  <Input
                    id="reseller-password"
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    minLength={6}
                    disabled={saving}
                  />
                </div>

                <div className="space-y-2">
                  <label htmlFor="reseller-credits">
                    Créditos iniciais
                  </label>
                  <Input
                    id="reseller-credits"
                    type="number"
                    min="0"
                    step="1"
                    value={credits}
                    onChange={(e) => setCredits(e.target.value)}
                    required
                    disabled={saving}
                  />
                </div>

                <div className="md:col-span-2">
                  <Button type="submit" disabled={saving}>
                    {saving
                      ? 'Cadastrando...'
                      : 'Cadastrar Revendedor'}
                  </Button>
                </div>
              </form>
            </CardContent>
          </Card>
        )}

        <div className="grid gap-4 md:grid-cols-2">
          <Card>
            <CardHeader>
              <CardTitle>Total de Revendedores</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold">
                {resellers.length}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Créditos dos Revendedores</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-3xl font-bold">
                {totalCredits}
              </div>
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Revendedores Cadastrados</CardTitle>
          </CardHeader>

          <CardContent>
            {loading ? (
              <p className="text-muted-foreground">
                Carregando revendedores...
              </p>
            ) : resellers.length === 0 ? (
              <p className="text-muted-foreground">
                Nenhum revendedor encontrado.
              </p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead>
                    <tr className="border-b">
                      <th className="p-3">Nome</th>
                      <th className="p-3">E-mail</th>
                      <th className="p-3">Cargo</th>
                      <th className="p-3">Status</th>
                      <th className="p-3">Créditos</th>
                      <th className="p-3">Criado em</th>
                      <th className="p-3">Ações</th>
                    </tr>
                  </thead>

                  <tbody>
                    {resellers.map((reseller) => (
                      <tr
                        key={reseller.id}
                        className="border-b"
                      >
                        <td className="p-3">
                          {reseller.name || '-'}
                        </td>

                        <td className="p-3">
                          {reseller.email}
                        </td>

                        <td className="p-3">
                          Revendedor
                        </td>

                        <td className="p-3">
                          {reseller.status}
                        </td>

                        <td className="p-3 font-semibold">
                          {reseller.credits ?? 0}
                        </td>

                        <td className="p-3">
                          {reseller.created_at
                            ? new Date(
                                reseller.created_at
                              ).toLocaleDateString('pt-BR')
                            : '-'}
                        </td>

                        <td className="p-3">
                          {selectedResellerId === reseller.id ? (
                            <div className="flex min-w-48 flex-col gap-2">
                              <Input
                                type="number"
                                min="1"
                                max="1000000"
                                step="1"
                                value={creditAmount}
                                disabled={addingCredits}
                                onChange={(e) =>
                                  setCreditAmount(e.target.value)
                                }
                              />

                              <div className="flex gap-2">
                                <Button
                                  size="sm"
                                  disabled={addingCredits}
                                  onClick={() =>
                                    void handleAddCredits(reseller)
                                  }
                                >
                                  {addingCredits
                                    ? 'Enviando...'
                                    : 'Confirmar'}
                                </Button>

                                <Button
                                  size="sm"
                                  variant="outline"
                                  disabled={addingCredits}
                                  onClick={() =>
                                    setSelectedResellerId(null)
                                  }
                                >
                                  Cancelar
                                </Button>
                              </div>
                            </div>
                          ) : (
                            <Button
                              size="sm"
                              variant="outline"
                              disabled={
                                addingCredits ||
                                reseller.status !== 'ACTIVE'
                              }
                              onClick={() => {
                                setSelectedResellerId(reseller.id)
                                setCreditAmount('1')
                                setError('')
                                setSuccess('')
                              }}
                            >
                              + Créditos
                            </Button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

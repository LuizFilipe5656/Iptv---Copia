
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
  const [showForm, setShowForm] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [credits, setCredits] = useState('0')

  const loadResellers = useCallback(async () => {
    if (user?.role !== 'super_admin') return

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
  }, [user?.id, user?.role])

  useEffect(() => {
    void loadResellers()
  }, [loadResellers])

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault()

    if (saving) return

    setError('')
    setSuccess('')
    setSaving(true)

    try {
      const { data: sessionData, error: sessionError } =
        await supabase.auth.getSession()

      if (sessionError || !sessionData.session) {
        throw new Error('Faça login novamente.')
      }

      const response = await fetch(
        '/api/admin/resellers',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization:
              `Bearer ${sessionData.session.access_token}`,
          },
          body: JSON.stringify({
            name: name.trim(),
            email: email.trim(),
            password,
            credits: Number(credits),
          }),
        }
      )

      const result = await response.json()

      if (!response.ok) {
        if (result.created) {
          await loadResellers()
        }

        throw new Error(
          result.error || 'Erro ao criar revendedor.'
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
        err instanceof Error
          ? err.message
          : 'Erro inesperado.'
      )
    } finally {
      setSaving(false)
    }
  }

  const totalCredits = resellers.reduce(
    (sum, reseller) => sum + (reseller.credits ?? 0),
    0
  )

  return (
    <div className="min-h-screen bg-[#0a1220] p-8 text-white">
      <div className="mx-auto max-w-7xl">
        <div className="mb-8 flex flex-wrap items-center justify-between gap-4">
          <div>
            <h1 className="text-3xl font-bold">
              Gerenciar Revendedores
            </h1>
            <p className="mt-2 text-gray-400">
              Cadastre revendedores e acompanhe seus créditos.
            </p>
          </div>

          <div className="flex flex-wrap gap-2">
            <Button
              onClick={() => setShowForm(!showForm)}
            >
              {showForm ? 'Cancelar' : '+ Novo Revendedor'}
            </Button>

            <Button asChild variant="outline">
              <Link href="/admin">Voltar ao painel</Link>
            </Button>
          </div>
        </div>

        {error && (
          <div className="mb-4 rounded border border-red-800 bg-red-950 p-4 text-red-300">
            {error}
          </div>
        )}

        {success && (
          <div className="mb-4 rounded border border-green-800 bg-green-950 p-4 text-green-300">
            {success}
          </div>
        )}

        {showForm && (
          <Card className="mb-6 border-gray-800 bg-[#111c33]">
            <CardHeader>
              <CardTitle>Novo Revendedor</CardTitle>
            </CardHeader>

            <CardContent>
              <form
                onSubmit={handleCreate}
                className="grid gap-4 md:grid-cols-2"
              >
                <div>
                  <label className="mb-2 block text-sm">
                    Nome
                  </label>
                  <Input
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    required
                    minLength={2}
                    maxLength={120}
                  />
                </div>

                <div>
                  <label className="mb-2 block text-sm">
                    E-mail
                  </label>
                  <Input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                  />
                </div>

                <div>
                  <label className="mb-2 block text-sm">
                    Senha inicial
                  </label>
                  <Input
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    minLength={8}
                    maxLength={128}
                    autoComplete="new-password"
                    required
                  />
                </div>

                <div>
                  <label className="mb-2 block text-sm">
                    Créditos iniciais
                  </label>
                  <Input
                    type="number"
                    min={0}
                    max={1000000}
                    step={1}
                    value={credits}
                    onChange={(e) => setCredits(e.target.value)}
                    required
                  />
                </div>

                <div className="md:col-span-2">
                  <Button type="submit" disabled={saving}>
                    {saving
                      ? 'Criando revendedor...'
                      : 'Cadastrar Revendedor'}
                  </Button>
                </div>
              </form>
            </CardContent>
          </Card>
        )}

        <div className="mb-6 grid grid-cols-1 gap-4 md:grid-cols-2">
          <Card className="border-gray-800 bg-[#111c33]">
            <CardHeader>
              <CardTitle className="text-sm text-gray-400">
                Total de Revendedores
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold">
                {loading ? '...' : resellers.length}
              </p>
            </CardContent>
          </Card>

          <Card className="border-gray-800 bg-[#111c33]">
            <CardHeader>
              <CardTitle className="text-sm text-gray-400">
                Créditos Disponíveis
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold">
                {loading
                  ? '...'
                  : totalCredits.toLocaleString('pt-BR')}
              </p>
            </CardContent>
          </Card>
        </div>

        <Card className="border-gray-800 bg-[#111c33]">
          <CardHeader>
            <CardTitle>Revendedores</CardTitle>
          </CardHeader>

          <CardContent>
            {loading ? (
              <p>Carregando revendedores...</p>
            ) : resellers.length === 0 ? (
              <p className="text-gray-400">
                Nenhum revendedor cadastrado.
              </p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-sm">
                  <thead>
                    <tr className="border-b border-gray-700">
                      <th className="p-3">Nome</th>
                      <th className="p-3">E-mail</th>
                      <th className="p-3">Cargo</th>
                      <th className="p-3">Status</th>
                      <th className="p-3">Créditos</th>
                      <th className="p-3">Criado em</th>
                    </tr>
                  </thead>

                  <tbody>
                    {resellers.map((reseller) => (
                      <tr
                        key={reseller.id}
                        className="border-b border-gray-800"
                      >
                        <td className="p-3">
                          {reseller.name || '-'}
                        </td>
                        <td className="p-3">
                          {reseller.email}
                        </td>
                        <td className="p-3 text-blue-400">
                          REVENDEDOR
                        </td>
                        <td className="p-3">
                          {reseller.status}
                        </td>
                        <td className="p-3">
                          {reseller.credits ?? 0}
                        </td>
                        <td className="p-3">
                          {new Date(
                            reseller.created_at
                          ).toLocaleDateString('pt-BR')}
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

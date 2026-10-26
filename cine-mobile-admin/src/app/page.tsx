
'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { AdminRoute } from '@/components/layout/AdminRoute'
import { useAuth } from '@/contexts/AuthContext'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { supabase } from '@/lib/supabase'

export default function AdminPanel() {
  return (
    <AdminRoute>
      <AdminDashboard />
    </AdminRoute>
  )
}

function AdminDashboard() {
  const router = useRouter()
  const { user, logout } = useAuth()

  const [totalUsers, setTotalUsers] = useState(0)
  const [activeUsers, setActiveUsers] = useState(0)
  const [totalMovies, setTotalMovies] = useState<number | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let active = true

    async function loadDashboard() {
      setLoading(true)
      setError('')

      const [usersResult, activeResult, moviesResult] =
        await Promise.all([
          supabase
            .from('users')
            .select('*', { count: 'exact', head: true }),

          supabase
            .from('users')
            .select('*', { count: 'exact', head: true })
            .eq('status', 'ACTIVE'),

          supabase
            .from('movies')
            .select('*', { count: 'exact', head: true }),
        ])

      if (!active) return

      if (usersResult.error || activeResult.error) {
        setError('Não foi possível carregar os dados dos usuários.')
      } else {
        setTotalUsers(usersResult.count ?? 0)
        setActiveUsers(activeResult.count ?? 0)
      }

      // A tabela movies pode ainda não existir.
      if (!moviesResult.error) {
        setTotalMovies(moviesResult.count ?? 0)
      }

      setLoading(false)
    }

    if (user?.role === 'super_admin') {
      void loadDashboard()
    }

    return () => {
      active = false
    }
  }, [user?.id, user?.role])

  async function handleLogout() {
    try {
      await logout()
      router.replace('/login')
    } catch {
      setError('Não foi possível encerrar a sessão.')
    }
  }

  return (
    <div className="min-h-screen bg-[#0a1220] text-white p-6">
      {/* HEADER */}
      <div className="flex justify-between items-center mb-8 max-w-7xl mx-auto">
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            <span className="bg-blue-600 p-2 rounded">
              ▶
            </span>
            CINE MOBILE
            <span className="text-green-400 text-sm ml-2">
              ● Supabase
            </span>
          </h1>

          <p className="text-gray-400 text-sm">
            IPTV ADMIN PANEL • {user?.email}
          </p>
          <p className="text-blue-400 text-xs mt-1">
            Administrador Master
          </p>
        </div>

        <Button
          variant="outline"
          onClick={handleLogout}
          className="border-gray-700 text-white"
        >
          Sair
        </Button>
      </div>

      {error && (
        <div className="max-w-7xl mx-auto mb-4 rounded border border-red-800 bg-red-950 p-3 text-red-300">
          {error}
        </div>
      )}

      {/* DASHBOARD */}
      <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <Card className="bg-[#111c33] border-gray-800">
          <CardHeader>
            <CardTitle className="text-gray-400 text-sm">
              Total Users
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">
              {loading ? '...' : totalUsers.toLocaleString('pt-BR')}
            </p>
            <p className="text-blue-400 text-xs mt-1">
              Dados reais do Supabase
            </p>
          </CardContent>
        </Card>

        <Card className="bg-[#111c33] border-gray-800">
          <CardHeader>
            <CardTitle className="text-gray-400 text-sm">
              Active Users
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">
              {loading ? '...' : activeUsers.toLocaleString('pt-BR')}
            </p>
            <p className="text-green-400 text-xs mt-1">
              Contas com status ACTIVE
            </p>
          </CardContent>
        </Card>

        <Card className="bg-[#111c33] border-gray-800">
          <CardHeader>
            <CardTitle className="text-gray-400 text-sm">
              Movies na Nuvem
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">
              {loading
                ? '...'
                : totalMovies === null
                  ? '—'
                  : totalMovies.toLocaleString('pt-BR')}
            </p>
            <p className="text-blue-400 text-xs mt-1">
              {totalMovies === null
                ? 'Dados indisponíveis'
                : 'Dados do Supabase'}
            </p>
          </CardContent>
        </Card>

        <Card className="bg-[#111c33] border-gray-800">
          <CardHeader>
            <CardTitle className="text-gray-400 text-sm">
              Revenue
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-3xl font-bold">
              —
            </p>
            <p className="text-gray-400 text-xs mt-1">
              Aguardando integração financeira
            </p>
          </CardContent>
        </Card>
      </div>

      <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card className="bg-[#111c33] border-gray-800 md:col-span-2">
          <CardHeader>
            <CardTitle>Server Status</CardTitle>
          </CardHeader>

          <CardContent className="space-y-3 text-sm">
            <div className="flex justify-between gap-4">
              <span>Streaming Server</span>
              <span className="text-gray-400">
                Monitoramento não configurado
              </span>
            </div>

            <div className="flex justify-between gap-4">
              <span>Database</span>
              <span className="text-gray-400">
                Consulte o painel Supabase
              </span>
            </div>

            <div className="flex justify-between gap-4">
              <span>CDN</span>
              <span className="text-gray-400">
                Monitoramento não configurado
              </span>
            </div>
          </CardContent>
        </Card>

        <Card className="bg-[#111c33] border-gray-800">
          <CardHeader>
            <CardTitle>Gerenciamento</CardTitle>
          </CardHeader>

          <CardContent>
            <p className="text-gray-400 text-sm">
              Painel protegido para o Admin Master.
              Gerenciamento de usuários, revendedores
              e créditos será integrado às operações
              seguras do Supabase.
            </p>

            <Button
              className="mt-4 w-full"
              onClick={() => router.push('/admin')}
            >
              Gerenciar usuários
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

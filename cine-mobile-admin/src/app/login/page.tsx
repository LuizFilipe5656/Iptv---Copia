
'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/contexts/AuthContext'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'

export default function LoginPage() {
  const router = useRouter()
  const { login } = useAuth()

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      await login(email, password)

      const { data, error: sessionError } =
        await supabase.auth.getUser()

      if (sessionError || !data.user) {
        throw new Error('Sessão não encontrada')
      }

      const { data: profile, error: profileError } =
        await supabase
          .from('users')
          .select('role, status')
          .eq('id', data.user.id)
          .single()

      if (profileError || !profile) {
        throw new Error('Perfil não encontrado')
      }

      if (profile.status !== 'ACTIVE') {
        throw new Error('Conta bloqueada')
      }

      if (profile.role === 'super_admin') {
        router.replace('/admin')
      } else if (profile.role === 'reseller') {
        router.replace('/reseller')
      } else {
        router.replace('/')
      }
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : 'Erro ao fazer login'
      )
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">
            Login
          </CardTitle>
          <CardDescription>
            Entre com suas credenciais para acessar o painel
          </CardDescription>
        </CardHeader>

        <CardContent>
          <form
            onSubmit={handleSubmit}
            className="space-y-4"
          >
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="seu@email.com"
                autoComplete="email"
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="password">Senha</Label>
              <Input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Sua senha"
                autoComplete="current-password"
                required
              />
            </div>

            {error && (
              <p className="text-sm text-destructive">
                {error}
              </p>
            )}

            <Button
              type="submit"
              className="w-full"
              disabled={loading}
            >
              {loading ? 'Entrando...' : 'Entrar'}
            </Button>

            <div className="text-center text-sm">
              <Link
                href="/register"
                className="text-primary hover:underline"
              >
                Não tem uma conta? Registre-se
              </Link>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}

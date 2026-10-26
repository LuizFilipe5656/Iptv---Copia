
'use client'

import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import type {
  User,
  AuthContextType,
  RegisterData,
  ProfileData,
} from '@/types/user'

const AuthContext =
  createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({
  children,
}: {
  children: ReactNode
}) {
  const [user, setUser] = useState<User | null>(null)
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)

  async function fetchProfile(id: string): Promise<User> {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', id)
      .single()

    if (error) {
      throw new Error(
        'Não foi possível carregar o perfil: ' + error.message
      )
    }

    if (!data || data.status !== 'ACTIVE') {
      throw new Error('Sua conta está bloqueada ou sem perfil')
    }

    return data as User
  }

  useEffect(() => {
    let mounted = true
    let version = 0

    async function synchronize() {
      const currentVersion = ++version

      try {
        const { data, error } = await supabase.auth.getUser()

        if (error || !data.user) {
          if (mounted && currentVersion === version) {
            setUser(null)
            setSession(null)
          }
          return
        }

        const profile = await fetchProfile(data.user.id)
        const { data: sessionData } =
          await supabase.auth.getSession()

        if (mounted && currentVersion === version) {
          setUser(profile)
          setSession(sessionData.session)
        }
      } catch {
        if (mounted && currentVersion === version) {
          setUser(null)
          setSession(null)
        }
      } finally {
        if (mounted && currentVersion === version) {
          setLoading(false)
        }
      }
    }

    void synchronize()

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event) => {
      if (
        event === 'SIGNED_IN' ||
        event === 'SIGNED_OUT' ||
        event === 'USER_UPDATED'
      ) {
        // Evita chamadas assíncronas dentro do callback
        // do Supabase Auth.
        setTimeout(() => {
          if (mounted) void synchronize()
        }, 0)
      }
    })

    return () => {
      mounted = false
      version++
      subscription.unsubscribe()
    }
  }, [])

  async function login(email: string, password: string) {
    setLoading(true)

    try {
      const { data, error } =
        await supabase.auth.signInWithPassword({
          email,
          password,
        })

      if (error) throw error

      if (!data.user) {
        throw new Error('Não foi possível autenticar')
      }

      const profile = await fetchProfile(data.user.id)

      setUser(profile)
      setSession(data.session)
    } catch (error) {
      await supabase.auth.signOut()
      setUser(null)
      setSession(null)
      throw error
    } finally {
      setLoading(false)
    }
  }

  async function register({
    name,
    email,
    password,
  }: RegisterData) {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { name: name || '' },
      },
    })

    if (error) throw error

    // O cadastro público nunca envia um cargo.
    // O trigger do banco decide se é Master ou user.
    if (data.session) {
      await supabase.auth.signOut()
      setUser(null)
      setSession(null)
    }
  }

  async function logout() {
    const { error } = await supabase.auth.signOut()

    if (error) throw error

    setUser(null)
    setSession(null)
  }

  async function createUserProfile(
    _userId: string,
    _data: ProfileData
  ) {
    throw new Error(
      'A criação de perfis deve usar uma operação segura no servidor.'
    )
  }

  const isAdmin =
    user?.role === 'super_admin'

  const isReseller =
    user?.role === 'reseller' || isAdmin

  return (
    <AuthContext.Provider
      value={{
        user,
        session,
        loading,
        isAdmin,
        isReseller,
        login,
        register,
        logout,
        createUserProfile,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)

  if (!context) {
    throw new Error(
      'useAuth precisa estar dentro do AuthProvider'
    )
  }

  return context
}

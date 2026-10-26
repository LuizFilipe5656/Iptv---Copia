
'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/contexts/AuthContext'

export function AdminRoute({
  children,
}: {
  children: React.ReactNode
}) {
  const { user, loading, isAdmin } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (loading) return

    if (!user) {
      router.replace('/login')
    } else if (!isAdmin) {
      router.replace('/')
    }
  }, [user, loading, isAdmin, router])

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        Carregando...
      </div>
    )
  }

  if (!user || !isAdmin) return null

  return <>{children}</>
}

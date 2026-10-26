
'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/contexts/AuthContext'

export function ResellerRoute({
  children,
}: {
  children: React.ReactNode
}) {
  const { user, loading, isReseller } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (loading) return

    if (!user) {
      router.replace('/login')
    } else if (!isReseller) {
      router.replace('/')
    }
  }, [user, loading, isReseller, router])

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        Carregando...
      </div>
    )
  }

  if (!user || !isReseller) return null

  return <>{children}</>
}

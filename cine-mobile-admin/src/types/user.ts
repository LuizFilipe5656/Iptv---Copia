
import type { Session } from '@supabase/supabase-js'

export type UserRole =
  | 'super_admin'
  | 'admin'
  | 'reseller'
  | 'user'

export type UserStatus = 'ACTIVE' | 'BANNED'

export interface User {
  id: string
  email: string
  name?: string | null
  plan: string
  expiration_date: string
  status: UserStatus
  role: UserRole
  created_by?: string | null
  credits: number
  credits_used?: number
  created_at: string
}

export interface RegisterData {
  name?: string
  email: string
  password: string
}

export interface ProfileData {
  name?: string
  plan?: string
}

export interface UserProfile {
  user: User
  session: Session | null
}

export interface AuthContextType {
  user: User | null
  session: Session | null
  loading: boolean
  isAdmin: boolean
  isReseller: boolean
  login: (email: string, password: string) => Promise<void>
  register: (data: RegisterData) => Promise<void>
  logout: () => Promise<void>
  createUserProfile: (
    userId: string,
    data: ProfileData
  ) => Promise<void>
}

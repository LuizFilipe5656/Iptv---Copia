-- Enable RLS
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

-- Create users table
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT,
  plan TEXT DEFAULT 'FREE',
  expiration_date TIMESTAMPTZ DEFAULT now() + interval '3 days',
  status TEXT DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'BANNED')),
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin', 'reseller')),
  created_by UUID REFERENCES public.users(id),
  credits INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Create index on created_by for faster queries
CREATE INDEX IF NOT EXISTS idx_users_created_by ON public.users(created_by);

-- Create index on role for faster queries
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);

-- Create index on status for faster queries
CREATE INDEX IF NOT EXISTS idx_users_status ON public.users(status);

-- RLS Policies

-- Allow admins to do everything
CREATE POLICY "Admins can do everything"
  ON public.users
  FOR ALL
  USING (
    auth.uid() IN (
      SELECT id FROM public.users WHERE role = 'admin'
    )
  );

-- Allow resellers to select, insert, and update their own created users
CREATE POLICY "Resellers can manage their clients"
  ON public.users
  FOR SELECT
  USING (
    auth.uid() IN (
      SELECT id FROM public.users WHERE role IN ('reseller', 'admin')
    )
    AND (
      created_by = auth.uid()
      OR id = auth.uid()
    )
  );

CREATE POLICY "Resellers can insert their clients"
  ON public.users
  FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT id FROM public.users WHERE role IN ('reseller', 'admin')
    )
    AND created_by = auth.uid()
  );

CREATE POLICY "Resellers can update their clients"
  ON public.users
  FOR UPDATE
  USING (
    auth.uid() IN (
      SELECT id FROM public.users WHERE role IN ('reseller', 'admin')
    )
    AND (
      created_by = auth.uid()
      OR id = auth.uid()
    )
  );

-- Allow users to see only their own data
CREATE POLICY "Users can view own data"
  ON public.users
  FOR SELECT
  USING (id = auth.uid());

-- Allow users to update their own data
CREATE POLICY "Users can update own data"
  ON public.users
  FOR UPDATE
  USING (id = auth.uid());

-- Function to automatically create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, plan, expiration_date, status, role, credits)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    'FREE',
    now() + interval '3 days',
    'ACTIVE',
    'user',
    0
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call the function on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.users TO anon, authenticated;
GRANT ALL ON SEQUENCE public.users_id_seq TO anon, authenticated;

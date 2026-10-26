-- Execute no SQL Editor. Não altera permissões ou senhas.
CREATE UNIQUE INDEX IF NOT EXISTS users_username_unique_idx
ON public.users (lower(trim(username))) WHERE username IS NOT NULL AND trim(username) <> '';

CREATE TABLE IF NOT EXISTS public.username_login_attempts (
  username text PRIMARY KEY,
  attempts integer NOT NULL DEFAULT 0,
  window_started timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.username_login_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.username_login_attempts FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.allow_username_login_attempt(p_username text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE n integer;
BEGIN
  INSERT INTO public.username_login_attempts(username, attempts, window_started)
  VALUES (lower(trim(p_username)), 1, now())
  ON CONFLICT (username) DO UPDATE
  SET attempts = CASE
    WHEN username_login_attempts.window_started < now() - interval '15 minutes' THEN 1
    ELSE username_login_attempts.attempts + 1 END,
      window_started = CASE
    WHEN username_login_attempts.window_started < now() - interval '15 minutes' THEN now()
    ELSE username_login_attempts.window_started END
  RETURNING attempts INTO n;
  RETURN n <= 5;
END;
$$;
REVOKE ALL ON FUNCTION public.allow_username_login_attempt(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.allow_username_login_attempt(text) TO service_role;

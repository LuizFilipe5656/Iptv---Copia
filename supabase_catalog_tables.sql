-- ============================================
-- SETUP DAS TABELAS DE CATÁLOGO NO SUPABASE
-- ============================================

-- Criar tabela movies
CREATE TABLE IF NOT EXISTS public.movies (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    content_id TEXT NOT NULL UNIQUE,
    imdb_id TEXT,
    title TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'movie',
    overview TEXT,
    poster_url TEXT,
    banner_url TEXT,
    imdb_rating NUMERIC,
    release_year INTEGER,
    genres TEXT[] DEFAULT ARRAY[]::TEXT[],
    addon_sources TEXT[] DEFAULT ARRAY[]::TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Criar tabela series
CREATE TABLE IF NOT EXISTS public.series (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    content_id TEXT NOT NULL UNIQUE,
    imdb_id TEXT,
    title TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'series',
    overview TEXT,
    poster_url TEXT,
    banner_url TEXT,
    imdb_rating NUMERIC,
    release_year INTEGER,
    genres TEXT[] DEFAULT ARRAY[]::TEXT[],
    addon_sources TEXT[] DEFAULT ARRAY[]::TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_movies_content_id ON public.movies(content_id);
CREATE INDEX IF NOT EXISTS idx_movies_imdb_id ON public.movies(imdb_id);
CREATE INDEX IF NOT EXISTS idx_movies_title ON public.movies USING gin(to_tsvector('portuguese', title));
CREATE INDEX IF NOT EXISTS idx_movies_genres ON public.movies USING gin(genres);
CREATE INDEX IF NOT EXISTS idx_movies_addon_sources ON public.movies USING gin(addon_sources);
CREATE INDEX IF NOT EXISTS idx_movies_updated_at ON public.movies(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_series_content_id ON public.series(content_id);
CREATE INDEX IF NOT EXISTS idx_series_imdb_id ON public.series(imdb_id);
CREATE INDEX IF NOT EXISTS idx_series_title ON public.series USING gin(to_tsvector('portuguese', title));
CREATE INDEX IF NOT EXISTS idx_series_genres ON public.series USING gin(genres);
CREATE INDEX IF NOT EXISTS idx_series_addon_sources ON public.series USING gin(addon_sources);
CREATE INDEX IF NOT EXISTS idx_series_updated_at ON public.series(updated_at DESC);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION public.handle_catalog_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER movies_updated_at
    BEFORE UPDATE ON public.movies
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_catalog_updated_at();

CREATE TRIGGER series_updated_at
    BEFORE UPDATE ON public.series
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_catalog_updated_at();

-- ============================================
-- POLÍTICAS RLS (ROW LEVEL SECURITY)
-- ============================================

-- Habilitar RLS
ALTER TABLE public.movies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.series ENABLE ROW LEVEL SECURITY;

-- Política: Qualquer usuário autenticado pode ler
CREATE POLICY "Authenticated users can view movies"
    ON public.movies
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can view series"
    ON public.series
    FOR SELECT
    USING (auth.role() = 'authenticated');

-- Política: Apenas admins podem inserir
CREATE POLICY "Admins can insert movies"
    ON public.movies
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "Admins can insert series"
    ON public.series
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE id = auth.uid() AND is_active = true
        )
    );

-- Política: Apenas admins podem atualizar
CREATE POLICY "Admins can update movies"
    ON public.movies
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "Admins can update series"
    ON public.series
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE id = auth.uid() AND is_active = true
        )
    );

-- Política: Apenas admins podem deletar
CREATE POLICY "Admins can delete movies"
    ON public.movies
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE id = auth.uid() AND is_active = true
        )
    );

CREATE POLICY "Admins can delete series"
    ON public.series
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE id = auth.uid() AND is_active = true
        )
    );

-- ============================================
-- FUNÇÕES AUXILIARES
-- ============================================

-- Função para busca full-text em português
CREATE OR REPLACE FUNCTION public.search_movies(query TEXT)
RETURNS TABLE (
    id UUID,
    content_id TEXT,
    title TEXT,
    overview TEXT,
    poster_url TEXT,
    imdb_rating NUMERIC,
    release_year INTEGER,
    genres TEXT[],
    addon_sources TEXT[],
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.id,
        m.content_id,
        m.title,
        m.overview,
        m.poster_url,
        m.imdb_rating,
        m.release_year,
        m.genres,
        m.addon_sources,
        ts_rank(to_tsvector('portuguese', m.title), plainto_tsquery('portuguese', query)) as rank
    FROM public.movies m
    WHERE to_tsvector('portuguese', m.title) @@ plainto_tsquery('portuguese', query)
    ORDER BY rank DESC, m.imdb_rating DESC NULLS LAST
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.search_series(query TEXT)
RETURNS TABLE (
    id UUID,
    content_id TEXT,
    title TEXT,
    overview TEXT,
    poster_url TEXT,
    imdb_rating NUMERIC,
    release_year INTEGER,
    genres TEXT[],
    addon_sources TEXT[],
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id,
        s.content_id,
        s.title,
        s.overview,
        s.poster_url,
        s.imdb_rating,
        s.release_year,
        s.genres,
        s.addon_sources,
        ts_rank(to_tsvector('portuguese', s.title), plainto_tsquery('portuguese', query)) as rank
    FROM public.series s
    WHERE to_tsvector('portuguese', s.title) @@ plainto_tsquery('portuguese', query)
    ORDER BY rank DESC, s.imdb_rating DESC NULLS LAST
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- Função para buscar por gênero
CREATE OR REPLACE FUNCTION public.get_movies_by_genre(genre TEXT)
RETURNS SETOF public.movies AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM public.movies
    WHERE genre = ANY(genres)
    ORDER BY imdb_rating DESC NULLS LAST, updated_at DESC
    LIMIT 100;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_series_by_genre(genre TEXT)
RETURNS SETOF public.series AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM public.series
    WHERE genre = ANY(genres)
    ORDER BY imdb_rating DESC NULLS LAST, updated_at DESC
    LIMIT 100;
END;
$$ LANGUAGE plpgsql;

-- Função para buscar por addon source
CREATE OR REPLACE FUNCTION public.get_movies_by_addon(addon_id TEXT)
RETURNS SETOF public.movies AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM public.movies
    WHERE addon_id = ANY(addon_sources)
    ORDER BY updated_at DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_series_by_addon(addon_id TEXT)
RETURNS SETOF public.series AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM public.series
    WHERE addon_id = ANY(addon_sources)
    ORDER BY updated_at DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VIEWS ÚTEIS
-- ============================================

-- View com filmes populares (altamente avaliados)
CREATE OR REPLACE VIEW public.popular_movies AS
SELECT * FROM public.movies
WHERE imdb_rating >= 7.0
ORDER BY imdb_rating DESC NULLS LAST, updated_at DESC
LIMIT 100;

-- View com séries populares (altamente avaliadas)
CREATE OR REPLACE VIEW public.popular_series AS
SELECT * FROM public.series
WHERE imdb_rating >= 7.0
ORDER BY imdb_rating DESC NULLS LAST, updated_at DESC
LIMIT 100;

-- View com conteúdo recente
CREATE OR REPLACE VIEW public.recent_content AS
SELECT
    'movie' as content_type,
    id,
    content_id,
    title,
    overview,
    poster_url,
    imdb_rating,
    release_year,
    genres,
    addon_sources,
    updated_at
FROM public.movies
UNION ALL
SELECT
    'series' as content_type,
    id,
    content_id,
    title,
    overview,
    poster_url,
    imdb_rating,
    release_year,
    genres,
    addon_sources,
    updated_at
FROM public.series
ORDER BY updated_at DESC
LIMIT 200;

-- =========================================================================
-- MUDANÇAS NA TABELA MEMBROS (CORREÇÃO DE ERRO DE SALVAMENTO)
-- Copie todo o código abaixo, acesse o painel do Supabase, vá em "SQL Editor"
-- e execute esta query para garantir as colunas e permissões necessárias.
-- =========================================================================

-- 1. Garante que as novas colunas existam (evita erro de coluna não encontrada)
DO $$ 
BEGIN
    BEGIN
        ALTER TABLE public.membros ADD COLUMN email TEXT;
    EXCEPTION WHEN duplicate_column THEN END;

    BEGIN
        ALTER TABLE public.membros ADD COLUMN nascimento TEXT;
    EXCEPTION WHEN duplicate_column THEN END;

    BEGIN
        ALTER TABLE public.membros ADD COLUMN escala_trabalho TEXT;
    EXCEPTION WHEN duplicate_column THEN END;

    BEGIN
        ALTER TABLE public.membros ADD COLUMN funcao TEXT;
    EXCEPTION WHEN duplicate_column THEN END;

    BEGIN
        ALTER TABLE public.membros ADD COLUMN dias_indisponiveis TEXT;
    EXCEPTION WHEN duplicate_column THEN END;
END $$;

-- 2. Concede permissões na tabela
GRANT ALL ON TABLE public.membros TO anon, authenticated, service_role;

-- 3. Habilita RLS (Row Level Security) e cria política permitindo inserção/edição
ALTER TABLE public.membros ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir tudo anon membros" ON public.membros;
CREATE POLICY "Permitir tudo anon membros" ON public.membros FOR ALL USING (true) WITH CHECK (true);

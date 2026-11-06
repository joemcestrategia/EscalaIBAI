-- =========================================================================
-- CRIAÇÃO DA TABELA DE COMPATIBILIDADE DE FUNÇÕES
-- Copie todo o código abaixo, acesse o painel do Supabase, vá em "SQL Editor"
-- e execute esta query para criar a tabela de regras de acúmulo de função.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.cfg_compatibilidades (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ministerio TEXT NOT NULL,
    funcao1 TEXT NOT NULL,
    funcao2 TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pendente', -- 'pendente', 'aprovado', 'rejeitado'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    -- Garante que o par seja único por ministério para evitar duplicidades
    UNIQUE (ministerio, funcao1, funcao2)
);

-- Concede permissões na tabela
GRANT ALL ON TABLE public.cfg_compatibilidades TO anon, authenticated, service_role;

-- Habilita RLS (Row Level Security) e cria política permitindo inserção/edição
ALTER TABLE public.cfg_compatibilidades ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir tudo anon cfg_compatibilidades" ON public.cfg_compatibilidades;
CREATE POLICY "Permitir tudo anon cfg_compatibilidades" ON public.cfg_compatibilidades FOR ALL USING (true) WITH CHECK (true);

-- =========================================================================
-- CRIAÇÃO DA TABELA DE CONFIGURAÇÃO DO JEJUM
-- Copie todo o código abaixo, acesse o painel do Supabase, vá em "SQL Editor"
-- e execute esta query para criar a tabela de configuração do Jejum.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.cfg_jejum (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    qtd_membros INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insere um valor padrão caso não exista
INSERT INTO public.cfg_jejum (qtd_membros) 
SELECT 1 WHERE NOT EXISTS (SELECT 1 FROM public.cfg_jejum);

-- Concede permissões na tabela
GRANT ALL ON TABLE public.cfg_jejum TO anon, authenticated, service_role;

-- Habilita RLS e cria política
ALTER TABLE public.cfg_jejum ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir tudo anon cfg_jejum" ON public.cfg_jejum;
CREATE POLICY "Permitir tudo anon cfg_jejum" ON public.cfg_jejum FOR ALL USING (true) WITH CHECK (true);

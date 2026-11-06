-- ========================================================
-- TABELA DE VERSÕES PARA O SISTEMA DE ATUALIZAÇÃO OTA
-- ========================================================

CREATE TABLE IF NOT EXISTS app_versions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  platform TEXT NOT NULL DEFAULT 'android',
  version_name TEXT NOT NULL,                  -- Ex: '1.0.1'
  version_code INT NOT NULL,                   -- Ex: 2 (o build number do pubspec.yaml)
  apk_url TEXT NOT NULL,                       -- URL do asset no GitHub Release
  changelog TEXT,                              -- Descrição do que há de novo nesta versão
  force_update BOOLEAN NOT NULL DEFAULT false, -- Se true, obriga a atualizar para prosseguir
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Ativa o RLS (Row Level Security)
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;

-- Leitura pública para que qualquer app consiga checar se há atualização
CREATE POLICY "Permitir leitura pública de app_versions" 
  ON app_versions FOR SELECT 
  USING (true);

-- Permissões de inserção e atualização
CREATE POLICY "Permitir inserção de app_versions" 
  ON app_versions FOR INSERT 
  WITH CHECK (true);

CREATE POLICY "Permitir atualização de app_versions" 
  ON app_versions FOR UPDATE 
  USING (true);


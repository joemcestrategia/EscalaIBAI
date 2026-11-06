-- =========================================================================
-- SCRIPT SUPABASE COMPLETO: CRIAÇÃO DE TABELAS + PERMISSÕES + CACHE
-- =========================================================================
-- Copie TODO o código abaixo e execute no SQL Editor do Supabase.

-- 1. CRIAÇÃO DAS TABELAS (Caso não existam)

CREATE TABLE IF NOT EXISTS membros (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  email TEXT,
  nascimento TEXT,
  ministerio TEXT NOT NULL,
  funcao TEXT,
  escala_trabalho TEXT,
  dias_indisponiveis TEXT,
  status_ativo BOOLEAN NOT NULL DEFAULT true,
  observacoes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS cfg_cultos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  dia_semana TEXT NOT NULL,
  horario TEXT NOT NULL,
  tema TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS cfg_ministerios (
  nome TEXT PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS cfg_funcoes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ministerio_pai TEXT NOT NULL REFERENCES cfg_ministerios(nome) ON DELETE CASCADE,
  nome_funcao TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS cfg_regras (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  dia_semana TEXT NOT NULL,
  horario TEXT NOT NULL,
  ministerio TEXT NOT NULL REFERENCES cfg_ministerios(nome) ON DELETE CASCADE,
  funcao TEXT NOT NULL,
  qtd INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS musicas (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  titulo TEXT NOT NULL,
  artista TEXT NOT NULL,
  tom_original TEXT,
  bpm INTEGER,
  link_youtube TEXT,
  cifra_url TEXT,
  tags JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS repertorios (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  data_culto TEXT NOT NULL,
  hora_culto TEXT NOT NULL,
  lista_musicas JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(data_culto, hora_culto)
);

CREATE TABLE IF NOT EXISTS escala (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  data TEXT NOT NULL,
  dia_semana TEXT NOT NULL,
  horario TEXT NOT NULL,
  ministerio TEXT NOT NULL,
  nome TEXT NOT NULL,
  funcao TEXT NOT NULL,
  tema TEXT,
  status_convite TEXT DEFAULT 'Pendente',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS ausencias (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  membro_nome TEXT NOT NULL,
  data_inicio TEXT NOT NULL,
  data_fim TEXT NOT NULL,
  motivo TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. DADOS INICIAIS PADRÃO
INSERT INTO cfg_ministerios (nome) VALUES ('Louvor'), ('Mídia e Transmissão'), ('Recepção') ON CONFLICT DO NOTHING;
INSERT INTO cfg_cultos (dia_semana, horario, tema) VALUES ('Domingo', '18:00', 'Culto da Família') ON CONFLICT DO NOTHING;
INSERT INTO cfg_funcoes (ministerio_pai, nome_funcao) VALUES 
('Louvor', 'Ministro(a)'), ('Louvor', 'Bateria'), ('Louvor', 'Teclado'),
('Mídia e Transmissão', 'Câmera'), ('Mídia e Transmissão', 'Projeção (Letras)') ON CONFLICT DO NOTHING;

-- 3. PERMISSÕES DE SCHEMA E TABELAS
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

-- 4. POLÍTICAS RLS LIVRES
ALTER TABLE membros ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon membros" ON membros;
CREATE POLICY "Permitir tudo anon membros" ON membros FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE cfg_cultos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon cfg_cultos" ON cfg_cultos;
CREATE POLICY "Permitir tudo anon cfg_cultos" ON cfg_cultos FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE cfg_ministerios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon cfg_ministerios" ON cfg_ministerios;
CREATE POLICY "Permitir tudo anon cfg_ministerios" ON cfg_ministerios FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE cfg_funcoes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon cfg_funcoes" ON cfg_funcoes;
CREATE POLICY "Permitir tudo anon cfg_funcoes" ON cfg_funcoes FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE cfg_regras ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon cfg_regras" ON cfg_regras;
CREATE POLICY "Permitir tudo anon cfg_regras" ON cfg_regras FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE musicas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon musicas" ON musicas;
CREATE POLICY "Permitir tudo anon musicas" ON musicas FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE repertorios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon repertorios" ON repertorios;
CREATE POLICY "Permitir tudo anon repertorios" ON repertorios FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE escala ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon escala" ON escala;
CREATE POLICY "Permitir tudo anon escala" ON escala FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE ausencias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon ausencias" ON ausencias;
CREATE POLICY "Permitir tudo anon ausencias" ON ausencias FOR ALL USING (true) WITH CHECK (true);

-- 5. RECARREGAR O CACHE DO POSTGREST
NOTIFY pgrst, 'reload schema';

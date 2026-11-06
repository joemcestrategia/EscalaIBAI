-- =========================================================================
-- ESQUEMA DO BANCO DE DADOS: IGREJA ADMIN
-- =========================================================================
-- Para instalar, copie e cole TODO o conteúdo deste arquivo 
-- no SQL Editor do Supabase e clique em "Run" (Executar).

-- 1. TABELA DE MEMBROS
CREATE TABLE IF NOT EXISTS membros (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  nascimento TEXT,
  ministerio TEXT NOT NULL,
  funcao TEXT NOT NULL, -- Armazena funções separadas por vírgula
  dias_indisponiveis TEXT NOT NULL DEFAULT '',
  escala_trabalho TEXT NOT NULL DEFAULT '',
  email TEXT,
  status_ativo BOOLEAN NOT NULL DEFAULT true,
  observacoes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. TABELA DE AGENDA (Cultos, Eventos e Reuniões)
CREATE TABLE IF NOT EXISTS agenda_igreja (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tipo TEXT NOT NULL, -- 'culto', 'evento', 'reuniao'
  titulo TEXT NOT NULL,
  data_especifica DATE, -- Apenas para eventos únicos
  horario TIME NOT NULL,
  dia_semana INTEGER, -- 0 (Dom) a 6 (Sáb)
  recorrencia_tipo TEXT NOT NULL, -- 'semanal', 'mensalPosicao', 'unico'
  recorrencia_valor INTEGER, -- 1 (1º), 2 (2º), -1 (Último)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. TABELA DE CULTOS (Configurações legadas - mantidas para compatibilidade se necessário)
CREATE TABLE IF NOT EXISTS cfg_cultos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  dia_semana TEXT NOT NULL,
  horario TEXT NOT NULL,
  tema TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. TABELA DE MINISTÉRIOS (Configurações)
CREATE TABLE IF NOT EXISTS cfg_ministerios (
  nome TEXT PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. TABELA DE FUNÇÕES (Configurações)
CREATE TABLE IF NOT EXISTS cfg_funcoes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ministerio_pai TEXT NOT NULL REFERENCES cfg_ministerios(nome) ON DELETE CASCADE,
  nome_funcao TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. TABELA DE REGRAS DE ESCALA (Configurações)
CREATE TABLE IF NOT EXISTS cfg_regras (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  dia_semana TEXT NOT NULL,
  horario TEXT NOT NULL,
  ministerio TEXT NOT NULL REFERENCES cfg_ministerios(nome) ON DELETE CASCADE,
  funcao TEXT NOT NULL,
  qtd INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. TABELA DE MÚSICAS (Catálogo Central)
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

-- 8. TABELA DE REPERTÓRIOS (Setlists de Cultos Específicos)
CREATE TABLE IF NOT EXISTS repertorios (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  data_culto TEXT NOT NULL, -- formato YYYY-MM-DD
  hora_culto TEXT NOT NULL, -- formato HH:MM
  lista_musicas JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array com IDs e Tom
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(data_culto, hora_culto)
);

-- 9. TABELA DA ESCALA PRINCIPAL
CREATE TABLE IF NOT EXISTS escala (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  data TEXT NOT NULL, -- YYYY-MM-DD
  dia_semana TEXT NOT NULL,
  horario TEXT NOT NULL,
  ministerio TEXT NOT NULL,
  nome TEXT NOT NULL,
  funcao TEXT NOT NULL,
  tema TEXT,
  status_convite TEXT DEFAULT 'Pendente',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 10. TABELA DE AUSÊNCIAS (Para bloqueio temporário na escala)
CREATE TABLE IF NOT EXISTS ausencias (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nome TEXT NOT NULL,
  data TEXT NOT NULL, -- Formato YYYY-MM-DD
  motivo TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 11. TABELA DE COMPATIBILIDADES (Regras de Acúmulo de Função)
CREATE TABLE IF NOT EXISTS cfg_compatibilidades (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ministerio TEXT NOT NULL,
  funcao1 TEXT NOT NULL,
  funcao2 TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pendente',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(ministerio, funcao1, funcao2)
);

-- 12. TABELA DE CONFIGURAÇÃO DE JEJUM
CREATE TABLE IF NOT EXISTS cfg_jejum (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  qtd_membros INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);


-- =========================================================================
-- CONFIGURAÇÕES DE ACESSO (RLS) - COMO NÃO HÁ LOGIN, PERMITIR ACESSO ANÔNIMO
-- =========================================================================
-- AVISO: Isso deixa suas tabelas públicas. Para esse aplicativo, que opera 
-- via anonKey diretamente nos dispositivos autorizados, isso é esperado.

-- Membros
ALTER TABLE membros ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público membros" ON membros;
CREATE POLICY "Acesso público membros" ON membros FOR ALL USING (true) WITH CHECK (true);

-- Cfg Cultos
ALTER TABLE cfg_cultos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público cfg_cultos" ON cfg_cultos;
CREATE POLICY "Acesso público cfg_cultos" ON cfg_cultos FOR ALL USING (true) WITH CHECK (true);

-- Cfg Ministérios
ALTER TABLE cfg_ministerios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público cfg_ministerios" ON cfg_ministerios;
CREATE POLICY "Acesso público cfg_ministerios" ON cfg_ministerios FOR ALL USING (true) WITH CHECK (true);

-- Cfg Funções
ALTER TABLE cfg_funcoes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público cfg_funcoes" ON cfg_funcoes;
CREATE POLICY "Acesso público cfg_funcoes" ON cfg_funcoes FOR ALL USING (true) WITH CHECK (true);

-- Cfg Regras
ALTER TABLE cfg_regras ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público cfg_regras" ON cfg_regras;
CREATE POLICY "Acesso público cfg_regras" ON cfg_regras FOR ALL USING (true) WITH CHECK (true);

-- Músicas
ALTER TABLE musicas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público musicas" ON musicas;
CREATE POLICY "Acesso público musicas" ON musicas FOR ALL USING (true) WITH CHECK (true);

-- Repertórios
ALTER TABLE repertorios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público repertorios" ON repertorios;
CREATE POLICY "Acesso público repertorios" ON repertorios FOR ALL USING (true) WITH CHECK (true);

-- Escala
ALTER TABLE escala ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público escala" ON escala;
CREATE POLICY "Acesso público escala" ON escala FOR ALL USING (true) WITH CHECK (true);

-- Ausências
ALTER TABLE ausencias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público ausencias" ON ausencias;
CREATE POLICY "Acesso público ausencias" ON ausencias FOR ALL USING (true) WITH CHECK (true);

-- Agenda Igreja
ALTER TABLE agenda_igreja ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público agenda_igreja" ON agenda_igreja;
CREATE POLICY "Acesso público agenda_igreja" ON agenda_igreja FOR ALL USING (true) WITH CHECK (true);

-- Cfg Compatibilidades
ALTER TABLE cfg_compatibilidades ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público cfg_compatibilidades" ON cfg_compatibilidades;
CREATE POLICY "Acesso público cfg_compatibilidades" ON cfg_compatibilidades FOR ALL USING (true) WITH CHECK (true);

-- Cfg Jejum
ALTER TABLE cfg_jejum ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público cfg_jejum" ON cfg_jejum;
CREATE POLICY "Acesso público cfg_jejum" ON cfg_jejum FOR ALL USING (true) WITH CHECK (true);

-- =========================================================================
-- DADOS INICIAIS (Opcional - Exemplo)
-- =========================================================================
INSERT INTO cfg_ministerios (nome) VALUES ('Louvor'), ('Mídia e Transmissão'), ('Recepção') ON CONFLICT DO NOTHING;
INSERT INTO cfg_cultos (dia_semana, horario, tema) VALUES ('Domingo', '18:00', 'Culto da Família') ON CONFLICT DO NOTHING;
INSERT INTO cfg_funcoes (ministerio_pai, nome_funcao) VALUES 
('Louvor', 'Ministro(a)'), ('Louvor', 'Bateria'), ('Louvor', 'Teclado'),
('Mídia e Transmissão', 'Câmera'), ('Mídia e Transmissão', 'Projeção (Letras)') ON CONFLICT DO NOTHING;

-- Exemplos de Regras de Escala
INSERT INTO cfg_regras (dia_semana, horario, ministerio, funcao, qtd) VALUES 
('Domingo', '18:00', 'Louvor', 'Ministro(a)', 1),
('Domingo', '18:00', 'Louvor', 'Bateria', 1),
('Domingo', '18:00', 'Louvor', 'Teclado', 1),
('Domingo', '18:00', 'Mídia e Transmissão', 'Projeção (Letras)', 1) ON CONFLICT DO NOTHING;

-- Exemplo de Membro
INSERT INTO membros (nome, ministerio, funcao) VALUES 
('Membro Exemplo', 'Louvor', 'Ministro(a), Teclado') ON CONFLICT DO NOTHING;

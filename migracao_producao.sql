-- =========================================================================
-- SCRIPT DE MIGRAÇÃO: ADAPTAÇÃO PARA NOVA ESTRUTURA (PRODUÇÃO)
-- =========================================================================
-- Este script adapta os dados existentes sem apagar as tabelas.

-- 1. ADAPTAR TABELA DE MEMBROS
DO $$ 
BEGIN 
    -- Adiciona colunas se não existirem
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='membros' AND COLUMN_NAME='funcao') THEN
        ALTER TABLE membros ADD COLUMN funcao TEXT NOT NULL DEFAULT '';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='membros' AND COLUMN_NAME='nascimento') THEN
        ALTER TABLE membros ADD COLUMN nascimento TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='membros' AND COLUMN_NAME='escala_trabalho') THEN
        ALTER TABLE membros ADD COLUMN escala_trabalho TEXT NOT NULL DEFAULT '';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='membros' AND COLUMN_NAME='email') THEN
        ALTER TABLE membros ADD COLUMN email TEXT;
    END IF;

    -- Tenta migrar dados de 'funcoes' (JSONB) para 'funcao' (TEXT) se houver dados
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='membros' AND COLUMN_NAME='funcoes') THEN
        UPDATE membros SET funcao = (
            SELECT string_agg(val, ', ') 
            FROM jsonb_array_elements_text(funcoes) val
        ) WHERE funcao = '' AND funcoes IS NOT NULL;
    END IF;

    -- Tenta migrar dados de 'dias_indisponiveis' (JSONB) para o formato TEXT (JSON string ou comma list)
    -- Para simplificar, vamos apenas converter o JSONB para TEXT
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='membros' AND COLUMN_NAME='dias_indisponiveis' AND DATA_TYPE='jsonb') THEN
        ALTER TABLE membros ALTER COLUMN dias_indisponiveis TYPE TEXT USING dias_indisponiveis::text;
    END IF;
END $$;

-- 2. ADAPTAR TABELA DE AUSÊNCIAS
DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='ausencias' AND COLUMN_NAME='membro_nome') THEN
        ALTER TABLE ausencias RENAME COLUMN membro_nome TO nome;
    END IF;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='ausencias' AND COLUMN_NAME='data_inicio') THEN
        ALTER TABLE ausencias RENAME COLUMN data_inicio TO data;
    END IF;
END $$;

-- 3. CRIAR TABELA DE AGENDA E MIGRAR CULTOS
CREATE TABLE IF NOT EXISTS agenda_igreja (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tipo TEXT NOT NULL,
  titulo TEXT NOT NULL,
  data_especifica DATE,
  horario TIME NOT NULL,
  dia_semana INTEGER,
  recorrencia_tipo TEXT NOT NULL,
  recorrencia_valor INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Migrar de cfg_cultos para agenda_igreja (Apenas se a agenda estiver vazia)
INSERT INTO agenda_igreja (tipo, titulo, horario, dia_semana, recorrencia_tipo)
SELECT 
    'culto', 
    COALESCE(tema, 'Culto'), 
    horario::TIME, 
    CASE 
        WHEN dia_semana = 'Domingo' THEN 0
        WHEN dia_semana = 'Segunda' THEN 1
        WHEN dia_semana = 'Terça' THEN 2
        WHEN dia_semana = 'Quarta' THEN 3
        WHEN dia_semana = 'Quinta' THEN 4
        WHEN dia_semana = 'Sexta' THEN 5
        WHEN dia_semana = 'Sábado' THEN 6
        ELSE 0
    END,
    'semanal'
FROM cfg_cultos
WHERE NOT EXISTS (SELECT 1 FROM agenda_igreja LIMIT 1);

-- 4. GARANTIR OUTRAS TABELAS NOVAS
CREATE TABLE IF NOT EXISTS cfg_compatibilidades (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ministerio TEXT NOT NULL,
  funcao1 TEXT NOT NULL,
  funcao2 TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pendente',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(ministerio, funcao1, funcao2)
);

CREATE TABLE IF NOT EXISTS cfg_jejum (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  qtd_membros INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. ATUALIZAR POLÍTICAS
ALTER TABLE membros ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público membros" ON membros;
CREATE POLICY "Acesso público membros" ON membros FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE agenda_igreja ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público agenda_igreja" ON agenda_igreja;
CREATE POLICY "Acesso público agenda_igreja" ON agenda_igreja FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE ausencias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público ausencias" ON ausencias;
CREATE POLICY "Acesso público ausencias" ON ausencias FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE cfg_compatibilidades ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público cfg_compatibilidades" ON cfg_compatibilidades;
CREATE POLICY "Acesso público cfg_compatibilidades" ON cfg_compatibilidades FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE cfg_jejum ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acesso público cfg_jejum" ON cfg_jejum;
CREATE POLICY "Acesso público cfg_jejum" ON cfg_jejum FOR ALL USING (true) WITH CHECK (true);

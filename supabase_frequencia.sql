-- =========================================================================
-- TABELA DE FREQUÊNCIA E FALTAS DOS MEMBROS (LIDERANÇA)
-- =========================================================================
-- Execute este script no SQL Editor do Supabase para habilitar o fluxo
-- completo de registro de faltas, justificativas e eventos avulsos
-- (ensaios, reuniões e cultos).

CREATE TABLE IF NOT EXISTS frequencia_membros (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  membro_id UUID REFERENCES membros(id) ON DELETE SET NULL,
  membro_nome TEXT NOT NULL,
  ministerio TEXT NOT NULL,
  escala_id UUID REFERENCES escala(id) ON DELETE SET NULL,
  data TEXT NOT NULL, -- Formato YYYY-MM-DD
  horario TEXT NOT NULL DEFAULT '',
  tipo_atividade TEXT NOT NULL DEFAULT 'Culto', -- 'Culto', 'Ensaio', 'Reunião', 'Evento'
  descricao_atividade TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL, -- 'PRESENTE', 'FALTA', 'FALTA_JUSTIFICADA'
  motivo TEXT NOT NULL DEFAULT '',
  registrado_por TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Garante no máximo 1 registro de frequência vinculado a cada item da escala
CREATE UNIQUE INDEX IF NOT EXISTS uq_frequencia_escala_id
  ON frequencia_membros (escala_id)
  WHERE escala_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_frequencia_data
  ON frequencia_membros (data);

CREATE INDEX IF NOT EXISTS idx_frequencia_membro_nome
  ON frequencia_membros (membro_nome);

GRANT ALL ON TABLE frequencia_membros TO anon, authenticated, service_role;

ALTER TABLE frequencia_membros ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon frequencia_membros" ON frequencia_membros;
CREATE POLICY "Permitir tudo anon frequencia_membros"
  ON frequencia_membros
  FOR ALL
  USING (true)
  WITH CHECK (true);

NOTIFY pgrst, 'reload schema';


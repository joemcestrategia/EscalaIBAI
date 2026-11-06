-- Cria a tabela de tokens de push para membros
CREATE TABLE IF NOT EXISTS membro_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  membro_id UUID NOT NULL REFERENCES membros(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  plataforma TEXT NOT NULL, -- 'android' ou 'web'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(membro_id, token) -- Um token não pode ser repetido para o mesmo membro
);

-- Ativa o RLS (Row Level Security) mas permite acesso total (pois já temos RLS simplificado)
ALTER TABLE membro_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir leitura total de membro_tokens" ON membro_tokens FOR SELECT USING (true);
CREATE POLICY "Permitir inserção total de membro_tokens" ON membro_tokens FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir atualização total de membro_tokens" ON membro_tokens FOR UPDATE USING (true);
CREATE POLICY "Permitir exclusão total de membro_tokens" ON membro_tokens FOR DELETE USING (true);

-- Adiciona colunas faltantes na tabela escala que o código Dart espera
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='escala' AND column_name='titulo_mensagem') THEN
        ALTER TABLE escala ADD COLUMN titulo_mensagem TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='escala' AND column_name='texto_biblico') THEN
        ALTER TABLE escala ADD COLUMN texto_biblico TEXT;
    END IF;
END $$;

-- Garante que a coluna status_convite tenha um padrão se for nula
ALTER TABLE escala ALTER COLUMN status_convite SET DEFAULT 'Pendente';
UPDATE escala SET status_convite = 'Pendente' WHERE status_convite IS NULL;

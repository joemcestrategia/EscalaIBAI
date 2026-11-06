-- 1. Criar a nova tabela de agenda unificada
CREATE TABLE IF NOT EXISTS agenda_igreja (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo TEXT NOT NULL CHECK (tipo IN ('culto', 'evento', 'reuniao')),
    titulo TEXT NOT NULL,
    data_especifica DATE,
    horario TIME NOT NULL,
    dia_semana INTEGER, -- 0-6 (0=Domingo, 6=Sábado)
    recorrencia_tipo TEXT NOT NULL CHECK (recorrencia_tipo IN ('semanal', 'mensal_posicao', 'unico')),
    recorrencia_valor INTEGER, -- 1=primeiro, 2=segundo, -1=ultimo (usado para mensal_posicao)
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Migrar dados da antiga tabela cfg_cultos para agenda_igreja
-- Nota: Estamos convertendo o nome do dia para o índice numérico
INSERT INTO agenda_igreja (tipo, titulo, horario, dia_semana, recorrencia_tipo, created_at)
SELECT 
    'culto', 
    tema, 
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
    'semanal',
    created_at
FROM cfg_cultos;

-- 3. (Opcional) Você pode renomear a tabela antiga ou mantê-la como backup
-- ALTER TABLE cfg_cultos RENAME TO cfg_cultos_old;

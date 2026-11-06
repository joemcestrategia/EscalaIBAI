-- Restaura membros a partir do histórico de escalas
-- Insere apenas nomes que ainda não existem na tabela de membros
INSERT INTO membros (nome, ministerio, funcao, dias_indisponiveis, escala_trabalho)
SELECT DISTINCT 
    nome, 
    ministerio, 
    funcao, 
    '', 
    'Sem restrição'
FROM escala
WHERE nome IS NOT NULL 
  AND nome != '[FALTA]'
  AND nome != ''
  AND NOT EXISTS (
      SELECT 1 FROM membros WHERE membros.nome = escala.nome
  );

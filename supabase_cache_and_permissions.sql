-- =========================================================================
-- SCRIPT DE CORREÇÃO: CACHE DO SCHEMA, PERMISSÕES E RLS
-- =========================================================================
-- Copie todo este código e execute-o no "SQL Editor" do painel do Supabase.

-- 1. FORÇAR RECARREGAMENTO DO CACHE DO POSTGREST (ESSENCIAL PARA PGRST205)
NOTIFY pgrst, 'reload schema';

-- 2. GARANTIR PERMISSÕES DE ACESSO PARA A API ANÔNIMA (anon) E AUTENTICADA (authenticated)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

-- 3. ASSEGURAR QUE AS POLÍTICAS DE RLS PERMITAM O ACESSO ABERTO (USO COM ANON KEY)
-- Para cada uma das tabelas do sistema:

-- membros
ALTER TABLE IF EXISTS membros ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon membros" ON membros;
CREATE POLICY "Permitir tudo anon membros" ON membros FOR ALL USING (true) WITH CHECK (true);

-- cfg_cultos
ALTER TABLE IF EXISTS cfg_cultos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon cfg_cultos" ON cfg_cultos;
CREATE POLICY "Permitir tudo anon cfg_cultos" ON cfg_cultos FOR ALL USING (true) WITH CHECK (true);

-- cfg_ministerios
ALTER TABLE IF EXISTS cfg_ministerios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon cfg_ministerios" ON cfg_ministerios;
CREATE POLICY "Permitir tudo anon cfg_ministerios" ON cfg_ministerios FOR ALL USING (true) WITH CHECK (true);

-- cfg_funcoes
ALTER TABLE IF EXISTS cfg_funcoes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon cfg_funcoes" ON cfg_funcoes;
CREATE POLICY "Permitir tudo anon cfg_funcoes" ON cfg_funcoes FOR ALL USING (true) WITH CHECK (true);

-- cfg_regras
ALTER TABLE IF EXISTS cfg_regras ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon cfg_regras" ON cfg_regras;
CREATE POLICY "Permitir tudo anon cfg_regras" ON cfg_regras FOR ALL USING (true) WITH CHECK (true);

-- musicas
ALTER TABLE IF EXISTS musicas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon musicas" ON musicas;
CREATE POLICY "Permitir tudo anon musicas" ON musicas FOR ALL USING (true) WITH CHECK (true);

-- repertorios
ALTER TABLE IF EXISTS repertorios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon repertorios" ON repertorios;
CREATE POLICY "Permitir tudo anon repertorios" ON repertorios FOR ALL USING (true) WITH CHECK (true);

-- escala
ALTER TABLE IF EXISTS escala ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon escala" ON escala;
CREATE POLICY "Permitir tudo anon escala" ON escala FOR ALL USING (true) WITH CHECK (true);

-- ausencias
ALTER TABLE IF EXISTS ausencias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permitir tudo anon ausencias" ON ausencias;
CREATE POLICY "Permitir tudo anon ausencias" ON ausencias FOR ALL USING (true) WITH CHECK (true);

-- =========================================================================
-- FIM DO SCRIPT
-- =========================================================================

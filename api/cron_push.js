import { createClient } from '@supabase/supabase-js';
import { google } from 'googleapis';
import fs from 'fs';
import path from 'path';

const supabaseUrl =
  process.env.SUPABASE_URL || 'https://dsgqlylniqqjavxwlzku.supabase.co';
const supabaseKey =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  process.env.SUPABASE_ANON_KEY ||
  'sb_publishable_bluqXnKz8L8Buvo820h_oQ_p6vMWo5q';
const supabase = createClient(supabaseUrl, supabaseKey);

function formatDateSaoPaulo(date) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Sao_Paulo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

function formatDiaMes(isoDate) {
  const parts = isoDate.split('-');
  return parts.length === 3 ? `${parts[2]}/${parts[1]}` : isoDate;
}

function getDiaSemanaNome(isoDate) {
  const dias = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
  const dt = new Date(`${isoDate}T12:00:00Z`);
  return dias[dt.getUTCDay()] || '';
}

function carregarServiceAccount() {
  const envStr = process.env.FCM_SERVICE_ACCOUNT;
  if (envStr && envStr.trim().length > 0) {
    const clean = envStr.trim().replace(/^'|'$/g, '');
    return JSON.parse(clean);
  }
  const serviceAccountPath = path.join(process.cwd(), 'service-account.json');
  if (fs.existsSync(serviceAccountPath)) {
    return JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  }
  throw new Error(
    'FCM_SERVICE_ACCOUNT não configurado nas variáveis de ambiente e service-account.json não encontrado.'
  );
}

async function enviarWebPush({ projectId, accessToken, token, title, body, data, tokensInvalidos }) {
  const message = {
    message: {
      token,
      notification: { title, body },
      data,
      webpush: {
        headers: {
          TTL: '86400',
          Urgency: 'high',
        },
        notification: {
          title,
          body,
          icon: '/icons/Icon-192.png',
          badge: '/icons/Icon-192.png',
        },
        fcm_options: {
          link: '/',
        },
      },
    },
  };

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(message),
    }
  );

  if (response.ok) {
    return true;
  }

  const errText = await response.text();
  console.error('FCM WebPush Error:', errText);
  if (errText.includes('UNREGISTERED') || errText.includes('INVALID_ARGUMENT')) {
    tokensInvalidos.push(token);
  }
  return false;
}

export default async function handler(req, res) {
  if (
    process.env.CRON_SECRET &&
    req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`
  ) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const agora = new Date();
    const hojeStr = formatDateSaoPaulo(agora);
    const amanhaStr = formatDateSaoPaulo(new Date(agora.getTime() + 24 * 60 * 60 * 1000));

    // 1. Buscar escalas de hoje e amanhã + membros + tokens WEB + repertórios
    const [escalaRes, membrosRes, tokensRes, repRes] = await Promise.all([
      supabase
        .from('escala')
        .select('id, data, horario, ministerio, nome, funcao, status_convite')
        .in('data', [hojeStr, amanhaStr]),
      supabase.from('membros').select('id, nome'),
      supabase
        .from('membro_tokens')
        .select('token, membro_id')
        .eq('plataforma', 'web'),
      supabase
        .from('repertorios')
        .select('data_culto, hora_culto, lista_musicas')
        .in('data_culto', [hojeStr, amanhaStr]),
    ]);

    if (escalaRes.error) throw escalaRes.error;
    if (membrosRes.error) throw membrosRes.error;
    if (tokensRes.error) throw tokensRes.error;
    if (repRes.error) throw repRes.error;

    const tokensWeb = tokensRes.data || [];
    if (tokensWeb.length === 0) {
      return res.status(200).json({
        message: 'Nenhum token Web/iPhone registrado para notificar.',
        sucessos: 0,
        falhas: 0,
      });
    }

    // Mapear membroNome (lowercase) -> membro_id -> tokens web
    const membroIdPorNome = new Map();
    for (const m of membrosRes.data || []) {
      if (m.nome) {
        membroIdPorNome.set(m.nome.trim().toLowerCase(), m.id);
      }
    }

    const tokensPorMembroId = new Map();
    for (const t of tokensWeb) {
      if (!t.membro_id || !t.token) continue;
      if (!tokensPorMembroId.has(t.membro_id)) {
        tokensPorMembroId.set(t.membro_id, new Set());
      }
      tokensPorMembroId.get(t.membro_id).add(t.token);
    }

    const escalasValidas = (escalaRes.data || []).filter((e) => {
      const nome = (e.nome || '').trim();
      return (
        nome !== '' &&
        nome !== '[FALTA]' &&
        e.status_convite !== 'FALTA' &&
        e.status_convite !== 'FALTA_JUSTIFICADA'
      );
    });

    if (escalasValidas.length === 0) {
      return res.status(200).json({ message: 'Nenhuma escala válida para hoje ou amanhã.' });
    }

    const serviceAccount = carregarServiceAccount();
    const auth = new google.auth.GoogleAuth({
      credentials: {
        client_email: serviceAccount.client_email,
        private_key: serviceAccount.private_key,
      },
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    });
    const accessToken = await auth.getAccessToken();

    // Agrupar avisos a enviar por (membro_id, chaveAviso) para não duplicar acúmulo de função
    const filaAvisos = [];

    // A) Cultos agrupados por membro + data + horario
    const cultosPorMembro = new Map();
    const jejunsNotificados = new Set();

    for (const item of escalasValidas) {
      const nomeNorm = item.nome.trim().toLowerCase();
      const membroId = membroIdPorNome.get(nomeNorm);
      if (!membroId || !tokensPorMembroId.has(membroId)) continue;

      if (item.ministerio === 'Jejum') {
        const chaveJejum = `${membroId}_${item.data}`;
        if (jejunsNotificados.has(chaveJejum)) continue;
        jejunsNotificados.add(chaveJejum);

        const diaNome = getDiaSemanaNome(item.data);
        const diaFmt = formatDiaMes(item.data);

        if (item.data === hojeStr) {
          filaAvisos.push({
            membroId,
            title: '🙏 Jejum Hoje',
            body: `${diaNome} (${diaFmt}) é seu propósito de jejum.`,
            data: { tipo: 'jejum_hoje', data: item.data },
          });
        } else if (item.data === amanhaStr) {
          filaAvisos.push({
            membroId,
            title: '🙏 Jejum Amanhã',
            body: `${diaNome} (${diaFmt}) é seu dia de jejum.`,
            data: { tipo: 'jejum_amanha', data: item.data },
          });
        }
        continue;
      }

      const horaCurta = (item.horario || '').substring(0, 5);
      const horaInt = parseInt((horaCurta.split(':')[0] || '0'), 10);
      const isMatutino = horaInt < 12;

      // Culto de hoje: avisa sempre; Culto de amanhã: avisa se for matutino (< 12:00)
      const deveAvisar =
        item.data === hojeStr || (item.data === amanhaStr && isMatutino);

      if (!deveAvisar) continue;

      const chaveGrupo = `${membroId}_${item.data}_${horaCurta}`;
      if (!cultosPorMembro.has(chaveGrupo)) {
        cultosPorMembro.set(chaveGrupo, {
          membroId,
          nome: item.nome,
          data: item.data,
          horaCurta,
          isMatutino,
          funcoes: new Set(),
          isMinistro: false,
        });
      }
      const grupo = cultosPorMembro.get(chaveGrupo);
      grupo.funcoes.add(`${item.ministerio} (${item.funcao})`);
      const funcLow = (item.funcao || '').toLowerCase();
      if (funcLow.includes('ministro') || funcLow.includes('dirigente')) {
        grupo.isMinistro = true;
      }
    }

    const repertorios = repRes.data || [];

    for (const grupo of cultosPorMembro.values()) {
      const diaNome = getDiaSemanaNome(grupo.data);
      const diaFmt = formatDiaMes(grupo.data);
      const funcoesTexto = [...grupo.funcoes].join(', ');

      if (grupo.data === hojeStr) {
        filaAvisos.push({
          membroId: grupo.membroId,
          title: '📅 Escala Hoje',
          body: `${diaNome} às ${grupo.horaCurta} • ${funcoesTexto}`,
          data: {
            tipo: 'escala_hoje',
            data_culto: grupo.data,
            hora_culto: grupo.horaCurta,
          },
        });
      } else if (grupo.data === amanhaStr && grupo.isMatutino) {
        filaAvisos.push({
          membroId: grupo.membroId,
          title: '📅 Escala Amanhã',
          body: `${diaNome} (${diaFmt}) às ${grupo.horaCurta} • ${funcoesTexto}`,
          data: {
            tipo: 'escala_amanha',
            data_culto: grupo.data,
            hora_culto: grupo.horaCurta,
          },
        });
      }

      // Cobrança de playlist pendente para Ministros (somente Web, não duplica Android)
      if (grupo.isMinistro) {
        const deveCobrar = grupo.isMatutino
          ? grupo.data === amanhaStr
          : grupo.data === hojeStr;

        if (deveCobrar) {
          const temPlaylist = repertorios.some((r) => {
            const rHora = (r.hora_culto || '').substring(0, 5);
            return (
              r.data_culto === grupo.data &&
              rHora === grupo.horaCurta &&
              Array.isArray(r.lista_musicas) &&
              r.lista_musicas.length > 0
            );
          });

          if (!temPlaylist) {
            filaAvisos.push({
              membroId: grupo.membroId,
              title: '🎵 Playlist Pendente',
              body: grupo.isMatutino
                ? `${diaNome} (${diaFmt}) às ${grupo.horaCurta} • A playlist ainda não foi montada!`
                : `${diaNome} às ${grupo.horaCurta} • A playlist ainda não foi montada!`,
              data: {
                tipo: 'playlist_pendente',
                data_culto: grupo.data,
                hora_culto: grupo.horaCurta,
              },
            });
          }
        }
      }
    }

    let successCount = 0;
    let failCount = 0;
    const tokensInvalidos = [];

    for (const aviso of filaAvisos) {
      const tokens = tokensPorMembroId.get(aviso.membroId);
      if (!tokens) continue;

      for (const token of tokens) {
        const ok = await enviarWebPush({
          projectId: serviceAccount.project_id,
          accessToken,
          token,
          title: aviso.title,
          body: aviso.body,
          data: aviso.data,
          tokensInvalidos,
        });
        if (ok) successCount++;
        else failCount++;
      }
    }

    if (tokensInvalidos.length > 0) {
      await supabase
        .from('membro_tokens')
        .delete()
        .in('token', [...new Set(tokensInvalidos)]);
    }

    return res.status(200).json({
      message: 'Processamento Web Push diário concluído.',
      avisosEnfileirados: filaAvisos.length,
      sucessos: successCount,
      falhas: failCount,
      tokensLimpos: [...new Set(tokensInvalidos)].length,
    });
  } catch (error) {
    console.error('Erro no cron_push:', error);
    return res.status(500).json({ error: error.message });
  }
}

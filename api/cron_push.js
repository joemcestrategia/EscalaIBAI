import { createClient } from '@supabase/supabase-js';
import { google } from 'googleapis';
import fs from 'fs';
import path from 'path';

// Configurações (você deve colocar SUPABASE_URL e SUPABASE_ANON_KEY nas variáveis de ambiente do Vercel depois)
// Como estamos em Node.js no Vercel, o service-account.json estará na raiz
const supabaseUrl = process.env.SUPABASE_URL || 'COLOQUE AQUI A URL';
const supabaseKey = process.env.SUPABASE_ANON_KEY || 'COLOQUE AQUI A CHAVE';
const supabase = createClient(supabaseUrl, supabaseKey);

export default async function handler(req, res) {
  // Autenticação básica para o cron do Vercel (opcional, mas recomendado)
  if (req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}` && process.env.CRON_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    // 1. Pegar a data de hoje (considerando fuso horário de Brasília GMT-3)
    const hoje = new Date();
    hoje.setHours(hoje.getHours() - 3);
    const dataString = hoje.toISOString().split('T')[0];

    // 2. Buscar escalas do dia de hoje
    const { data: escalas, error: errorEscala } = await supabase
      .from('escala')
      .select('id_membro, cargo')
      .eq('data', dataString);

    if (errorEscala) throw errorEscala;

    if (!escalas || escalas.length === 0) {
      return res.status(200).json({ message: 'Nenhuma escala para hoje.' });
    }

    // 3. Pegar IDs únicos dos membros escalados hoje
    const membrosIds = [...new Set(escalas.map(e => e.id_membro))];

    // 4. Buscar os tokens desses membros
    const { data: tokens, error: errorTokens } = await supabase
      .from('membro_tokens')
      .select('token, membro_id')
      .in('membro_id', membrosIds);

    if (errorTokens) throw errorTokens;

    if (!tokens || tokens.length === 0) {
      return res.status(200).json({ message: 'Nenhum token encontrado para os membros escalados.' });
    }

    // 5. Autenticar no Firebase FCM v1 usando o service-account.json
    // Vercel Serverless copia arquivos se estiverem incluídos, mas como ler da raiz? 
    // Vamos requerer o arquivo diretamente. 
    const serviceAccountPath = path.join(process.cwd(), 'service-account.json');
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

    const auth = new google.auth.GoogleAuth({
      credentials: {
        client_email: serviceAccount.client_email,
        private_key: serviceAccount.private_key,
      },
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    });

    const accessToken = await auth.getAccessToken();

    // 6. Enviar Push para cada token
    let successCount = 0;
    let failCount = 0;

    for (const t of tokens) {
      const message = {
        message: {
          token: t.token,
          notification: {
            title: '📅 Já olhou a escala hoje?',
            body: 'Você tem um compromisso na escala da igreja hoje!',
          },
          data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            type: 'escala',
          }
        }
      };

      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(message),
      });

      if (response.ok) {
        successCount++;
      } else {
        failCount++;
        const error = await response.json();
        console.error('FCM Error:', error);
      }
    }

    return res.status(200).json({
      message: 'Processamento concluído.',
      escaladosHoje: membrosIds.length,
      sucessos: successCount,
      falhas: failCount
    });

  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: error.message });
  }
}

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

function base64UrlEncode(data: Uint8Array | string): string {
  const str = typeof data === 'string'
    ? btoa(data)
    : btoa(String.fromCharCode(...data))
  return str.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '')
  const binary = atob(b64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return bytes.buffer
}

async function getAccessToken(serviceAccount: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }

  const encodedHeader = base64UrlEncode(JSON.stringify(header))
  const encodedPayload = base64UrlEncode(JSON.stringify(payload))
  const unsignedToken = `${encodedHeader}.${encodedPayload}`

  const keyData = pemToArrayBuffer(serviceAccount.private_key)
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  )

  const jwt = `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  if (!res.ok) {
    const errText = await res.text()
    throw new Error(`Falha ao obter access_token do Google OAuth2: ${errText}`)
  }

  const data = await res.json()
  return data.access_token
}

serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const reqBody = await req.json()
    const { dataCulto, horaCulto, qtdMusicas, membroId, titulo, corpo, acao } = reqBody

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Preparar credenciais FCM (HTTP v1)
    const serviceAccountStr = Deno.env.get('FCM_SERVICE_ACCOUNT')
    const projectId = Deno.env.get('FCM_PROJECT_ID')

    if (!serviceAccountStr || !projectId) {
      throw new Error('FCM_SERVICE_ACCOUNT ou FCM_PROJECT_ID não configurados nas secrets')
    }

    const cleanJsonStr = serviceAccountStr.replace(/^'|'$/g, '')
    const serviceAccount = JSON.parse(cleanJsonStr)
    const accessToken = await getAccessToken(serviceAccount)

    // MODO 0: Verificação de pendências de playlist para ministros
    if (acao === 'verificar_pendencias_ministro') {
      const agoraUtc = new Date()
      // Fuso horário de Brasília (UTC-3)
      const agoraBrasilia = new Date(agoraUtc.getTime() - 3 * 60 * 60 * 1000)
      const hojeStr = agoraBrasilia.toISOString().split('T')[0]
      const amanhaObj = new Date(agoraBrasilia.getTime() + 24 * 60 * 60 * 1000)
      const amanhaStr = amanhaObj.toISOString().split('T')[0]

      const { data: escalas, error: escalaErr } = await supabaseClient
        .from('escala')
        .select('id, data, horario, nome, funcao')
        .in('data', [hojeStr, amanhaStr])

      if (escalaErr) throw escalaErr

      const ministrosEscalados = (escalas ?? []).filter((e: any) => {
        const f = (e.funcao ?? '').toLowerCase()
        const n = (e.nome ?? '').trim()
        return (f.includes('ministro') || f.includes('dirigente')) && n !== '' && n !== '[FALTA]'
      })

      const { data: repertorios } = await supabaseClient
        .from('repertorios')
        .select('data_culto, hora_culto, lista_musicas')
        .in('data_culto', [hojeStr, amanhaStr])

      const diasSemana = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado']
      let totalCobrados = 0

      for (const item of ministrosEscalados) {
        const horaParts = (item.horario ?? '').split(':')
        const hora = parseInt(horaParts[0] ?? '0', 10)
        const isCultoMatutino = hora < 12
        const horaCurta = item.horario.length >= 5 ? item.horario.substring(0, 5) : item.horario

        // Se culto matutino: cobra na véspera (quando hoje == amanha do culto - 1)
        // Se culto noturno: cobra no dia do culto (quando hoje == data do culto)
        const deveCobrarHoje = isCultoMatutino
          ? item.data === amanhaStr
          : item.data === hojeStr

        if (!deveCobrarHoje) continue

        // Verifica se a playlist já possui músicas cadastradas
        const temPlaylist = (repertorios ?? []).some((r: any) => {
          const rData = r.data_culto
          const rHora = (r.hora_culto ?? '').substring(0, 5)
          const rMusicas = r.lista_musicas
          return rData === item.data && rHora === horaCurta && Array.isArray(rMusicas) && rMusicas.length > 0
        })

        if (temPlaylist) continue // Já preencheu, não cobra

        // Busca o membro_id pelo nome
        const { data: membroRow } = await supabaseClient
          .from('membros')
          .select('id')
          .eq('nome', item.nome)
          .maybeSingle()

        if (!membroRow) continue

        // Busca tokens FCM do ministro
        const { data: tokensRow } = await supabaseClient
          .from('membro_tokens')
          .select('token')
          .eq('membro_id', membroRow.id)

        const tokens = tokensRow
          ? [...new Set(tokensRow.map((t: any) => t.token).filter(Boolean))]
          : []

        if (tokens.length === 0) continue

        const dParts = item.data.split('-')
        const dataFmt = dParts.length === 3 ? `${dParts[2]}/${dParts[1]}` : item.data
        const dt = new Date(`${item.data}T12:00:00Z`)
        const diaSemanaNome = diasSemana[dt.getUTCDay()]

        const corpoMsg = isCultoMatutino
          ? `${diaSemanaNome} (${dataFmt}) às ${horaCurta} • A playlist ainda não foi montada!`
          : `${diaSemanaNome} às ${horaCurta} • A playlist ainda não foi montada!`

        for (const token of tokens) {
          const pushPayload = {
            message: {
              token: token,
              notification: {
                title: '🎵 Playlist Pendente',
                body: corpoMsg,
              },
              data: {
                tipo: 'playlist_pendente',
                data_culto: String(item.data),
                hora_culto: String(horaCurta),
              },
              android: {
                priority: 'high',
                notification: {
                  sound: 'toque_escala',
                  channel_id: 'alertas_igreja_v4',
                },
              },
            },
          }

          try {
            await fetch(
              `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
              {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  Authorization: `Bearer ${accessToken}`,
                },
                body: JSON.stringify(pushPayload),
              }
            )
            totalCobrados++
          } catch (e) {
            console.error(`Erro ao enviar cobrança para ${item.nome}:`, e)
          }
        }
      }

      return new Response(
        JSON.stringify({
          message: 'Verificação de pendências concluída',
          ministrosCobrados: totalCobrados,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // MODO 1: Envio individual para um membro específico (ex: teste ou aviso individual)
    if (membroId) {
      const { data: tokensRow, error: tokenErr } = await supabaseClient
        .from('membro_tokens')
        .select('token')
        .eq('membro_id', membroId)

      if (tokenErr) throw tokenErr

      const tokens = tokensRow
        ? [...new Set(tokensRow.map((t: any) => t.token).filter(Boolean))]
        : []

      if (tokens.length === 0) {
        return new Response(
          JSON.stringify({
            message: 'Nenhum token registrado para este membro ainda.',
            tokensEncontrados: 0,
            sucesso: 0,
            falha: 0,
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )
      }

      let successCount = 0
      let failureCount = 0

      for (const token of tokens) {
        const fcmPayload = {
          message: {
            token: token,
            notification: {
              title: titulo ?? '🔔 Aviso da Escala',
              body: corpo ?? 'Você recebeu uma nova notificação no app Escala!',
            },
            data: {
              tipo: 'aviso_pessoal',
              membro_id: String(membroId),
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'toque_escala',
                channel_id: 'alertas_igreja_v4',
              },
            },
          },
        }

        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify(fcmPayload),
          }
        )

        if (res.ok) {
          successCount++
        } else {
          failureCount++
          console.error(`Erro ao enviar para token de ${membroId}:`, await res.text())
        }
      }

      return new Response(
        JSON.stringify({
          message: 'Notificação individual processada',
          tokensEncontrados: tokens.length,
          sucesso: successCount,
          falha: failureCount,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // MODO 2: Envio de Nova Playlist para TODOS
    if (!dataCulto || !horaCulto) {
      throw new Error('Parâmetros dataCulto ou horaCulto ausentes')
    }

    const partesData = dataCulto.split('-') // YYYY-MM-DD
    const dataFormatada = partesData.length === 3
      ? `${partesData[2]}/${partesData[1]}/${partesData[0]}`
      : dataCulto

    const horaCurta = horaCulto.length >= 5 ? horaCulto.substring(0, 5) : horaCulto

    let diaSemanaNome = ''
    try {
      const dataObj = new Date(`${dataCulto}T12:00:00Z`)
      const diasSemana = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado']
      diaSemanaNome = `${diasSemana[dataObj.getUTCDay()]}, `
    } catch (_) {}

    const title = '🎵 Playlist do Culto'
    const body = `${diaSemanaNome}${dataFormatada} às ${horaCurta} • ${qtdMusicas ?? 0} música(s)`

    let successCount = 0
    let failureCount = 0

    // 1. Envia para o tópico 'todos' (recebido por todos os aparelhos Android com o app instalado)
    const topicPayload = {
      message: {
        topic: 'todos',
        notification: {
          title: title,
          body: body,
        },
        data: {
          tipo: 'novo_repertorio',
          data_culto: String(dataCulto),
          hora_culto: String(horaCurta),
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'toque_escala',
            channel_id: 'alertas_igreja_v4',
          },
        },
      },
    }

    const topicRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(topicPayload),
      }
    )

    if (topicRes.ok) {
      successCount++
    } else {
      failureCount++
      console.error('Erro ao enviar para tópico todos:', await topicRes.text())
    }

    // 2. Envia também para tokens Web registrados em membro_tokens
    const { data: webTokensRow } = await supabaseClient
      .from('membro_tokens')
      .select('token')
      .eq('plataforma', 'web')

    const webTokens = webTokensRow
      ? [...new Set(webTokensRow.map((t: any) => t.token).filter(Boolean))]
      : []

    const tokensInvalidos: string[] = []

    if (webTokens.length > 0) {
      const sendPromises = webTokens.map(async (token) => {
        const fcmPayload = {
          message: {
            token: token,
            notification: {
              title: title,
              body: body,
            },
            data: {
              tipo: 'novo_repertorio',
              data_culto: String(dataCulto),
              hora_culto: String(horaCurta),
            },
          },
        }

        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify(fcmPayload),
          }
        )

        if (res.ok) {
          successCount++
        } else {
          failureCount++
          const errBody = await res.text()
          if (errBody.includes('UNREGISTERED') || errBody.includes('INVALID_ARGUMENT')) {
            tokensInvalidos.push(token)
          }
        }
      })

      await Promise.all(sendPromises)

      if (tokensInvalidos.length > 0) {
        await supabaseClient
          .from('membro_tokens')
          .delete()
          .in('token', tokensInvalidos)
      }
    }

    return new Response(
      JSON.stringify({
        message: 'Notificações processadas',
        sucesso: successCount,
        falha: failureCount,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error: any) {
    console.error('Erro na edge function:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})

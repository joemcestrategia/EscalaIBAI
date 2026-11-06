import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { google } from 'npm:googleapis'

// 1. Criar credenciais de Service Account a partir da string JSON guardada nas secrets do Supabase.
//    No Supabase CLI: supabase secrets set FCM_SERVICE_ACCOUNT='{"type": "service_account", ...}'
// 2. Colocar o Project ID do Firebase. No Supabase CLI: supabase secrets set FCM_PROJECT_ID='meu-projeto'
// 3. Fazer o deploy: supabase functions deploy notificar-repertorio --no-verify-jwt

const getAccessToken = async (serviceAccountJson: any) => {
  const jwtClient = new google.auth.JWT(
    serviceAccountJson.client_email,
    null,
    serviceAccountJson.private_key,
    ['https://www.googleapis.com/auth/firebase.messaging']
  )
  const tokens = await jwtClient.authorize()
  return tokens.access_token
}

serve(async (req: Request) => {
  // CORS (permitir requisições do App/Web)
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { dataCulto, horaCulto, qtdMusicas } = await req.json()

    if (!dataCulto || !horaCulto) {
      throw new Error('Parâmetros dataCulto ou horaCulto ausentes')
    }

    // Instanciar o cliente Supabase usando a chave service_role (ignorando RLS)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Pegar todos os tokens registrados na tabela membro_tokens
    const { data: tokensRow, error: tokenError } = await supabaseClient
      .from('membro_tokens')
      .select('token')

    if (tokenError) throw tokenError
    if (!tokensRow || tokensRow.length === 0) {
      return new Response(JSON.stringify({ message: 'Nenhum token encontrado.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    const tokens = [...new Set(tokensRow.map((t: any) => t.token))]

    // Preparar credenciais FCM (HTTP v1)
    const serviceAccountStr = Deno.env.get('FCM_SERVICE_ACCOUNT')
    const projectId = Deno.env.get('FCM_PROJECT_ID')

    if (!serviceAccountStr || !projectId) {
      throw new Error('FCM_SERVICE_ACCOUNT ou FCM_PROJECT_ID não configurados nas secrets')
    }

    const serviceAccount = JSON.parse(serviceAccountStr)
    const accessToken = await getAccessToken(serviceAccount)

    // Formatar os dados para exibição na push
    const partesData = dataCulto.split('-') // Assumindo YYYY-MM-DD
    const dataFormatada = partesData.length === 3 
      ? `${partesData[2]}/${partesData[1]}/${partesData[0]}` 
      : dataCulto

    const title = '🎵 Novo Repertório Disponível!'
    const body = `O repertório para o culto do dia ${dataFormatada} às ${horaCulto} foi adicionado. Contém ${qtdMusicas} música(s).`

    // Enviar notificações via FCM HTTP v1
    let successCount = 0
    let failureCount = 0

    // FCM HTTP v1 só suporta envio individual ou de tópicos.
    // Como temos uma lista de tokens, vamos disparar em paralelo.
    const sendPromises = tokens.map(async (token) => {
      const fcmPayload = {
        message: {
          token: token,
          notification: {
            title: title,
            body: body,
          },
          data: {
            tipo: 'novo_repertorio',
            data_culto: dataCulto,
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channel_id: 'alertas_igreja_v4'
            }
          }
        }
      }

      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`
        },
        body: JSON.stringify(fcmPayload)
      })

      if (res.ok) {
        successCount++
      } else {
        failureCount++
        console.error(`Erro ao enviar para o token ${token}:`, await res.text())
      }
    })

    await Promise.all(sendPromises)

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

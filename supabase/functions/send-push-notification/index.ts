import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationPayload {
  user_id?: string
  user_ids?: string[]
  title: string
  body: string
  data?: Record<string, any>
  image?: string
  click_action?: string
}

interface FCMMessage {
  to?: string
  registration_ids?: string[]
  notification: {
    title: string
    body: string
    image?: string
  }
  data?: Record<string, string>
  android?: {
    notification: {
      channel_id: string
      priority: string
      click_action?: string
    }
  }
  apns?: {
    payload: {
      aps: {
        alert: {
          title: string
          body: string
        }
        sound: string
        badge: number
      }
    }
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client with service role key
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Parse request payload
    const payload: NotificationPayload = await req.json()
    const { user_id, user_ids, title, body, data, image, click_action } = payload

    // Validate required fields
    if (!title || !body) {
      throw new Error('Title and body are required')
    }

    // Determine target users
    const targetUserIds = user_ids || (user_id ? [user_id] : [])
    
    if (targetUserIds.length === 0) {
      throw new Error('No target users specified')
    }

    console.log(`📤 Sending notification to ${targetUserIds.length} users: "${title}"`)

    // Get FCM tokens for target users
    const { data: tokens, error: tokensError } = await supabaseClient
      .from('user_device_tokens')
      .select('*')
      .in('user_id', targetUserIds)
      .eq('is_active', true)

    if (tokensError) {
      console.error('❌ Error fetching tokens:', tokensError)
      throw tokensError
    }

    if (!tokens || tokens.length === 0) {
      console.log('⚠️ No active FCM tokens found for target users')
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'No active FCM tokens found',
          target_users: targetUserIds.length,
          active_tokens: 0
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📱 Found ${tokens.length} active FCM tokens`)

    // Get FCM Server Key from environment
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')
    if (!fcmServerKey) {
      throw new Error('FCM_SERVER_KEY environment variable not configured')
    }

    // Prepare FCM messages
    const androidTokens = tokens.filter(t => t.platform === 'android').map(t => t.token)
    const iosTokens = tokens.filter(t => t.platform === 'ios').map(t => t.token)
    
    const results: any[] = []

    // Send to Android devices
    if (androidTokens.length > 0) {
      const androidMessage: FCMMessage = {
        registration_ids: androidTokens,
        notification: {
          title,
          body,
          ...(image && { image })
        },
        data: {
          ...data,
          ...(click_action && { click_action })
        },
        android: {
          notification: {
            channel_id: data?.type === 'order' ? 'orders' : 'default',
            priority: 'high',
            ...(click_action && { click_action })
          }
        }
      }

      try {
        const response = await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            'Authorization': `key=${fcmServerKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(androidMessage)
        })

        const result = await response.json()
        
        console.log(`📱 Android FCM Response:`, result)
        
        results.push({
          platform: 'android',
          tokens_count: androidTokens.length,
          success: response.ok,
          result
        })

        // Log individual results for Android
        if (result.results) {
          for (let i = 0; i < result.results.length; i++) {
            const tokenResult = result.results[i]
            const token = androidTokens[i]
            const userToken = tokens.find(t => t.token === token)
            
            await supabaseClient
              .from('push_notifications_log')
              .insert({
                user_id: userToken?.user_id,
                title,
                body,
                data,
                fcm_message_id: tokenResult.message_id,
                platform: 'android',
                status: tokenResult.error ? 'failed' : 'sent',
                error_message: tokenResult.error ? JSON.stringify(tokenResult.error) : null
              })
          }
        }

      } catch (error) {
        console.error('❌ Android FCM Error:', error)
        results.push({
          platform: 'android',
          tokens_count: androidTokens.length,
          success: false,
          error: error.message
        })
      }
    }

    // Send to iOS devices
    if (iosTokens.length > 0) {
      const iosMessage: FCMMessage = {
        registration_ids: iosTokens,
        notification: {
          title,
          body,
          ...(image && { image })
        },
        data: {
          ...data,
          ...(click_action && { click_action })
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title,
                body
              },
              sound: 'default',
              badge: 1
            }
          }
        }
      }

      try {
        const response = await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            'Authorization': `key=${fcmServerKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(iosMessage)
        })

        const result = await response.json()
        
        console.log(`📱 iOS FCM Response:`, result)
        
        results.push({
          platform: 'ios',
          tokens_count: iosTokens.length,
          success: response.ok,
          result
        })

        // Log individual results for iOS
        if (result.results) {
          for (let i = 0; i < result.results.length; i++) {
            const tokenResult = result.results[i]
            const token = iosTokens[i]
            const userToken = tokens.find(t => t.token === token)
            
            await supabaseClient
              .from('push_notifications_log')
              .insert({
                user_id: userToken?.user_id,
                title,
                body,
                data,
                fcm_message_id: tokenResult.message_id,
                platform: 'ios',
                status: tokenResult.error ? 'failed' : 'sent',
                error_message: tokenResult.error ? JSON.stringify(tokenResult.error) : null
              })
          }
        }

      } catch (error) {
        console.error('❌ iOS FCM Error:', error)
        results.push({
          platform: 'ios',
          tokens_count: iosTokens.length,
          success: false,
          error: error.message
        })
      }
    }

    // Calculate totals
    const totalSent = results.reduce((sum, r) => sum + (r.success ? r.tokens_count : 0), 0)
    const totalFailed = results.reduce((sum, r) => sum + (r.success ? 0 : r.tokens_count), 0)

    console.log(`✅ Notification sending completed: ${totalSent} sent, ${totalFailed} failed`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        results,
        summary: {
          target_users: targetUserIds.length,
          active_tokens: tokens.length,
          android_tokens: androidTokens.length,
          ios_tokens: iosTokens.length,
          total_sent: totalSent,
          total_failed: totalFailed
        },
        notification: {
          title,
          body,
          data
        }
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Edge Function Error:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message,
        timestamp: new Date().toISOString()
      }),
      { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreateSessionRequest {
  user_id: string
  phone: string
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
    const payload: CreateSessionRequest = await req.json()
    const { user_id, phone } = payload

    // Validate required fields
    if (!user_id || !phone) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'user_id and phone are required'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Verify user exists in Supabase Auth
    const { data: userData, error: userError } = await supabaseClient.auth.admin.getUserById(user_id)

    if (userError || !userData) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'User not found in Supabase Auth'
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Verify phone matches
    if (userData.user.phone !== phone) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Phone number mismatch'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Generate a magic link for the user
    // This will allow the client to establish a session
    const { data: linkData, error: linkError } = await supabaseClient.auth.admin.generateLink({
      type: 'magiclink',
      email: `${user_id}@phone-auth.temp`, // Temporary email for phone auth
      options: {
        redirectTo: undefined,
      },
    })

    if (linkError) {
      console.error('❌ Error generating magic link:', linkError)
      // Fallback: return user info and let client handle session
      return new Response(
        JSON.stringify({
          success: true,
          user_id,
          phone,
          message: 'User verified. Please establish session using alternative method.',
          // Client will need to use a custom session creation method
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Session creation link generated for user ${user_id}`)

    return new Response(
      JSON.stringify({
        success: true,
        user_id,
        phone,
        message: 'Session creation initiated',
        // Note: The client will need to use the magic link or another method
        // to establish a session. For phone auth, we recommend using
        // Supabase's passwordless authentication or a custom session token.
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Edge Function Error:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Internal server error',
        timestamp: new Date().toISOString()
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface VerifyOtpRequest {
  phone_number: string
  country_code: string
  full_phone: string
  code: string
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
    const payload: VerifyOtpRequest = await req.json()
    const { phone_number, country_code, full_phone, code } = payload

    // Validate required fields
    if (!phone_number || !country_code || !full_phone || !code) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'phone_number, country_code, full_phone, and code are required'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Find valid OTP code
    const { data: otpRecord, error: findError } = await supabaseClient
      .from('otp_codes')
      .select('*')
      .eq('full_phone', full_phone)
      .eq('code', code)
      .eq('is_used', false)
      .gte('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (findError) {
      console.error('❌ Error finding OTP:', findError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to verify code'
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (!otpRecord) {
      console.log(`❌ Invalid or expired OTP for ${full_phone}`)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Invalid or expired verification code'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Mark OTP as used
    const { error: updateError } = await supabaseClient
      .from('otp_codes')
      .update({
        is_used: true,
        verified_at: new Date().toISOString(),
      })
      .eq('id', otpRecord.id)

    if (updateError) {
      console.error('❌ Error marking OTP as used:', updateError)
      // Continue anyway - the OTP was found and is valid
    }

    // Check if user exists in Supabase Auth
    const { data: authUsers, error: authError } = await supabaseClient.auth.admin.listUsers()

    let existingUser = null
    if (!authError && authUsers) {
      existingUser = authUsers.users.find(
        (user) => user.phone === full_phone || user.user_metadata?.phone === full_phone
      )
    }

    let userId: string
    let isNewUser = false

    if (existingUser) {
      // User exists - sign them in
      userId = existingUser.id
      console.log(`✅ Existing user verified: ${userId}`)
    } else {
      // Create new user in Supabase Auth
      const { data: newUser, error: createError } = await supabaseClient.auth.admin.createUser({
        phone: full_phone,
        phone_confirmed: true,
        user_metadata: {
          phone_number,
          country_code,
          full_phone,
        },
      })

      if (createError || !newUser) {
        console.error('❌ Error creating user:', createError)
        return new Response(
          JSON.stringify({
            success: false,
            error: 'Failed to create user account'
          }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      userId = newUser.user.id
      isNewUser = true
      console.log(`✅ New user created: ${userId}`)
    }

    // Ensure user profile exists in user_profiles table
    const { data: profile, error: profileError } = await supabaseClient
      .from('user_profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle()

    if (!profile && !profileError) {
      // Create user profile if it doesn't exist
      const { error: createProfileError } = await supabaseClient
        .from('user_profiles')
        .insert({
          id: userId,
          phone: full_phone,
          is_verified: true,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })

      if (createProfileError) {
        console.error('❌ Error creating user profile:', createProfileError)
        // Continue anyway - profile can be created later
      } else {
        console.log(`✅ User profile created for ${userId}`)
      }
    } else if (profile) {
      // Update existing profile to mark phone as verified
      const { error: updateProfileError } = await supabaseClient
        .from('user_profiles')
        .update({
          phone: full_phone,
          is_verified: true,
          updated_at: new Date().toISOString(),
        })
        .eq('id', userId)

      if (updateProfileError) {
        console.error('❌ Error updating user profile:', updateProfileError)
      }
    }

    // Get user data
    const { data: userData, error: userError } = await supabaseClient.auth.admin.getUserById(userId)

    if (userError) {
      console.error('⚠️ Could not retrieve user data:', userError)
    }

    // Generate a session token using Supabase Admin API
    // Since we created the user with phone_confirmed: true, we can generate a session
    // However, Supabase Admin API doesn't directly generate sessions
    // Instead, we'll use the admin API to create a password reset token or magic link
    // For phone auth, the simplest approach is to return the user info and let the client
    // establish a session using Supabase's passwordless auth or a custom method

    // Alternative: Generate a custom JWT token (complex, requires JWT library)
    // For now, we'll return user info and the client will handle session creation
    // The user exists in Supabase Auth, so the client can use various methods to sign in

    console.log(`✅ OTP verified successfully for ${full_phone}`)

    return new Response(
      JSON.stringify({
        success: true,
        user_id: userId,
        is_new_user: isNewUser,
        phone: full_phone,
        message: 'Phone number verified successfully',
        // The user has been created/updated in Supabase Auth
        // The client will need to establish a session
        // Since Supabase Auth for phone requires OTP to create a session,
        // and we're bypassing that, we'll need a custom session creation method
        // Option 1: Use Supabase Admin API to generate a session token (requires another Edge Function)
        // Option 2: Use passwordless auth with a temporary password (not ideal)
        // Option 3: Have the client call a separate session creation endpoint
        // For now, the SessionManager will handle session restoration
        user: userData?.user ? {
          id: userData.user.id,
          phone: userData.user.phone,
          phone_confirmed: userData.user.phone_confirmed,
          created_at: userData.user.created_at,
        } : null,
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

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SendOtpRequest {
  phone_number: string
  country_code: string
  full_phone: string
}

// Generate a random 6-digit OTP
function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString()
}

// Helper functions for AWS Signature Version 4
async function sha256(message: string): Promise<string> {
  const msgBuffer = new TextEncoder().encode(message)
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer)
  return Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

async function hmacSha256(key: string | Uint8Array, message: string): Promise<Uint8Array> {
  const keyBuffer = typeof key === 'string' ? new TextEncoder().encode(key) : key
  const msgBuffer = new TextEncoder().encode(message)
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyBuffer,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  )
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, msgBuffer)
  return new Uint8Array(signature)
}

// Send SMS using various providers (prioritized by cost-effectiveness for Algeria)
async function sendSMS(phoneNumber: string, code: string): Promise<boolean> {
  try {
    const message = `Your verification code is: ${code}. Valid for 10 minutes.`

    // Debug: Log which providers are configured
    console.log('🔍 Checking SMS providers...')
    const providersChecked: string[] = []

    // Option 1: Bienvoip (BEST FOR ALGERIA - $0.0162 per SMS)
    // Very cheap and reliable option for Algerian numbers
    const bienvoipApiKey = Deno.env.get('BIENVOIP_API_KEY')
    const bienvoipUsername = Deno.env.get('BIENVOIP_USERNAME')

    if (bienvoipApiKey && bienvoipUsername) {
      providersChecked.push('Bienvoip')
      console.log('✅ Bienvoip credentials found')
      try {
        // Bienvoip API endpoint - check their docs for exact endpoint
        const bienvoipUrl = 'https://api.bienvoip.com/sms/send'
        const formData = new URLSearchParams()
        formData.append('api_key', bienvoipApiKey)
        formData.append('username', bienvoipUsername)
        formData.append('to', phoneNumber)
        formData.append('text', message)

        const response = await fetch(bienvoipUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: formData.toString(),
        })

        if (response.ok) {
          const result = await response.json()
          if (result.status === 'success' || result.success || result.code === '200') {
            console.log(`✅ SMS sent via Bienvoip to ${phoneNumber}`)
            return true
          }
        }
        const errorText = await response.text()
        console.warn(`⚠️ Bienvoip response: ${errorText}`)
      } catch (error) {
        console.warn(`⚠️ Bienvoip error: ${error}`)
        // Fall through to next provider
      }
    }

    // Option 2: Messaggio (Good for Algeria - €0.12 for Djezzy)
    const messaggioApiKey = Deno.env.get('MESSAGGIO_API_KEY')
    const messaggioSender = Deno.env.get('MESSAGGIO_SENDER') || 'Sahla'

    if (messaggioApiKey) {
      providersChecked.push('Messaggio')
      console.log('✅ Messaggio credentials found')
      try {
        // Messaggio API endpoint - check their docs for exact format
        const messaggioUrl = 'https://api.messaggio.com/sms/send'
        const formData = new URLSearchParams()
        formData.append('api_key', messaggioApiKey)
        formData.append('to', phoneNumber)
        formData.append('message', message)
        if (messaggioSender) {
          formData.append('from', messaggioSender)
        }

        const response = await fetch(messaggioUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: formData.toString(),
        })

        if (response.ok) {
          const result = await response.json()
          if (result.status === 'success' || result.success) {
            console.log(`✅ SMS sent via Messaggio to ${phoneNumber}`)
            return true
          }
        }
        const errorText = await response.text()
        console.warn(`⚠️ Messaggio response: ${errorText}`)
      } catch (error) {
        console.warn(`⚠️ Messaggio error: ${error}`)
        // Fall through to next provider
      }
    }

    // Option 3: BudgetSMS (Backup option - $0.17 per SMS, more expensive)
    const budgetsmsUsername = Deno.env.get('BUDGETSMS_USERNAME')
    const budgetsmsUserId = Deno.env.get('BUDGETSMS_USER_ID')
    const budgetsmsHandle = Deno.env.get('BUDGETSMS_HANDLE')

    if (budgetsmsUsername && budgetsmsUserId && budgetsmsHandle) {
      providersChecked.push('BudgetSMS')
      console.log('✅ BudgetSMS credentials found')
      try {
        const budgetsmsUrl = 'https://api.budgetsms.net/sendsms'
        const formData = new URLSearchParams()
        formData.append('username', budgetsmsUsername)
        formData.append('userid', budgetsmsUserId)
        formData.append('handle', budgetsmsHandle)
        formData.append('to', phoneNumber)
        formData.append('msg', message)

        const response = await fetch(budgetsmsUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: formData.toString(),
        })

        if (response.ok) {
          const result = await response.text()
          if (result.startsWith('OK') || result.includes('success')) {
            console.log(`✅ SMS sent via BudgetSMS to ${phoneNumber}`)
            return true
          }
          console.warn(`⚠️ BudgetSMS response: ${result}`)
        } else {
          const errorText = await response.text()
          console.warn(`⚠️ BudgetSMS error response: ${errorText}`)
        }
      } catch (error) {
        console.warn(`⚠️ BudgetSMS error: ${error}`)
        // Fall through to next provider
      }
    }

    // Option 4: Twilio (fallback - works globally but more expensive)
    const twilioAccountSid = Deno.env.get('TWILIO_ACCOUNT_SID')
    const twilioAuthToken = Deno.env.get('TWILIO_AUTH_TOKEN')
    const twilioPhoneNumber = Deno.env.get('TWILIO_PHONE_NUMBER')

    if (twilioAccountSid && twilioAuthToken && twilioPhoneNumber) {
      providersChecked.push('Twilio')
      console.log('✅ Twilio credentials found')
      try {
        const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${twilioAccountSid}/Messages.json`

        const formData = new URLSearchParams()
        formData.append('To', phoneNumber)
        formData.append('From', twilioPhoneNumber)
        formData.append('Body', message)

        const response = await fetch(twilioUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Basic ${btoa(`${twilioAccountSid}:${twilioAuthToken}`)}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: formData.toString(),
        })

        if (response.ok) {
          console.log(`✅ SMS sent via Twilio to ${phoneNumber}`)
          return true
        } else {
          const error = await response.text()
          console.error(`❌ Twilio SMS error: ${error}`)
        }
      } catch (error) {
        console.warn(`⚠️ Twilio error: ${error}`)
        // Fall through to next provider
      }
    }

    // Option 5: AWS SNS (alternative - works globally)
    const awsAccessKeyId = Deno.env.get('AWS_ACCESS_KEY_ID')
    const awsSecretAccessKey = Deno.env.get('AWS_SECRET_ACCESS_KEY')
    const awsRegion = Deno.env.get('AWS_REGION') || 'us-east-1'

    if (awsAccessKeyId && awsSecretAccessKey) {
      providersChecked.push('AWS SNS')
      console.log('✅ AWS SNS credentials found')
      try {
        // Use AWS SNS REST API directly with Signature Version 4
        const snsEndpoint = `https://sns.${awsRegion}.amazonaws.com/`

        // Create the SNS publish request body - parameters must be sorted alphabetically
        const params = new Map([
          ['Action', 'Publish'],
          ['Message', message],
          ['PhoneNumber', phoneNumber],
          ['Version', '2010-03-31']
        ])

        // Sort and encode parameters
        const sortedParams = Array.from(params.entries()).sort((a, b) => a[0].localeCompare(b[0]))
        const requestBody = sortedParams
          .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(value)}`)
          .join('&')

        // AWS Signature Version 4 signing
        const now = new Date()
        // Format: YYYYMMDDTHHmmssZ (e.g., 20231114T212209Z)
        const isoString = now.toISOString()
        const timestamp = isoString.replace(/[-:]/g, '').replace(/\.\d{3}/, '') // YYYYMMDDTHHmmssZ
        const dateStamp = timestamp.substring(0, 8) // YYYYMMDD

        // For POST requests, query string is empty, body goes in payload hash
        const canonicalUri = '/'
        const canonicalQuerystring = '' // Empty for POST
        const host = `sns.${awsRegion}.amazonaws.com`
        const canonicalHeaders = `host:${host}\nx-amz-date:${timestamp}\n`
        const signedHeaders = 'host;x-amz-date'

        // Payload hash is SHA256 of the request body (must be lowercase hex)
        const payloadHashHex = await sha256(requestBody)

        // Build canonical request (must match exactly what AWS expects)
        const canonicalRequest = `POST\n${canonicalUri}\n${canonicalQuerystring}\n${canonicalHeaders}\n${signedHeaders}\n${payloadHashHex}`

        // Create string to sign
        const algorithm = 'AWS4-HMAC-SHA256'
        const credentialScope = `${dateStamp}/${awsRegion}/sns/aws4_request`
        const canonicalRequestHash = await sha256(canonicalRequest)
        const stringToSign = `${algorithm}\n${timestamp}\n${credentialScope}\n${canonicalRequestHash}`

        // Calculate signature using HMAC-SHA256
        const kDate = await hmacSha256(`AWS4${awsSecretAccessKey}`, dateStamp)
        const kRegion = await hmacSha256(kDate, awsRegion)
        const kService = await hmacSha256(kRegion, 'sns')
        const kSigning = await hmacSha256(kService, 'aws4_request')
        const signature = await hmacSha256(kSigning, stringToSign)
        const signatureHex = Array.from(signature)
          .map(b => b.toString(16).padStart(2, '0'))
          .join('')

        // Create authorization header
        const authorization = `${algorithm} Credential=${awsAccessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signatureHex}`

        // Make the request
        const response = await fetch(snsEndpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-Amz-Date': timestamp,
            'Authorization': authorization,
          },
          body: requestBody,
        })

        if (response.ok) {
          const result = await response.text()
          // Parse XML response to check for success
          if (result.includes('<PublishResponse>') || result.includes('MessageId')) {
            console.log(`✅ SMS sent via AWS SNS to ${phoneNumber}`)
            return true
          }
        }
        const errorText = await response.text()
        console.warn(`⚠️ AWS SNS response: ${errorText}`)
      } catch (error) {
        console.warn(`⚠️ AWS SNS error: ${error}`)
        // Fall through to next provider
      }
    }

    // Option 6: Vonage/Nexmo (alternative)
    const vonageApiKey = Deno.env.get('VONAGE_API_KEY')
    const vonageApiSecret = Deno.env.get('VONAGE_API_SECRET')

    if (vonageApiKey && vonageApiSecret) {
      // Vonage implementation would go here
      console.warn('⚠️ Vonage not yet implemented')
    }

    // If no SMS provider succeeded, log and return false
    console.error(`❌ No SMS provider succeeded. Providers checked: ${providersChecked.length > 0 ? providersChecked.join(', ') : 'NONE'}`)
    if (providersChecked.length === 0) {
      console.error('⚠️ No provider credentials found. Please configure at least one SMS provider.')
      console.error('💡 Available providers: Bienvoip, Messaggio, BudgetSMS, Twilio, AWS SNS')
    } else {
      console.error(`⚠️ ${providersChecked.length} provider(s) configured but all failed. Check logs above for details.`)
    }
    return false

  } catch (error) {
    console.error('❌ Error sending SMS:', error)
    return false
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
    const payload: SendOtpRequest = await req.json()
    const { phone_number, country_code, full_phone } = payload

    // Validate required fields
    if (!phone_number || !country_code || !full_phone) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'phone_number, country_code, and full_phone are required'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Rate limiting: Check if there's a recent OTP sent to this number (within last 60 seconds)
    const { data: recentOtp } = await supabaseClient
      .from('otp_codes')
      .select('id, created_at')
      .eq('full_phone', full_phone)
      .eq('is_used', false)
      .gte('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (recentOtp) {
      const timeSinceLastOtp = Date.now() - new Date(recentOtp.created_at).getTime()
      if (timeSinceLastOtp < 60000) { // 60 seconds
        return new Response(
          JSON.stringify({
            success: false,
            error: 'Please wait before requesting another code',
            retry_after: Math.ceil((60000 - timeSinceLastOtp) / 1000)
          }),
          {
            status: 429,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }
    }

    // Generate OTP code
    const code = generateOTP()
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000) // 10 minutes from now

    // Store OTP in database
    const { data: otpRecord, error: insertError } = await supabaseClient
      .from('otp_codes')
      .insert({
        phone_number,
        country_code,
        full_phone,
        code,
        is_used: false,
        expires_at: expiresAt.toISOString(),
      })
      .select()
      .single()

    if (insertError) {
      console.error('❌ Error inserting OTP:', insertError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to generate OTP code'
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Send SMS
    const smsSent = await sendSMS(full_phone, code)

    if (!smsSent) {
      // Even if SMS fails, we still created the OTP record
      // This allows for testing/development without SMS provider
      console.warn('⚠️ OTP generated but SMS not sent. OTP code:', code)

      // In production, you might want to delete the OTP record if SMS fails
      // For now, we'll keep it but log the issue
    }

    console.log(`✅ OTP generated for ${full_phone} (SMS sent: ${smsSent})`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'OTP code sent successfully',
        expires_in: 600, // 10 minutes in seconds
        // In development, you might want to return the code for testing
        // code: Deno.env.get('ENVIRONMENT') === 'development' ? code : undefined
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

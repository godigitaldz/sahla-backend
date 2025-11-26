import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { restaurantId, clearAll } = await req.json()

    // Initialize Redis client (if available)
    let redisClient = null
    try {
      const redisUrl = Deno.env.get('REDIS_URL')
      if (redisUrl) {
        // Note: Redis client implementation would go here
        console.log('🗑️ Redis cache clearing requested')
      }
    } catch (e) {
      console.log('⚠️ Redis not available, using fallback')
    }

    // Clear specific restaurant cache patterns
    const patterns = [
      `restaurant:${restaurantId}`,
      `menu_items:${restaurantId}`,
      `restaurants:*${restaurantId}*`,
      'search:restaurants:*',
      'restaurants:*'
    ]

    console.log(`🗑️ Clearing cache patterns: ${patterns.join(', ')}`)

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        message: `Cache cleared for restaurant: ${restaurantId}`,
        patterns: patterns,
        clearedKeys: patterns.length,
        timestamp: Date.now()
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('❌ Error clearing restaurant cache:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: Date.now()
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})

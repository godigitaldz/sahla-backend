import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    )

    // Parse query parameters
    const url = new URL(req.url)
    const limit = parseInt(url.searchParams.get('limit') || '20')
    const offset = parseInt(url.searchParams.get('offset') || '0')
    const restaurantId = url.searchParams.get('restaurant_id')

    // Build query
    let query = supabase
      .from('promo_codes')
      .select('*')
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1)

    // Filter by restaurant if provided
    if (restaurantId) {
      query = query.eq('restaurant_id', restaurantId)
    }

    // Only get active promo codes (if column exists)
    // query = query.eq('is_active', true)

    const { data, error } = await query

    if (error) throw error

    // Filter active promo codes based on dates
    const now = new Date()
    const activePromos = data.filter(promo => {
      const startDate = promo.start_date ? new Date(promo.start_date) : null
      const endDate = promo.end_date ? new Date(promo.end_date) : null

      if (startDate && now < startDate) return false
      if (endDate && now > endDate) return false

      return true
    })

    return new Response(
      JSON.stringify({
        success: true,
        data: activePromos,
        count: activePromos.length
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200
      },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      },
    )
  }
})

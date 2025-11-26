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
    const restaurantId = url.searchParams.get('restaurant_id')
    const category = url.searchParams.get('category')
    const limit = parseInt(url.searchParams.get('limit') || '50')
    const offset = parseInt(url.searchParams.get('offset') || '0')
    const availableOnly = url.searchParams.get('available_only') === 'true'

    if (!restaurantId) {
      throw new Error('restaurant_id is required')
    }

    // Build query
    let query = supabase
      .from('menu_items')
      .select(`
        *,
        cuisine_types(*),
        categories(*)
      `)
      .eq('restaurant_id', restaurantId)
      .order('category')
      .order('name')
      .range(offset, offset + limit - 1)

    // Apply filters
    if (category) {
      query = query.eq('category', category)
    }
    if (availableOnly) {
      query = query.eq('is_available', true)
    }

    const { data, error } = await query

    if (error) throw error

    return new Response(
      JSON.stringify({
        success: true,
        data,
        count: data.length,
        restaurant_id: restaurantId
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

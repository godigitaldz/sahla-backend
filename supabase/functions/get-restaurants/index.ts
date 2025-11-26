import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    )

    // Parse query parameters
    const url = new URL(req.url)
    const category = url.searchParams.get('category')
    const cuisine = url.searchParams.get('cuisine')
    const limit = parseInt(url.searchParams.get('limit') || '20')
    const offset = parseInt(url.searchParams.get('offset') || '0')
    const minRating = url.searchParams.get('minRating')
    const isFeatured = url.searchParams.get('isFeatured')

    // Build query
    let query = supabase
      .from('restaurants')
      .select('*')
      .order('rating', { ascending: false })
      .range(offset, offset + limit - 1)

    // Apply filters
    if (category) {
      query = query.eq('category', category)
    }
    if (cuisine) {
      query = query.eq('cuisine_type', cuisine)
    }
    if (minRating) {
      query = query.gte('rating', parseFloat(minRating))
    }
    if (isFeatured === 'true') {
      query = query.eq('is_featured', true)
    }

    const { data, error } = await query

    if (error) throw error

    return new Response(
      JSON.stringify({
        success: true,
        data,
        count: data.length
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

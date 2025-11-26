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
    // Get auth token from header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader }
        }
      }
    )

    // Verify user is authenticated
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      throw new Error('Unauthorized')
    }

    // Parse request body
    const body = await req.json()
    const {
      restaurant_id,
      items,
      delivery_address,
      delivery_fee,
      subtotal,
      total,
      payment_method,
      promo_code,
      notes
    } = body

    // Validate required fields
    if (!restaurant_id || !items || items.length === 0) {
      throw new Error('Missing required fields: restaurant_id and items')
    }

    // Create order
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .insert({
        user_id: user.id,
        restaurant_id,
        delivery_address,
        delivery_fee: delivery_fee || 0,
        subtotal: subtotal || 0,
        total: total || 0,
        payment_method: payment_method || 'cash',
        promo_code,
        notes,
        status: 'pending',
      })
      .select()
      .single()

    if (orderError) throw orderError

    // Create order items
    const orderItems = items.map((item: any) => ({
      order_id: order.id,
      menu_item_id: item.menu_item_id,
      quantity: item.quantity,
      price: item.price,
      subtotal: item.quantity * item.price,
      customizations: item.customizations || null,
    }))

    const { error: itemsError } = await supabase
      .from('order_items')
      .insert(orderItems)

    if (itemsError) throw itemsError

    return new Response(
      JSON.stringify({
        success: true,
        data: order,
        message: 'Order created successfully'
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 201
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
        status: error.message === 'Unauthorized' ? 401 : 400
      },
    )
  }
})

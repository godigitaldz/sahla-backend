import { supabase } from '../config/supabase.js';

export class PromoCodeService {
  async getPromoCodes({ restaurantId, limit = 20, offset = 0 }) {
    let query = supabase
      .from('promo_codes')
      .select('*', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (restaurantId) {
      query = query.eq('restaurant_id', restaurantId);
    }

    const { data, error, count } = await query;

    if (error) throw error;

    // Filter active promo codes based on dates
    const now = new Date();
    const activePromos = data.filter(promo => {
      const startDate = promo.start_date ? new Date(promo.start_date) : null;
      const endDate = promo.end_date ? new Date(promo.end_date) : null;

      if (startDate && now < startDate) return false;
      if (endDate && now > endDate) return false;

      return true;
    });

    return { data: activePromos, count: activePromos.length };
  }

  async validatePromoCode(code, restaurantId) {
    const { data, error } = await supabase
      .from('promo_codes')
      .select('*')
      .eq('code', code.toUpperCase())
      .single();

    if (error) throw new Error('Promo code not found');

    // Validate dates
    const now = new Date();
    const startDate = data.start_date ? new Date(data.start_date) : null;
    const endDate = data.end_date ? new Date(data.end_date) : null;

    if (startDate && now < startDate) {
      throw new Error('Promo code not yet active');
    }
    if (endDate && now > endDate) {
      throw new Error('Promo code has expired');
    }

    // Validate restaurant
    if (data.restaurant_id && data.restaurant_id !== restaurantId) {
      throw new Error('Promo code not valid for this restaurant');
    }

    return data;
  }
}

export default new PromoCodeService();

import { supabase } from '../config/supabase.js';

export class CuisineService {
  async getCuisines() {
    const { data, error } = await supabase
      .from('cuisine_types')
      .select('*')
      .eq('is_active', true)
      .order('display_order')
      .order('name');

    if (error) throw error;

    return data;
  }

  async getCuisineById(id) {
    const { data, error } = await supabase
      .from('cuisine_types')
      .select('*')
      .eq('id', id)
      .single();

    if (error) throw error;

    return data;
  }
}

export default new CuisineService();

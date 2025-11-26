const { Client } = require('pg');

const CONNECTION_STRING = process.env.DB_URL || 'postgresql://postgres.wtowqpejzxlsmgywkjvn:Khazani05102002@aws-1-us-east-2.pooler.supabase.com:6543/postgres';

const SQL = `
-- Idempotent seed of wider mappings
-- Restaurants
INSERT INTO public.info_registry(namespace, entity, attribute, priority, source_type, source_schema, source_ref, source_column, id_column, notes) VALUES
  ('lo9ma','restaurant','description',10,'table','public','restaurants','description','id',''),
  ('lo9ma','restaurant','phone',10,'table','public','restaurants','phone','id',''),
  ('lo9ma','restaurant','email',10,'table','public','restaurants','email','id',''),
  ('lo9ma','restaurant','address_line1',10,'table','public','restaurants','address_line1','id',''),
  ('lo9ma','restaurant','address_line2',10,'table','public','restaurants','address_line2','id',''),
  ('lo9ma','restaurant','state',10,'table','public','restaurants','state','id',''),
  ('lo9ma','restaurant','postal_code',10,'table','public','restaurants','postal_code','id',''),
  ('lo9ma','restaurant','latitude',10,'table','public','restaurants','latitude','id',''),
  ('lo9ma','restaurant','longitude',10,'table','public','restaurants','longitude','id',''),
  ('lo9ma','restaurant','review_count',10,'table','public','restaurants','review_count','id',''),
  ('lo9ma','restaurant','delivery_fee',10,'table','public','restaurants','delivery_fee','id',''),
  ('lo9ma','restaurant','minimum_order',10,'table','public','restaurants','minimum_order','id',''),
  ('lo9ma','restaurant','estimated_delivery_time',10,'table','public','restaurants','estimated_delivery_time','id',''),
  ('lo9ma','restaurant','is_featured',10,'table','public','restaurants','is_featured','id',''),
  ('lo9ma','restaurant','is_verified',10,'table','public','restaurants','is_verified','id',''),
  ('lo9ma','restaurant','opening_hours',10,'table','public','restaurants','opening_hours','id',''),
  ('lo9ma','restaurant','wilaya',10,'table','public','restaurants','wilaya','id',''),
  ('lo9ma','restaurant','created_at',10,'table','public','restaurants','created_at','id',''),
  ('lo9ma','restaurant','updated_at',10,'table','public','restaurants','updated_at','id','')
ON CONFLICT (namespace, entity, attribute, priority) DO NOTHING;

-- Users (user_profiles)
INSERT INTO public.info_registry(namespace, entity, attribute, priority, source_type, source_schema, source_ref, source_column, id_column, notes) VALUES
  ('lo9ma','user','email',10,'table','public','user_profiles','email','id',''),
  ('lo9ma','user','role',10,'table','public','user_profiles','role','id',''),
  ('lo9ma','user','profile_image_url',10,'table','public','user_profiles','profile_image_url','id',''),
  ('lo9ma','user','is_active',10,'table','public','user_profiles','is_active','id',''),
  ('lo9ma','user','is_verified',10,'table','public','user_profiles','is_verified','id',''),
  ('lo9ma','user','last_login',10,'table','public','user_profiles','last_login','id',''),
  ('lo9ma','user','created_at',10,'table','public','user_profiles','created_at','id',''),
  ('lo9ma','user','updated_at',10,'table','public','user_profiles','updated_at','id','')
ON CONFLICT (namespace, entity, attribute, priority) DO NOTHING;

-- Orders
INSERT INTO public.info_registry(namespace, entity, attribute, priority, source_type, source_schema, source_ref, source_column, id_column, notes) VALUES
  ('lo9ma','order','subtotal',10,'table','public','orders','subtotal','id',''),
  ('lo9ma','order','delivery_fee',10,'table','public','orders','delivery_fee','id',''),
  ('lo9ma','order','tax_amount',10,'table','public','orders','tax_amount','id',''),
  ('lo9ma','order','payment_method',10,'table','public','orders','payment_method','id',''),
  ('lo9ma','order','payment_status',10,'table','public','orders','payment_status','id',''),
  ('lo9ma','order','special_instructions',10,'table','public','orders','special_instructions','id',''),
  ('lo9ma','order','estimated_delivery_time',10,'table','public','orders','estimated_delivery_time','id',''),
  ('lo9ma','order','actual_delivery_time',10,'table','public','orders','actual_delivery_time','id',''),
  ('lo9ma','order','actual_pickup_time',10,'table','public','orders','actual_pickup_time','id',''),
  ('lo9ma','order','created_at',10,'table','public','orders','created_at','id',''),
  ('lo9ma','order','updated_at',10,'table','public','orders','updated_at','id','')
ON CONFLICT (namespace, entity, attribute, priority) DO NOTHING;

-- Orders: delivery_address json fields (transform_sql uses {col})
INSERT INTO public.info_registry(namespace, entity, attribute, priority, source_type, source_schema, source_ref, source_column, id_column, transform_sql, notes) VALUES
  ('lo9ma','order','delivery_address_full',10,'table','public','orders','delivery_address','id','({col} ->> ''fullAddress'')',''),
  ('lo9ma','order','delivery_address_street',10,'table','public','orders','delivery_address','id','({col} ->> ''street'')',''),
  ('lo9ma','order','delivery_address_city',10,'table','public','orders','delivery_address','id','({col} ->> ''city'')',''),
  ('lo9ma','order','delivery_address_wilaya',10,'table','public','orders','delivery_address','id','({col} ->> ''wilaya'')',''),
  ('lo9ma','order','delivery_address_postal_code',10,'table','public','orders','delivery_address','id','({col} ->> ''postal_code'')',''),
  ('lo9ma','order','delivery_address_latitude',10,'table','public','orders','delivery_address','id','({col} ->> ''latitude'')',''),
  ('lo9ma','order','delivery_address_longitude',10,'table','public','orders','delivery_address','id','({col} ->> ''longitude'')','')
ON CONFLICT (namespace, entity, attribute, priority) DO NOTHING;

-- Menu items
INSERT INTO public.info_registry(namespace, entity, attribute, priority, source_type, source_schema, source_ref, source_column, id_column, notes) VALUES
  ('lo9ma','menu_item','name',10,'table','public','menu_items','name','id',''),
  ('lo9ma','menu_item','description',10,'table','public','menu_items','description','id',''),
  ('lo9ma','menu_item','image',10,'table','public','menu_items','image','id',''),
  ('lo9ma','menu_item','price',10,'table','public','menu_items','price','id',''),
  ('lo9ma','menu_item','category',10,'table','public','menu_items','category','id',''),
  ('lo9ma','menu_item','is_available',10,'table','public','menu_items','is_available','id',''),
  ('lo9ma','menu_item','is_featured',10,'table','public','menu_items','is_featured','id',''),
  ('lo9ma','menu_item','preparation_time',10,'table','public','menu_items','preparation_time','id',''),
  ('lo9ma','menu_item','rating',10,'table','public','menu_items','rating','id',''),
  ('lo9ma','menu_item','review_count',10,'table','public','menu_items','review_count','id',''),
  ('lo9ma','menu_item','created_at',10,'table','public','menu_items','created_at','id',''),
  ('lo9ma','menu_item','updated_at',10,'table','public','menu_items','updated_at','id','')
ON CONFLICT (namespace, entity, attribute, priority) DO NOTHING;

-- Order items
INSERT INTO public.info_registry(namespace, entity, attribute, priority, source_type, source_schema, source_ref, source_column, id_column, notes) VALUES
  ('lo9ma','order_item','order_id',10,'table','public','order_items','order_id','id',''),
  ('lo9ma','order_item','menu_item_id',10,'table','public','order_items','menu_item_id','id',''),
  ('lo9ma','order_item','quantity',10,'table','public','order_items','quantity','id',''),
  ('lo9ma','order_item','unit_price',10,'table','public','order_items','unit_price','id',''),
  ('lo9ma','order_item','total_price',10,'table','public','order_items','total_price','id',''),
  ('lo9ma','order_item','special_instructions',10,'table','public','order_items','special_instructions','id',''),
  ('lo9ma','order_item','created_at',10,'table','public','order_items','created_at','id','')
ON CONFLICT (namespace, entity, attribute, priority) DO NOTHING;

-- Promo codes
INSERT INTO public.info_registry(namespace, entity, attribute, priority, source_type, source_schema, source_ref, source_column, id_column, notes) VALUES
  ('lo9ma','promo_code','code',10,'table','public','promo_codes','code','id',''),
  ('lo9ma','promo_code','restaurant_id',10,'table','public','promo_codes','restaurant_id','id',''),
  ('lo9ma','promo_code','name',10,'table','public','promo_codes','name','id',''),
  ('lo9ma','promo_code','description',10,'table','public','promo_codes','description','id',''),
  ('lo9ma','promo_code','type',10,'table','public','promo_codes','type','id',''),
  ('lo9ma','promo_code','value',10,'table','public','promo_codes','value','id',''),
  ('lo9ma','promo_code','minimum_order_amount',10,'table','public','promo_codes','minimum_order_amount','id',''),
  ('lo9ma','promo_code','maximum_discount_amount',10,'table','public','promo_codes','maximum_discount_amount','id',''),
  ('lo9ma','promo_code','start_date',10,'table','public','promo_codes','start_date','id',''),
  ('lo9ma','promo_code','end_date',10,'table','public','promo_codes','end_date','id',''),
  ('lo9ma','promo_code','status',10,'table','public','promo_codes','status','id',''),
  ('lo9ma','promo_code','usage_limit',10,'table','public','promo_codes','usage_limit','id',''),
  ('lo9ma','promo_code','used_count',10,'table','public','promo_codes','used_count','id',''),
  ('lo9ma','promo_code','user_usage_limit',10,'table','public','promo_codes','user_usage_limit','id',''),
  ('lo9ma','promo_code','is_public',10,'table','public','promo_codes','is_public','id',''),
  ('lo9ma','promo_code','image_url',10,'table','public','promo_codes','image_url','id',''),
  ('lo9ma','promo_code','conditions',10,'table','public','promo_codes','conditions','id',''),
  ('lo9ma','promo_code','created_at',10,'table','public','promo_codes','created_at','id',''),
  ('lo9ma','promo_code','updated_at',10,'table','public','promo_codes','updated_at','id','')
ON CONFLICT (namespace, entity, attribute, priority) DO NOTHING;

-- Delivery personnel
INSERT INTO public.info_registry(namespace, entity, attribute, priority, source_type, source_schema, source_ref, source_column, id_column, notes) VALUES
  ('lo9ma','delivery_person','user_id',10,'table','public','delivery_personnel','user_id','id',''),
  ('lo9ma','delivery_person','license_number',10,'table','public','delivery_personnel','license_number','id',''),
  ('lo9ma','delivery_person','vehicle_type',10,'table','public','delivery_personnel','vehicle_type','id',''),
  ('lo9ma','delivery_person','vehicle_plate',10,'table','public','delivery_personnel','vehicle_plate','id',''),
  ('lo9ma','delivery_person','is_available',10,'table','public','delivery_personnel','is_available','id',''),
  ('lo9ma','delivery_person','is_online',10,'table','public','delivery_personnel','is_online','id',''),
  ('lo9ma','delivery_person','current_latitude',10,'table','public','delivery_personnel','current_latitude','id',''),
  ('lo9ma','delivery_person','current_longitude',10,'table','public','delivery_personnel','current_longitude','id',''),
  ('lo9ma','delivery_person','rating',10,'table','public','delivery_personnel','rating','id',''),
  ('lo9ma','delivery_person','total_deliveries',10,'table','public','delivery_personnel','total_deliveries','id',''),
  ('lo9ma','delivery_person','created_at',10,'table','public','delivery_personnel','created_at','id',''),
  ('lo9ma','delivery_person','updated_at',10,'table','public','delivery_personnel','updated_at','id','')
ON CONFLICT (namespace, entity, attribute, priority) DO NOTHING;

-- Notifications
INSERT INTO public.info_registry(namespace, entity, attribute, priority, source_type, source_schema, source_ref, source_column, id_column, notes) VALUES
  ('lo9ma','notification','user_id',10,'table','public','notifications','user_id','id',''),
  ('lo9ma','notification','title',10,'table','public','notifications','title','id',''),
  ('lo9ma','notification','message',10,'table','public','notifications','message','id',''),
  ('lo9ma','notification','type',10,'table','public','notifications','type','id',''),
  ('lo9ma','notification','is_read',10,'table','public','notifications','is_read','id',''),
  ('lo9ma','notification','data',10,'table','public','notifications','data','id',''),
  ('lo9ma','notification','created_at',10,'table','public','notifications','created_at','id','')
ON CONFLICT (namespace, entity, attribute, priority) DO NOTHING;

-- Aliases
INSERT INTO public.info_alias(namespace, entity, alias, attribute) VALUES
  ('lo9ma','restaurant','title','name'),
  ('lo9ma','restaurant','logo','logo_url'),
  ('lo9ma','order','number','order_number'),
  ('lo9ma','order','total','total_amount'),
  ('lo9ma','user','phone_number','phone')
ON CONFLICT (namespace, entity, alias) DO NOTHING;
`;

async function main() {
  const client = new Client({ connectionString: CONNECTION_STRING, ssl: { rejectUnauthorized: false } });
  await client.connect();
  await client.query('BEGIN');
  try {
    await client.query(SQL);
    await client.query('COMMIT');
    console.log('Extended info registry mappings applied.');
  } catch (e) {
    await client.query('ROLLBACK');
    console.error('Extend failed:', e.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();

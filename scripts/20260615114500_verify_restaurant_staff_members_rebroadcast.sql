-- Verification for pending-order rebroadcast recipients.
-- The backend includes active restaurant staff members when sending `new_order`
-- reminders for pending orders.

select
  to_regclass('public.restaurants') as restaurants_table,
  to_regclass('public.restaurant_staff_members') as restaurant_staff_members_table;

select
  restaurant_id,
  count(*) as active_staff_members
from public.restaurant_staff_members
where status = 'active'
group by restaurant_id
order by active_staff_members desc
limit 20;


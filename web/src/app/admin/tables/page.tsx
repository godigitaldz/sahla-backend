import { redirect } from 'next/navigation';

/** Table management uses Performance dashboard (same password as /performance). */
export default function AdminTablesRedirectPage() {
  redirect('/performance?view=restaurant-tables');
}

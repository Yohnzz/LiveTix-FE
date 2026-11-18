import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config();
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);

async function check() {
  const { data, error } = await supabase.from('concerts').select('id, title, status, category, venue');
  console.log('Error:', error);
  console.log('Concerts count:', data ? data.length : 0);
  console.log('Concerts:', JSON.stringify(data, null, 2));
}

check();

import { SUPABASE_URL, SUPABASE_ANON_KEY, DEMO_MODE } from "./config.js";
export const isDemo = DEMO_MODE;
export const supabase = isDemo ? null : window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
});

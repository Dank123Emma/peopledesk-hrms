// Set these values from your Supabase project. The anon/publishable key is intended for browser use;
// database security must be enforced with Row Level Security. Never put a service-role key here.
export const SUPABASE_URL = "https://rytnybvuvkimdmuubwco.supabase.co";
export const SUPABASE_ANON_KEY = "sb_publishable_-YX8If7F7xt8ATstLkRoNA_7pzBXVsW";
export const DEMO_MODE = SUPABASE_URL.includes("YOUR_PROJECT_REF") || SUPABASE_ANON_KEY.includes("YOUR_SUPABASE");

#!/usr/bin/env node
// Creates a login (used once to bootstrap the first admin; after that, admins
// create users from the app). Needs the service-role key — run it on a trusted
// machine, never ship the key in the app.
//
//   SUPABASE_URL=https://xxxx.supabase.co SUPABASE_SERVICE_ROLE_KEY=... \
//     node scripts/create-user.mjs <user_id> "<Full Name>" <admin|order_taker> <password>
import { createClient } from "@supabase/supabase-js";

const [userId, fullName, role, password] = process.argv.slice(2);
const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!userId || !fullName || !role || !password || !url || !key) {
  console.error('Usage: SUPABASE_URL=… SUPABASE_SERVICE_ROLE_KEY=… node create-user.mjs <user_id> "<Full Name>" <role> <password>');
  process.exit(1);
}
const login = userId.trim().toLowerCase();
const db = createClient(url, key, { auth: { persistSession: false } });

const { data, error } = await db.auth.admin.createUser({
  email: `${login}@parker.local`,
  password,
  email_confirm: true,
  user_metadata: { user_id: login, full_name: fullName },
});
if (error) {
  console.error("Auth error:", error.message);
  process.exit(1);
}
const { error: insErr } = await db.from("users").insert({
  id: data.user.id, user_id: login, full_name: fullName, role,
});
if (insErr) {
  await db.auth.admin.deleteUser(data.user.id);
  console.error("Profile error:", insErr.message);
  process.exit(1);
}
console.log(`Created ${role} "${login}" (${data.user.id})`);

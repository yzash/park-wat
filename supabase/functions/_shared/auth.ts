import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2.49.4";

export const LOGIN_DOMAIN = "parker.local";

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Expose-Headers": "content-disposition",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

function env(...names: string[]): string {
  for (const n of names) {
    const v = Deno.env.get(n);
    if (v) return v;
  }
  throw new Error(`Missing env ${names.join(" / ")}`);
}

export const supabaseUrl = () => env("SUPABASE_URL");
const anonKey = () => env("SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEY");
const serviceKey = () => env("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEY");

/** Client that acts as the calling user (row-level security applies). */
export function userClient(req: Request): SupabaseClient {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) throw new HttpError(401, "Missing Authorization header");
  return createClient(supabaseUrl(), anonKey(), {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Service-role client. Only use after requireAdmin() succeeded. */
export function adminClient(): SupabaseClient {
  return createClient(supabaseUrl(), serviceKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Verifies the caller's JWT and that they are an active admin. Returns their user id. */
export async function requireAdmin(req: Request): Promise<{ uid: string; client: SupabaseClient }> {
  const client = userClient(req);
  const token = req.headers.get("Authorization")!.replace(/^Bearer\s+/i, "");
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, "Not signed in");
  const { data: isAdmin, error: rpcError } = await client.rpc("is_admin");
  if (rpcError) throw new HttpError(500, rpcError.message);
  if (isAdmin !== true) throw new HttpError(403, "Admin only");
  return { uid: data.user.id, client };
}

export function handle(fn: (req: Request) => Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
    try {
      return await fn(req);
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.message }, e.status);
      console.error(e);
      return json({ error: (e as Error).message ?? "Internal error" }, 500);
    }
  };
}

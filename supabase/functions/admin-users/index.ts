// Admin user management: create, edit, reset password, (de)activate.
// Creating auth users needs the service-role key, so this runs server-side.
// Users are never hard-deleted — deactivation bans the login and keeps history.
import { adminClient, handle, HttpError, json, LOGIN_DOMAIN, requireAdmin } from "../_shared/auth.ts";

const USER_ID_RE = /^[a-z0-9][a-z0-9._-]{1,39}$/;
const BAN_FOREVER = "876000h"; // ~100 years

type Body =
  | { action: "create"; user_id: string; full_name: string; role: string; password: string }
  | { action: "update"; id: string; full_name?: string; role?: string }
  | { action: "reset_password"; id: string; password: string }
  | { action: "set_active"; id: string; is_active: boolean };

function checkPassword(p: unknown): string {
  if (typeof p !== "string" || p.length < 8) {
    throw new HttpError(400, "Password must be at least 8 characters");
  }
  return p;
}

Deno.serve(handle(async (req) => {
  const { uid } = await requireAdmin(req);
  const db = adminClient();
  const body = (await req.json()) as Body;

  const roleExists = async (role: string) => {
    const { data } = await db.from("roles").select("code").eq("code", role).maybeSingle();
    return !!data;
  };
  const activeAdminCount = async () => {
    const { count } = await db.from("users").select("id", { count: "exact", head: true })
      .eq("role", "admin").eq("is_active", true);
    return count ?? 0;
  };
  const getUser = async (id: string) => {
    const { data, error } = await db.from("users").select("*").eq("id", id).maybeSingle();
    if (error) throw new HttpError(500, error.message);
    if (!data) throw new HttpError(404, "User not found");
    return data;
  };

  switch (body.action) {
    case "create": {
      const userId = String(body.user_id ?? "").trim().toLowerCase();
      const fullName = String(body.full_name ?? "").trim();
      if (!USER_ID_RE.test(userId)) {
        throw new HttpError(400, "User ID: 2–40 characters, letters, digits, . _ - only");
      }
      if (!fullName) throw new HttpError(400, "Full name is required");
      if (!(await roleExists(body.role))) throw new HttpError(400, "Unknown role");
      const password = checkPassword(body.password);

      const { data: existing } = await db.from("users").select("id").ilike("user_id", userId).maybeSingle();
      if (existing) throw new HttpError(409, "That user ID is already taken");

      const { data: created, error } = await db.auth.admin.createUser({
        email: `${userId}@${LOGIN_DOMAIN}`,
        password,
        email_confirm: true,
        user_metadata: { user_id: userId, full_name: fullName },
      });
      if (error || !created.user) {
        throw new HttpError(400, error?.message?.includes("already") ? "That user ID is already taken" : (error?.message ?? "Could not create login"));
      }
      const { data: row, error: insErr } = await db.from("users").insert({
        id: created.user.id, user_id: userId, full_name: fullName, role: body.role, created_by: uid,
      }).select().single();
      if (insErr) {
        await db.auth.admin.deleteUser(created.user.id);
        throw new HttpError(400, insErr.message);
      }
      return json({ user: row });
    }

    case "update": {
      const user = await getUser(body.id);
      const patch: Record<string, unknown> = { updated_by: uid };
      if (body.full_name !== undefined) {
        const n = String(body.full_name).trim();
        if (!n) throw new HttpError(400, "Full name is required");
        patch.full_name = n;
      }
      if (body.role !== undefined && body.role !== user.role) {
        if (!(await roleExists(body.role))) throw new HttpError(400, "Unknown role");
        if (user.role === "admin" && user.is_active && (await activeAdminCount()) <= 1) {
          throw new HttpError(400, "Cannot change the role of the last active admin");
        }
        patch.role = body.role;
      }
      const { data, error } = await db.from("users").update(patch).eq("id", body.id).select().single();
      if (error) throw new HttpError(400, error.message);
      return json({ user: data });
    }

    case "reset_password": {
      await getUser(body.id);
      const { error } = await db.auth.admin.updateUserById(body.id, { password: checkPassword(body.password) });
      if (error) throw new HttpError(400, error.message);
      return json({ ok: true });
    }

    case "set_active": {
      const user = await getUser(body.id);
      const active = body.is_active === true;
      if (!active) {
        if (body.id === uid) throw new HttpError(400, "You cannot deactivate yourself");
        if (user.role === "admin" && user.is_active && (await activeAdminCount()) <= 1) {
          throw new HttpError(400, "Cannot deactivate the last active admin");
        }
      }
      const { error: banErr } = await db.auth.admin.updateUserById(body.id, {
        ban_duration: active ? "none" : BAN_FOREVER,
      });
      if (banErr) throw new HttpError(400, banErr.message);
      const { data, error } = await db.from("users").update({ is_active: active, updated_by: uid })
        .eq("id", body.id).select().single();
      if (error) throw new HttpError(400, error.message);
      return json({ user: data });
    }

    default:
      throw new HttpError(400, "Unknown action");
  }
}));

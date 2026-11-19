import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...corsHeaders, "Content-Type": "application/json" },
});
const allowedRoles = ["administrator", "hr", "manager", "payroll", "employee"];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json({ error: "Server configuration is incomplete." }, 500);

  const authHeader = req.headers.get("Authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Authentication is required." }, 401);

  const callerClient = createClient(url, anonKey, { global: { headers: { Authorization: `Bearer ${token}` } }, auth: { persistSession: false } });
  const { data: authData, error: authError } = await callerClient.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "Your session is invalid or expired." }, 401);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: caller, error: callerError } = await admin.from("profiles")
    .select("id,role,is_active").eq("id", authData.user.id).maybeSingle();
  if (callerError || !caller || !caller.is_active || !["administrator", "hr"].includes(caller.role)) {
    return json({ error: "You are not authorized to administer PeopleDesk accounts." }, 403);
  }

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON request." }, 400); }
  const action = body.action;

  if (action === "invite") {
    const employeeId = String(body.employee_id || "");
    const email = String(body.email || "").trim().toLowerCase();
    const role = String(body.role || "employee");
    if (!employeeId || !/^\S+@\S+\.\S+$/.test(email) || !allowedRoles.includes(role)) {
      return json({ error: "Provide a valid employee, email address and role." }, 400);
    }
    if (caller.role !== "administrator" && role !== "employee") {
      return json({ error: "HR users may only provision employee accounts. An administrator must assign privileged roles." }, 403);
    }
    const { data: employee, error: employeeError } = await admin.from("employees")
      .select("id,full_name,email,department,employment_status").eq("id", employeeId).maybeSingle();
    if (employeeError || !employee) return json({ error: "The selected employee record was not found." }, 404);
    if (employee.employment_status !== "Active") return json({ error: "Only active employees can be invited." }, 400);
    if (employee.email && employee.email.toLowerCase() !== email) return json({ error: "The invitation email must match the employee's email on record." }, 400);
    const { data: existingProfile } = await admin.from("profiles").select("id").eq("employee_id", employeeId).maybeSingle();
    if (existingProfile) return json({ error: "This employee is already linked to a PeopleDesk account." }, 409);

    const redirectTo = Deno.env.get("INVITE_REDIRECT_URL");
    const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
      data: { full_name: employee.full_name },
      ...(redirectTo ? { redirectTo } : {}),
    });
    if (inviteError || !invited.user) return json({ error: inviteError?.message || "Could not send the invitation." }, 400);

    const { error: profileError } = await admin.from("profiles").insert({
      id: invited.user.id, employee_id: employee.id, full_name: employee.full_name,
      role, department: employee.department || null, is_active: true,
    });
    if (profileError) {
      await admin.auth.admin.deleteUser(invited.user.id);
      return json({ error: `Invitation created but profile setup failed; the invited auth user was rolled back. ${profileError.message}` }, 500);
    }
    if (!employee.email) {
      const { error: emailUpdateError } = await admin.from("employees").update({ email }).eq("id", employee.id);
      if (emailUpdateError) {
        await admin.from("profiles").delete().eq("id", invited.user.id);
        await admin.auth.admin.deleteUser(invited.user.id);
        return json({ error: `Could not save the employee email; the invitation was rolled back. ${emailUpdateError.message}` }, 500);
      }
    }
    await admin.from("audit_logs").insert({ actor_id: authData.user.id, action: "invite_user", table_name: "profiles", record_id: invited.user.id, details: { employee_id: employee.id, role } });
    return json({ success: true, user_id: invited.user.id, message: "Invitation sent. The employee must accept the email invitation to set up access." });
  }

  const targetId = String(body.user_id || "");
  if (!targetId) return json({ error: "A target user ID is required." }, 400);
  if (targetId === authData.user.id && action === "set-active" && body.is_active === false) {
    return json({ error: "You cannot deactivate your own account." }, 400);
  }
  const { data: target, error: targetError } = await admin.from("profiles")
    .select("id,role,employee_id").eq("id", targetId).maybeSingle();
  if (targetError || !target) return json({ error: "The target account was not found." }, 404);
  if (caller.role !== "administrator" && target.role !== "employee") {
    return json({ error: "HR users may only manage employee accounts." }, 403);
  }

  if (action === "set-active") {
    if (typeof body.is_active !== "boolean") return json({ error: "is_active must be true or false." }, 400);
    if (body.is_active === true && target.employee_id) {
      const { data: employee } = await admin.from("employees").select("employment_status").eq("id", target.employee_id).maybeSingle();
      if (!employee || employee.employment_status !== "Active") return json({ error: "Only an employee with Active employment status can have account access reactivated." }, 400);
    }
    const { error } = await admin.from("profiles").update({ is_active: body.is_active }).eq("id", targetId);
    if (error) return json({ error: error.message }, 400);
    await admin.from("audit_logs").insert({ actor_id: authData.user.id, action: body.is_active ? "activate_user" : "deactivate_user", table_name: "profiles", record_id: targetId, details: {} });
    return json({ success: true });
  }

  if (action === "set-role") {
    if (caller.role !== "administrator") return json({ error: "Only an administrator can change account roles." }, 403);
    const role = String(body.role || "");
    if (!allowedRoles.includes(role)) return json({ error: "Invalid account role." }, 400);
    const { error } = await admin.from("profiles").update({ role }).eq("id", targetId);
    if (error) return json({ error: error.message }, 400);
    await admin.from("audit_logs").insert({ actor_id: authData.user.id, action: "change_user_role", table_name: "profiles", record_id: targetId, details: { role } });
    return json({ success: true });
  }
  return json({ error: "Unsupported account administration action." }, 400);
});

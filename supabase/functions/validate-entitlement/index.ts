import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json, sha256 } from "../_shared/http.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ entitled: false, error: "Method not allowed" }, 405);

  try {
    const { deviceId } = await req.json();
    if (typeof deviceId !== "string" || !deviceId.trim()) {
      return json({ entitled: false, error: "بيانات الجهاز غير مكتملة" }, 400);
    }

    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) return json({ entitled: false, error: "Server configuration error" }, 500);

    const supabase = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const deviceHash = await sha256(deviceId.trim());

    const { data: device, error } = await supabase
      .from("license_devices")
      .select("id, license_id")
      .eq("device_id_hash", deviceHash)
      .is("deactivated_at", null)
      .maybeSingle();

    if (error) {
      console.error("validate-entitlement device query:", error.message);
      return json({ entitled: false, error: "تعذر التحقق من الترخيص" }, 500);
    }
    if (!device) return json({ entitled: false });

    const { data: license, error: licenseError } = await supabase
      .from("licenses")
      .select("status, license_type, expires_at")
      .eq("id", device.license_id)
      .maybeSingle();

    if (licenseError) {
      console.error("validate-entitlement license query:", licenseError.message);
      return json({ entitled: false, error: "تعذر التحقق من الترخيص" }, 500);
    }

    const valid = !!license &&
      license.status === "active" &&
      license.license_type === "lifetime" &&
      (!license.expires_at || new Date(license.expires_at).getTime() > Date.now());

    if (valid) {
      await supabase.from("license_devices")
        .update({ last_validated_at: new Date().toISOString() })
        .eq("id", device.id);
    }
    return json({ entitled: valid, licenseType: valid ? "lifetime" : null });
  } catch (error) {
    console.error("validate-entitlement error:", error);
    return json({ entitled: false, error: "طلب التحقق غير صالح" }, 400);
  }
});

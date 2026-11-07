import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json, sha256 } from "../_shared/http.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "Method not allowed" }, 405);

  try {
    const { licenseKey, deviceId } = await req.json();
    if (typeof licenseKey !== "string" || !licenseKey.trim() ||
        typeof deviceId !== "string" || !deviceId.trim()) {
      return json({ success: false, error: "بيانات التفعيل غير مكتملة" }, 400);
    }

    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) return json({ success: false, error: "Server configuration error" }, 500);

    const supabase = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await supabase.rpc("activate_license_device", {
      p_license_key_hash: await sha256(licenseKey.trim()),
      p_device_id_hash: await sha256(deviceId.trim()),
    });
    if (error) {
      console.error("activate-license RPC error:", error.message);
      return json({ success: false, error: "تعذر تفعيل الترخيص حاليًا" }, 500);
    }
    return json(data);
  } catch (error) {
    console.error("activate-license error:", error);
    return json({ success: false, error: "طلب التفعيل غير صالح" }, 400);
  }
});

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json, sha256 } from "../_shared/http.ts";

function newLicenseKey(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(20));
  const raw = Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("").toUpperCase();
  return "NOVA-" + raw.match(/.{1,5}/g)!.join("-");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ success: false, error: "Method not allowed" }, 405);

  const adminSecret = Deno.env.get("LICENSE_ADMIN_SECRET");
  const suppliedSecret = req.headers.get("x-admin-secret");
  if (!adminSecret || !suppliedSecret || suppliedSecret !== adminSecret) {
    return json({ success: false, error: "Unauthorized" }, 401);
  }

  try {
    const body = await req.json().catch(() => ({}));
    const customerEmail = typeof body.customerEmail === "string" ? body.customerEmail.trim() : null;
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) return json({ success: false, error: "Server configuration error" }, 500);

    const licenseKey = newLicenseKey();
    const supabase = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { error } = await supabase.from("licenses").insert({
      license_key_hash: await sha256(licenseKey),
      license_type: "lifetime",
      status: "active",
      max_devices: 1,
      customer_email: customerEmail,
      expires_at: null,
    });
    if (error) {
      console.error("create-license insert error:", error.message);
      return json({ success: false, error: "تعذر إنشاء مفتاح الترخيص" }, 500);
    }

    // Plaintext key is returned once only. Never expose this endpoint or secret in the client app.
    return json({ success: true, licenseKey });
  } catch (error) {
    console.error("create-license error:", error);
    return json({ success: false, error: "تعذر إنشاء الترخيص" }, 500);
  }
});

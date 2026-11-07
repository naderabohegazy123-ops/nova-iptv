import { corsHeaders, json } from "../_shared/http.ts";

// Customer-side deactivation is disabled. Device resets must be handled by the administrator.
Deno.serve((req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  return json({ success: false, error: "إلغاء ربط الجهاز يتطلب مراجعة الإدارة" }, 403);
});

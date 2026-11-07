import { corsHeaders, json } from "../_shared/http.ts";

// Paid-only product: trials are intentionally disabled.
Deno.serve((req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  return json({ success: false, entitled: false, error: "التجربة المجانية غير متاحة" }, 410);
});

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Same reasoning as groq-proxy: verify_jwt = true (see config.toml)
// only proves the token is *a* valid Supabase JWT, and the public anon
// key is itself a valid JWT already shipping inside the compiled app —
// so the explicit auth.getUser(token) check below is what actually
// restricts this to a real logged-in user's session.
//
// USDA_API_KEY itself isn't a billing-linked secret the way the Groq
// key was — it's free and only rate-limits per key, not per dollar —
// but USDA's own key-usage policy still says not to expose it publicly
// or commit it to a repo, and this project already had one real
// incident from shipping an API key client-side. Proxying it costs
// nothing extra to set up given groq-proxy already exists as a
// template, so there's no reason to make a weaker choice here.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const USDA_API_KEY = Deno.env.get("USDA_API_KEY")!;
const USDA_BASE_URL = "https://api.nal.usda.gov/fdc/v1";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  const jsonHeaders = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
  };

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");

    const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const { data: { user }, error: authError } = await authClient.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Not authenticated" }),
        { status: 401, headers: jsonHeaders },
      );
    }

    const { query } = await req.json();
    if (!query || typeof query !== "string") {
      return new Response(
        JSON.stringify({ error: "Missing 'query' in request body" }),
        { status: 400, headers: jsonHeaders },
      );
    }

    const url = new URL(`${USDA_BASE_URL}/foods/search`);
    url.searchParams.set("api_key", USDA_API_KEY);
    url.searchParams.set("query", query);
    url.searchParams.set("pageSize", "25");
    // Foundation + SR Legacy cover raw/whole ingredients ("chicken
    // breast, raw"). Survey (FNDDS) specifically covers foods AS
    // EATEN — composite, prepared dishes like an omelette or a
    // sandwich — which is exactly the category Open Food Facts (a
    // packaged-product database) has the least coverage of, and the
    // actual reason this proxy exists. Branded Foods is deliberately
    // excluded — that's manufacturer label data, which overlaps with
    // what Open Food Facts already covers as the primary source.
    url.searchParams.set("dataType", "Foundation,SR Legacy,Survey (FNDDS)");

    const response = await fetch(url.toString());
    const data = await response.json();

    return new Response(JSON.stringify(data), {
      status: response.status,
      headers: jsonHeaders,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: jsonHeaders,
    });
  }
});
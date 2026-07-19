import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// verify_jwt = true (see config.toml) only checks that the incoming
// token is a cryptographically valid Supabase JWT — it does NOT check
// that it's a real logged-in user's session. The app's public anon key
// is itself a valid JWT (decode it at jwt.io, its payload literally
// says role: anon), and that key already ships inside the compiled app
// same as the Groq key used to. So verify_jwt alone would let anyone
// holding the anon key through. The explicit role check below is what
// actually restricts this to authenticated users.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY")!;
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  try {
    // The client must send its actual user session access token here,
    // not the anon key — see the note above for why the anon key alone
    // wouldn't be rejected by verify_jwt.
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Not authenticated" }),
        {
          status: 401,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        },
      );
    }

    // Forwarded as-is: { model, max_tokens, messages }. Both
    // meal_plan_screen.dart call sites (full-plan generation and
    // single-meal swap) already build this exact shape today for the
    // direct Groq call — the client-side change is just pointing the
    // request at this URL instead of api.groq.com, with the app's own
    // Supabase user session token instead of a Groq key.
    const body = await req.json();

    const response = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify(body),
    });

    const data = await response.json();

    return new Response(JSON.stringify(data), {
      status: response.status,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }
});
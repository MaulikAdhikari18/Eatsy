import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Same reasoning as groq-proxy: verify_jwt = true (see config.toml) only
// proves the token is *a* valid Supabase JWT, and the public anon key is
// itself a valid JWT — so the explicit auth.getUser(token) check below is
// what actually restricts this to a real logged-in user's own session,
// not just anyone holding the anon key.
//
// This function additionally needs the SERVICE ROLE key, not the anon
// key, because deleting a row from `auth.users` (auth.admin.deleteUser)
// is an admin-only operation — RLS and the anon/session key can never
// do it, by design. The service role key must ONLY ever live here, as
// an Edge Function secret; it must never be shipped in the Flutter app
// the way the old Groq key was.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Every table in the schema that stores rows keyed by user_id, keyed off
// the *column name* that points back to the user — profiles is the one
// exception, since its primary key IS the auth user's id (see
// auth_controller.dart's signUpWithEmail: `'id': response.user!.id`),
// not a separate user_id foreign key like everywhere else.
const USER_ID_TABLES = [
  "food_logs",
  "goals",
  "water_logs",
  "weight_logs",
  "diet_plans",
  "user_preferences",
];
const ID_KEYED_TABLES = ["profiles"];

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

    // Anon-key client purely to resolve "who is this token for" — never
    // used for the actual deletes, which need the service role client
    // below to bypass RLS (the user is about to lose access to their
    // own rows, so RLS working correctly would otherwise block this).
    const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const { data: { user }, error: authError } = await authClient.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Not authenticated" }),
        { status: 401, headers: jsonHeaders },
      );
    }

    const userId = user.id;
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Delete data first, and collect (rather than throw on) any
    // individual table failure — we want to know exactly which table
    // failed rather than a single opaque error, and we deliberately
    // do NOT delete the auth user below if anything here failed, so a
    // partial failure never results in an orphaned-but-inaccessible
    // account with no way for the person to try again.
    const tableErrors: Record<string, string> = {};

    for (const table of USER_ID_TABLES) {
      const { error } = await admin.from(table).delete().eq("user_id", userId);
      if (error) tableErrors[table] = error.message;
    }
    for (const table of ID_KEYED_TABLES) {
      const { error } = await admin.from(table).delete().eq("id", userId);
      if (error) tableErrors[table] = error.message;
    }

    if (Object.keys(tableErrors).length > 0) {
      return new Response(
        JSON.stringify({
          error: "Failed to delete some account data. No data was left partially deleted from auth — please try again.",
          tableErrors,
        }),
        { status: 500, headers: jsonHeaders },
      );
    }

    // Only reached once every data table above succeeded — this is the
    // irreversible step.
    const { error: deleteUserError } = await admin.auth.admin.deleteUser(userId);
    if (deleteUserError) {
      return new Response(
        JSON.stringify({ error: `Account data was removed, but deleting the login itself failed: ${deleteUserError.message}. Please contact support.` }),
        { status: 500, headers: jsonHeaders },
      );
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: jsonHeaders,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: jsonHeaders,
    });
  }
});
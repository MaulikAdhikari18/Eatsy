import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const CLIENT_ID = Deno.env.get("FATSECRET_CLIENT_ID")!;
const CLIENT_SECRET = Deno.env.get("FATSECRET_CLIENT_SECRET")!;
const AUTH_URL = "https://oauth.fatsecret.com/connect/token";
const BASE_URL = "https://platform.fatsecret.com/rest/server.api";

let accessToken: string | null = null;
let tokenExpiry: number = 0;

async function getAccessToken(): Promise<string> {
  if (accessToken && Date.now() < tokenExpiry) {
    return accessToken;
  }

  const credentials = btoa(`${CLIENT_ID}:${CLIENT_SECRET}`);
  const response = await fetch(AUTH_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Authorization": `Basic ${credentials}`,
    },
    body: "grant_type=client_credentials&scope=basic",
  });

  const data = await response.json();
  accessToken = data.access_token;
  tokenExpiry = Date.now() + (data.expires_in - 60) * 1000;
  return accessToken!;
}

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
    const { method, params } = await req.json();
    const token = await getAccessToken();

    const url = new URL(BASE_URL);
    url.searchParams.set("method", method);
    url.searchParams.set("format", "json");

    for (const [key, value] of Object.entries(params || {})) {
      url.searchParams.set(key, String(value));
    }

    const response = await fetch(url.toString(), {
      headers: { "Authorization": `Bearer ${token}` },
    });

    const data = await response.json();

    return new Response(JSON.stringify(data), {
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
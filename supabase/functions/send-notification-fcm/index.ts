import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-notification-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type NotificationRow = {
  id?: string;
  user_id?: string;
  title?: string;
  body?: string;
  category?: string;
  target_kind?: string | null;
  target_id?: string | null;
  data?: Record<string, unknown> | null;
  fcm_token?: string;
  token?: string;
};

type DatabaseWebhook = {
  type?: string;
  table?: string;
  schema?: string;
  record?: NotificationRow;
};

type FirebaseServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
};

let cachedAccessToken: string | null = null;
let cachedAccessTokenExpiry = 0;

Deno.serve(async (request) => {
  // 1. Tangani CORS Preflight
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: corsHeaders,
    });
  }

  // 2. Verifikasi Autentikasi / Secret (Opsional jika NOTIFICATION_WEBHOOK_SECRET dikonfigurasi)
  const expectedSecret = Deno.env.get("NOTIFICATION_WEBHOOK_SECRET")?.trim();
  if (expectedSecret && expectedSecret.length > 0) {
    const suppliedSecret =
      request.headers.get("x-notification-webhook-secret")?.trim() ?? "";
    const authHeader = request.headers.get("authorization")?.trim() ?? "";
    const bearerToken = authHeader.replace(/^Bearer\s+/i, "");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";

    const secretMatches =
      suppliedSecret.length > 0 &&
      constantTimeEquals(expectedSecret, suppliedSecret);
    const serviceRoleMatches =
      serviceRoleKey.length > 0 &&
      bearerToken.length > 0 &&
      constantTimeEquals(serviceRoleKey, bearerToken);

    if (!secretMatches && !serviceRoleMatches) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid webhook secret or bearer token." }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
  }

  try {
    const rawBody = await request.json();
    // Mendukung dua format:
    // A. Format Supabase Database Webhook (memiliki properti .record)
    // B. Format Pemanggilan Langsung HTTP / Test ({ user_id, title, body, ... })
    const webhook = rawBody as DatabaseWebhook;
    const row: NotificationRow = webhook.record ?? (rawBody as NotificationRow);

    const title = row.title ?? "Notifikasi LiveTix";
    const messageBody = row.body ?? "";
    const category = row.category ?? "general";
    const targetKind = row.target_kind ?? "";
    const targetId = row.target_id ?? "";
    const notificationId = row.id ?? "";

    // 3. Muat Firebase Service Account dari Secret
    const account = loadFirebaseServiceAccount();

    // 4. Tentukan daftar FCM token penerima
    let tokens: string[] = [];

    // Jika dipanggil dengan direct token (misal untuk testing spesifik device)
    if (row.fcm_token || row.token) {
      tokens = [row.fcm_token || row.token!];
    } else if (row.user_id) {
      // Ambil seluruh token milik user dari database tabel user_fcm_tokens
      const supabaseUrl = requiredSecret("SUPABASE_URL");
      const serviceRoleKey = requiredSecret("SUPABASE_SERVICE_ROLE_KEY");
      const supabase = createClient(supabaseUrl, serviceRoleKey);

      const { data: tokenRows, error: tokenError } = await supabase
        .from("user_fcm_tokens")
        .select("fcm_token")
        .eq("user_id", row.user_id);

      if (tokenError) {
        console.error("Gagal mengambil token FCM dari database:", tokenError);
        throw tokenError;
      }

      tokens = (tokenRows ?? [])
        .map((item) => (item.fcm_token as string)?.trim())
        .filter((token) => token && token.length > 0);
    } else {
      return new Response(
        JSON.stringify({
          error: "Payload harus menyertakan 'user_id' atau 'fcm_token'.",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (tokens.length === 0) {
      console.log(`[send-notification-fcm] Tidak ada token FCM untuk user: ${row.user_id}`);
      return new Response(
        JSON.stringify({
          sent: 0,
          message: "Tidak ada perangkat FCM terdaftar untuk penerima ini.",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 5. Ambil Google OAuth2 Access Token untuk FCM HTTP v1 API
    const accessToken = await getGoogleAccessToken(account);

    // 6. Kirim pesan ke semua token secara paralel
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const supabase = (supabaseUrl && serviceRoleKey)
      ? createClient(supabaseUrl, serviceRoleKey)
      : null;

    const results = await Promise.all(
      tokens.map(async (token) => {
        try {
          const response = await fetch(
            `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
            {
              method: "POST",
              headers: {
                Authorization: `Bearer ${accessToken}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                message: {
                  token,
                  notification: {
                    title,
                    body: messageBody,
                  },
                  data: {
                    notification_id: String(notificationId),
                    category: String(category),
                    target_kind: String(targetKind),
                    target_id: String(targetId),
                  },
                  android: {
                    priority: "HIGH",
                    notification: {
                      channel_id: "livetix_notifications",
                      sound: "default",
                    },
                  },
                  apns: {
                    payload: {
                      aps: {
                        sound: "default",
                        badge: 1,
                      },
                    },
                  },
                },
              }),
            },
          );

          const responseText = await response.text();

          if (!response.ok) {
            // Jika token sudah tidak valid / aplikasi diuninstall, bersihkan dari tabel
            if (responseText.includes("UNREGISTERED") && supabase) {
              console.warn(`[send-notification-fcm] Token tidak aktif, menghapus dari DB: ${token}`);
              await supabase
                .from("user_fcm_tokens")
                .delete()
                .eq("fcm_token", token);
              return { sent: false, token, error: "UNREGISTERED" };
            }

            console.error(`[send-notification-fcm] FCM API error (${response.status}):`, responseText);
            return { sent: false, token, error: responseText };
          }

          return { sent: true, token };
        } catch (sendErr) {
          console.error(`[send-notification-fcm] Exception saat kirim ke token ${token}:`, sendErr);
          return { sent: false, token, error: String(sendErr) };
        }
      }),
    );

    const successful = results.filter((r) => r.sent).length;
    const failed = results.filter((r) => !r.sent).length;

    console.log(`[send-notification-fcm] Selesai: ${successful} terkirim, ${failed} gagal.`);

    return new Response(
      JSON.stringify({
        success: true,
        sent: successful,
        failed,
        results,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("[send-notification-fcm] Handler exception:", error);
    return new Response(
      JSON.stringify({
        error: "Gagal mengirim push notification FCM.",
        details: String(error),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});

function requiredSecret(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing required secret: ${name}`);
  return value;
}

function loadFirebaseServiceAccount(): FirebaseServiceAccount {
  let raw = requiredSecret("FIREBASE_SERVICE_ACCOUNT").trim();

  // Jika dienkode base64, decode terlebih dahulu
  if (!raw.startsWith("{")) {
    try {
      raw = atob(raw);
    } catch (_) {
      // Abaikan jika bukan base64
    }
  }

  const account = JSON.parse(raw) as FirebaseServiceAccount;
  if (!account.client_email || !account.private_key || !account.project_id) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT tidak memiliki client_email, private_key, atau project_id.",
    );
  }
  return account;
}

function constantTimeEquals(expected: string, supplied: string): boolean {
  const left = new TextEncoder().encode(expected);
  const right = new TextEncoder().encode(supplied);
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let index = 0; index < left.length; index++) {
    mismatch |= left[index] ^ right[index];
  }
  return mismatch === 0;
}

async function getGoogleAccessToken(
  account: FirebaseServiceAccount,
): Promise<string> {
  if (cachedAccessToken && Date.now() < cachedAccessTokenExpiry) {
    return cachedAccessToken;
  }

  const now = Math.floor(Date.now() / 1000);
  const encodedHeader = base64UrlEncode(
    JSON.stringify({ alg: "RS256", typ: "JWT" }),
  );
  const encodedClaims = base64UrlEncode(
    JSON.stringify({
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsignedAssertion = `${encodedHeader}.${encodedClaims}`;
  const key = await importPrivateKey(account.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedAssertion),
  );
  const assertion = `${unsignedAssertion}.${base64UrlEncodeBytes(signature)}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  const payload = await response.json();
  if (!response.ok || typeof payload.access_token !== "string") {
    throw new Error(
      `Firebase OAuth token request failed: ${JSON.stringify(payload)}`,
    );
  }

  cachedAccessToken = payload.access_token;
  cachedAccessTokenExpiry =
    Date.now() + (Number(payload.expires_in) - 60) * 1000;
  return cachedAccessToken;
}

async function importPrivateKey(privateKey: string): Promise<CryptoKey> {
  // Membersihkan literal \n, header, footer, dan whitespace
  const encoded = privateKey
    .replace(/\\n/g, "")
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");

  const binary = atob(encoded);
  const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    bytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

function base64UrlEncode(value: string): string {
  return base64UrlEncodeBytes(new TextEncoder().encode(value));
}

function base64UrlEncodeBytes(value: ArrayBuffer | Uint8Array): string {
  const bytes = value instanceof Uint8Array ? value : new Uint8Array(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

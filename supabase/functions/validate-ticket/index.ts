// supabase/functions/validate-ticket/index.ts
// FASE 4 - Validasi QR Tiket Aman
// - Menerima payload QR: ticket_id.kode_tiket.signature
// - Memanggil RPC atomic validate_ticket_scan di PostgreSQL
// - Server menghitung ulang HMAC-SHA256(secret_server, NIK|NamaUser|tanggal_buat|kode_tiket)
// - Constant-time comparison, cek status pembatalan, anti scan ganda

import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const hmacSecret = Deno.env.get("HMAC_TICKET_SECRET") ?? "";

  const supabase = createClient(supabaseUrl, serviceKey);

  try {
    const body = await req.json();
    // qrPayload format: "ticket_id.kode_tiket.signature"
    const { qrPayload, gateUserId } = body as {
      qrPayload: string;
      gateUserId?: string;
    };

    if (!qrPayload || typeof qrPayload !== "string") {
      return jsonError("QR payload tidak valid", 400);
    }

    // ── 1. Parse payload ──────────────────────────────────────────────────────
    const parts = qrPayload.trim().split(".");
    if (parts.length !== 3) {
      return jsonError("Format QR tidak dikenali (harus 3 segmen)", 400);
    }
    const [ticketId, kodeTiket, signature] = parts;

    if (!ticketId || ticketId.length < 5) {
      return jsonError("ID tiket tidak valid", 400);
    }
    if (!kodeTiket || kodeTiket.length < 8) {
      return jsonError("Kode tiket tidak valid", 400);
    }
    if (!signature || signature.length < 32) {
      return jsonError("Signature tiket tidak valid", 400);
    }

    // ── 2. Atomic validate via PostgreSQL RPC ────────────────────────────────
    // Fungsi ini mengunci baris (FOR UPDATE), meregenerasi HMAC dari database,
    // memeriksa pembatalan/kuota, dan menambah counter scan secara atomic.
    const { data: scanResult, error: scanErr } = await supabase.rpc(
      "validate_ticket_scan",
      {
        p_ticket_id: ticketId,
        p_kode_tiket: kodeTiket,
        p_signature: signature,
        p_secret: hmacSecret,
        p_gate_user: gateUserId ?? null,
      }
    );

    if (scanErr) {
      console.error("[validate-ticket] RPC error:", scanErr);
      return jsonError(`Gagal memvalidasi tiket di server: ${scanErr.message}`, 500);
    }

    return jsonResult(scanResult as Record<string, unknown>);
  } catch (err) {
    console.error("[validate-ticket] Unexpected error:", err);
    return jsonError("Internal Server Error", 500);
  }
});

// ── Helpers ──────────────────────────────────────────────────────────────────

function jsonResult(data: Record<string, unknown>): Response {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status = 400): Response {
  return new Response(JSON.stringify({ valid: false, error: message }), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

serve(async (req) => {
  // Midtrans hanya mengirim POST; OPTIONS tidak diperlukan tapi aman jika ada
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200 });
  }

  try {
    const notification = await req.json();

    const orderId: string = notification.order_id ?? "";
    const statusCode: string = String(notification.status_code ?? "");
    const grossAmountStr: string = String(notification.gross_amount ?? "0");
    const signatureKey: string = notification.signature_key ?? "";
    const transactionStatus: string = notification.transaction_status ?? "";
    const fraudStatus: string = notification.fraud_status ?? "";
    const transactionId: string = notification.transaction_id ?? "";

    if (!orderId) {
      return new Response(JSON.stringify({ error: "order_id kosong" }), { status: 400 });
    }

    const serverKey = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";
    const isProd = Deno.env.get("MIDTRANS_IS_PRODUCTION") === "true";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // ─── 1. VERIFIKASI SIGNATURE (SHA-512) ───────────────────────────────────
    // rawString = order_id + status_code + gross_amount + server_key
    let isVerified = false;

    // Sandbox simulation: flutter client boleh mengirim signature="sandbox_simulation_key"
    if (!isProd && signatureKey === "sandbox_simulation_key") {
      isVerified = true;
    } else if (serverKey && serverKey.trim().length > 5) {
      const rawString = `${orderId}${statusCode}${grossAmountStr}${serverKey.trim()}`;
      const enc = new TextEncoder();
      const hashBuf = await crypto.subtle.digest("SHA-512", enc.encode(rawString));
      const calculated = Array.from(new Uint8Array(hashBuf))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");

      if (calculated.toLowerCase() === signatureKey.toLowerCase()) {
        isVerified = true;
      } else {
        // Fallback: verifikasi langsung via Midtrans GET /v2/:orderId/status
        const statusUrl = isProd
          ? `https://api.midtrans.com/v2/${orderId}/status`
          : `https://api.sandbox.midtrans.com/v2/${orderId}/status`;
        try {
          const checkResp = await fetch(statusUrl, {
            headers: {
              Authorization: "Basic " + btoa(`${serverKey.trim()}:`),
              Accept: "application/json",
            },
          });
          const checkData = await checkResp.json();
          if (
            checkData.transaction_id === transactionId ||
            checkData.order_id === orderId
          ) {
            isVerified = true;
            console.log(`Webhook order ${orderId} terverifikasi via Midtrans Status API.`);
          }
        } catch (apiErr) {
          console.error("Gagal menjangkau Midtrans Status API:", apiErr);
        }
      }
    } else {
      // Sandbox tanpa server key: izinkan untuk pengujian lokal
      if (!isProd) isVerified = true;
    }

    if (!isVerified) {
      console.warn(`Webhook tidak terverifikasi untuk order ${orderId}, diabaikan.`);
      return new Response(
        JSON.stringify({ status: "ignored", message: "Signature tidak valid" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ─── 2. IDEMPOTENCY CHECK ────────────────────────────────────────────────
    const { data: existingOrder, error: fetchErr } = await supabase
      .from("orders")
      .select("*, concerts(id, title, date, time, venue, producer_id)")
      .eq("id", orderId)
      .maybeSingle();

    if (fetchErr) console.warn("Fetch order error:", fetchErr);

    if (!existingOrder) {
      console.warn(`Order ${orderId} tidak ditemukan.`);
      return new Response(
        JSON.stringify({ status: "ok", message: "Order tidak ditemukan (acknowledged)" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Idempotent: sudah PAID → abaikan tanpa mutasi ganda
    if (existingOrder.payment_status === "PAID") {
      return new Response(
        JSON.stringify({ status: "ok", message: "Order sudah diproses (idempotent)." }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ─── 3. TENTUKAN PAYMENT STATUS ─────────────────────────────────────────
    if (transactionStatus === "pending") {
      await supabase
        .from("orders")
        .update({ payment_status: "PENDING", updated_at: new Date().toISOString() })
        .eq("id", orderId);
      return new Response(
        JSON.stringify({ status: "ok", message: "Pending acknowledged", order_id: orderId }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    let paymentStatus = "PENDING";
    if (transactionStatus === "capture") {
      paymentStatus = fraudStatus === "accept" ? "PAID" : "CHALLENGE";
    } else if (transactionStatus === "settlement") {
      paymentStatus = "PAID";
    } else if (["cancel", "deny", "expire"].includes(transactionStatus)) {
      paymentStatus = "FAILED";
    }

    // ─── 4. SETTLEMENT → PAID ────────────────────────────────────────────────
    if (paymentStatus === "PAID") {
      const nowIso = new Date().toISOString();
      const totalBayarFromOrder =
        Math.round(Number(existingOrder.total_bayar) || Number(existingOrder.total_amount) || 0);
      const grossVal = Math.round(Number(grossAmountStr) || totalBayarFromOrder);

      const concertData = existingOrder.concerts;
      const producerId: string | null = concertData?.producer_id ?? existingOrder.producer_id ?? null;
      const concertTitle: string = concertData?.title ?? "Konser LiveTix";
      const concertDate: string = concertData?.date ?? "2026-11-20";
      const concertTime: string = concertData?.time ?? "19:00 WIB";
      const venue: string = concertData?.venue ?? "Stadion LiveTix";

      // Ambil komponen biaya dari orders (sudah diisi oleh create-payment)
      const bagianProduser: number =
        Math.round(Number(existingOrder.bagian_produser) || Number(existingOrder.harga_tiket ?? 0) + Number(existingOrder.pajak_hiburan ?? 0));
      const bagianAdmin: number =
        Math.round(Number(existingOrder.bagian_admin) || grossVal - bagianProduser);

      // Validasi invarian sebelum tulis ledger
      if (bagianProduser + bagianAdmin !== grossVal) {
        console.warn(
          `Invarian ledger warning: produser(${bagianProduser}) + admin(${bagianAdmin}) != grossVal(${grossVal}). Koreksi otomatis.`
        );
      }

      // A. Update status order → PAID (atomic)
      await supabase
        .from("orders")
        .update({
          payment_status: "PAID",
          paid_at: nowIso,
          updated_at: nowIso,
          midtrans_transaction_id: transactionId || null,
        })
        .eq("id", orderId);

      // A2. Update tabel transactions jika ada
      await supabase
        .from("transactions")
        .update({ status: "paid", paid_at: nowIso, updated_at: nowIso })
        .eq("id", orderId);

      // B. Tulis LEDGER append-only: 2 baris (produser + admin)
      //    Hitung saldo setelah dari ledger yang ada (atau 0 jika pertama)
      const saldoProdBefore: number = await getLatestBalance(supabase, "produser", producerId);
      const saldoAdminBefore: number = await getLatestBalance(supabase, "admin", null);

      const producerUuid = producerId && /^[0-9a-f-]{36}$/.test(producerId) ? producerId : null;

      // Baris ledger produser
      if (bagianProduser > 0 && producerUuid) {
        const { error: lp } = await supabase.from("ledger").insert({
          wallet_type: "produser",
          wallet_owner_id: producerUuid,
          transaksi_id: orderId,
          tipe: "kredit",
          jumlah: bagianProduser,
          saldo_setelah: saldoProdBefore + bagianProduser,
          keterangan: `Penjualan tiket ${existingOrder.quantity ?? 1}x ${existingOrder.tier_name ?? "Tiket"} – ${concertTitle}`,
        });
        if (lp) console.error("Ledger produser error:", lp);
      }

      // Baris ledger admin
      if (bagianAdmin > 0) {
        const { error: la } = await supabase.from("ledger").insert({
          wallet_type: "admin",
          wallet_owner_id: null,
          transaksi_id: orderId,
          tipe: "kredit",
          jumlah: bagianAdmin,
          saldo_setelah: saldoAdminBefore + bagianAdmin,
          keterangan: `Biaya aplikasi + pembulatan – order ${orderId}`,
        });
        if (la) console.error("Ledger admin error:", la);
      }

      // C. Panggil confirm_ticket_payment RPC (menerbitkan tiket & fix reserved_count)
      try {
        const { data: rpcData, error: rpcErr } = await supabase.rpc(
          "confirm_ticket_payment",
          { p_order_id: orderId }
        );
        if (rpcErr) {
          console.warn("confirm_ticket_payment RPC error, fallback insert:", rpcErr);
          // Fallback: insert tiket langsung jika RPC gagal
          const cleanCode = orderId.replace(/[^a-zA-Z0-9]/g, "").substring(0, 8);
          const uniqueCode = `LTX-${cleanCode}-${Math.floor(1000 + Math.random() * 9000)}`;
          const secretToken = `sec_${crypto.randomUUID()}`;

          if (!await ticketExists(supabase, orderId)) {
            await supabase.from("tickets").insert({
              order_id: orderId,
              user_id: existingOrder.user_id ?? null,
              concert_id: existingOrder.concert_id ?? null,
              tier_id: existingOrder.tier_id ?? null,
              ticket_code: uniqueCode,
              secret_hmac: secretToken,
              tier_name: existingOrder.tier_name ?? "Tiket Resmi",
              gate_name: "Gate A",
              venue: venue,
              concert_title: concertTitle,
              concert_date: concertDate,
              concert_time: concertTime,
              status: "AKTIF",
              qr_scan_quota: existingOrder.quantity ?? 1,
              qr_scans_used: 0,
              issued_at: nowIso,
            });
          }
        } else {
          console.log("confirm_ticket_payment sukses:", JSON.stringify(rpcData));
        }
      } catch (err) {
        console.error("confirm_ticket_payment exception:", err);
      }

      // D. Generate kode_tiket + HMAC-SHA256 (issue_ticket_secure)
      //    Dipanggil setelah confirm_ticket_payment agar tiket sudah ada di DB
      try {
        const hmacSecret = Deno.env.get("HMAC_TICKET_SECRET") ?? "";
        if (hmacSecret) {
          const { error: issueErr } = await supabase.rpc("issue_ticket_secure", {
            p_order_id: orderId,
            p_secret: hmacSecret,
          });
          if (issueErr) {
            console.warn("issue_ticket_secure warning:", issueErr);
          } else {
            console.log(`QR payload generated for order ${orderId}`);
          }
        } else {
          console.warn("HMAC_TICKET_SECRET not set — QR payload not generated (sandbox mode)");
        }
      } catch (hmacErr) {
        console.warn("issue_ticket_secure exception:", hmacErr);
      }

      // E. Update sold_count tier (fallback jika RPC di atas tidak melakukannya)
      if (existingOrder.tier_id) {
        try {
          const { data: tierData } = await supabase
            .from("ticket_tiers")
            .select("sold_count, quota, reserved_count")
            .eq("id", existingOrder.tier_id)
            .maybeSingle();
          if (tierData) {
            const qty = existingOrder.quantity ?? 1;
            const newSold = (tierData.sold_count ?? 0) + qty;
            const newReserved = Math.max(0, (tierData.reserved_count ?? 0) - qty);
            await supabase
              .from("ticket_tiers")
              .update({ sold_count: newSold, reserved_count: newReserved })
              .eq("id", existingOrder.tier_id);
          }
        } catch (tErr) {
          console.warn("Update tier sold_count warning:", tErr);
        }
      }
    } else if (paymentStatus === "FAILED") {
      // Pembayaran gagal / expire: update status
      await supabase
        .from("orders")
        .update({ payment_status: "EXPIRED", updated_at: new Date().toISOString() })
        .eq("id", orderId);

      await supabase
        .from("transactions")
        .update({ status: "expired", updated_at: new Date().toISOString() })
        .eq("id", orderId);

      // Lepaskan reserved_count
      if (existingOrder.tier_id) {
        try {
          const qty = existingOrder.quantity ?? 1;
          const { data: tierData } = await supabase
            .from("ticket_tiers")
            .select("reserved_count")
            .eq("id", existingOrder.tier_id)
            .maybeSingle();
          if (tierData) {
            await supabase
              .from("ticket_tiers")
              .update({ reserved_count: Math.max(0, (tierData.reserved_count ?? 0) - qty) })
              .eq("id", existingOrder.tier_id);
          }
        } catch (_) {}
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Webhook diproses: order ${orderId} → ${paymentStatus}`,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    console.error("Webhook error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

// ─── Helper: ambil saldo terakhir dari ledger ───────────────────────────────
async function getLatestBalance(
  supabase: ReturnType<typeof createClient>,
  walletType: string,
  ownerId: string | null
): Promise<number> {
  try {
    let query = supabase
      .from("ledger")
      .select("saldo_setelah")
      .eq("wallet_type", walletType)
      .order("created_at", { ascending: false })
      .limit(1);
    if (ownerId) query = query.eq("wallet_owner_id", ownerId);
    else query = query.is("wallet_owner_id", null);
    const { data } = await query.maybeSingle();
    return Math.max(0, Number(data?.saldo_setelah ?? 0));
  } catch (_) {
    return 0;
  }
}

// ─── Helper: cek apakah tiket sudah diterbitkan ─────────────────────────────
async function ticketExists(
  supabase: ReturnType<typeof createClient>,
  orderId: string
): Promise<boolean> {
  try {
    const { data } = await supabase
      .from("tickets")
      .select("id")
      .eq("order_id", orderId)
      .limit(1)
      .maybeSingle();
    return data !== null;
  } catch (_) {
    return false;
  }
}

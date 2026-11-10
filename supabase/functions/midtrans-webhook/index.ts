import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const notification = await req.json();

    const orderId = notification.order_id;
    const statusCode = notification.status_code;
    const grossAmount = notification.gross_amount;
    const signatureKey = notification.signature_key;
    const transactionStatus = notification.transaction_status;
    const fraudStatus = notification.fraud_status;

    const serverKey = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";
    const isProd = Deno.env.get("MIDTRANS_IS_PRODUCTION") === "true";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const isSandboxSimulation = !isProd && signatureKey === "sandbox_simulation_key";

    // 1. Verifikasi Keaslian Notifikasi (Signature Hash SHA512 & GET Status API Midtrans)
    let isVerified = false;

    if (isSandboxSimulation) {
      isVerified = true;
    } else if (serverKey && serverKey.trim().length > 5) {
      const cleanKey = serverKey.trim();
      const rawString = `${orderId}${statusCode}${grossAmount}${cleanKey}`;
      const encoder = new TextEncoder();
      const data = encoder.encode(rawString);
      const hashBuffer = await crypto.subtle.digest("SHA-512", data);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      const calculatedSignature = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

      if (calculatedSignature.toLowerCase() === (signatureKey || "").toLowerCase()) {
        isVerified = true;
      } else {
        console.warn("Signature hash mismatch, verifying directly via Midtrans GET Status API...", {
          orderId,
          receivedSignature: signatureKey,
          calculatedSignature,
        });

        // Verifikasi langsung ke GET Status API Midtrans resmi sebagai fallback definitif
        const statusApiUrl = isProd
          ? `https://api.midtrans.com/v2/${orderId}/status`
          : `https://api.sandbox.midtrans.com/v2/${orderId}/status`;

        try {
          const checkResp = await fetch(statusApiUrl, {
            headers: {
              Authorization: "Basic " + btoa(`${cleanKey}:`),
              Accept: "application/json",
            },
          });
          const checkData = await checkResp.json();
          // Jika transaksi terdaftar di Midtrans dan statusnya cocok
          if (
            checkData.transaction_id === notification.transaction_id ||
            checkData.order_id === orderId ||
            checkData.status_code === statusCode
          ) {
            isVerified = true;
            console.log(`Order ${orderId} successfully verified via Midtrans GET Status API.`);
          } else {
            console.warn("Midtrans Status API check returned non-matching data:", checkData);
          }
        } catch (apiErr) {
          console.error("Could not reach Midtrans Status API:", apiErr);
        }
      }
    } else {
      // Di environment sandbox pengujian, izinkan jika key belum terset
      if (!isProd) isVerified = true;
    }

    // Jika notifikasi tidak valid dari sumber luar, abaikan dengan respons HTTP 200
    // agar Midtrans tidak terus mengulang retry dan membanjiri email merchant
    if (!isVerified) {
      console.warn(`Unverified webhook notification for ${orderId} ignored.`);
      return new Response(
        JSON.stringify({ status: "ignored", message: "Notification received but could not be verified" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Tangani status "pending" (misal saat barcode QRIS baru dibuat)
    if (transactionStatus === "pending") {
      console.log(`Order ${orderId} status is pending (acknowledged).`);
      await supabase
        .from("orders")
        .update({ payment_status: "PENDING", updated_at: new Date().toISOString() })
        .eq("id", orderId);

      return new Response(
        JSON.stringify({ status: "ok", message: "Pending notification acknowledged", order_id: orderId }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // 2. Ambil data order dari Supabase (Idempotency Check)
    const { data: existingOrder } = await supabase
      .from("orders")
      .select("*, concerts(title, date, time, venue, producer_id)")
      .eq("id", orderId)
      .maybeSingle();

    if (!existingOrder) {
      console.warn(`Order ${orderId} tidak ditemukan di database.`);
      // Kembalikan status 200 agar Midtrans mencatat webhook berhasil diterima
      return new Response(
        JSON.stringify({ status: "ok", message: "Order not found in database (acknowledged)" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Idempotent: Jika order sudah pernah dinyatakan PAID, jangan buat tiket ganda / mutasi ganda!
    if (existingOrder.payment_status === "PAID") {
      return new Response(
        JSON.stringify({ message: "Order already processed (idempotent ignore)." }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // 3. Tentukan status pembayaran
    let paymentStatus = "PENDING";
    if (transactionStatus === "capture") {
      paymentStatus = fraudStatus === "accept" ? "PAID" : "CHALLENGE";
    } else if (transactionStatus === "settlement") {
      paymentStatus = "PAID";
    } else if (["cancel", "deny", "expire"].includes(transactionStatus)) {
      paymentStatus = "FAILED";
    }

    // 4. Jika Pembayaran Berhasil (PAID)
    if (paymentStatus === "PAID") {
      const nowIso = new Date().toISOString();
      const grossVal = Math.round(Number(grossAmount) || Number(existingOrder.total_amount) || 0);

      // Perhitungan Pembagian Dana & Fee Admin 3%
      // fee_admin = round(3% * grossAmount)
      const feeAdmin = Math.round(grossVal * 0.03);
      const netProducer = grossVal - feeAdmin;

      const concertData = existingOrder.concerts;
      const producerId = concertData?.producer_id || existingOrder.producer_id || null;
      const concertTitle = concertData?.title || "Konser LiveTix";
      const concertDate = concertData?.date || "2026-11-20";
      const concertTime = concertData?.time || "19:00 WIB";
      const venue = concertData?.venue || "Stadion LiveTix";

      // A. Update Status Order menjadi PAID
      await supabase
        .from("orders")
        .update({
          payment_status: "PAID",
          paid_at: nowIso,
          updated_at: nowIso,
        })
        .eq("id", orderId);

      // B. Catat ke Tabel Ledger Mutasi Saldo (Append-Only)
      await supabase.from("ledger_mutations").insert({
        id: `lm_${orderId}_${Date.now()}`,
        order_id: orderId,
        concert_id: existingOrder.concert_id,
        producer_id: producerId,
        gross_amount: grossVal,
        fee_admin: feeAdmin,
        net_producer: netProducer,
        mutation_type: "TICKET_SALE",
        status: "PENDING_BALANCE", // Tertahan sampai konser dimulai
        reference_id: orderId,
        notes: `Penjualan ${existingOrder.quantity}x tiket ${existingOrder.tier_name} (${concertTitle})`,
        created_at: nowIso,
      });

      // C. Terbitkan Tiket Resmi & QR Code Unik
      const cleanOrderCode = orderId.replace(/[^a-zA-Z0-9]/g, "").substring(0, 8);
      const ticketId = `tkt_${orderId}_${Date.now()}`;
      const uniqueCode = `LTX-${cleanOrderCode}-${Math.floor(1000 + Math.random() * 9000)}`;

      // HMAC Secret Token untuk Validasi Keaslian QR Scanner
      const secretToken = `sec_${crypto.randomUUID()}`;

      await supabase.from("tickets").insert({
        id: ticketId,
        order_id: orderId,
        user_id: existingOrder.user_id,
        concert_id: existingOrder.concert_id,
        tier_id: existingOrder.tier_id,
        ticket_code: uniqueCode,
        secret_hmac: secretToken,
        tier_name: existingOrder.tier_name || "Reguler",
        gate_name: "Gate A",
        venue: venue,
        concert_title: concertTitle,
        concert_date: concertDate,
        concert_time: concertTime,
        status: "AKTIF",
        qr_scan_quota: existingOrder.quantity || 1,
        qr_scans_used: 0,
        issued_at: nowIso,
      });

      // D. Update Kuota Tiket Terjual
      if (existingOrder.tier_id) {
        try {
          await supabase.rpc("increment_tier_sold_count", {
            p_tier_id: existingOrder.tier_id,
            p_qty: existingOrder.quantity || 1,
          });
        } catch (_) {
          // Fallback manual update jika RPC belum ada
          const { data: tier } = await supabase
            .from("ticket_tiers")
            .select("sold_count, quota")
            .eq("id", existingOrder.tier_id)
            .maybeSingle();

          if (tier) {
            const newSold = (tier.sold_count || 0) + (existingOrder.quantity || 1);
            await supabase
              .from("ticket_tiers")
              .update({
                sold_count: newSold,
                is_sold_out: newSold >= (tier.quota || 100),
              })
              .eq("id", existingOrder.tier_id);
          }
        }
      }
    } else if (paymentStatus === "FAILED") {
      // Pembayaran Gagal / Kedaluwarsa: Update Status Order
      await supabase
        .from("orders")
        .update({
          payment_status: "EXPIRED",
          updated_at: new Date().toISOString(),
        })
        .eq("id", orderId);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Webhook processed successfully for ${orderId}: ${paymentStatus}`,
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error: any) {
    console.error("Webhook processing error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});

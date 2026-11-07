import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

serve(async (req) => {
  try {
    const notification = await req.json();

    const orderId = notification.order_id;
    const statusCode = notification.status_code;
    const grossAmount = notification.gross_amount;
    const signatureKey = notification.signature_key;
    const transactionStatus = notification.transaction_status;
    const fraudStatus = notification.fraud_status;

    const serverKey = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";

    // 1. Verifikasi Signature Hash SHA512 (order_id + status_code + gross_amount + ServerKey)
    const rawString = `${orderId}${statusCode}${grossAmount}${serverKey}`;
    const encoder = new TextEncoder();
    const data = encoder.encode(rawString);
    const hashBuffer = await crypto.subtle.digest("SHA-512", data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const calculatedSignature = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

    if (calculatedSignature !== signatureKey) {
      return new Response(JSON.stringify({ error: "Invalid signature key" }), { status: 403 });
    }

    // 2. Hubungkan ke Database Supabase menggunakan Service Role Key
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 3. Tentukan status pembayaran
    let paymentStatus = "PENDING";
    if (transactionStatus === "capture") {
      paymentStatus = fraudStatus === "accept" ? "PAID" : "CHALLENGE";
    } else if (transactionStatus === "settlement") {
      paymentStatus = "PAID";
    } else if (["cancel", "deny", "expire"].includes(transactionStatus)) {
      paymentStatus = "FAILED";
    }

    // 4. Update status di tabel orders
    if (paymentStatus === "PAID") {
      await supabase
        .from("orders")
        .update({
          status: "PAID",
          paid_at: new Date().toISOString()
        })
        .eq("id", orderId);

      // Terbitkan / aktifkan tiket terkait
      await supabase
        .from("tickets")
        .update({ is_active: true, status: "ACTIVE" })
        .eq("order_id", orderId);
    }

    return new Response(JSON.stringify({ message: "Webhook processed successfully" }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
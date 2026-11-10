import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const {
      orderId,
      concertId,
      tierId,
      quantity,
      paymentMethod, // 'QRIS', 'GOPAY', 'SHOPEEPAY', 'BCA_VA', 'BNI_VA', 'BRI_VA', 'MANDIRI_BILL', 'PERMATA_VA'
      customerName,
      customerEmail,
      customerPhone,
      userId,
    } = body;

    const serverKey = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";
    const isProd = Deno.env.get("MIDTRANS_IS_PRODUCTION") === "true";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "https://ljjnbovuihyymdmrikuq.supabase.co";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    console.log("create-payment called, supabaseUrl:", supabaseUrl, "hasServiceKey:", Boolean(supabaseServiceKey));
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Ambil data harga resmi dari database backend (Mencegah manipulasi harga dari client)
    let ticketPrice = 0;
    let tierName = "Reguler";
    let concertTitle = "Konser LiveTix";
    let validConcertId: string | null = null;

    if (tierId) {
      const { data: tier } = await supabase
        .from("ticket_tiers")
        .select("name, price, quota, sold_count, concert_id")
        .eq("id", tierId)
        .maybeSingle();

      if (tier) {
        ticketPrice = Number(tier.price) || 0;
        tierName = tier.name;
        if (tier.concert_id) validConcertId = tier.concert_id;
      }
    }

    if (concertId) {
      const { data: concert } = await supabase
        .from("concerts")
        .select("id, title, price")
        .eq("id", concertId)
        .maybeSingle();

      if (concert) {
        validConcertId = concert.id;
        if (ticketPrice <= 0) {
          ticketPrice = Number(concert.price) || 0;
        }
        concertTitle = concert.title || concertTitle;
      }
    }

    // Fallback jika database belum ada data konser ini
    if (ticketPrice <= 0) {
      ticketPrice = Number(body.ticketPrice) || 150000;
    }

    const qty = Math.max(1, Number(quantity) || 1);
    const subtotal = ticketPrice * qty;
    const serviceFee = 5000;
    const taxAndAdmin = Math.round(subtotal * 0.05); // 5% pajak & platform
    const grossAmount = subtotal + serviceFee + taxAndAdmin;

    // 2. Tentukan konfigurasi Midtrans Core API (/v2/charge)
    const midtransUrl = isProd
      ? "https://api.midtrans.com/v2/charge"
      : "https://api.sandbox.midtrans.com/v2/charge";

    const authHeader = "Basic " + btoa(`${serverKey}:`);

    const midtransPayload: Record<string, any> = {
      transaction_details: {
        order_id: orderId,
        gross_amount: grossAmount,
      },
      customer_details: {
        first_name: customerName || "Penonton LiveTix",
        email: customerEmail || "user@livetix.com",
        phone: customerPhone || "081234567890",
      },
      item_details: [
        {
          id: tierId || "TIER-01",
          price: ticketPrice,
          quantity: qty,
          name: `${tierName} - ${concertTitle}`.substring(0, 50),
        },
        {
          id: "FEE-SERVICE",
          price: serviceFee,
          quantity: 1,
          name: "Biaya Layanan",
        },
        {
          id: "TAX-ADMIN",
          price: taxAndAdmin,
          quantity: 1,
          name: "Pajak & Penanganan",
        },
      ],
      custom_expiry: {
        expiry_duration: 60,
        unit: "minute",
      },
    };

    const methodUpper = (paymentMethod || "QRIS").toUpperCase();

    if (methodUpper.includes("QRIS")) {
      midtransPayload.payment_type = "qris";
      midtransPayload.qris = { acquirer: "gopay" };
    } else if (methodUpper.includes("GOPAY")) {
      midtransPayload.payment_type = "gopay";
      midtransPayload.gopay = {
        enable_callback: true,
        callback_url: "livetix://payment/callback",
      };
    } else if (methodUpper.includes("SHOPEE")) {
      midtransPayload.payment_type = "shopeepay";
      midtransPayload.shopeepay = {
        callback_url: "livetix://payment/callback",
      };
    } else if (methodUpper.includes("MANDIRI")) {
      midtransPayload.payment_type = "echannel";
      midtransPayload.echannel = {
        bill_info1: "Pembayaran Tiket:",
        bill_info2: "LiveTix Konser",
      };
    } else if (methodUpper.includes("PERMATA")) {
      midtransPayload.payment_type = "permata";
    } else if (methodUpper.includes("BCA")) {
      midtransPayload.payment_type = "bank_transfer";
      midtransPayload.bank_transfer = { bank: "bca" };
    } else if (methodUpper.includes("BNI")) {
      midtransPayload.payment_type = "bank_transfer";
      midtransPayload.bank_transfer = { bank: "bni" };
    } else if (methodUpper.includes("BRI")) {
      midtransPayload.payment_type = "bank_transfer";
      midtransPayload.bank_transfer = { bank: "bri" };
    } else {
      // Default Bank VA BCA
      midtransPayload.payment_type = "bank_transfer";
      midtransPayload.bank_transfer = { bank: "bca" };
    }

    let midtransResponse: any = null;
    let qrString = "";
    let qrUrl = "";
    let deeplinkUrl = "";
    let vaNumber = "";
    let billerCode = "";
    let billKey = "";

    // 3. Panggil API Midtrans jika serverKey tersedia
    if (serverKey && serverKey.trim().length > 5) {
      const resp = await fetch(midtransUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          Authorization: authHeader,
        },
        body: JSON.stringify(midtransPayload),
      });

      midtransResponse = await resp.json();

      // Ekstraksi response berdasarkan payment_type
      if (midtransResponse.qr_string) {
        qrString = midtransResponse.qr_string;
      }
      if (Array.isArray(midtransResponse.actions)) {
        for (const action of midtransResponse.actions) {
          if (action.name === "generate-qr-code" || action.name === "qr-code") {
            qrUrl = action.url;
          }
          if (action.name === "deeplink-redirect") {
            deeplinkUrl = action.url;
          }
        }
      }
      if (Array.isArray(midtransResponse.va_numbers) && midtransResponse.va_numbers.length > 0) {
        vaNumber = midtransResponse.va_numbers[0].va_number;
      } else if (midtransResponse.permata_va_number) {
        vaNumber = midtransResponse.permata_va_number;
      }
      if (midtransResponse.biller_code) {
        billerCode = midtransResponse.biller_code;
        billKey = midtransResponse.bill_key;
        vaNumber = `${billerCode} ${billKey}`;
      }
    } else {
      // Sandbox Simulation Mode jika Server Key belum di-set di environment
      const cleanOrderId = String(orderId).replace(/[^0-9]/g, "");
      const sampleVa = cleanOrderId.length >= 8 ? cleanOrderId.substring(0, 8) : "12345678";

      if (methodUpper.includes("QRIS")) {
        qrString = `00020101021226590014ID.LINKAJA.WWW011893600911002230467702150000000000000000303UMI51440014ID.CO.QRIS.WWW0215ID10260088912040303UMI5204581253033605802ID5916LIVETIX OFFICIAL6006MALANG61056514162190715${orderId}6304`;
      } else if (methodUpper.includes("GOPAY")) {
        deeplinkUrl = `gojek://gopay/partnerweb/pay?order_id=${orderId}&amount=${grossAmount}`;
      } else if (methodUpper.includes("SHOPEE")) {
        deeplinkUrl = `shopeeid://shopeepay/payment?order_id=${orderId}&amount=${grossAmount}`;
      } else if (methodUpper.includes("MANDIRI")) {
        billerCode = "89022";
        billKey = `0812${sampleVa}`;
        vaNumber = `${billerCode} ${billKey}`;
      } else if (methodUpper.includes("BNI")) {
        vaNumber = `8808 1234 ${sampleVa}`;
      } else if (methodUpper.includes("BRI")) {
        vaNumber = `7788 9012 ${sampleVa}`;
      } else {
        vaNumber = `8808 1234 ${sampleVa}`;
      }
    }

    const expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString(); // 1 Jam (60 Menit)

    // 4. Simpan order ke tabel orders di Supabase
    try {
      const uuidRegex =
        /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
      const validUserId = userId && uuidRegex.test(userId) ? userId : null;

      const { error: upsertErr } = await supabase.from("orders").upsert({
        id: orderId,
        user_id: validUserId,
        concert_id: validConcertId,
        tier_id: tierId || null,
        tier_name: tierName,
        quantity: qty,
        ticket_price: ticketPrice,
        service_fee: serviceFee,
        tax_admin_fee: taxAndAdmin,
        payment_fee: 0,
        total_amount: grossAmount,
        gross_amount: grossAmount,
        payment_method: methodUpper,
        payment_type: midtransPayload.payment_type,
        payment_status: "PENDING",
        midtrans_transaction_id: midtransResponse?.transaction_id || null,
        va_number: vaNumber || null,
        biller_code: billerCode || null,
        bill_key: billKey || null,
        qr_string: qrString || null,
        qr_url: qrUrl || null,
        deeplink_url: deeplinkUrl || null,
        expires_at: expiresAt,
        customer_name: customerName,
        customer_email: customerEmail,
        customer_phone: customerPhone,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });
      if (upsertErr) {
        console.error("Supabase upsert error:", JSON.stringify(upsertErr));
      } else {
        console.log("Supabase order upserted successfully:", orderId);
      }
    } catch (dbErr) {
      console.error("Error inserting order to Supabase:", dbErr);
    }

    return new Response(
      JSON.stringify({
        success: true,
        orderId,
        grossAmount,
        ticketPrice,
        serviceFee,
        taxAndAdmin,
        paymentMethod: methodUpper,
        paymentType: midtransPayload.payment_type,
        qrString,
        qrUrl,
        deeplinkUrl,
        vaNumber,
        billerCode,
        billKey,
        expiresAt,
        midtransResponse,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error: any) {
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});

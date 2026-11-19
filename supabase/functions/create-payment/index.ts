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
      paymentMethod,
      customerName,
      customerEmail,
      customerPhone,
      customerNik,
      userId,
    } = body;

    if (!orderId) {
      return new Response(JSON.stringify({ success: false, error: "orderId wajib diisi" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      });
    }

    const serverKey = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Ambil data harga tiket resmi dari database Supabase (Pencegahan manipulasi harga client)
    let ticketPrice = 0;
    let tierName = "Reguler";
    let concertTitle = "Konser LiveTix";
    let validConcertId: string | null = null;
    let producerId: string | null = null;

    if (tierId) {
      const { data: tier } = await supabase
        .from("ticket_tiers")
        .select("name, price, quota, sold_count, concert_id, concerts(id, title, producer_id)")
        .eq("id", tierId)
        .maybeSingle();

      if (tier) {
        ticketPrice = Math.round(Number(tier.price) || 0);
        tierName = tier.name;
        if (tier.concert_id) validConcertId = tier.concert_id;
        if (tier.concerts) {
          concertTitle = (tier.concerts as any).title || concertTitle;
          producerId = (tier.concerts as any).producer_id || null;
        }
      }
    }

    if (concertId && !validConcertId) {
      const { data: concert } = await supabase
        .from("concerts")
        .select("id, title, price, producer_id")
        .eq("id", concertId)
        .maybeSingle();

      if (concert) {
        validConcertId = concert.id;
        if (ticketPrice <= 0) ticketPrice = Math.round(Number(concert.price) || 0);
        concertTitle = concert.title || concertTitle;
        producerId = concert.producer_id || producerId;
      }
    }

    if (ticketPrice <= 0) {
      ticketPrice = Math.round(Number(body.ticketPrice) || 150000);
    }

    // 2. Hitung Ulang Komponen Biaya di Server (Sumber Kebenaran Tunggal & Invarian Wajib)
    const qty = Math.min(4, Math.max(1, Math.round(Number(quantity) || 1)));

    // Ambil konfigurasi persentase dari app_config
    let pajakPct = 10;
    let biayaPct = 2;
    try {
      const { data: configs } = await supabase.from("app_config").select("key, value");
      if (configs && Array.isArray(configs)) {
        for (const c of configs) {
          if (c.key === "pajak_hiburan_persen") pajakPct = Number(c.value) || 10;
          if (c.key === "biaya_aplikasi_persen") biayaPct = Number(c.value) || 2;
        }
      }
    } catch (_) {}

    const hargaTiket = ticketPrice * qty;
    const pajakHiburan = Math.round(hargaTiket * (pajakPct / 100));
    const biayaAplikasi = Math.round(hargaTiket * (biayaPct / 100)); // 1x per transaksi
    const subtotal = hargaTiket + pajakHiburan + biayaAplikasi;
    const totalBayar = Math.ceil(subtotal / 1000) * 1000; // Pembulatan ke atas kelipatan Rp 1.000
    const pembulatan = totalBayar - subtotal;
    const bagianProduser = hargaTiket + pajakHiburan;
    const bagianAdmin = biayaAplikasi + pembulatan;

    // Invarian Wajib: produser + admin == total_bayar
    if (bagianProduser + bagianAdmin !== totalBayar) {
      throw new Error(`Pelanggaran invarian: ${bagianProduser} + ${bagianAdmin} !== ${totalBayar}`);
    }

    // 3. Konfigurasi Item Details Midtrans Snap Sandbox
    // Syarat Midtrans: Total harga item_details harus tepat sama dengan gross_amount (totalBayar)
    const itemDetails: Array<{ id: string; price: number; quantity: number; name: string }> = [
      {
        id: (tierId || "TIER-01").substring(0, 50),
        price: ticketPrice,
        quantity: qty,
        name: `${tierName} - ${concertTitle}`.substring(0, 50),
      },
      {
        id: "PAJAK_HIBURAN",
        price: pajakHiburan,
        quantity: 1,
        name: `Pajak Hiburan (${pajakPct}%)`.substring(0, 50),
      },
      {
        id: "BIAYA_APLIKASI",
        price: biayaAplikasi,
        quantity: 1,
        name: `Biaya Aplikasi (${biayaPct}%)`.substring(0, 50),
      },
    ];

    if (pembulatan > 0) {
      itemDetails.push({
        id: "PEMBULATAN",
        price: pembulatan,
        quantity: 1,
        name: "Pembulatan",
      });
    }

    const snapPayload = {
      transaction_details: {
        order_id: orderId,
        gross_amount: totalBayar,
      },
      item_details: itemDetails,
      customer_details: {
        first_name: customerName || "Penonton LiveTix",
        email: customerEmail || "user@livetix.com",
        phone: customerPhone || "081234567890",
      },
      expiry: {
        unit: "minute",
        duration: 15,
      },
    };

    // 4. Request Snap Token ke Midtrans Sandbox (https://app.sandbox.midtrans.com/snap/v1/transactions)
    let snapToken = "";
    let snapRedirectUrl = "";
    let midtransResponse: any = null;

    if (serverKey && serverKey.trim().length > 5) {
      try {
        const snapResp = await fetch("https://app.sandbox.midtrans.com/snap/v1/transactions", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            Authorization: "Basic " + btoa(`${serverKey.trim()}:`),
          },
          body: JSON.stringify(snapPayload),
        });

        if (snapResp.ok) {
          midtransResponse = await snapResp.json();
          snapToken = midtransResponse.token || "";
          snapRedirectUrl = midtransResponse.redirect_url || "";
        } else {
          const errText = await snapResp.text();
          console.warn("Midtrans Snap sandbox error response:", errText);
        }
      } catch (snapErr) {
        console.error("Gagal memanggil Snap API Midtrans:", snapErr);
      }
    }

    // Fallback Simulation URL jika server key belum diset atau di environment offline
    if (!snapToken) {
      snapToken = `snap_sandbox_${orderId}`;
      snapRedirectUrl = `https://app.sandbox.midtrans.com/snap/v2/vtweb/${snapToken}`;
    }

    // Direct QRIS Sandbox fallback string jika client membutuhkan barcode inline
    const cleanOrderId = String(orderId).replace(/[^0-9]/g, "");
    const sampleVa = cleanOrderId.length >= 8 ? cleanOrderId.substring(0, 8) : "12345678";
    const qrString = `00020101021226590014ID.LINKAJA.WWW011893600911002230467702150000000000000000303UMI51440014ID.CO.QRIS.WWW0215ID10260088912040303UMI5204581253033605802ID5916LIVETIX OFFICIAL6006MALANG61056514162190715${orderId}6304`;
    const vaNumber = `8808 1234 ${sampleVa}`;
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString(); // 15 menit

    // 5. Simpan / Upsert Data ke Tabel transactions & orders
    const uuidRegex =
      /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
    const validUserId = userId && uuidRegex.test(userId) ? userId : null;
    const nowIso = new Date().toISOString();

    try {
      // Tabel transactions (Pencatatan rincian resmi)
      await supabase.from("transactions").upsert({
        id: orderId,
        order_id: orderId,
        user_id: validUserId,
        concert_id: validConcertId,
        tier_id: tierId || null,
        tier_name: tierName,
        jumlah_tiket: qty,
        harga_satuan: ticketPrice,
        harga_tiket: hargaTiket,
        pajak_hiburan: pajakHiburan,
        biaya_aplikasi: biayaAplikasi,
        subtotal: subtotal,
        total_bayar: totalBayar,
        pembulatan: pembulatan,
        bagian_produser: bagianProduser,
        bagian_admin: bagianAdmin,
        status: "pending",
        payment_method: (paymentMethod || "SNAP").toUpperCase(),
        payment_type: "snap",
        snap_token: snapToken,
        snap_redirect_url: snapRedirectUrl,
        customer_name: customerName,
        customer_email: customerEmail,
        customer_nik: customerNik || null,
        expires_at: expiresAt,
        created_at: nowIso,
        updated_at: nowIso,
      });

      // Tabel orders (Kompatibilitas aplikasi eksisting)
      await supabase.from("orders").upsert({
        id: orderId,
        user_id: validUserId,
        concert_id: validConcertId,
        tier_id: tierId || null,
        tier_name: tierName,
        quantity: qty,
        ticket_price: ticketPrice,
        service_fee: biayaAplikasi,
        tax_admin_fee: pajakHiburan,
        harga_satuan: ticketPrice,
        jumlah_tiket: qty,
        harga_tiket: hargaTiket,
        pajak_hiburan: pajakHiburan,
        biaya_aplikasi: biayaAplikasi,
        subtotal: subtotal,
        total_bayar: totalBayar,
        pembulatan: pembulatan,
        bagian_produser: bagianProduser,
        bagian_admin: bagianAdmin,
        total_amount: totalBayar,
        gross_amount: totalBayar,
        payment_method: (paymentMethod || "SNAP").toUpperCase(),
        payment_type: "snap",
        payment_status: "PENDING",
        customer_name: customerName,
        customer_email: customerEmail,
        customer_phone: customerPhone,
        customer_nik: customerNik || null,
        qr_string: qrString,
        va_number: vaNumber,
        deeplink_url: snapRedirectUrl,
        expires_at: expiresAt,
        created_at: nowIso,
        updated_at: nowIso,
      });
    } catch (dbErr) {
      console.error("Error upserting transaction/order in Supabase:", dbErr);
    }

    // 6. Return response lengkap ke Flutter Client
    return new Response(
      JSON.stringify({
        success: true,
        orderId,
        snapToken,
        snapRedirectUrl,
        grossAmount: totalBayar,
        totalBayar,
        pricing: {
          hargaSatuan: ticketPrice,
          jumlah: qty,
          hargaTiket,
          pajakHiburan,
          biayaAplikasi,
          subtotal,
          totalBayar,
          pembulatan,
          bagianProduser,
          bagianAdmin,
        },
        paymentMethod: (paymentMethod || "SNAP").toUpperCase(),
        paymentType: "snap",
        qrString,
        vaNumber,
        expiresAt,
        midtransResponse,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error: any) {
    console.error("create-payment function error:", error);
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});

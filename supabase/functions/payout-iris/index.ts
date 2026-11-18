import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  let referenceId = "";
  let payoutType = "";

  try {
    const body = await req.json();
    const {
      amount,
      beneficiaryBank,
      beneficiaryAccount,
      beneficiaryName,
      notes,
      simulateFailure, // flag untuk tes alur gagal -> kredit balik
    } = body;

    payoutType = body.payoutType ?? "";
    referenceId = body.referenceId ?? "";

    const irisKey = Deno.env.get("MIDTRANS_IRIS_KEY") ?? "";
    const isProd = Deno.env.get("MIDTRANS_IS_PRODUCTION") === "true";

    const irisBaseUrl = isProd
      ? "https://app.midtrans.com/iris/api/v1"
      : "https://app.sandbox.midtrans.com/iris/api/v1";

    let isSuccess = false;
    let irisPayoutId = `iris_${Date.now()}`;
    let failureReason = "";

    if (simulateFailure === true) {
      isSuccess = false;
      failureReason = "SIMULATED_FAILURE: Rekening tujuan tidak valid di sandbox";
    } else if (irisKey && irisKey.trim().length > 5) {
      // Panggil API Midtrans Iris Payout Sandbox / Production
      try {
        const resp = await fetch(`${irisBaseUrl}/payouts`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            Authorization: "Basic " + btoa(`${irisKey}:`),
          },
          body: JSON.stringify({
            payouts: [
              {
                beneficiary_name: beneficiaryName,
                beneficiary_account: beneficiaryAccount,
                beneficiary_bank: (beneficiaryBank || "bca").toLowerCase(),
                beneficiary_email: "finance@livetix.com",
                amount: String(amount),
                notes: notes || `LiveTix Payout ${referenceId}`,
              },
            ],
          }),
        });

        const data = await resp.json();
        if (resp.ok && (data.status === "queued" || data.status === "completed" || data.status === "processed")) {
          isSuccess = true;
          irisPayoutId = data.payouts?.[0]?.reference_no || irisPayoutId;
        } else {
          isSuccess = false;
          failureReason = data.error_message || data.message || "Penolakan dari bank tujuan (Iris Midtrans)";
        }
      } catch (irisErr: any) {
        isSuccess = false;
        failureReason = irisErr?.message || "Koneksi Iris Midtrans gagal";
      }
    } else {
      // Sandbox Simulation Payout (Ketika Iris Key belum diset)
      isSuccess = true;
      irisPayoutId = `iris_sandbox_${Date.now()}`;
    }

    // ── Alur Database Sesuai Hasil Payout ────────────────────────────────────
    if (payoutType === "REFUND_USER") {
      if (isSuccess) {
        try {
          await supabase.rpc("complete_refund_payout", {
            p_refund_id: referenceId,
            p_iris_id: irisPayoutId,
          });
        } catch (_) {
          await supabase
            .from("refunds")
            .update({
              status: "completed",
              iris_payout_id: irisPayoutId,
              updated_at: new Date().toISOString(),
            })
            .eq("id", referenceId);
        }
      } else {
        try {
          await supabase.rpc("fail_refund_payout", {
            p_refund_id: referenceId,
            p_reason: failureReason,
          });
        } catch (_) {
          await supabase
            .from("refunds")
            .update({
              status: "failed",
              failure_reason: failureReason,
              updated_at: new Date().toISOString(),
            })
            .eq("id", referenceId);
        }
      }
    } else if (payoutType === "WITHDRAWAL_ADMIN") {
      if (isSuccess) {
        await supabase.rpc("complete_admin_withdrawal", {
          p_withdrawal_id: referenceId,
          p_iris_id: irisPayoutId,
        });
      } else {
        await supabase.rpc("fail_admin_withdrawal", {
          p_withdrawal_id: referenceId,
          p_reason: failureReason,
        });
      }
    } else {
      // Payout Penarikan Produser ('WITHDRAWAL_PRODUCER')
      if (isSuccess) {
        await supabase.rpc("complete_producer_withdrawal", {
          p_withdrawal_id: referenceId,
          p_iris_id: irisPayoutId,
        });
      } else {
        // Panggil fail_producer_withdrawal (otomatis KREDIT BALIK ke ledger)
        await supabase.rpc("fail_producer_withdrawal", {
          p_withdrawal_id: referenceId,
          p_reason: failureReason,
        });
      }
    }

    return new Response(
      JSON.stringify({
        success: isSuccess,
        referenceId,
        irisPayoutId: isSuccess ? irisPayoutId : null,
        message: isSuccess
          ? "Pencairan dana berhasil diproses ke rekening tujuan."
          : `Pencairan dana gagal (${failureReason}). Dana telah dikreditkan kembali ke saldo.`,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error: any) {
    if (referenceId) {
      // Fallback kredit balik jika terjadi crash server
      try {
        if (payoutType === "WITHDRAWAL_ADMIN") {
          await supabase.rpc("fail_admin_withdrawal", {
            p_withdrawal_id: referenceId,
            p_reason: error.message,
          });
        } else if (payoutType === "REFUND_USER") {
          await supabase.rpc("fail_refund_payout", {
            p_refund_id: referenceId,
            p_reason: error.message,
          });
        } else {
          await supabase.rpc("fail_producer_withdrawal", {
            p_withdrawal_id: referenceId,
            p_reason: error.message,
          });
        }
      } catch (_) {}
    }

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        message: "Terjadi error sistem. Dana dikembalikan ke saldo jika sudah terpotong.",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});

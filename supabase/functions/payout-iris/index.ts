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
      payoutType, // 'WITHDRAWAL_PRODUCER', 'WITHDRAWAL_ADMIN', 'REFUND_USER'
      referenceId,
      amount,
      beneficiaryBank,
      beneficiaryAccount,
      beneficiaryName,
      notes,
    } = body;

    const irisKey = Deno.env.get("MIDTRANS_IRIS_KEY") ?? "";
    const isProd = Deno.env.get("MIDTRANS_IS_PRODUCTION") === "true";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const irisBaseUrl = isProd
      ? "https://app.midtrans.com/iris/api/v1"
      : "https://app.sandbox.midtrans.com/iris/api/v1";

    let payoutResult: any = null;

    if (irisKey && irisKey.trim().length > 5) {
      // Panggil API Midtrans Iris Payout
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
              beneficiary_bank: beneficiaryBank.toLowerCase(),
              beneficiary_email: "finance@livetix.com",
              amount: String(amount),
              notes: notes || `LiveTix Payout ${referenceId}`,
            },
          ],
        }),
      });
      payoutResult = await resp.json();
    } else {
      // Sandbox Simulation Payout
      payoutResult = {
        status: "queued",
        payouts: [
          {
            reference_no: referenceId,
            status: "completed",
            amount: amount,
            beneficiary_name: beneficiaryName,
          },
        ],
      };
    }

    // Update status di tabel withdrawals atau refunds
    if (payoutType === "REFUND_USER") {
      await supabase
        .from("refunds")
        .update({
          status: "BERHASIL",
          iris_payout_id: payoutResult?.payouts?.[0]?.reference_no || `iris_${Date.now()}`,
          updated_at: new Date().toISOString(),
        })
        .eq("id", referenceId);
    } else {
      await supabase
        .from("withdrawals")
        .update({
          status: "SUCCESS",
          iris_payout_id: payoutResult?.payouts?.[0]?.reference_no || `iris_${Date.now()}`,
          completed_at: new Date().toISOString(),
        })
        .or(`id.eq.${referenceId},reference_no.eq.${referenceId}`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Payout disbursement processed successfully",
        payoutResult,
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


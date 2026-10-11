// Creates a Ziina hosted-checkout payment intent for a vote bundle.
//
// Required secrets (set with `supabase secrets set`):
//   ZIINA_ACCESS_TOKEN  - Bearer token from https://ziina.com/business/connect
//
// Deploy with: supabase functions deploy ziina-create-payment
import { createClient } from "npm:@supabase/supabase-js@2";

const ZIINA_API_URL = "https://api-v2.ziina.com/api/payment_intent";
// Custom URL scheme already registered for this app (see AndroidManifest.xml
// and ios/Runner/Info.plist), reused here for the Ziina redirect callback.
const APP_SCHEME = "io.supabase.almamoura";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const ziinaToken = Deno.env.get("ZIINA_ACCESS_TOKEN");

    if (!ziinaToken) {
      throw new Error("ZIINA_ACCESS_TOKEN secret is not configured.");
    }

    // Identify the calling user from their forwarded session JWT.
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return jsonResponse({ error: "Not authenticated." }, 401);
    }
    const user = userData.user;
    if (user.is_anonymous) {
      return jsonResponse({ error: "Guests cannot purchase votes." }, 403);
    }

    const { bundleId } = await req.json().catch(() => ({}));
    if (!bundleId || typeof bundleId !== "string") {
      return jsonResponse({ error: "bundleId is required." }, 400);
    }

    // Service role client: looks up the authoritative bundle price and
    // writes the payment record. Never trust a client-supplied amount.
    const admin = createClient(supabaseUrl, serviceRoleKey);

    const { data: bundle, error: bundleError } = await admin
      .from("vote_bundles")
      .select("id, votes, price, currency")
      .eq("id", bundleId)
      .single();
    if (bundleError || !bundle) {
      return jsonResponse({ error: "Unknown vote bundle." }, 404);
    }

    const operationId = crypto.randomUUID();
    const amountMinorUnits = Math.round(Number(bundle.price) * 100);
    if (
      bundle.currency !== "AED" ||
      !Number.isFinite(amountMinorUnits) ||
      amountMinorUnits < 200
    ) {
      return jsonResponse({ error: "This vote bundle is not configured for payment." }, 409);
    }

    const { data: payment, error: insertError } = await admin
      .from("payments")
      .insert({
        user_id: user.id,
        bundle_id: bundle.id,
        operation_id: operationId,
        amount: bundle.price,
        currency: bundle.currency,
        status: "pending",
      })
      .select("id")
      .single();
    if (insertError || !payment) {
      throw insertError ?? new Error("Failed to create payment record.");
    }

    const callbackUrl = (status: string) =>
      `${APP_SCHEME}://payment-callback/?status=${status}&payment_id=${payment.id}`;
    const markPaymentFailed = async () => {
      const { error } = await admin
        .from("payments")
        .update({ status: "failed" })
        .eq("id", payment.id);
      if (error) throw error;
    };

    const ziinaResponse = await fetch(ZIINA_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${ziinaToken}`,
      },
      body: JSON.stringify({
        amount: amountMinorUnits,
        currency_code: bundle.currency,
        message: `${bundle.votes} vote${bundle.votes === 1 ? "" : "s"} - Almamoura Film Festival`,
        success_url: callbackUrl("success"),
        cancel_url: callbackUrl("cancel"),
        failure_url: callbackUrl("failure"),
        operation_id: operationId,
        ...(Deno.env.get("ZIINA_TEST_MODE") === "true" ? { test: true } : {}),
      }),
    });

    let ziinaData: {
      id?: unknown;
      redirect_url?: unknown;
      message?: unknown;
    };
    try {
      ziinaData = await ziinaResponse.json();
    } catch {
      await markPaymentFailed();
      return jsonResponse({ error: "Ziina returned an invalid response." }, 502);
    }

    if (!ziinaResponse.ok) {
      await markPaymentFailed();
      const message = typeof ziinaData.message === "string"
        ? ziinaData.message
        : "Ziina rejected the payment request.";
      return jsonResponse({ error: message }, 502);
    }

    let redirectUrl: URL;
    try {
      if (typeof ziinaData.id !== "string" || typeof ziinaData.redirect_url !== "string") {
        throw new Error("Missing payment intent fields.");
      }
      redirectUrl = new URL(ziinaData.redirect_url);
    } catch {
      await markPaymentFailed();
      return jsonResponse({ error: "Ziina returned an invalid payment link." }, 502);
    }
    if (redirectUrl.protocol !== "https:") {
      await markPaymentFailed();
      return jsonResponse({ error: "Ziina returned an invalid payment link." }, 502);
    }

    const { error: intentUpdateError } = await admin
      .from("payments")
      .update({ ziina_payment_intent_id: ziinaData.id })
      .eq("id", payment.id);
    if (intentUpdateError) throw intentUpdateError;

    return jsonResponse({
      paymentId: payment.id,
      redirectUrl: redirectUrl.toString(),
    });
  } catch (error) {
    console.error("ziina-create-payment error", error);
    return jsonResponse({ error: "Unable to start payment. Please try again." }, 500);
  }
});

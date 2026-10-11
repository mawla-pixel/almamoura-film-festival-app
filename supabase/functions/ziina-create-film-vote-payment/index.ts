import { createClient } from "npm:@supabase/supabase-js@2";

const ZIINA_API_URL = "https://api-v2.ziina.com/api/payment_intent";
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
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed." }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const ziinaToken = Deno.env.get("ZIINA_ACCESS_TOKEN");
    if (!ziinaToken) throw new Error("ZIINA_ACCESS_TOKEN is not configured.");

    const authorization = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return jsonResponse({ error: "Not authenticated." }, 401);
    }
    if (userData.user.is_anonymous) {
      return jsonResponse({ error: "Sign in to purchase votes." }, 403);
    }

    let body: { filmId?: unknown; bundleId?: unknown };
    try {
      body = await req.json();
    } catch {
      return jsonResponse({ error: "Invalid request body." }, 400);
    }
    if (typeof body.filmId !== "string" || typeof body.bundleId !== "string") {
      return jsonResponse({ error: "filmId and bundleId are required." }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const [{ data: film, error: filmError }, { data: bundle, error: bundleError }] =
      await Promise.all([
        admin.from("festival_submissions").select("id, project_title")
          .eq("id", body.filmId).maybeSingle(),
        admin.from("vote_bundles").select("id, votes, price, currency, label")
          .eq("id", body.bundleId).maybeSingle(),
      ]);

    if (filmError) throw filmError;
    if (!film) return jsonResponse({ error: "Film was not found." }, 404);
    if (bundleError) throw bundleError;
    if (!bundle || bundle.currency !== "AED") {
      return jsonResponse({ error: "Vote bundle is not available." }, 404);
    }

    const amountMinorUnits = Math.round(Number(bundle.price) * 100);
    if (!Number.isSafeInteger(amountMinorUnits) || amountMinorUnits < 200) {
      return jsonResponse({ error: "Vote bundle price is invalid." }, 409);
    }
    const operationId = crypto.randomUUID();
    const { data: payment, error: insertError } = await admin
      .from("film_vote_payments")
      .insert({
        user_id: userData.user.id,
        film_id: film.id,
        bundle_id: bundle.id,
        operation_id: operationId,
        votes: bundle.votes,
        amount: bundle.price,
        currency: bundle.currency,
        status: "pending",
      })
      .select("id")
      .single();
    if (insertError || !payment) throw insertError ?? new Error("Payment record creation failed.");

    const markPaymentFailed = async () => {
      const { error } = await admin.from("film_vote_payments")
        .update({ status: "failed" }).eq("id", payment.id);
      if (error) throw error;
    };
    const testMode = Deno.env.get("ZIINA_TEST_MODE") !== "false";
    const callbackUrl = (status: string) =>
      `${APP_SCHEME}://payment-callback/?status=${status}&payment_id=${payment.id}`;

    let ziinaResponse: Response;
    try {
      ziinaResponse = await fetch(ZIINA_API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${ziinaToken}`,
        },
        body: JSON.stringify({
          amount: amountMinorUnits,
          currency_code: bundle.currency,
          message: `${bundle.label} for ${film.project_title} - Almamoura Film Festival`,
          success_url: callbackUrl("success"),
          cancel_url: callbackUrl("cancel"),
          failure_url: callbackUrl("failure"),
          operation_id: operationId,
          ...(testMode ? { test: true } : {}),
        }),
      });
    } catch (error) {
      try {
        await markPaymentFailed();
      } catch (updateError) {
        console.error("Could not mark payment failed", updateError);
      }
      throw error;
    }

    let ziinaData: { id?: unknown; redirect_url?: unknown; message?: unknown };
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
        throw new Error("Missing payment intent details.");
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

    const { error: intentUpdateError } = await admin.from("film_vote_payments")
      .update({ ziina_payment_intent_id: ziinaData.id }).eq("id", payment.id);
    if (intentUpdateError) throw intentUpdateError;

    return jsonResponse({ paymentId: payment.id, redirectUrl: redirectUrl.toString() });
  } catch (error) {
    console.error("ziina-create-film-vote-payment error", error);
    return jsonResponse({ error: "Unable to start payment. Please try again." }, 500);
  }
});

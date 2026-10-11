// Receives Ziina's `payment_intent.status.updated` webhook, verifies its
// authenticity, and updates the matching row in `public.payments`.
//
// Setup (one-time, after deploying this function):
//   1. supabase secrets set ZIINA_WEBHOOK_SECRET=<a-random-string-you-choose>
//   2. Register the webhook with Ziina:
//        curl -X POST https://api-v2.ziina.com/api/webhook \
//          -H "Authorization: Bearer $ZIINA_ACCESS_TOKEN" \
//          -H "Content-Type: application/json" \
//          -d '{"url":"https://<project-ref>.supabase.co/functions/v1/ziina-webhook","secret":"<same-random-string>"}'
//
// Deploy with: supabase functions deploy ziina-webhook --no-verify-jwt
import { createClient } from "npm:@supabase/supabase-js@2";

// Ziina only ever calls webhooks from these IP addresses.
const ZIINA_IPS = new Set([
  "3.29.184.186",
  "3.29.190.95",
  "20.233.47.127",
  "13.202.161.181",
]);

const TERMINAL_STATUSES = new Set(["completed", "failed", "canceled"]);

async function isValidSignature(secret: string, rawBody: string, signature: string) {
  if (!signature) return false;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, encoder.encode(rawBody));
  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  if (expected.length !== signature.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Defense in depth: reject requests not coming from Ziina's documented IPs.
  const forwardedFor = req.headers.get("x-forwarded-for") ?? "";
  const callerIp = forwardedFor.split(",")[0]?.trim();
  if (callerIp && !ZIINA_IPS.has(callerIp)) {
    console.warn("Rejected ziina webhook from unexpected IP", callerIp);
    return new Response("Forbidden", { status: 403 });
  }

  const rawBody = await req.text();

  const webhookSecret = Deno.env.get("ZIINA_WEBHOOK_SECRET");
  if (!webhookSecret) {
    console.error("ZIINA_WEBHOOK_SECRET is not configured.");
    return new Response("Webhook is not configured", { status: 500 });
  }
  const signature = req.headers.get("x-hmac-signature") ?? "";
  if (!(await isValidSignature(webhookSecret, rawBody, signature))) {
    return new Response("Invalid signature", { status: 401 });
  }

  let payload: {
    event?: string;
    data?: {
      id?: string;
      operation_id?: string;
      status?: string;
      amount?: number;
      currency_code?: string;
    };
  };
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  if (payload.event !== "payment_intent.status.updated") {
    // Acknowledge unrelated/future event types without retry churn.
    return new Response("ok", { status: 200 });
  }
  const data = payload.data;
  if (
    !data?.id ||
    !data.operation_id ||
    typeof data.amount !== "number" ||
    !data.currency_code ||
    !data.status
  ) {
    return new Response("Invalid payment event", { status: 400 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const incomingStatus = data.status;
  const mappedStatus = TERMINAL_STATUSES.has(incomingStatus) ? incomingStatus : "pending";

  const { data: paymentByIntent, error: intentLookupError } = await admin
    .from("payments")
    .select("id, bundle_id, operation_id, ziina_payment_intent_id, amount, currency, status, votes_granted")
    .eq("ziina_payment_intent_id", data.id)
    .maybeSingle();
  if (intentLookupError) {
    console.error("Unable to look up payment intent", intentLookupError);
    return new Response("Payment lookup failed", { status: 500 });
  }

  // The operation ID fallback handles a webhook arriving before the create
  // function has persisted Ziina's payment-intent ID.
  let payment = paymentByIntent;
  if (!payment) {
    const { data: paymentByOperation, error: operationLookupError } = await admin
      .from("payments")
      .select("id, bundle_id, operation_id, ziina_payment_intent_id, amount, currency, status, votes_granted")
      .eq("operation_id", data.operation_id)
      .maybeSingle();
    if (operationLookupError) {
      console.error("Unable to look up payment operation", operationLookupError);
      return new Response("Payment lookup failed", { status: 500 });
    }
    payment = paymentByOperation;
  }

  if (!payment) {
    // Unknown intent; duplicate and delayed webhooks are expected.
    return new Response("ok", { status: 200 });
  }

  if (
    payment.operation_id !== data.operation_id ||
    payment.currency !== data.currency_code ||
    Math.round(Number(payment.amount) * 100) !== data.amount
  ) {
    console.error("Ziina webhook did not match the stored payment", data.id);
    return new Response("Payment details do not match", { status: 400 });
  }

  if (
    payment.status === "completed" ||
    (["failed", "canceled"].includes(payment.status) && mappedStatus !== "completed")
  ) {
    return new Response("ok", { status: 200 });
  }

  let votesGranted = payment.votes_granted;
  if (mappedStatus === "completed" && votesGranted == null) {
    const { data: bundle, error: bundleError } = await admin
      .from("vote_bundles")
      .select("votes")
      .eq("id", payment.bundle_id)
      .single();
    if (bundleError || !bundle) {
      console.error("Unable to load purchased vote bundle", bundleError);
      return new Response("Vote bundle lookup failed", { status: 500 });
    }
    votesGranted = bundle.votes;
  }

  const { error: updateError } = await admin
    .from("payments")
    .update({
      ziina_payment_intent_id: data.id,
      status: mappedStatus,
      votes_granted: votesGranted,
    })
    .eq("id", payment.id);
  if (updateError) {
    console.error("Unable to update payment from webhook", updateError);
    return new Response("Payment update failed", { status: 500 });
  }

  return new Response("ok", { status: 200 });
});

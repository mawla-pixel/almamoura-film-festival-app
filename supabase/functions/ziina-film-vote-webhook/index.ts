import { createClient } from "npm:@supabase/supabase-js@2";

const ZIINA_IPS = new Set([
  "3.29.184.186",
  "3.29.190.95",
  "20.233.47.127",
  "13.202.161.181",
]);

async function validSignature(secret: string, rawBody: string, signature: string) {
  if (!signature) return false;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const result = await crypto.subtle.sign("HMAC", key, encoder.encode(rawBody));
  const expected = Array.from(new Uint8Array(result), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
  if (expected.length !== signature.length) return false;
  let difference = 0;
  for (let i = 0; i < expected.length; i++) {
    difference |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return difference === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const forwardedFor = req.headers.get("x-forwarded-for") ?? "";
  const callerIp = forwardedFor.split(",")[0]?.trim();
  if (callerIp && !ZIINA_IPS.has(callerIp)) {
    return new Response("Forbidden", { status: 403 });
  }

  const secret = Deno.env.get("ZIINA_WEBHOOK_SECRET");
  if (!secret) {
    console.error("ZIINA_WEBHOOK_SECRET is not configured.");
    return new Response("Webhook is not configured", { status: 500 });
  }
  const rawBody = await req.text();
  if (!await validSignature(secret, rawBody, req.headers.get("x-hmac-signature") ?? "")) {
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
  if (payload.event !== "payment_intent.status.updated") return new Response("ok");

  const data = payload.data;
  if (
    !data?.id || !data.operation_id || !data.status ||
    typeof data.amount !== "number" || !data.currency_code
  ) {
    return new Response("Invalid payment event", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: byIntent, error: intentError } = await supabase
    .from("film_vote_payments")
    .select("id, operation_id, amount, currency, status")
    .eq("ziina_payment_intent_id", data.id)
    .maybeSingle();
  if (intentError) {
    console.error("Payment intent lookup failed", intentError);
    return new Response("Database lookup failed", { status: 500 });
  }
  let payment = byIntent;
  if (!payment) {
    const { data: byOperation, error: operationError } = await supabase
      .from("film_vote_payments")
      .select("id, operation_id, amount, currency, status")
      .eq("operation_id", data.operation_id)
      .maybeSingle();
    if (operationError) {
      console.error("Payment operation lookup failed", operationError);
      return new Response("Database lookup failed", { status: 500 });
    }
    payment = byOperation;
  }
  if (!payment) return new Response("ok");

  if (
    payment.operation_id !== data.operation_id ||
    payment.currency !== data.currency_code ||
    Math.round(Number(payment.amount) * 100) !== data.amount
  ) {
    console.error("Webhook payment data mismatch", data.id);
    return new Response("Payment details do not match", { status: 400 });
  }

  const status = ["completed", "failed", "canceled"].includes(data.status)
    ? data.status
    : "pending";
  if (
    payment.status === "completed" ||
    (["failed", "canceled"].includes(payment.status) && status !== "completed")
  ) {
    return new Response("ok");
  }
  const { error: updateError } = await supabase
    .from("film_vote_payments")
    .update({ ziina_payment_intent_id: data.id, status })
    .eq("id", payment.id);
  if (updateError) {
    console.error("Payment status update failed", updateError);
    return new Response("Database update failed", { status: 500 });
  }
  return new Response("ok");
});

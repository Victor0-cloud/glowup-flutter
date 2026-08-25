// Supabase Edge Function: analyze-scan
//
// The single, authenticated proxy between the Glow Up Flutter client and
// a vision-capable model provider, for both Food Scan and Facial Scan.
// Deploy with:
//
//   supabase functions deploy analyze-scan
//
// Required secrets (never present in the Flutter client — see
// README.md in this folder for the full activation checklist):
//
//   supabase secrets set VISION_API_KEY=sk-...
//   supabase secrets set VISION_API_URL=https://api.openai.com/v1/chat/completions   (optional override)
//   supabase secrets set VISION_MODEL=gpt-4o-mini                                    (optional override)
//
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are already available to
// every Edge Function automatically — they are not set manually.

import { createClient } from "jsr:@supabase/supabase-js@2";

const MAX_IMAGE_BYTES = 8 * 1024 * 1024; // 8 MB — mirrors the Flutter client's own pre-check.
const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);
const ALLOWED_KINDS = new Set(["food", "facial", "product"]);
const ALLOWED_PRODUCT_CATEGORIES = new Set([
  "food",
  "supplement",
  "equipment",
  "activewear",
  "skincare",
]);
const RATE_LIMIT_WINDOW_SECONDS = 60;
const RATE_LIMIT_MAX_REQUESTS = 5;

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

// Server-side safety net: even though the prompt instructs the model to
// stay observational/non-diagnostic, model output is never trusted
// blindly. Any observation matching a diagnostic-sounding pattern is
// replaced with a safe, generic fallback rather than failing the whole
// request outright.
const DIAGNOSTIC_PATTERNS = [
  /you have\s/i,
  /diagnos/i,
  /infection/i,
  /\bdisease\b/i,
  /medical condition/i,
  /(is|are)\s+cancerous/i,
  /melanoma/i,
  // Attractiveness/beauty scoring — never permitted in this app, even
  // hedged. Any such phrasing is caught and replaced below, same as a
  // diagnostic claim.
  /beaut(y|iful)/i,
  /attractive/i,
  /score of \d/i,
  /\brate(d)?\b.*\b(looks|appearance)\b/i,
];

function sanitizeObservation(text: string): string {
  for (const pattern of DIAGNOSTIC_PATTERNS) {
    if (pattern.test(text)) {
      return "This area may be worth a closer look — consider a wellness routine change, or consult a dermatology professional if it persists.";
    }
  }
  return text;
}

// Product-text safety net (skincare/supplement text fields only) — a
// label-photo extraction must never promise a cure/treatment outcome or
// imply "natural"/"organic" automatically means safe, even if the actual
// product packaging carries that marketing language. Any product text
// field matching one of these gets replaced with a neutral, factual
// fallback rather than being passed through verbatim.
const PRODUCT_CLAIM_PATTERNS = [
  /cures?\b/i,
  /treats?\s/i,
  /heals?\b/i,
  /guarantee/i,
  /100%\s*safe/i,
  /clinically proven/i,
  /(natural|organic).{0,20}safe/i,
];

function sanitizeProductText(text: string): string {
  for (const pattern of PRODUCT_CLAIM_PATTERNS) {
    if (pattern.test(text)) {
      return "See product packaging for full ingredient and safety details.";
    }
  }
  return text;
}

interface ScanRequestBody {
  kind: "food" | "facial" | "product";
  mimeType: string;
  imageBase64: string;
  /** Only meaningful when kind === "product" — a hint, not a hard filter. */
  category?: string;
}

function validateRequestBody(body: unknown): ScanRequestBody {
  if (typeof body !== "object" || body === null) {
    throw new Error("request body must be a JSON object");
  }
  const b = body as Record<string, unknown>;
  if (typeof b.kind !== "string" || !ALLOWED_KINDS.has(b.kind)) {
    throw new Error("kind must be 'food', 'facial', or 'product'");
  }
  if (typeof b.mimeType !== "string" || !ALLOWED_MIME_TYPES.has(b.mimeType)) {
    throw new Error("mimeType must be one of image/jpeg, image/png, image/webp");
  }
  if (typeof b.imageBase64 !== "string" || b.imageBase64.length === 0) {
    throw new Error("imageBase64 is required");
  }
  // Rough size check on the base64 payload itself (base64 is ~4/3 the
  // decoded size) — an exact decoded-byte check happens below.
  if (b.imageBase64.length > MAX_IMAGE_BYTES * 1.4) {
    throw new Error("image too large");
  }
  let category: string | undefined;
  if (b.kind === "product" && typeof b.category === "string" && ALLOWED_PRODUCT_CATEGORIES.has(b.category)) {
    category = b.category;
  }
  return {
    kind: b.kind as "food" | "facial" | "product",
    mimeType: b.mimeType,
    imageBase64: b.imageBase64,
    category,
  };
}

function decodedByteLength(base64: string): number {
  const padding = base64.endsWith("==") ? 2 : base64.endsWith("=") ? 1 : 0;
  return Math.floor((base64.length * 3) / 4) - padding;
}

const FOOD_SYSTEM_PROMPT =
  `You are a nutrition-estimation assistant. Given a photo of a meal, identify the ` +
  `likely distinct food items. For each item, estimate a plausible portion, calories, ` +
  `protein (g), carbohydrates (g), and fat (g). These are ALWAYS estimates, never exact ` +
  `values. Respond with ONLY valid JSON, no prose, matching exactly this shape: ` +
  `{"items":[{"name":string,"portion":string,"calories":number,"proteinGrams":number,` +
  `"carbsGrams":number,"fatGrams":number,"confidence":number between 0 and 1}],` +
  `"qualityNote":string describing the photo's clarity/lighting briefly}. ` +
  `If you cannot identify any food, return {"items":[],"qualityNote":"..."}.`;

const FACIAL_SYSTEM_PROMPT =
  `You are a healthy-skin support assistant for a women's wellness app — NOT a medical or ` +
  `dermatological diagnostic tool, and NEVER an attractiveness/beauty scorer. Given a facial ` +
  `photo, describe only general, visible, non-diagnostic wellness observations — possible ` +
  `visible concerns such as breakouts, redness, oiliness/dryness, dark marks after acne, or ` +
  `uneven-looking texture — using hedged language such as "may appear" or "possible visible ` +
  `concern," never an assertion. NEVER diagnose acne, infection, disease, or any medical ` +
  `condition. NEVER output a numeric attractiveness/beauty/skin score of any kind. NEVER ` +
  `identify who the person is or comment on ethnicity/race — your observations must work ` +
  `fairly and consistently across all skin tones, describing what is visible without bias ` +
  `toward any tone. NEVER shame or use judgmental language. Respond with ONLY valid JSON, no ` +
  `prose, matching exactly this shape: {"observations":[{"area":string short code,` +
  `"observation":string hedged non-diagnostic sentence,"confidence":number between 0 and 1}],` +
  `"qualityNote":string briefly describing lighting/blur/framing quality}. If the image ` +
  `quality is too poor to say anything useful, return {"observations":[],"qualityNote":"..."} ` +
  `explaining why.`;

const PRODUCT_SYSTEM_PROMPT =
  `You are a product-label reading assistant for a women's fitness/wellness shopping app. Given ` +
  `a photo of a product, its nutrition/ingredient label, or its packaging, extract ONLY what is ` +
  `clearly legible in the photo — if a value is not clearly visible or you are unsure, use null ` +
  `rather than guessing or estimating. NEVER invent a brand, ingredient, or number that is not ` +
  `visible in the image. NEVER claim a product cures, treats, or heals anything, and NEVER state ` +
  `or imply that "natural" or "organic" automatically means safe. For skincare items, describe ` +
  `possible irritants factually (e.g. "contains fragrance") without diagnosing skin conditions or ` +
  `promising a treatment outcome. Respond with ONLY valid JSON, no prose, matching exactly this ` +
  `shape (every field nullable, use null for anything not clearly legible or not applicable to ` +
  `this product): {"name":string|null,"brand":string|null,"category":one of "food","supplement",` +
  `"equipment","activewear","skincare"|null,"servingSize":string|null,"caloriesPerServing":number|null,` +
  `"proteinGrams":number|null,"carbsGrams":number|null,"fatGrams":number|null,"fiberGrams":number|null,` +
  `"sugarGrams":number|null,"sodiumMg":number|null,"ingredients":string|null,"allergens":string|null,` +
  `"intendedUse":string|null,"exercisesSupported":string[]|null,"muscleGroups":string[]|null,` +
  `"beginnerSuitable":boolean|null,"safetyNotes":string|null,"size":string|null,"material":string|null,` +
  `"activityType":string|null,"careInstructions":string|null,"skinTypeInfo":string|null,` +
  `"possibleIrritants":string|null,"confidence":number between 0 and 1,` +
  `"qualityNote":string describing the photo's clarity/legibility briefly}.`;

async function callVisionProvider(
  kind: "food" | "facial" | "product",
  imageBase64: string,
  mimeType: string,
  category?: string,
): Promise<Record<string, unknown>> {
  const apiKey = Deno.env.get("VISION_API_KEY");
  if (!apiKey) {
    throw new Error("VISION_API_KEY is not configured on this Edge Function");
  }
  const apiUrl =
    Deno.env.get("VISION_API_URL") ?? "https://api.openai.com/v1/chat/completions";
  const model = Deno.env.get("VISION_MODEL") ?? "gpt-4o-mini";
  const systemPrompt = kind === "food"
    ? FOOD_SYSTEM_PROMPT
    : kind === "facial"
    ? FACIAL_SYSTEM_PROMPT
    : PRODUCT_SYSTEM_PROMPT + (category ? ` The user indicated this is likely a "${category}" product — use that as a hint only, not a hard constraint.` : "");

  const response = await fetch(apiUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        {
          role: "user",
          content: [
            { type: "text", text: "Analyze this image." },
            { type: "image_url", image_url: { url: `data:${mimeType};base64,${imageBase64}` } },
          ],
        },
      ],
      max_tokens: 800,
    }),
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(`vision provider returned ${response.status}: ${detail.slice(0, 200)}`);
  }

  const completion = await response.json();
  const content = completion?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    throw new Error("vision provider returned an unexpected response shape");
  }
  const parsed = JSON.parse(content);
  return parsed as Record<string, unknown>;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }

  // Authenticate the caller. `SUPABASE_URL`/`SUPABASE_ANON_KEY` are
  // injected automatically for every Edge Function; passing the caller's
  // own Authorization header makes every downstream call (auth.getUser,
  // and the RLS-scoped inserts below) run *as that user*, never as an
  // elevated role.
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "missing Authorization header" }, 401);
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData?.user) {
    return jsonResponse({ error: "invalid or expired session" }, 401);
  }
  const userId = userData.user.id;

  let requestBody: ScanRequestBody;
  try {
    requestBody = validateRequestBody(await req.json());
  } catch (error) {
    return jsonResponse({ error: (error as Error).message }, 400);
  }

  const actualBytes = decodedByteLength(requestBody.imageBase64);
  if (actualBytes <= 0 || actualBytes > MAX_IMAGE_BYTES) {
    return jsonResponse({ error: "image size out of allowed range" }, 400);
  }

  // Rate limiting + ownership: performed with the service-role key so the
  // count/insert always succeeds regardless of RLS, but every row is
  // still stamped with the *caller's own* user_id (never a different
  // user's), and RLS on the table (see migration 0001) still protects it
  // from any other access path.
  const serviceClient = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_SECONDS * 1000).toISOString();
  const { count, error: countError } = await serviceClient
    .from("scan_requests")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("created_at", windowStart);

  if (countError) {
    // Diagnostic-only expansion (no functional change) — sanitized
    // Postgres error fields plus env-presence booleans only. Never logs
    // the URL value, service-role key, VISION_API_KEY, JWT, Authorization
    // header, image data, or request body.
    console.error("rate limit check failed", {
      code: countError.code ?? null,
      message: countError.message ?? null,
      details: countError.details ?? null,
      hint: countError.hint ?? null,
      name: countError.name ?? null,
      supabaseUrlConfigured: Boolean(Deno.env.get("SUPABASE_URL")),
      serviceRoleKeyConfigured: Boolean(
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
      ),
    });
    return jsonResponse({ error: "internal error" }, 500);
  }
  if ((count ?? 0) >= RATE_LIMIT_MAX_REQUESTS) {
    return jsonResponse(
      { error: "too many scan requests, please wait a moment and try again" },
      429,
    );
  }

  await serviceClient.from("scan_requests").insert({ user_id: userId, kind: requestBody.kind });

  try {
    const raw = await callVisionProvider(
      requestBody.kind,
      requestBody.imageBase64,
      requestBody.mimeType,
      requestBody.category,
    );

    if (requestBody.kind === "facial" && Array.isArray(raw.observations)) {
      raw.observations = (raw.observations as Array<Record<string, unknown>>).map((o) => ({
        ...o,
        observation:
          typeof o.observation === "string" ? sanitizeObservation(o.observation) : o.observation,
      }));
    }

    if (requestBody.kind === "product") {
      const productTextFields = [
        "ingredients",
        "allergens",
        "intendedUse",
        "safetyNotes",
        "careInstructions",
        "skinTypeInfo",
        "possibleIrritants",
      ];
      for (const field of productTextFields) {
        const value = raw[field];
        if (typeof value === "string") raw[field] = sanitizeProductText(value);
      }
    }

    // Never log raw image bytes/base64, the API key, or a full local
    // path — only non-sensitive metadata.
    console.log("scan analyzed", {
      kind: requestBody.kind,
      userId,
      itemCount: requestBody.kind === "food"
        ? (raw.items as unknown[] | undefined)?.length ?? 0
        : requestBody.kind === "facial"
        ? (raw.observations as unknown[] | undefined)?.length ?? 0
        : 1,
    });

    return jsonResponse(raw, 200);
  } catch (error) {
    console.error("vision provider call failed", { kind: requestBody.kind, userId, error: (error as Error).message });
    return jsonResponse({ error: "analysis provider unavailable" }, 502);
  }
});

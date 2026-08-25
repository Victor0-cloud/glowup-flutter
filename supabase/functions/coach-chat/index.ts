// Supabase Edge Function: coach-chat
//
// The authenticated proxy between the Glow Up Flutter client's AI Coach
// (23e chat thread) and a text-generation model provider — now backed by
// the real Glow Up Brain schema (see supabase/migrations/0006_glow_up_brain.sql):
// coach_threads, coach_messages, brain_events, coach_memory, coach_feedback,
// coach_request_log. Deploy with:
//
//   supabase functions deploy coach-chat
//
// Required secrets (never present in the Flutter client — see README.md
// in this folder for the full activation checklist):
//
//   supabase secrets set COACH_API_KEY=sk-...
//   supabase secrets set COACH_API_URL=https://api.openai.com/v1/chat/completions  (optional override)
//   supabase secrets set COACH_MODEL=gpt-4o-mini                                    (optional override)
//
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are already available to
// every Edge Function automatically — they are not set manually.
//
// The service-role client below is used ONLY for the operations RLS
// deliberately keeps out of the `authenticated` role's own grants
// (coach_memory writes, coach_request_log inserts, and reading another
// table under the caller's own verified user_id) — every such call is
// still explicitly scoped to `userId`, the value derived from the
// caller's own verified JWT. The service-role key never leaves this
// function, and no request from the client is ever trusted to name its
// own user_id (see `validateRequestBody` — there is no such field).

import { createClient } from "jsr:@supabase/supabase-js@2";

const RATE_LIMIT_WINDOW_SECONDS = 60;
const RATE_LIMIT_MAX_REQUESTS = 20; // higher than analyze-scan's 5 — text chat, not image analysis
const MAX_MESSAGE_CHARS = 2000;
const MAX_HISTORY_MESSAGES = 20; // bounded conversation window loaded from coach_messages
const MAX_MEMORY_FACTS = 30;
// Larger than the other bounds: a single workout can produce several
// exerciseCompleted rows, so a small window would only ever cover 1-2
// workouts' worth of history — this still stays well within a reasonable
// prompt size, since only structured, short `data` fields are ever
// forwarded (see BrainEventRepository/the consent-scope gate in
// learning_event_controller.dart).
const MAX_RECENT_EVENTS = 50;

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

// Server-side safety net: even though the system prompt instructs the
// model to stay supportive/non-diagnostic, model output is never trusted
// blindly — same principle as analyze-scan's sanitizeObservation. Any
// reply matching a diagnostic, extreme-restriction, or crisis-adjacent
// pattern is replaced with a safe, generic fallback rather than being
// passed through verbatim.
const UNSAFE_REPLY_PATTERNS = [
  // Diagnostic-sounding claims — scoped to "you [may] have a/an <condition
  // word>" rather than the bare "you have " that used to match here. That
  // bare pattern matched almost any coaching sentence about the user's own
  // logged data ("you have logged cramps today", "you have not logged a
  // period yet" — even the honest missing-data reply), silently discarding
  // real, correct replies and substituting SAFE_FALLBACK_REPLY instead.
  /you (have|might have|could have|may have|likely have)\s+(a|an)\s+[a-z-]*\s*(disease|disorder|infection|condition|syndrome|deficiency|illness)\b/i,
  /diagnos/i,
  /\bdisease\b/i,
  /\bdisorder\b/i,
  /\binfection\b/i,
  /\bsyndrome\b/i,
  /\bpcos\b/i,
  /endometriosis/i,
  /medical condition/i,
  /prescri/i,
  /\bfast(ing)?\s+for\s+\d+\s+days?\b/i,
  /under\s+\d{3,4}\s*(kcal|calories)/i,
  /purge/i,
  // Attractiveness/beauty scoring — never permitted in this app.
  /beaut(y|iful)/i,
  /attractive/i,
  /score of \d/i,
];

const SAFE_FALLBACK_REPLY =
  "I want to make sure I give you safe, supportive guidance rather than " +
  "a generic reply here — could you tell me a bit more about what you're " +
  "going for? If this is about a health concern, a doctor or registered " +
  "dietitian is the right person to ask.";

function sanitizeReply(text: string): string {
  for (const pattern of UNSAFE_REPLY_PATTERNS) {
    if (pattern.test(text)) return SAFE_FALLBACK_REPLY;
  }
  return text;
}

// A message that reads as a crisis/self-harm disclosure never goes to the
// model for a "coaching" reply — it gets a fixed, caring redirect instead.
// This check runs on the *user's* message, before any provider call, and
// is never counted against the provider rate limit.
const CRISIS_PATTERNS = [
  /\bsuicid/i,
  /kill myself/i,
  /want to die/i,
  /self[\s-]?harm/i,
  /hurt myself/i,
];

const CRISIS_REPLY =
  "I'm really glad you told me. I'm not able to give the kind of support " +
  "you need for this, but you deserve real help — please reach out to a " +
  "crisis line or someone you trust right now. In the US you can call or " +
  "text 988 (Suicide & Crisis Lifeline), available 24/7.";

interface CoachChatRequestBody {
  threadId: string | null;
  userMessage: string;
  // Real-time client-derived context (see CoachBrainContext.toRequestJson
  // in the Flutter client) — bounded, aggregate fields only, never raw
  // journal/mood/image content. Supplements (never replaces) the
  // server-loaded memory/event history below.
  context: Record<string, unknown> | null;
}

function validateRequestBody(body: unknown): CoachChatRequestBody {
  if (typeof body !== "object" || body === null) {
    throw new Error("request body must be a JSON object");
  }
  const b = body as Record<string, unknown>;
  if (typeof b.userMessage !== "string" || b.userMessage.trim().length === 0) {
    throw new Error("userMessage is required");
  }
  if (b.userMessage.length > MAX_MESSAGE_CHARS) {
    throw new Error("userMessage too long");
  }
  // threadId, if present, must look like a uuid — anything else is
  // treated as "no thread" (a new one is created) rather than trusted.
  const threadId =
    typeof b.threadId === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(b.threadId)
      ? b.threadId
      : null;
  const context =
    typeof b.context === "object" && b.context !== null
      ? (b.context as Record<string, unknown>)
      : null;
  return { threadId, userMessage: b.userMessage, context };
}

const SYSTEM_PROMPT =
  `You are the Glow Up AI Coach — a supportive fitness/wellness companion for a women's ` +
  `wellness app. Be warm, encouraging, and practical. You may suggest workouts, routines, ` +
  `hydration/rest reminders, and general wellness habits grounded in the user's real context ` +
  `provided below. NEVER diagnose a medical condition, prescribe medication or supplements, or ` +
  `claim to treat or cure anything. NEVER recommend extreme calorie restriction, fasting beyond ` +
  `routine intermittent-fasting norms, or purging. NEVER comment on attractiveness, beauty, or ` +
  `assign any appearance-based score. If the user reports pain or a recent pain flag is present ` +
  `in their context, prioritize caution — suggest rest, form check, or consulting a professional ` +
  `over pushing through. When asked about the user's workouts, exercises, or activity history, ` +
  `answer ONLY from the "Fitness activity from real Glow Up records" data provided below — ` +
  `NEVER invent, estimate, or assume a workout/exercise happened. If that data shows zero ` +
  `completed workouts or an empty list, say so honestly (e.g. "I don't see a completed workout ` +
  `recorded yet") rather than claiming any activity occurred. You DO have access to the user's ` +
  `real Period & Cycle data and Journal activity summary when they are included below ("Live ` +
  `context right now" and "Journal activity") — when a field is present, use it directly and ` +
  `NEVER claim you don't have access to it or to "modules"/"personal data" in general; when a ` +
  `specific field the user is asking about is absent, say exactly what's missing (e.g. "You ` +
  `haven't logged a period yet, so I can't tell you your current cycle day") and suggest logging ` +
  `it, rather than guessing or refusing to engage. NEVER state or imply a fertility window, ` +
  `ovulation timing, or pregnancy likelihood — cycle day and logged symptoms/mood/energy only, ` +
  `never a phase-based medical claim. If cycle-aware suggestions are OFF, don't volunteer ` +
  `cycle-specific advice unless the user asks directly. The verbatim entry TEXT of a journal ` +
  `entry is never visible to you — only counts and mood tags by default. If a "Journal signals" ` +
  `block is included below, the user has explicitly opted in to sharing a bounded set of real, ` +
  `extracted facts from their own recent entry (never the full text) — use those facts directly ` +
  `and naturally in your answer, and if asked what specifically influenced your recommendation, ` +
  `name the actual signals provided (never just "your mood was X" alone if more signals exist). ` +
  `Never quote journal signals back verbatim as a list, never treat one day's mention as a ` +
  `permanent habit or trait, and never diagnose a condition from journal content. If no "Journal ` +
  `signals" block is present (opted out, or nothing recent to extract) and the user asks what ` +
  `you read in their journal, say honestly that you don't have that right now — never claim you ` +
  `have no access at all if a "Journal activity" summary (counts/mood) is present. Keep replies ` +
  `to 2-4 short sentences unless the user asks for more detail. Respond in plain text only, no ` +
  `markdown, no JSON.`;

function contextToPromptLine(context: Record<string, unknown> | null): string {
  if (!context) return "";
  const parts: string[] = [];
  if (typeof context.greetingName === "string") parts.push(`Name: ${context.greetingName}`);
  if (typeof context.period === "string") parts.push(`Time of day: ${context.period}`);
  if (typeof context.primaryGoal === "string") parts.push(`Primary goal: ${context.primaryGoal}`);
  if (typeof context.routinesScheduledToday === "number" && typeof context.routinesCompletedToday === "number") {
    parts.push(`Routines today: ${context.routinesCompletedToday}/${context.routinesScheduledToday} completed`);
  }
  if (typeof context.activeStreakCount === "number") parts.push(`Active streaks: ${context.activeStreakCount}`);
  if (typeof context.recentWorkoutCount === "number") parts.push(`Recent completed workouts: ${context.recentWorkoutCount}`);
  if (typeof context.latestWorkoutFeeling === "string") parts.push(`Latest workout feeling: ${context.latestWorkoutFeeling}`);
  if (context.hasRecentPainFlag === true) parts.push(`CAUTION: a recent pain flag is active — prioritize safety.`);
  if (typeof context.todayWaterMl === "number" && typeof context.todayWaterGoalMl === "number") {
    parts.push(`Water today: ${context.todayWaterMl}ml of ${context.todayWaterGoalMl}ml goal`);
  }
  // Period & Cycle — real CycleState/CycleDayEntry fields, never a
  // phase/fertility label (see CoachBrainContext's own doc comment).
  if (context.cycleAwareSuggestionsEnabled === false) {
    parts.push("Cycle-aware suggestions are turned OFF by the user — do not offer cycle-specific advice unless asked directly");
  }
  if (typeof context.currentCycleDay === "number") {
    parts.push(`Current cycle day: day ${context.currentCycleDay}`);
  }
  if (typeof context.latestPeriodStart === "string") {
    parts.push(`Latest period start: ${context.latestPeriodStart}`);
  }
  if (typeof context.predictedNextPeriodStart === "string") {
    parts.push(`Predicted next period start (estimate only, never certain): ${context.predictedNextPeriodStart}`);
  }
  if (typeof context.todayCycleMood === "string") {
    parts.push(`Today's logged mood: ${context.todayCycleMood}`);
  }
  if (typeof context.todayCycleEnergyLevel === "number") {
    parts.push(`Today's logged energy level: ${context.todayCycleEnergyLevel}/5`);
  }
  if (typeof context.todayCyclePainIntensity === "number") {
    parts.push(`Today's logged pain intensity: ${context.todayCyclePainIntensity}/5`);
  }
  if (Array.isArray(context.todayCycleSymptoms) && context.todayCycleSymptoms.length > 0) {
    parts.push(`Today's logged symptoms: ${context.todayCycleSymptoms.join(", ")}`);
  }
  return parts.length > 0 ? `Live context right now: ${parts.join(". ")}.` : "";
}

interface MemoryFact {
  memory_key: string;
  memory_value: unknown;
  category: string;
}

function memoryToPromptLine(facts: MemoryFact[]): string {
  if (facts.length === 0) return "";
  const lines = facts.map((f) => `${f.memory_key} (${f.category}): ${JSON.stringify(f.memory_value)}`);
  return `Known durable preferences about this user: ${lines.join("; ")}.`;
}

interface BrainEventRow {
  source: string;
  event_type: string;
  occurred_at: string;
  data: Record<string, unknown> | null;
}

const RECENT_WORKOUTS_WINDOW_DAYS = 7;
const MAX_RECENT_EXERCISE_NAMES = 8;

// Builds a small, bounded, computed "fitness" summary from real
// brain_events rows — never a raw dump of the events themselves (Section
// 5: "Do not send the whole database to OpenAI. Build a bounded Coach
// context"). Only fields that genuinely exist in a row's `data` are used;
// nothing here is inferred or fabricated, and an empty/missing history
// produces an honest "no completed workouts yet" statement rather than
// silence (which the model could otherwise fill in with a guess).
function buildFitnessContext(events: BrainEventRow[]): string {
  const workoutEvents = events.filter(
    (e) => e.source === "workout" && e.event_type === "workoutCompleted",
  );
  const exerciseEvents = events.filter(
    (e) => e.source === "workout" && e.event_type === "exerciseCompleted",
  );

  if (workoutEvents.length === 0 && exerciseEvents.length === 0) {
    return (
      "Fitness activity from real Glow Up records: no completed workouts or " +
      "exercises are on file yet for this user. Never claim a workout was " +
      "completed unless it appears here."
    );
  }

  const cutoff = Date.now() - RECENT_WORKOUTS_WINDOW_DAYS * 24 * 60 * 60 * 1000;
  const workoutsLast7Days = workoutEvents.filter(
    (e) => new Date(e.occurred_at).getTime() >= cutoff,
  ).length;

  const latest = workoutEvents[0]; // events are already ordered most-recent-first
  const latestWorkoutName =
    latest && typeof latest.data?.workoutName === "string"
      ? (latest.data.workoutName as string)
      : null;
  const latestWorkoutAt = latest?.occurred_at ?? null;

  const recentExerciseNames: string[] = [];
  for (const e of exerciseEvents) {
    const name = typeof e.data?.exerciseName === "string" ? (e.data.exerciseName as string) : null;
    if (name && !recentExerciseNames.includes(name)) recentExerciseNames.push(name);
    if (recentExerciseNames.length >= MAX_RECENT_EXERCISE_NAMES) break;
  }

  const categoryCounts = new Map<string, number>();
  for (const e of exerciseEvents) {
    const category = typeof e.data?.category === "string" ? (e.data.category as string) : null;
    if (!category) continue;
    categoryCounts.set(category, (categoryCounts.get(category) ?? 0) + 1);
  }
  let mostUsedCategory: string | null = null;
  let mostUsedCategoryCount = 0;
  for (const [category, count] of categoryCounts) {
    if (count > mostUsedCategoryCount) {
      mostUsedCategory = category;
      mostUsedCategoryCount = count;
    }
  }

  const fitness = {
    workouts_last_7_days: workoutsLast7Days,
    total_completed_workouts_on_file: workoutEvents.length,
    latest_workout: latestWorkoutName,
    latest_workout_at: latestWorkoutAt,
    recent_exercises: recentExerciseNames,
    most_used_category: mostUsedCategory,
  };

  return (
    "Fitness activity from real Glow Up records (JSON; every field here is " +
    "an actual persisted record, never invented — if a field is null or an " +
    "array is empty, say so honestly rather than guessing): " +
    JSON.stringify(fitness)
  );
}

interface JournalRow {
  mood: string | null;
  created_at: string;
}

const RECENT_JOURNAL_WINDOW_DAYS = 7;

// Journal entries are real, synced Supabase rows (journal_entries — see
// supabase/migrations/0007_journal.sql), so this queries them directly
// server-side (same pattern as coach_memory/brain_events) — but by default
// the Coach only ever learns a bounded COUNT and the short mood tags
// already forwarded, NEVER the entry content itself. This function alone
// never reads `content` (only `mood`/`created_at`) regardless of consent —
// see `extractJournalSignals`/`buildJournalSignalsContext` below for the
// separate, opt-in-only path that reads bounded, extracted signals from
// content (never the raw text) once the user has explicitly consented via
// `journal_ai_consent` (supabase/migrations/0008_journal_ai_consent.sql).
function buildJournalContext(rows: JournalRow[]): string {
  if (rows.length === 0) {
    return "Journal: no entries logged yet.";
  }
  const cutoff = Date.now() - RECENT_JOURNAL_WINDOW_DAYS * 24 * 60 * 60 * 1000;
  const recentCount = rows.filter((r) => new Date(r.created_at).getTime() >= cutoff).length;
  const latest = rows[0]; // already ordered most-recent-first
  const summary: Record<string, unknown> = {
    entries_last_7_days: recentCount,
    total_entries_on_file: rows.length,
    latest_entry_at: latest.created_at,
  };
  if (latest.mood) summary.latest_entry_mood = latest.mood;
  return (
    "Journal activity (JSON; entry TEXT is never included here — only " +
    "counts and mood tags): " +
    JSON.stringify(summary)
  );
}

// ==================================================
// Journal AI-consent signal extraction (opt-in only)
// ==================================================
// Only reached when journal_ai_consent.enabled = true for this user (see
// the caller). Deterministic keyword/pattern matching over the user's own
// recent entry text — never a second LLM call, so extraction itself can
// never hallucinate a fact the user didn't write. Only facts actually
// matched are ever included; nothing here invents a value. The raw
// `content` string is read from the DB, passed into this function, and
// discarded once these bounded arrays are built — it is never logged,
// never returned in any response, never written to coach_memory or
// brain_events, and never included in `logRequest`'s payload.
interface JournalSignals {
  sleep: string[];
  nutrition: string[];
  hydration: string[];
  physical: string[];
  emotional: string[];
  activity: string[];
  intentions: string[];
}

const MAX_SIGNALS_PER_CATEGORY = 5;
const MAX_SIGNAL_LENGTH = 60;
// How many most-recent content-bearing entries feed extraction, and how
// far back — keeps this a small, bounded "recent state" snapshot, never
// months of raw journal history (Section 3/4 of the approved spec).
const JOURNAL_CONTENT_WINDOW_DAYS = 7;
const MAX_JOURNAL_CONTENT_ENTRIES = 3;

function truncateSignal(s: string, max: number): string {
  return s.length <= max ? s : s.slice(0, max - 1).trimEnd() + "…";
}

function extractJournalSignals(text: string): JournalSignals {
  const signals: JournalSignals = {
    sleep: [],
    nutrition: [],
    hydration: [],
    physical: [],
    emotional: [],
    activity: [],
    intentions: [],
  };
  const push = (arr: string[], val: string) => {
    const v = truncateSignal(val.trim(), MAX_SIGNAL_LENGTH);
    if (v && arr.length < MAX_SIGNALS_PER_CATEGORY && !arr.includes(v)) arr.push(v);
  };

  const sleepHoursMatch = text.match(/slept\s+(?:about\s+)?(\d+)\s*hours?/i);
  if (sleepHoursMatch) push(signals.sleep, `slept about ${sleepHoursMatch[1]} hours`);
  if (/\btired\b/i.test(text) && /\bslept\b|\bsleep\b/i.test(text)) {
    push(signals.sleep, "tired despite sleeping");
  }

  const skippedMealMatch = text.match(/skipped\s+(breakfast|lunch|dinner)/i);
  if (skippedMealMatch) push(signals.nutrition, `skipped ${skippedMealMatch[1].toLowerCase()}`);
  if (/not hungry|wasn.?t hungry|no appetite|low appetite/i.test(text)) {
    push(signals.nutrition, "low appetite");
  }

  const waterMatch = text.match(/(\d+)\s*(?:glass|glasses|cups?)\s*(?:of\s*)?water/i);
  if (waterMatch) push(signals.hydration, `about ${waterMatch[1]} glasses of water`);
  if (/barely drank|didn.?t drink (?:much|enough) water|low on water/i.test(text)) {
    push(signals.hydration, "low water intake");
  }

  const physicalPatterns: [RegExp, string][] = [
    [/\bcramps?\b/i, "cramps"],
    [/\bbloating\b/i, "bloating"],
    [/\bheadache\b/i, "headache"],
    [/\bnausea\b/i, "nausea"],
    [/\bsore\b/i, "sore"],
    [/\bdizzy\b/i, "dizzy"],
    [/\bbackache\b/i, "backache"],
    [/\bfatigue\b/i, "fatigue"],
    [/\bmigraine\b/i, "migraine"],
  ];
  for (const [re, label] of physicalPatterns) {
    if (re.test(text)) push(signals.physical, label);
  }

  const walkMatch = text.match(/(\d+)[- ]?minute\s+walk/i);
  if (walkMatch) {
    const suffix = /yesterday/i.test(text) ? " yesterday" : "";
    push(signals.activity, `${walkMatch[1]}-minute walk${suffix}`);
  }
  if (
    /don.?t (?:feel like doing|want)\s*(?:a\s+)?hard workout|avoid(?:ing)? (?:a )?hard workout|nothing (?:too )?intense/i.test(
      text,
    )
  ) {
    push(signals.activity, "prefers to avoid a hard workout today");
  }

  const emotionalPatterns: [RegExp, string][] = [
    [/mood is low|low mood/i, "low mood"],
    [/\bemotional\b/i, "emotional"],
    [/\bstressed\b|\bstress\b/i, "stressed"],
    [/\bsad\b/i, "sad"],
    [/\banxious\b/i, "anxious"],
    [/\boverwhelmed\b/i, "overwhelmed"],
    [/\birritable\b/i, "irritable"],
  ];
  for (const [re, label] of emotionalPatterns) {
    if (re.test(text)) push(signals.emotional, label);
  }

  // Positive intentions: "want(s) to X" / "would like to X" / "hoping to
  // X" / "plan(ning) to X" — skipped when immediately preceded by a
  // negation (handled by the separate avoid-pattern below instead, so
  // "I don't want to push myself too hard" never becomes a false-positive
  // "wants to push myself too hard").
  const negationLookback = /\b(don.?t|doesn.?t|do not|does not|won.?t|will not)\s*$/i;
  const wantRe =
    /\b(?:wants?|would like|hoping|plan(?:s|ning)?)\s+to\s+([a-z0-9 ,'’-]{3,140}?)(?:,?\s*but\b|[.!?]|$)/gi;
  for (const m of text.matchAll(wantRe)) {
    const before = text.slice(Math.max(0, m.index - 15), m.index);
    if (negationLookback.test(before)) continue;
    const parts = m[1].split(/,|\band\b/i).map((p) => p.trim()).filter((p) => p.length > 1);
    for (const p of parts) push(signals.intentions, p);
  }
  const avoidRe = /\b(?:don.?t|doesn.?t|do not|does not|won.?t|will not)\s+want\s+to\s+([a-z0-9 ,'’-]{3,60}?)(?:[.,!?]|$)/gi;
  for (const m of text.matchAll(avoidRe)) {
    push(signals.intentions, `avoid ${m[1].trim()}`);
  }

  return signals;
}

function mergeJournalSignals(into: JournalSignals, from: JournalSignals): void {
  for (const key of Object.keys(into) as (keyof JournalSignals)[]) {
    for (const v of from[key]) {
      if (into[key].length < MAX_SIGNALS_PER_CATEGORY && !into[key].includes(v)) {
        into[key].push(v);
      }
    }
  }
}

// The bounded, server-facing "journal_context" (Section 4 of the approved
// spec) — recent_entry_count + a plain-text recent_summary derived
// entirely from the extracted signals (never a quoted sentence from the
// entry) + the signals object itself. Returns "" when there is nothing to
// report (no recent content-bearing entries), so it's simply omitted from
// the prompt rather than sent as an empty/misleading block.
function buildJournalSignalsContext(signals: JournalSignals, entryCount: number): string {
  const totalSignals = Object.values(signals).reduce((n, arr) => n + arr.length, 0);
  if (totalSignals === 0) return "";
  const recentSummary = (Object.entries(signals) as [string, string[]][])
    .filter(([, v]) => v.length > 0)
    .map(([k, v]) => `${k}: ${v.join(", ")}`)
    .join("; ");
  const journalContext = {
    recent_entry_count: entryCount,
    recent_summary: recentSummary,
    signals,
  };
  return (
    "Journal signals (JSON; bounded facts the user actually wrote in their " +
    "own recent entries, extracted only because they explicitly opted in " +
    "via journal_ai_consent — synthesize naturally, never quote verbatim, " +
    "never treat a single day's mention as a permanent habit/trait, never " +
    "diagnose from this content, and if asked what influenced your reply, " +
    "name these actual signals): " +
    JSON.stringify(journalContext)
  );
}

interface ProviderReply {
  text: string;
  provider: string;
  model: string;
  inputTokens: number | null;
  outputTokens: number | null;
}

async function callCoachProvider(
  systemPrompt: string,
  history: { role: "user" | "assistant"; content: string }[],
  userMessage: string,
): Promise<ProviderReply> {
  const apiKey = Deno.env.get("COACH_API_KEY");
  if (!apiKey) {
    throw new Error("COACH_API_KEY is not configured on this Edge Function");
  }
  const apiUrl = Deno.env.get("COACH_API_URL") ?? "https://api.openai.com/v1/chat/completions";
  const model = Deno.env.get("COACH_MODEL") ?? "gpt-4o-mini";

  const messages = [
    { role: "system", content: systemPrompt },
    ...history.map((turn) => ({ role: turn.role, content: turn.content })),
    { role: "user", content: userMessage },
  ];

  const response = await fetch(apiUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ model, messages, max_tokens: 300 }),
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(`coach provider returned ${response.status}: ${detail.slice(0, 200)}`);
  }

  const completion = await response.json();
  const content = completion?.choices?.[0]?.message?.content;
  if (typeof content !== "string" || content.trim().length === 0) {
    throw new Error("coach provider returned an unexpected response shape");
  }
  return {
    text: content.trim(),
    provider: "openai-compatible",
    model,
    inputTokens: typeof completion?.usage?.prompt_tokens === "number" ? completion.usage.prompt_tokens : null,
    outputTokens: typeof completion?.usage?.completion_tokens === "number" ? completion.usage.completion_tokens : null,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }

  const startedAt = Date.now();

  // 1-2. Require an authenticated Supabase user; derive user_id from the
  // verified JWT — never from request JSON (validateRequestBody below has
  // no user_id field at all).
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

  // service-role client — used only for the operations RLS deliberately
  // keeps out of `authenticated`'s own grants (coach_memory writes,
  // coach_request_log inserts), every call still explicitly scoped to
  // `userId` above, never to a client-supplied id.
  const serviceClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  async function logRequest(status: string, extra: Record<string, unknown> = {}) {
    await serviceClient.from("coach_request_log").insert({
      user_id: userId,
      status,
      latency_ms: Date.now() - startedAt,
      ...extra,
    });
  }

  // 5. Validate message length / body shape.
  let requestBody: CoachChatRequestBody;
  try {
    requestBody = validateRequestBody(await req.json());
  } catch (error) {
    await logRequest("rejected", { error_code: (error as Error).message.slice(0, 100) });
    return jsonResponse({ error: (error as Error).message }, 400);
  }

  // 4. Rate limit (separate lightweight counter table from the audit log).
  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_SECONDS * 1000).toISOString();
  const { count, error: countError } = await serviceClient
    .from("coach_chat_requests")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .gte("created_at", windowStart);

  if (countError) {
    console.error("rate limit check failed", {
      code: countError.code ?? null,
      message: countError.message ?? null,
    });
    await logRequest("internal_error", { error_code: "rate_limit_check_failed" });
    return jsonResponse({ error: "internal error" }, 500);
  }
  if ((count ?? 0) >= RATE_LIMIT_MAX_REQUESTS) {
    await logRequest("rate_limited");
    return jsonResponse({ error: "too many messages, please wait a moment and try again" }, 429);
  }
  await serviceClient.from("coach_chat_requests").insert({ user_id: userId });

  // 6. Create/reuse the thread — a client-supplied id is only ever used
  // after confirming it actually belongs to this user.
  let threadId = requestBody.threadId;
  if (threadId) {
    const { data: existingThread } = await userClient
      .from("coach_threads")
      .select("id")
      .eq("id", threadId)
      .eq("user_id", userId)
      .maybeSingle();
    if (!existingThread) threadId = null;
  }
  if (!threadId) {
    const { data: newThread, error: threadError } = await userClient
      .from("coach_threads")
      .insert({ user_id: userId })
      .select("id")
      .single();
    if (threadError || !newThread) {
      await logRequest("internal_error", { error_code: "thread_create_failed" });
      return jsonResponse({ error: "could not start a conversation thread" }, 500);
    }
    threadId = newThread.id;
  }

  // 7. Store the user message (real thread ownership already confirmed
  // above) — but first check whether this is a retry of an already-saved
  // message that never got an assistant reply (e.g. the previous attempt
  // failed after saving the user message but before saving the reply).
  // If the thread's last message is already this exact user text with no
  // assistant reply after it, reuse that row instead of inserting a
  // second copy — "Try Again" must never duplicate the user's message.
  const { data: lastMessageRows } = await userClient
    .from("coach_messages")
    .select("id, role, content, created_at")
    .eq("thread_id", threadId)
    .order("created_at", { ascending: false })
    .limit(1);
  const lastMessage = lastMessageRows?.[0];
  const isRetryOfSameMessage =
    lastMessage?.role === "user" && lastMessage.content === requestBody.userMessage;

  let userMessageRow: { id: string; created_at: string };
  if (isRetryOfSameMessage) {
    userMessageRow = { id: lastMessage!.id, created_at: lastMessage!.created_at };
  } else {
    const { data: insertedRow, error: userMessageError } = await userClient
      .from("coach_messages")
      .insert({
        thread_id: threadId,
        user_id: userId,
        role: "user",
        content: requestBody.userMessage,
      })
      .select("id, created_at")
      .single();
    if (userMessageError || !insertedRow) {
      await logRequest("internal_error", { thread_id: threadId, error_code: "user_message_insert_failed" });
      // thread_id is included even on failure — see CoachBrainError's doc
      // comment in the Flutter client: without it, a retry can't target
      // the thread that already exists and creates an orphaned duplicate.
      return jsonResponse({ error: "could not save your message", thread_id: threadId }, 500);
    }
    userMessageRow = insertedRow;
  }

  // Crisis check runs on the user's message, after it's safely stored, but
  // before any provider call — never sent to the model, never counted as
  // a normal provider request.
  if (CRISIS_PATTERNS.some((pattern) => pattern.test(requestBody.userMessage))) {
    // Assistant-role rows can only ever be written by the service-role
    // client — RLS deliberately grants `authenticated` no insert policy
    // for role='assistant' (see 0006_glow_up_brain.sql), so the backend
    // itself is the only writer, never the caller's own session.
    const { data: crisisReplyRow } = await serviceClient
      .from("coach_messages")
      .insert({
        thread_id: threadId,
        user_id: userId,
        role: "assistant",
        content: CRISIS_REPLY,
      })
      .select("id, created_at")
      .single();
    await logRequest("completed", { thread_id: threadId, error_code: "crisis_redirect" });
    return jsonResponse({
      thread_id: threadId,
      message_id: crisisReplyRow?.id ?? null,
      reply: CRISIS_REPLY,
      created_at: crisisReplyRow?.created_at ?? new Date().toISOString(),
      request_id: crypto.randomUUID(),
    });
  }

  // 8. Load only the last bounded number of chat messages (server is the
  // source of truth for history — never trusts a client-supplied
  // transcript).
  const { data: historyRows } = await userClient
    .from("coach_messages")
    .select("role, content, created_at")
    .eq("thread_id", threadId)
    .order("created_at", { ascending: false })
    .limit(MAX_HISTORY_MESSAGES);
  // The row just stored/reused for this exact message (step 7) is always
  // the last entry here — dropped since `callCoachProvider` appends
  // `requestBody.userMessage` itself; otherwise the current message would
  // appear twice in the prompt sent to the model.
  const history = (historyRows ?? [])
    .reverse()
    .filter((m) => m.role === "user" || m.role === "assistant")
    .map((m) => ({ role: m.role as "user" | "assistant", content: m.content as string }));
  if (
    history.length > 0 &&
    history[history.length - 1].role === "user" &&
    history[history.length - 1].content === requestBody.userMessage
  ) {
    history.pop();
  }

  // 9. Load active coach_memory (bounded).
  const { data: memoryRows } = await userClient
    .from("coach_memory")
    .select("memory_key, memory_value, category")
    .eq("user_id", userId)
    .eq("is_active", true)
    .limit(MAX_MEMORY_FACTS);

  // 10. Load a bounded recent brain_events summary.
  const { data: eventRows } = await userClient
    .from("brain_events")
    .select("source, event_type, occurred_at, data")
    .eq("user_id", userId)
    .order("occurred_at", { ascending: false })
    .limit(MAX_RECENT_EVENTS);

  // Journal — real, synced rows. `content` is only ever selected when the
  // user has explicitly opted in via journal_ai_consent (server-enforced —
  // never trusts a client-sent flag, since a modified client could
  // otherwise claim consent it doesn't have). Count/mood/timestamp
  // behavior (buildJournalContext) is unchanged regardless of consent.
  const { data: journalConsentRow } = await userClient
    .from("journal_ai_consent")
    .select("enabled")
    .eq("user_id", userId)
    .maybeSingle();
  const journalAiConsent = journalConsentRow?.enabled === true;

  const { data: journalRows } = await userClient
    .from("journal_entries")
    .select(journalAiConsent ? "content, mood, created_at" : "mood, created_at")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(MAX_RECENT_EVENTS);

  // Extract bounded signals from a small recent, content-bearing window
  // only — never the whole journal history. `content` never leaves this
  // block as raw text; only the resulting `journalSignalsLine` (bounded
  // extracted facts) is used below.
  let journalSignalsLine = "";
  if (journalAiConsent && journalRows) {
    const contentCutoff = Date.now() - JOURNAL_CONTENT_WINDOW_DAYS * 24 * 60 * 60 * 1000;
    const recentWithContent = (journalRows as { content?: string; created_at: string }[])
      .filter((r) => typeof r.content === "string" && new Date(r.created_at).getTime() >= contentCutoff)
      .slice(0, MAX_JOURNAL_CONTENT_ENTRIES);
    if (recentWithContent.length > 0) {
      const merged: JournalSignals = {
        sleep: [],
        nutrition: [],
        hydration: [],
        physical: [],
        emotional: [],
        activity: [],
        intentions: [],
      };
      for (const row of recentWithContent) {
        mergeJournalSignals(merged, extractJournalSignals(row.content as string));
      }
      journalSignalsLine = buildJournalSignalsContext(merged, recentWithContent.length);
    }
  }

  // 11. Build the system prompt server-side from all of the above.
  const systemPrompt = [
    SYSTEM_PROMPT,
    contextToPromptLine(requestBody.context),
    memoryToPromptLine((memoryRows ?? []) as MemoryFact[]),
    buildFitnessContext((eventRows ?? []) as BrainEventRow[]),
    buildJournalContext((journalRows ?? []) as JournalRow[]),
    journalSignalsLine,
  ]
    .filter((line) => line.length > 0)
    .join("\n\n");

  // 12-15. Call the provider, apply the safety filter, never diagnose/
  // guarantee/score appearance (enforced by SYSTEM_PROMPT + sanitizeReply).
  try {
    const providerReply = await callCoachProvider(systemPrompt, history, requestBody.userMessage);
    const safeReply = sanitizeReply(providerReply.text);

    // 16. Persist the assistant response — service-role client only (see
    // the crisis-reply insert above for why: RLS never grants
    // `authenticated` an insert policy for role='assistant').
    const { data: assistantRow, error: assistantError } = await serviceClient
      .from("coach_messages")
      .insert({
        thread_id: threadId,
        user_id: userId,
        role: "assistant",
        content: safeReply,
        provider: providerReply.provider,
        model: providerReply.model,
        input_tokens: providerReply.inputTokens,
        output_tokens: providerReply.outputTokens,
      })
      .select("id, created_at")
      .single();
    if (assistantError || !assistantRow) {
      console.error("assistant message insert failed", {
        userId,
        threadId,
        code: assistantError?.code ?? null,
        message: assistantError?.message ?? null,
      });
      await logRequest("internal_error", {
        thread_id: threadId,
        provider: providerReply.provider,
        model: providerReply.model,
        error_code: `assistant_message_insert_failed:${assistantError?.code ?? "unknown"}`,
      });
      return jsonResponse(
        { error: "reply generated but could not be saved", thread_id: threadId },
        500,
      );
    }

    // 17. Log request status/latency. Never logs the message, context,
    // memory, events, or reply content — only mechanics.
    await logRequest("completed", {
      thread_id: threadId,
      provider: providerReply.provider,
      model: providerReply.model,
    });

    // 18-19. Structured JSON only — never a provider API key.
    return jsonResponse({
      thread_id: threadId,
      message_id: assistantRow.id,
      reply: safeReply,
      created_at: assistantRow.created_at,
      request_id: crypto.randomUUID(),
    });
  } catch (error) {
    console.error("coach provider call failed", { userId, threadId, error: (error as Error).message });
    await logRequest("provider_error", {
      thread_id: threadId,
      error_code: (error as Error).message.slice(0, 100),
    });
    return jsonResponse({ error: "coach provider unavailable", thread_id: threadId }, 502);
  }
});

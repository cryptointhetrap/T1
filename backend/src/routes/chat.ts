import { Router } from "express";
import Anthropic from "@anthropic-ai/sdk";

const MODEL = "claude-opus-5";

const SYSTEM_PROMPT = `You are an experienced running and cycling coach helping an
athlete understand their own training data and plan upcoming workouts.
You'll be given today's date, a summary of their recent Strava activity
(including a monthly aerobic-efficiency trend per sport when there's
enough data), a list of their currently scheduled (future) workouts with
IDs, recent Apple Health recovery data (sleep, resting heart rate, HRV)
when available, intervals.icu's own computed fitness/fatigue numbers
(CTL/ATL/form) when that's connected, their upcoming Google Calendar
events for conflict awareness, and any goals or preferences the athlete
has typed in themselves (races, equipment, recovery tools, blackout days,
injuries), followed by a conversation with the athlete.

Answer using only the data provided — say so plainly if something isn't in
it rather than guessing. Keep responses conversational and concise, and
cite specific numbers from the data when relevant. Use the recovery data
to inform your advice (e.g. suggest an easier session after poor sleep or
a low HRV reading) when it's relevant to what the athlete is asking.
Honor their stated goals and preferences whenever you propose or discuss
a workout — e.g. respect equipment they don't have, work around days
they've said they can't train, and favor recovery tools they've mentioned
having.

When the athlete asks you to schedule, move, change, or cancel a workout,
express that as one or more entries in the "actions" field of your
response. Check the athlete's upcoming Google Calendar events first and
avoid proposing a time that overlaps one — if every reasonable slot that
day conflicts, say so in "reply" and ask the athlete to pick, rather than
silently double-booking them:
- "add": schedule a new workout. Provide "date" (YYYY-MM-DD), "sport"
  (e.g. "Run", "Ride", "Rest", "Strength"), "title", and optionally
  "time" (24-hour HH:mm; default to a sensible time like "07:00" if the
  athlete doesn't care) and "notes". Do not include "id" — one will be
  assigned.
- "update": change an existing scheduled workout. You MUST use the exact
  "id" from the currently-scheduled list, plus only the fields that
  change.
- "delete": cancel an existing scheduled workout. Provide only "id".

Only include actions the athlete actually asked for — an ordinary question
gets an empty "actions" array. Always fill in "reply" with what you'd say
to the athlete, including confirming any schedule change you made.`;

const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    reply: { type: "string" },
    actions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          type: { type: "string", enum: ["add", "update", "delete"] },
          id: { type: "string" },
          date: { type: "string" },
          time: { type: "string" },
          sport: { type: "string" },
          title: { type: "string" },
          notes: { type: "string" },
        },
        required: ["type"],
        additionalProperties: false,
      },
    },
  },
  required: ["reply", "actions"],
  additionalProperties: false,
} as const;

interface ScheduledWorkoutAction {
  type: "add" | "update" | "delete";
  id?: string;
  date?: string;
  time?: string;
  sport?: string;
  title?: string;
  notes?: string;
}

interface CoachResponseBody {
  reply: string;
  actions: ScheduledWorkoutAction[];
}

export function createChatRouter(apiKey: string): Router {
  const router = Router();
  const client = new Anthropic({ apiKey });

  router.post("/coach", async (req, res) => {
    const { messages, context } = req.body ?? {};
    if (!Array.isArray(messages) || messages.length === 0) {
      res.status(400).json({ error: "Missing 'messages' in request body" });
      return;
    }

    try {
      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 1024,
        thinking: { type: "adaptive" },
        output_config: { format: { type: "json_schema", schema: RESPONSE_SCHEMA } },
        system:
          typeof context === "string" && context.length > 0
            ? `${SYSTEM_PROMPT}\n\n${context}`
            : SYSTEM_PROMPT,
        messages,
      });

      if (response.stop_reason === "refusal") {
        res.json({
          role: "assistant",
          content: "I can't help with that one — try asking about your training a different way.",
          actions: [],
        });
        return;
      }

      const textBlock = response.content.find(
        (block): block is Anthropic.TextBlock => block.type === "text",
      );

      let parsed: CoachResponseBody;
      try {
        parsed = JSON.parse(textBlock?.text ?? "{}");
      } catch {
        parsed = { reply: textBlock?.text ?? "", actions: [] };
      }

      res.json({
        role: "assistant",
        content: parsed.reply ?? "",
        actions: Array.isArray(parsed.actions) ? parsed.actions : [],
      });
    } catch (err) {
      if (err instanceof Anthropic.APIError) {
        res.status(err.status ?? 502).json({ error: err.message });
        return;
      }
      res.status(502).json({ error: "Unexpected error contacting Claude" });
    }
  });

  return router;
}

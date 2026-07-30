import { Router } from "express";
import Anthropic from "@anthropic-ai/sdk";

const MODEL = "claude-opus-5";

const SYSTEM_PROMPT = `You are an experienced running and cycling coach helping an
athlete understand their own training data. You'll be given a summary of
their recent Strava activity, followed by a conversation with the athlete.
Answer using only the data provided in the summary — say so plainly if
something isn't in it rather than guessing. Keep responses conversational
and concise, and cite specific numbers from the data when relevant.`;

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
        system:
          typeof context === "string" && context.length > 0
            ? `${SYSTEM_PROMPT}\n\nAthlete's training summary:\n${context}`
            : SYSTEM_PROMPT,
        messages,
      });

      if (response.stop_reason === "refusal") {
        res.json({
          role: "assistant",
          content: "I can't help with that one — try asking about your training a different way.",
        });
        return;
      }

      const text = response.content
        .filter((block): block is Anthropic.TextBlock => block.type === "text")
        .map((block) => block.text)
        .join("\n");

      res.json({ role: "assistant", content: text });
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

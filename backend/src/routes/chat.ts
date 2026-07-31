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
  (e.g. "Run", "Ride", "Swim", "Weight Training", "Rest"), "title", and optionally
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

const MOTIVATION_SYSTEM_PROMPT = `Write one short, original motivational line for an athlete about to train (running or cycling). Channel the mental-toughness, no-excuses, embrace-the-suck spirit of ultra-endurance and elite-competitor culture — callousing the mind, discipline over motivation, doing the work when it's hard, outworking doubt.

This must be an ORIGINAL line you write yourself, 1-2 sentences, under 240 characters. Do NOT attribute it to David Goggins, Kobe Bryant, or any other real named person, and do not present it as a quote from anyone — it's your own line, not theirs. No quotation marks, no attribution, no preamble or title. Output only the line itself.`;

const FALLBACK_QUOTE = "Show up. Do the work. That's the whole plan.";

const MEALS_SYSTEM_PROMPT = `You generate daily meal suggestions for a fitness/training app. For each of Breakfast, Lunch, and Dinner, generate exactly 5 low-carb options and exactly 5 high-carb options (10 per meal, 30 total).

Every option must be a real, familiar dish — the kind of thing a home cook can actually make from a normal recipe, or that a typical restaurant/delivery app would list. No invented fusion dishes, no unrealistic ingredient combinations, no vague descriptions like "protein bowl" — name the actual dish (e.g. "Grilled chicken Caesar salad", "Spaghetti and meatballs").

"Low-carb" means roughly under 30g of carbohydrate for a normal portion (lean protein, vegetables, healthy fats, minimal grains/starch/sugar). "High-carb" means a normal portion built around grains, pasta, bread, rice, or other starches. Use your judgment — this doesn't need to be nutritionally precise, just a sensible everyday split.

Vary the specific dishes meaningfully from what a generic list would produce — don't just output the most obvious 5 examples for each category every time. Give each dish a short, appetizing one-sentence description.

If the athlete's past likes/dislikes are provided below, let them steer today's picks: lean toward the kinds of dishes, cuisines, proteins, or flavors they've liked, and away from the pattern of ones they've disliked — without repeating the exact same dish names verbatim every day.

Output only the structured JSON — no commentary.`;

const MEAL_OPTION_SCHEMA = {
  type: "object",
  properties: {
    name: { type: "string" },
    description: { type: "string" },
  },
  required: ["name", "description"],
  additionalProperties: false,
} as const;

const MEALS_RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    breakfastLowCarb: { type: "array", items: MEAL_OPTION_SCHEMA },
    breakfastHighCarb: { type: "array", items: MEAL_OPTION_SCHEMA },
    lunchLowCarb: { type: "array", items: MEAL_OPTION_SCHEMA },
    lunchHighCarb: { type: "array", items: MEAL_OPTION_SCHEMA },
    dinnerLowCarb: { type: "array", items: MEAL_OPTION_SCHEMA },
    dinnerHighCarb: { type: "array", items: MEAL_OPTION_SCHEMA },
  },
  required: [
    "breakfastLowCarb",
    "breakfastHighCarb",
    "lunchLowCarb",
    "lunchHighCarb",
    "dinnerLowCarb",
    "dinnerHighCarb",
  ],
  additionalProperties: false,
} as const;

interface MealOption {
  name: string;
  description: string;
  carbLevel: "low" | "high";
}

interface MealsResponseBody {
  breakfast: MealOption[];
  lunch: MealOption[];
  dinner: MealOption[];
}

interface RawMealOption {
  name?: string;
  description?: string;
}

interface RawMealsBody {
  breakfastLowCarb?: RawMealOption[];
  breakfastHighCarb?: RawMealOption[];
  lunchLowCarb?: RawMealOption[];
  lunchHighCarb?: RawMealOption[];
  dinnerLowCarb?: RawMealOption[];
  dinnerHighCarb?: RawMealOption[];
}

const FALLBACK_MEALS: MealsResponseBody = {
  breakfast: [
    { name: "Veggie egg scramble with spinach and feta", description: "Fluffy eggs scrambled with wilted spinach and salty feta.", carbLevel: "low" },
    { name: "Greek yogurt with berries and almonds", description: "Creamy Greek yogurt topped with fresh berries and crunchy almonds.", carbLevel: "low" },
    { name: "Avocado and smoked salmon on cucumber rounds", description: "Cool cucumber slices topped with avocado and smoked salmon.", carbLevel: "low" },
    { name: "Bacon and eggs with sautéed greens", description: "Crispy bacon and fried eggs alongside garlicky sautéed greens.", carbLevel: "low" },
    { name: "Cottage cheese with walnuts and cinnamon", description: "Cottage cheese swirled with toasted walnuts and a dash of cinnamon.", carbLevel: "low" },
    { name: "Oatmeal with banana and honey", description: "Warm oatmeal topped with sliced banana and a drizzle of honey.", carbLevel: "high" },
    { name: "Whole wheat pancakes with maple syrup", description: "Fluffy whole wheat pancakes stacked high with maple syrup.", carbLevel: "high" },
    { name: "Bagel with cream cheese and fruit", description: "A toasted bagel with cream cheese and a side of fresh fruit.", carbLevel: "high" },
    { name: "Overnight oats with granola", description: "Chilled overnight oats topped with crunchy granola.", carbLevel: "high" },
    { name: "Banana bread French toast", description: "Thick-cut banana bread griddled French-toast style.", carbLevel: "high" },
  ],
  lunch: [
    { name: "Grilled chicken Caesar salad", description: "Crisp romaine, grilled chicken, and parmesan, no croutons.", carbLevel: "low" },
    { name: "Turkey lettuce wraps", description: "Seasoned ground turkey wrapped in crisp lettuce leaves.", carbLevel: "low" },
    { name: "Tuna salad over greens", description: "Classic tuna salad served over a bed of mixed greens.", carbLevel: "low" },
    { name: "Zucchini noodle chicken alfredo", description: "Creamy alfredo chicken over spiralized zucchini noodles.", carbLevel: "low" },
    { name: "Steak and roasted vegetable bowl", description: "Sliced steak over a bowl of roasted seasonal vegetables.", carbLevel: "low" },
    { name: "Turkey and cheese sandwich", description: "Sliced turkey and cheese on fresh bread with lettuce and tomato.", carbLevel: "high" },
    { name: "Chicken burrito bowl with rice and beans", description: "Seasoned chicken over rice and black beans with fresh toppings.", carbLevel: "high" },
    { name: "Pasta primavera", description: "Pasta tossed with a colorful mix of sautéed vegetables.", carbLevel: "high" },
    { name: "Quinoa and chickpea salad", description: "Quinoa and chickpeas tossed with herbs and a lemon vinaigrette.", carbLevel: "high" },
    { name: "Grilled cheese with tomato soup", description: "A classic grilled cheese sandwich paired with tomato soup.", carbLevel: "high" },
  ],
  dinner: [
    { name: "Baked salmon with asparagus", description: "Oven-baked salmon fillet with roasted asparagus spears.", carbLevel: "low" },
    { name: "Grilled steak with cauliflower mash", description: "Grilled steak served with creamy cauliflower mash.", carbLevel: "low" },
    { name: "Chicken stir-fry with broccoli", description: "Stir-fried chicken and broccoli in a savory sauce, no rice.", carbLevel: "low" },
    { name: "Shrimp and zucchini scampi", description: "Garlic butter shrimp tossed with zucchini ribbons.", carbLevel: "low" },
    { name: "Pork tenderloin with green beans", description: "Roasted pork tenderloin with sautéed green beans.", carbLevel: "low" },
    { name: "Spaghetti and meatballs", description: "Classic spaghetti tossed in marinara with hearty meatballs.", carbLevel: "high" },
    { name: "Chicken fried rice", description: "Wok-fried rice with chicken, egg, and vegetables.", carbLevel: "high" },
    { name: "Baked ziti", description: "Baked pasta layered with marinara, ricotta, and melted cheese.", carbLevel: "high" },
    { name: "Beef and bean burritos", description: "Seasoned beef and beans wrapped in a warm flour tortilla.", carbLevel: "high" },
    { name: "Teriyaki chicken with rice", description: "Glazed teriyaki chicken served over steamed rice.", carbLevel: "high" },
  ],
};

function normalizeMeals(raw: RawMealsBody): MealsResponseBody {
  const clean = (items: RawMealOption[] | undefined, carbLevel: "low" | "high"): MealOption[] =>
    (Array.isArray(items) ? items : [])
      .filter((item): item is Required<RawMealOption> => typeof item?.name === "string" && typeof item?.description === "string")
      .slice(0, 5)
      .map((item) => ({ name: item.name, description: item.description, carbLevel }));

  const combine = (low: RawMealOption[] | undefined, high: RawMealOption[] | undefined, fallback: MealOption[]): MealOption[] => {
    const combined = [...clean(low, "low"), ...clean(high, "high")];
    return combined.length === 10 ? combined : fallback;
  };

  return {
    breakfast: combine(raw.breakfastLowCarb, raw.breakfastHighCarb, FALLBACK_MEALS.breakfast),
    lunch: combine(raw.lunchLowCarb, raw.lunchHighCarb, FALLBACK_MEALS.lunch),
    dinner: combine(raw.dinnerLowCarb, raw.dinnerHighCarb, FALLBACK_MEALS.dinner),
  };
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

  router.post("/motivation", async (_req, res) => {
    try {
      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 150,
        // A one-line creative burst doesn't need reasoning — keep it cheap and fast.
        thinking: { type: "disabled" },
        output_config: { effort: "low" },
        system: MOTIVATION_SYSTEM_PROMPT,
        messages: [{ role: "user", content: "Give me today's line." }],
      });

      if (response.stop_reason === "refusal") {
        res.json({ quote: FALLBACK_QUOTE });
        return;
      }

      const textBlock = response.content.find(
        (block): block is Anthropic.TextBlock => block.type === "text",
      );
      const quote = (textBlock?.text ?? "").trim();
      res.json({ quote: quote.length > 0 ? quote : FALLBACK_QUOTE });
    } catch (err) {
      if (err instanceof Anthropic.APIError) {
        res.status(err.status ?? 502).json({ error: err.message });
        return;
      }
      res.status(502).json({ error: "Unexpected error contacting Claude" });
    }
  });

  router.post("/meals", async (req, res) => {
    const { likedMeals, dislikedMeals } = req.body ?? {};

    const contextLines: string[] = [];
    if (Array.isArray(likedMeals) && likedMeals.length > 0) {
      contextLines.push(`Meals this athlete has rated 👍 in the past: ${likedMeals.join(", ")}.`);
    }
    if (Array.isArray(dislikedMeals) && dislikedMeals.length > 0) {
      contextLines.push(`Meals this athlete has rated 👎 in the past: ${dislikedMeals.join(", ")}.`);
    }
    const context = contextLines.join("\n");

    try {
      const response = await client.messages.create({
        model: MODEL,
        max_tokens: 3000,
        output_config: {
          format: { type: "json_schema", schema: MEALS_RESPONSE_SCHEMA },
          effort: "medium",
        },
        system: context.length > 0 ? `${MEALS_SYSTEM_PROMPT}\n\n${context}` : MEALS_SYSTEM_PROMPT,
        messages: [{ role: "user", content: "Generate today's meal suggestions." }],
      });

      if (response.stop_reason === "refusal") {
        res.json({ meals: FALLBACK_MEALS });
        return;
      }

      const textBlock = response.content.find(
        (block): block is Anthropic.TextBlock => block.type === "text",
      );

      let parsed: RawMealsBody;
      try {
        parsed = JSON.parse(textBlock?.text ?? "{}");
      } catch {
        parsed = {};
      }

      res.json({ meals: normalizeMeals(parsed) });
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

import { Router } from "express";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { generateICS, type FeedWorkout } from "../ics.js";

const TOKEN_PATTERN = /^[A-Za-z0-9-]{8,64}$/;

function isFeedWorkout(value: unknown): value is FeedWorkout {
  if (typeof value !== "object" || value === null) return false;
  const workout = value as Record<string, unknown>;
  return (
    typeof workout.id === "string" &&
    typeof workout.date === "string" &&
    typeof workout.sport === "string" &&
    typeof workout.title === "string" &&
    (workout.notes === undefined || typeof workout.notes === "string")
  );
}

/// The single piece of state this otherwise-stateless backend holds: each
/// athlete's scheduled workouts, keyed by an unguessable per-install token
/// the app generates locally, so their calendar app can subscribe to a
/// stable `.ics` URL. The token is a bearer secret, same as a Google
/// Calendar "private address" — anyone with the link can read that
/// athlete's schedule, so nothing sensitive belongs in it.
export function createFeedRouter(dataDir: string): Router {
  const router = Router();

  const fileFor = (token: string) => path.join(dataDir, `${token}.json`);

  router.put("/:token", async (req, res) => {
    const { token } = req.params;
    if (!TOKEN_PATTERN.test(token)) {
      res.status(400).json({ error: "Invalid feed token" });
      return;
    }

    const { workouts } = req.body ?? {};
    if (!Array.isArray(workouts) || !workouts.every(isFeedWorkout)) {
      res.status(400).json({ error: "Body must be { workouts: FeedWorkout[] }" });
      return;
    }

    try {
      await mkdir(dataDir, { recursive: true });
      await writeFile(fileFor(token), JSON.stringify(workouts), "utf8");
      res.status(204).end();
    } catch {
      res.status(500).json({ error: "Couldn't save the feed" });
    }
  });

  router.get("/:token.ics", async (req, res) => {
    const { token } = req.params;
    if (!TOKEN_PATTERN.test(token)) {
      res.status(400).send("Invalid feed token");
      return;
    }

    let workouts: FeedWorkout[] = [];
    try {
      const raw = await readFile(fileFor(token), "utf8");
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed) && parsed.every(isFeedWorkout)) {
        workouts = parsed;
      }
    } catch {
      // No feed uploaded yet — serve an empty (but valid) calendar rather
      // than a 404, so subscribing before the first sync doesn't error.
    }

    res.set("Content-Type", "text/calendar; charset=utf-8");
    res.send(generateICS(workouts));
  });

  return router;
}

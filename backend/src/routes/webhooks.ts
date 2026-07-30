import { Router } from "express";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

interface StravaWebhookEvent {
  object_type?: string;
  object_id?: number;
  aspect_type?: string;
  owner_id?: number;
  event_time?: number;
  subscription_id?: number;
  updates?: Record<string, string>;
}

const ATHLETE_ID_PATTERN = /^\d{1,20}$/;

/// Strava webhooks are app-level, not per-user: you create ONE push
/// subscription (a one-time `POST` with client_id/client_secret/
/// callback_url/verify_token — see backend/README.md) and Strava then
/// calls this same `/strava` endpoint for every athlete who's authorized
/// the app. There's no way for this stateless backend to push straight to
/// a specific phone (that would need APNs plus a device-token registry,
/// a separate feature), so instead it just remembers the latest event
/// time per athlete and the app polls the cheap `/status` route on
/// foreground to decide whether a full Strava resync is worth doing —
/// much cheaper than always re-fetching the activity list.
export function createWebhooksRouter(verifyToken: string, dataDir: string): Router {
  const router = Router();
  const fileFor = (athleteID: string) => path.join(dataDir, `${athleteID}.json`);

  router.get("/strava", (req, res) => {
    const mode = req.query["hub.mode"];
    const token = req.query["hub.verify_token"];
    const challenge = req.query["hub.challenge"];

    if (mode === "subscribe" && token === verifyToken && typeof challenge === "string") {
      res.json({ "hub.challenge": challenge });
      return;
    }
    res.status(403).json({ error: "Verification failed" });
  });

  router.post("/strava", async (req, res) => {
    const event = (req.body ?? {}) as StravaWebhookEvent;
    // Strava requires a 200 within two seconds and retries on anything
    // else, so acknowledge before doing any file I/O.
    res.status(200).end();

    if (event.object_type !== "activity" || !event.owner_id || !event.event_time) return;

    try {
      await mkdir(dataDir, { recursive: true });
      await writeFile(
        fileFor(String(event.owner_id)),
        JSON.stringify({ latestEventAt: event.event_time }),
        "utf8",
      );
    } catch {
      // Best-effort — the app's normal refresh cadence is the fallback.
    }
  });

  router.get("/strava/status/:athleteID", async (req, res) => {
    const { athleteID } = req.params;
    if (!ATHLETE_ID_PATTERN.test(athleteID)) {
      res.status(400).json({ error: "Invalid athlete ID" });
      return;
    }

    try {
      const raw = await readFile(fileFor(athleteID), "utf8");
      const parsed = JSON.parse(raw);
      const latestEventAt = typeof parsed.latestEventAt === "number" ? parsed.latestEventAt : null;
      res.json({ latestEventAt });
    } catch {
      res.json({ latestEventAt: null });
    }
  });

  return router;
}

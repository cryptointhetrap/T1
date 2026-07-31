import { Router } from "express";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import type { APNsClient } from "../apns.js";
import type { createPushStore } from "../pushStore.js";

interface StravaWebhookEvent {
  object_type?: string;
  object_id?: number;
  aspect_type?: string;
  owner_id?: number;
  event_time?: number;
  subscription_id?: number;
  updates?: Record<string, string>;
}

export interface PushConfig {
  store: ReturnType<typeof createPushStore>;
  apns: APNsClient;
}

const ATHLETE_ID_PATTERN = /^\d{1,20}$/;

/// Strava webhooks are app-level, not per-user: you create ONE push
/// subscription (a one-time `POST` with client_id/client_secret/
/// callback_url/verify_token — see backend/README.md) and Strava then
/// calls this same `/strava` endpoint for every athlete who's authorized
/// the app. It always remembers the latest event time per athlete so the
/// app can poll the cheap `/status` route on foreground to decide whether
/// a full Strava resync is worth doing. When `push` is configured (APNs
/// keys set — see backend/README.md → "Push notifications setup") and a
/// device is registered for that athlete, a genuinely new activity
/// (`aspect_type === "create"`) also gets a silent push, waking the app
/// to generate an AI workout-review notification. Either way the app's
/// normal polling stays the fallback.
export function createWebhooksRouter(verifyToken: string, dataDir: string, push?: PushConfig): Router {
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

    if (event.aspect_type !== "create" || !push) return;

    try {
      const registration = await push.store.get(String(event.owner_id));
      if (!registration) return;
      await push.apns.sendSilentPush(registration.deviceToken, registration.environment, {
        type: "workout-review",
        activityId: event.object_id,
      });
    } catch {
      // Best-effort — a missed push just means no review notification
      // this time; nothing else about the app depends on it.
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

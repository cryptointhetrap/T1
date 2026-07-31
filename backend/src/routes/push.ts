import { Router } from "express";
import { createPushStore } from "../pushStore.js";

/// Lets the app register (or clear) this device's APNs token for a given
/// athlete, so the Strava webhook handler (`routes/webhooks.ts`) knows
/// where to send a silent push when a new activity syncs for them. See
/// backend/README.md → "Push notifications setup" for the APNs
/// configuration this depends on.
export function createPushRouter(dataDir: string): Router {
  const router = Router();
  const store = createPushStore(dataDir);

  router.put("/:athleteID/token", async (req, res) => {
    const { athleteID } = req.params;
    if (!store.isValidAthleteID(athleteID)) {
      res.status(400).json({ error: "Invalid athlete ID" });
      return;
    }

    const { deviceToken, environment } = req.body ?? {};
    if (
      typeof deviceToken !== "string" ||
      !deviceToken ||
      (environment !== "sandbox" && environment !== "production")
    ) {
      res.status(400).json({ error: "Body must be { deviceToken, environment: 'sandbox' | 'production' }" });
      return;
    }

    await store.set(athleteID, { deviceToken, environment, updatedAt: Date.now() });
    res.status(204).end();
  });

  router.delete("/:athleteID/token", async (req, res) => {
    const { athleteID } = req.params;
    if (!store.isValidAthleteID(athleteID)) {
      res.status(400).json({ error: "Invalid athlete ID" });
      return;
    }

    await store.delete(athleteID);
    res.status(204).end();
  });

  return router;
}

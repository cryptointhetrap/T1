import { Router } from "express";
import { StravaApiError, exchangeAuthorizationCode, refreshAccessToken } from "../strava.js";

export function createAuthRouter(clientId: string, clientSecret: string): Router {
  const router = Router();

  router.post("/exchange", async (req, res) => {
    const { code } = req.body ?? {};
    if (typeof code !== "string" || code.length === 0) {
      res.status(400).json({ error: "Missing 'code' in request body" });
      return;
    }

    try {
      const tokens = await exchangeAuthorizationCode(clientId, clientSecret, code);
      res.json(tokens);
    } catch (err) {
      if (err instanceof StravaApiError) {
        res.status(err.status).json({ error: err.message });
        return;
      }
      res.status(502).json({ error: "Unexpected error contacting Strava" });
    }
  });

  router.post("/refresh", async (req, res) => {
    const { refresh_token: refreshToken } = req.body ?? {};
    if (typeof refreshToken !== "string" || refreshToken.length === 0) {
      res.status(400).json({ error: "Missing 'refresh_token' in request body" });
      return;
    }

    try {
      const tokens = await refreshAccessToken(clientId, clientSecret, refreshToken);
      res.json(tokens);
    } catch (err) {
      if (err instanceof StravaApiError) {
        res.status(err.status).json({ error: err.message });
        return;
      }
      res.status(502).json({ error: "Unexpected error contacting Strava" });
    }
  });

  return router;
}

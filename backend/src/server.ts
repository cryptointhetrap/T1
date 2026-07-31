import "dotenv/config";
import cors from "cors";
import express from "express";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { createAPNsClient } from "./apns.js";
import { createPushStore } from "./pushStore.js";
import { createAuthRouter } from "./routes/auth.js";
import { createChatRouter } from "./routes/chat.js";
import { createFeedRouter } from "./routes/feed.js";
import { createGroupsRouter } from "./routes/groups.js";
import { createPushRouter } from "./routes/push.js";
import { createWebhooksRouter, type PushConfig } from "./routes/webhooks.js";

const PORT = Number(process.env.PORT ?? 8787);
const CLIENT_ID = process.env.STRAVA_CLIENT_ID;
const CLIENT_SECRET = process.env.STRAVA_CLIENT_SECRET;
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const FEED_DATA_DIR = process.env.FEED_DATA_DIR ?? path.join(process.cwd(), "data", "feeds");
const WEBHOOK_DATA_DIR = process.env.WEBHOOK_DATA_DIR ?? path.join(process.cwd(), "data", "webhooks");
const GROUPS_DATA_DIR = process.env.GROUPS_DATA_DIR ?? path.join(process.cwd(), "data", "groups");
const PUSH_DATA_DIR = process.env.PUSH_DATA_DIR ?? path.join(process.cwd(), "data", "push");
// Only used for the one-time Strava subscription-creation handshake (see
// backend/README.md) — not required for the server to run day to day.
const STRAVA_WEBHOOK_VERIFY_TOKEN = process.env.STRAVA_WEBHOOK_VERIFY_TOKEN ?? "training-monitor-verify-token";

// Push notifications (AI workout reviews) are entirely optional — see
// backend/README.md → "Push notifications setup". Leave any of these
// unset and the webhook route just skips the silent-push step.
const APNS_TEAM_ID = process.env.APNS_TEAM_ID;
const APNS_KEY_ID = process.env.APNS_KEY_ID;
const APNS_AUTH_KEY_PATH = process.env.APNS_AUTH_KEY_PATH;
const APNS_BUNDLE_ID = process.env.APNS_BUNDLE_ID;

if (!CLIENT_ID || !CLIENT_SECRET) {
  throw new Error(
    "STRAVA_CLIENT_ID and STRAVA_CLIENT_SECRET must be set (see .env.example).",
  );
}

if (!ANTHROPIC_API_KEY) {
  throw new Error("ANTHROPIC_API_KEY must be set (see .env.example).");
}

async function buildPushConfig(): Promise<PushConfig | undefined> {
  if (!APNS_TEAM_ID || !APNS_KEY_ID || !APNS_AUTH_KEY_PATH || !APNS_BUNDLE_ID) return undefined;

  // A missing/unreadable key file (e.g. leftover placeholder text in
  // .env) should disable this optional feature, not take down the whole
  // server — every other route works fine without it.
  try {
    const privateKey = await readFile(APNS_AUTH_KEY_PATH, "utf8");
    return {
      store: createPushStore(PUSH_DATA_DIR),
      apns: createAPNsClient({ teamID: APNS_TEAM_ID, keyID: APNS_KEY_ID, privateKey, bundleID: APNS_BUNDLE_ID }),
    };
  } catch (err) {
    console.warn(`Push notifications disabled: couldn't read APNS_AUTH_KEY_PATH (${APNS_AUTH_KEY_PATH}): ${(err as Error).message}`);
    return undefined;
  }
}

const app = express();
app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => res.json({ status: "ok" }));
app.use("/auth", createAuthRouter(CLIENT_ID, CLIENT_SECRET));
app.use("/chat", createChatRouter(ANTHROPIC_API_KEY));
app.use("/feed", createFeedRouter(FEED_DATA_DIR));
app.use("/groups", createGroupsRouter(GROUPS_DATA_DIR));
app.use("/push", createPushRouter(PUSH_DATA_DIR));
app.use("/webhooks", createWebhooksRouter(STRAVA_WEBHOOK_VERIFY_TOKEN, WEBHOOK_DATA_DIR, await buildPushConfig()));

app.listen(PORT, () => {
  console.log(`training-monitor-backend listening on port ${PORT}`);
});

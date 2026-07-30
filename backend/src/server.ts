import "dotenv/config";
import cors from "cors";
import express from "express";
import path from "node:path";
import { createAuthRouter } from "./routes/auth.js";
import { createChatRouter } from "./routes/chat.js";
import { createFeedRouter } from "./routes/feed.js";
import { createGroupsRouter } from "./routes/groups.js";
import { createWebhooksRouter } from "./routes/webhooks.js";

const PORT = Number(process.env.PORT ?? 8787);
const CLIENT_ID = process.env.STRAVA_CLIENT_ID;
const CLIENT_SECRET = process.env.STRAVA_CLIENT_SECRET;
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const FEED_DATA_DIR = process.env.FEED_DATA_DIR ?? path.join(process.cwd(), "data", "feeds");
const WEBHOOK_DATA_DIR = process.env.WEBHOOK_DATA_DIR ?? path.join(process.cwd(), "data", "webhooks");
const GROUPS_DATA_DIR = process.env.GROUPS_DATA_DIR ?? path.join(process.cwd(), "data", "groups");
// Only used for the one-time Strava subscription-creation handshake (see
// backend/README.md) — not required for the server to run day to day.
const STRAVA_WEBHOOK_VERIFY_TOKEN = process.env.STRAVA_WEBHOOK_VERIFY_TOKEN ?? "training-monitor-verify-token";

if (!CLIENT_ID || !CLIENT_SECRET) {
  throw new Error(
    "STRAVA_CLIENT_ID and STRAVA_CLIENT_SECRET must be set (see .env.example).",
  );
}

if (!ANTHROPIC_API_KEY) {
  throw new Error("ANTHROPIC_API_KEY must be set (see .env.example).");
}

const app = express();
app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => res.json({ status: "ok" }));
app.use("/auth", createAuthRouter(CLIENT_ID, CLIENT_SECRET));
app.use("/chat", createChatRouter(ANTHROPIC_API_KEY));
app.use("/feed", createFeedRouter(FEED_DATA_DIR));
app.use("/webhooks", createWebhooksRouter(STRAVA_WEBHOOK_VERIFY_TOKEN, WEBHOOK_DATA_DIR));
app.use("/groups", createGroupsRouter(GROUPS_DATA_DIR));

app.listen(PORT, () => {
  console.log(`training-monitor-backend listening on port ${PORT}`);
});

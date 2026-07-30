import "dotenv/config";
import cors from "cors";
import express from "express";
import { createAuthRouter } from "./routes/auth.js";

const PORT = Number(process.env.PORT ?? 8787);
const CLIENT_ID = process.env.STRAVA_CLIENT_ID;
const CLIENT_SECRET = process.env.STRAVA_CLIENT_SECRET;

if (!CLIENT_ID || !CLIENT_SECRET) {
  throw new Error(
    "STRAVA_CLIENT_ID and STRAVA_CLIENT_SECRET must be set (see .env.example).",
  );
}

const app = express();
app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => res.json({ status: "ok" }));
app.use("/auth", createAuthRouter(CLIENT_ID, CLIENT_SECRET));

app.listen(PORT, () => {
  console.log(`training-monitor-backend listening on port ${PORT}`);
});

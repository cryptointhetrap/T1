# TrainingMonitor backend

A minimal Express service with two jobs: keep the Strava **client secret**
and the **Anthropic API key** out of the iOS app.

- `POST /auth/exchange` — exchanges an OAuth `code` (from the in-app Strava
  login) for an `access_token` / `refresh_token` pair.
- `POST /auth/refresh` — exchanges a stored `refresh_token` for a fresh
  `access_token` once the old one expires.
- `POST /chat/coach` — forwards a chat conversation plus a context string to
  Claude and returns its reply as structured JSON: a `reply` string plus an
  `actions` array the athlete's device applies to its locally-stored
  scheduled workouts (add/update/delete, with an optional time-of-day).
  This endpoint holds no schedule, Health, or calendar data itself — the
  device assembles all of that (current schedule, recent Strava activity,
  Apple Health recovery metrics, intervals.icu wellness, upcoming Google
  Calendar events, and the athlete's own typed-in goals/preferences) into
  the `context` string on every request, and Claude's proposed changes
  travel back the same way.
- `PUT /feed/:token` / `GET /feed/:token.ics` — the one piece of state
  this backend holds. The app uploads its scheduled workouts (as plain
  JSON) to a random per-install token it generates itself; the `.ics`
  endpoint reads that back and renders it as an RFC 5545 calendar, so any
  calendar app can subscribe to it as a read-only feed. There's no login
  here — the token is a bearer secret, the same trust model as a Google
  Calendar "private address" link. Data is written to
  `FEED_DATA_DIR` (defaults to `./data/feeds`) as one small JSON file per
  token; delete a file to wipe that feed.
- `POST /groups` / `GET /groups/:code` / `PUT
  /groups/:code/members/:athleteID` / `DELETE
  /groups/:code/members/:athleteID` — small invite-code groups for the
  in-app "Compare" page, where athletes who separately connect their own
  Strava account to this app can compare relative effort, hours, and
  mileage for the current month. Strava's API has no athlete search and
  no way to read another athlete's data at all, so this is deliberately
  not a public leaderboard — just people who share a 6-character code.
  There's no login: whoever has the code can join or read the group,
  the same trust model as the `.ics` feed token above. Data lives in
  `GROUPS_DATA_DIR` (defaults to `./data/groups`) as one JSON file per
  group.
- `GET /webhooks/strava` / `POST /webhooks/strava` / `GET
  /webhooks/strava/status/:athleteID` — Strava webhook plumbing. The first
  two are Strava calling *this backend*: a one-time subscription-
  verification handshake, and then a ping every time an activity is
  created/updated/deleted for any athlete who's authorized the app. The
  backend just remembers the latest event time per athlete
  (`WEBHOOK_DATA_DIR`, defaults to `./data/webhooks`) — it has no way to
  push straight to a specific phone (no APNs, no device-token registry),
  so instead the app polls the third, cheap route on foreground and only
  does a full Strava resync if there's actually something new. See
  *Strava webhook setup* below.

Everything else (Strava activities/stats, Apple Health, Google Calendar,
Intervals.icu) is called by the iOS app **directly against those APIs** —
this backend never proxies that data. Strava and Anthropic need their
secrets kept server-side, which is this backend's real job; the `.ics`
feed above is the one deliberate exception to "no database, no user
data," added because a shareable calendar subscription URL has to live
somewhere reachable, and a phone that's asleep can't serve one. Google
Calendar in particular never touches this backend at all: Google issues
no client secret for the "iOS" OAuth client type (PKCE proves the request
instead), so that auth flow is entirely on-device. Same for Intervals.icu
— it's a self-serve API key the athlete pastes in, no OAuth, no backend
involvement.

## Setup

```bash
cd backend
npm install
cp .env.example .env
# fill in STRAVA_CLIENT_ID / STRAVA_CLIENT_SECRET from
# https://www.strava.com/settings/api, and ANTHROPIC_API_KEY from
# https://console.anthropic.com
npm run dev
```

The server listens on `http://localhost:8787` by default.

## Deploying

Any Node host works (Render, Fly.io, Railway, a small VPS, etc.):

```bash
npm run build
npm start
```

Set `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, `ANTHROPIC_API_KEY`, and
`PORT` as environment variables on the host. Once deployed, point the iOS
app's `backendBaseURL` (in `ios/TrainingMonitor/Config/AppConfig.swift`) at
the deployed URL.

If you want the `.ics` calendar feed, webhook event cache, or compare
groups to survive redeploys, mount a persistent volume and point
`FEED_DATA_DIR` / `WEBHOOK_DATA_DIR` / `GROUPS_DATA_DIR` at it —
otherwise they're just small JSON files on local disk and get wiped on a
platform that uses ephemeral filesystems (fine for personal use; the feed
repopulates next time the app saves a workout, webhook status just goes
back to "unknown" until the next event arrives, and a wiped group means
whoever created it has to create a new one and re-share the code).

## Strava app configuration

When you register your API application at
https://www.strava.com/settings/api, set the **Authorization Callback
Domain** to the domain you'll use for the OAuth redirect. The iOS app uses a
custom URL scheme (`trainingmonitor://oauth-callback`) for the redirect, so
this backend never needs to be publicly reachable during the OAuth
handshake itself — only for the `/auth/exchange` and `/auth/refresh` calls
that follow it.

## Strava webhook setup

Unlike everything else here, this is a one-time, app-level step you run
once against your deployed backend (not something the iOS app does):

1. Deploy the backend somewhere publicly reachable and set
   `STRAVA_WEBHOOK_VERIFY_TOKEN` to a random string of your choosing.
2. Create the push subscription — Strava will immediately call back to
   `GET /webhooks/strava` to verify it, so the backend must already be
   deployed and reachable when you run this:

   ```bash
   curl -X POST https://www.strava.com/api/v3/push_subscriptions \
     -F client_id=YOUR_STRAVA_CLIENT_ID \
     -F client_secret=YOUR_STRAVA_CLIENT_SECRET \
     -F callback_url=https://your-deployed-backend/webhooks/strava \
     -F verify_token=YOUR_STRAVA_WEBHOOK_VERIFY_TOKEN
   ```
3. A successful response includes an `id` — that's your subscription. You
   only do this once per Strava API application; it then applies to every
   athlete who authorizes the app, automatically. Check it any time with:

   ```bash
   curl -G https://www.strava.com/api/v3/push_subscriptions \
     -d client_id=YOUR_STRAVA_CLIENT_ID \
     -d client_secret=YOUR_STRAVA_CLIENT_SECRET
   ```

Skipping this step doesn't break anything — the app just won't get the
foreground fast-path and falls back to its normal refresh cadence
(pull-to-refresh, tab appearance).

# Go Harder Ai Training backend

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
- `POST /chat/motivation` — asks Claude for one short, original line in an
  intense, no-excuses training mindset — deliberately *not* a quote
  attributed to David Goggins, Kobe Bryant, or anyone else real; the
  system prompt explicitly forbids misattributing invented lines to a
  named person. Shown on the app's launch splash, not a tab. The app
  caches the result locally and only calls this once per calendar day.
- `POST /chat/workout-review` — given a plain-text summary of one
  just-completed Strava activity (pace/speed, heart rate, elevation,
  power, relative effort) plus whatever recent recovery/training-load
  context the device has on hand (Apple Health sleep/resting heart rate/
  HRV, intervals.icu CTL/ATL), returns a short AI review reacting to how
  that workout went in light of the athlete's current recovery/load.
  Triggered by the app in the background after a silent push (see "Push
  notifications setup" below) — this endpoint itself never touches
  HealthKit or intervals.icu data directly, the device gathers all of
  that locally and sends only a plain-text summary.
- `PUT` / `DELETE /push/:athleteID/token` — the app registers (or clears)
  this device's APNs token here so the webhook handler below knows where
  to send a silent push. Registering is what turns workout-review push
  on for that athlete; there's no separate flag, just whether a token is
  on file.
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
  *Strava webhook setup* below. When APNs is also configured (see *Push
  notifications setup*) and the athlete has a registered device, a
  genuinely new activity additionally gets a silent push, waking the app
  to generate an AI workout-review notification — the polling above stays
  the fallback either way.

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

## Push notifications setup

Entirely optional, and layered on top of the Strava webhook above (do that
first — push notifications only fire off the `aspect_type === "create"`
events it already receives). This is what lets the backend wake the app in
the background to generate an AI workout review right after a new activity
syncs, rather than the athlete having to open the app and wait.

**Requires a paid Apple Developer Program membership ($99/year).** Apple's
free/personal development teams (just an Apple ID, no paid enrollment)
cannot provision an app with the Push Notifications capability at all —
Xcode will refuse to build with an error like *"Personal development
teams... do not support the Push Notifications capability."* That's why
`TrainingMonitor.entitlements` does **not** declare `aps-environment` by
default — everything else in this app builds and runs fine on a free
account; this one feature is opt-in specifically because most people
cloning this repo won't have a paid membership.

1. In [Apple Developer](https://developer.apple.com/account) → **Certificates,
   Identifiers & Profiles → Keys**, create a new key with the **Apple Push
   Notifications service (APNs)** capability checked. Download the `.p8`
   file it gives you (only downloadable once) and note its **Key ID**.
2. Note your **Team ID** (top right of the Apple Developer site, or
   **Membership** in the sidebar).
3. Set four environment variables on the backend (see `.env.example`):
   `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_AUTH_KEY_PATH` (path to the `.p8`
   file on the server), and `APNS_BUNDLE_ID` (the iOS app's bundle ID,
   e.g. `com.trainingmonitor.app` — must match exactly, it's used as the
   APNs "topic").
4. On the iOS side, in Xcode: select the target → **Signing & Capabilities**
   → **+ Capability** → **Push Notifications** (this only succeeds if your
   Team is enrolled in the paid Developer Program — it adds the
   `aps-environment` key to `TrainingMonitor.entitlements` for you) — and
   separately enable **Background Modes → Remote notifications** if it
   isn't already checked (`project.yml`/`Info.plist` already declare that
   one, since Background Modes alone doesn't need a paid account). The
   athlete then turns workout reviews on from the Stats tab's `•••` menu.

Leaving any of the four `APNS_*` variables unset is completely fine —
`server.ts` only wires up the APNs client when all four are present, and
the webhook route silently skips the push step otherwise. Nothing else in
the backend depends on this.

Apple's sandbox vs. production APNs environments are separate — a device
running a debug build registers with `environment: "sandbox"`
automatically (see `PushRegistrationClient` on the iOS side), and this
backend picks the matching APNs host per registration, so no separate
staging configuration is needed here.

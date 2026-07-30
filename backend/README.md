# TrainingMonitor backend

A minimal Express service with two jobs: keep the Strava **client secret**
and the **Anthropic API key** out of the iOS app.

- `POST /auth/exchange` — exchanges an OAuth `code` (from the in-app Strava
  login) for an `access_token` / `refresh_token` pair.
- `POST /auth/refresh` — exchanges a stored `refresh_token` for a fresh
  `access_token` once the old one expires.
- `POST /chat/coach` — forwards a chat conversation plus a training-data
  summary to Claude and returns its reply as structured JSON: a `reply`
  string plus an `actions` array the athlete's device applies to its
  locally-stored scheduled workouts (add/update/delete). This endpoint
  holds no schedule data itself — the device sends its current schedule
  as part of the request context, and Claude's proposed changes travel
  back the same way.

Everything else (activities, athlete stats, etc.) is called by the iOS app
**directly against the Strava API** using the `access_token` returned here —
this backend never proxies activity data, so it stays tiny and stateless. It
holds no database and no user data.

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

## Strava app configuration

When you register your API application at
https://www.strava.com/settings/api, set the **Authorization Callback
Domain** to the domain you'll use for the OAuth redirect. The iOS app uses a
custom URL scheme (`trainingmonitor://oauth-callback`) for the redirect, so
this backend never needs to be publicly reachable during the OAuth
handshake itself — only for the `/auth/exchange` and `/auth/refresh` calls
that follow it.

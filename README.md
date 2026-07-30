# TrainingMonitor

An iOS app that connects to Strava to monitor your training, starting with a
training load / trends dashboard. Built as two pieces:

- **`ios/`** — the SwiftUI app (native, App Store target).
- **`backend/`** — a minimal Node/Express service that performs the Strava
  OAuth token exchange/refresh, so the Strava **client secret** never has to
  live inside the mobile app. It does not store or proxy your activity
  data — the app talks to Strava directly for everything else.

## Why a backend at all?

Strava's OAuth flow is the standard `client_id` + `client_secret` grant.
Shipping the `client_secret` inside an iOS binary means anyone can extract
it, so a small server-side piece holds it instead and only ever hands the
app short-lived tokens.

## Getting started

1. **Register a Strava API app**: https://www.strava.com/settings/api
   (gives you a Client ID and Client Secret).
2. **Run the backend** — see `backend/README.md`. For local development
   against the iOS Simulator, `http://localhost:8787` (the default) works
   out of the box.
3. **Build the iOS app** — see `ios/README.md`. Requires a Mac with Xcode
   and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (this repo doesn't
   include a hand-built `.xcodeproj`; `xcodegen generate` produces one from
   `ios/project.yml`).

## Current features (v1)

- Connect/disconnect your Strava account (OAuth via
  `ASWebAuthenticationSession`, tokens kept in the iOS Keychain)
- Weekly training volume chart (distance/time/elevation)
- Bike & Run section: weekly, monthly, and yearly mileage and elevation
  gain, broken out per sport (miles/feet)
- Training load trend: 7-day (acute) vs 28-day (chronic) rolling load, with
  a simple status readout (ramping up / optimal / high load / detraining)
- Recent activities list

## What's next

This is intentionally a thin first slice. Natural next additions, roughly
in order of how self-contained they are:

- Swim/other sports in the per-sport breakdown
- Weekly goal setting + progress rings
- Push notifications (e.g. a weekly recap, or an overload warning)
- HealthKit integration for recovery signals (resting HR, HRV, sleep)
- Home screen widgets / Live Activities

Tell me which of these (or something else) you want next and I'll build it
on top of this foundation.

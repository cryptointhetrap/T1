# TrainingMonitor (iOS)

A SwiftUI app that connects to Strava and shows a training load / trends
dashboard: weekly volume (distance/time/elevation), a Bike & Run section
with weekly/monthly/yearly mileage and elevation gain per sport, a 7-day
vs 28-day acute:chronic load trend, and a recent activities list. Distances
are shown in miles, elevation gain in feet.

This project was scaffolded without Xcode (built in a Linux container), so
it uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the
`.xcodeproj` deterministically from `project.yml` rather than shipping a
hand-edited project file. You'll need a Mac with Xcode to build/run it.

## One-time setup (on your Mac)

```bash
brew install xcodegen
cd ios
xcodegen generate
open TrainingMonitor.xcodeproj
```

In Xcode:
1. Select the `TrainingMonitor` target → **Signing & Capabilities** → set
   your Team, and change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`
   (then re-run `xcodegen generate`) if `com.trainingmonitor.app` is taken.
2. Add a real 1024x1024 app icon to
   `TrainingMonitor/Assets.xcassets/AppIcon.appiconset` before shipping —
   a placeholder Contents.json is there but no image yet.

## Before it will run

Edit `TrainingMonitor/Config/AppConfig.swift`:

- `stravaClientID` — from your app at https://www.strava.com/settings/api
- `backendBaseURL` — wherever you deployed `../backend` (defaults to
  `http://localhost:8787` for local testing against the simulator)

Also register the OAuth redirect: this app uses the custom URL scheme
`trainingmonitor://oauth-callback`, which is already declared in
`Info.plist` — nothing to configure on the Strava side for the redirect
itself (Strava mobile OAuth allows custom URL scheme callbacks).

## How auth works

1. User taps **Connect with Strava** → app opens Strava's OAuth screen via
   `ASWebAuthenticationSession`.
2. Strava redirects to `trainingmonitor://oauth-callback?code=...`.
3. The app sends that `code` to our backend's `/auth/exchange`, which is
   the only thing that knows the Strava client secret.
4. The backend returns `access_token` / `refresh_token`; the app stores
   them in the Keychain (`KeychainStore`) and calls the Strava API
   *directly* from then on, refreshing via the backend's `/auth/refresh`
   when the access token expires.

## Project layout

```
TrainingMonitor/
  App/            App entry point (@main)
  Config/         Client ID / backend URL constants
  Models/         Codable Strava API models
  Services/       Keychain, OAuth, backend client, Strava API client
  ViewModels/      Training-load aggregation (weekly + acute:chronic)
  Views/          SwiftUI screens and chart components
```

## Roadmap ideas (not yet built)

- Per-sport filtering (run/ride/swim) on the dashboard
- Push notifications for weekly summaries
- Goal setting (weekly distance/time targets) with progress rings
- HealthKit cross-check for recovery metrics (HRV, resting HR)
- Widgets / Live Activities for an in-progress activity

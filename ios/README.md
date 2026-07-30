# TrainingMonitor (iOS)

A SwiftUI app that connects to Strava and shows a training load / trends
dashboard: weekly volume (distance/time/elevation), a Bike & Run section
with weekly/monthly/yearly mileage and elevation gain per sport, a 7-day
vs 28-day acute:chronic load trend, and a recent activities list. A second
tab is an activity calendar that scrolls back through your entire Strava
history, month by month, with a dot per day for each sport you did that
day — tap a day to see its activities. A third tab is a chat with Claude,
grounded in the same training data, for reviewing workouts and trends —
Claude can also schedule, move, or cancel future workouts there, which
show up as hollow calendar markers alongside completed activities.
Distances are shown in miles, elevation gain in feet.

Two more connections, both optional, from the Training tab's `•••` menu:
Apple Health (sleep, resting heart rate, HRV, shown in a Recovery section
and fed into the coach's context) and Google Calendar (scheduled workouts
are pushed there as real events, and Claude reads your upcoming events
back so it can avoid double-booking you).

The whole UI uses one small, deliberate palette: the Maryland state
flag's gold, red, and black (`Views/Theme.swift`), in place of the
assorted orange/blue/purple/green/yellow this app used earlier. Strava's
own "Connect with Strava" button keeps Strava's brand orange per their
usage guidelines — that one's intentionally not part of the theme.

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
2. Still on **Signing & Capabilities**, confirm **HealthKit** is listed
   (it's already declared in `TrainingMonitor.entitlements`); with
   automatic signing Xcode enables the capability on your App ID the
   first time it builds. With manual signing you'll need to add it to the
   App ID yourself in the Apple Developer portal first.
3. Add a real 1024x1024 app icon to
   `TrainingMonitor/Assets.xcassets/AppIcon.appiconset` before shipping —
   a placeholder Contents.json is there but no image yet.

## Before it will run

Edit `TrainingMonitor/Config/AppConfig.swift`:

- `stravaClientID` — from your app at https://www.strava.com/settings/api
- `backendBaseURL` — wherever you deployed `../backend` (defaults to
  `http://localhost:8787` for local testing against the simulator)
- `googleClientID` / `googleRedirectScheme` — see **Google Calendar
  setup** below. Leave as the placeholders if you don't want that
  connection; the app runs fine without it, the menu button just won't
  complete.

Also register the OAuth redirect: this app uses the custom URL scheme
`trainingmonitor://oauth-callback`, which is already declared in
`Info.plist` — nothing to configure on the Strava side for the redirect
itself (Strava mobile OAuth allows custom URL scheme callbacks).

### Google Calendar setup

Unlike Strava, Google's OAuth for the "iOS" client type needs no client
secret (PKCE proves the request instead), so there's nothing to add to the
backend — it's entirely client-side:

1. In [Google Cloud Console](https://console.cloud.google.com), create/select
   a project, enable the **Google Calendar API**, then go to **APIs &
   Services → Credentials → Create Credentials → OAuth client ID** and
   choose type **iOS**. Use your app's bundle ID
   (`com.trainingmonitor.app` or whatever you changed it to).
2. Copy the generated client ID (looks like
   `1234567890-abc123.apps.googleusercontent.com`) into
   `AppConfig.googleClientID`.
3. The **reversed** form of that same ID
   (`com.googleusercontent.apps.1234567890-abc123`) goes in two places:
   `AppConfig.googleRedirectScheme` and the second `CFBundleURLSchemes`
   entry in `Info.plist`.
4. The OAuth consent screen will show an "unverified app" warning until
   you submit for Google's verification — expected and fine for personal
   use; click through it (Google restricts this to a testers list you
   control until then).

### Apple Health

No account or console setup — HealthKit permission is a plain system
dialog. Testing sleep data specifically works best on a real device (the
Simulator's Health app has no real sleep history to read).

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
  Models/         Codable Strava/Google API models, unit conversions
  Services/       Keychain, Strava + Google OAuth, backend client,
                  Strava/Google Calendar API clients, coach chat client,
                  local scheduled-workout store, HealthKit manager
  ViewModels/      Training-load aggregation (weekly + acute:chronic),
                  calendar month pagination, coach chat, Health, Google
                  Calendar
  Views/          SwiftUI screens and chart components
```

## Roadmap ideas (not yet built)

- Per-sport filtering (run/ride/swim) on the dashboard
- Push notifications for weekly summaries
- Goal setting (weekly distance/time targets) with progress rings
- Widgets / Live Activities for an in-progress activity

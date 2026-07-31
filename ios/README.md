# Go Harder Ai Training (iOS)

A SwiftUI app that connects to Strava and Apple Health, across five tabs:

- **Stats**: a training load / trends dashboard — weekly volume
  (distance/time/elevation), a By Sport section with weekly/monthly/
  yearly totals for Run, Bike, Swim, and Weight Training (mileage and
  elevation gain for the first three; duration and session count for
  Weight Training, since Strava reports no distance for it), a 7-day vs
  28-day acute:chronic load trend, and a recent activities list.
  Distances are shown in miles, elevation gain in feet. Also shows:
  average/weighted watts and kilojoules on activities that have them; a
  monthly aerobic-efficiency trend per sport (real power-per-heartbeat
  for rides with a power meter, speed-per-heartbeat otherwise) once
  there's a few months of data; and a Recent PRs list of any run effort
  Strava currently ranks in your all-time top 3, found among your most
  recently synced runs. A "Longest Efforts" row opens a separate page
  ranking your top 10 longest runs, top 10 longest rides, and top 10
  longest swims across your entire Strava history (not just the
  ~370-day window everything else on the dashboard uses — Weight
  Training isn't ranked there, since it has no distance to rank by). A
  "Weekly Goal" section lets you set your own weekly distance/time/
  elevation targets (each optional independently) and shows progress as
  three concentric rings against the current calendar week's actual
  totals — leave a target unset and its ring just shows an empty track. A
  "Compare" row opens a page for creating or joining a small invite-code
  group with other Go Harder Ai Training users, to see everyone's
  current-month relative effort, hours, and mileage side by side — see
  *Compare groups* below for why this isn't a general Strava
  leaderboard. Four more connections, all optional, live behind this
  tab's `•••` menu: Apple Health (sleep, resting heart rate, HRV, shown
  in a Recovery section and fed into the coach's context), Google
  Calendar (scheduled workouts are pushed there as real events, and
  Claude reads your upcoming events back so it can avoid double-booking
  you), Intervals.icu (a self-serve API key, no OAuth — pulls in its
  own CTL/ATL/form fitness-and-fatigue numbers, and pushes scheduled
  workouts there too), and Workout Reviews (push notifications — see
  *Push notifications* below).
- **Steps**: daily step count and walking/running distance from Apple
  Health (same HealthKit permission sheet as the Recovery section
  above), led by today's step count and mileage, then rolled up into
  this week/this month/this year totals plus a rolling 365-day daily
  average — a stable "typical day" number that doesn't swing early in
  January the way a year-to-date average would — and a 30-day step
  chart. Folded into the coach's context alongside the other Health
  data.
- **Meals**: Claude generates 5 low-carb and 5 high-carb suggestions for
  each of breakfast/lunch/dinner every day (30 total) — real, familiar
  dishes, not invented ones — refreshed automatically once a day (cached
  on-device, same pattern as the launch splash's daily line below) or on
  demand from the refresh button. Thumbs up/down on any suggestion; rated
  dishes are remembered on-device and sent back as steering context on
  future requests, so the picks drift toward what you've liked and away
  from what you haven't —
  no backend state, the same "context, not database" personalization
  approach as the rest of this app. Tap a suggestion for two links: a
  recipe search ("how to make it") and a delivery search ("order it").
  Both are search-results links rather than a guessed direct URL —
  Claude can't guarantee a real recipe page exists at a made-up address,
  and DoorDash's internal link scheme isn't something to hardcode a
  guess at, so a search is the honest, always-valid choice.
- **Calendar**: scrolls back through your entire Strava history, month
  by month, with a dot per day for each sport you did that day — tap a
  day to see its activities. Can hand you a subscribable `.ics` feed URL
  (share-icon button) for any calendar app. If you've set up the
  backend's optional Strava webhook subscription, the app also does a
  cheap foreground check here and only does a full resync when
  something's actually new.
- **Coach**: a chat with Claude, grounded in the same training, Health,
  steps, and weekly-goal-progress data shown elsewhere in the app, for
  reviewing workouts and trends. Claude can also schedule, move, or cancel future workouts,
  which then show up as hollow calendar markers on the Calendar tab
  alongside completed activities. Has a free-text goals & preferences
  box (target-icon button) for anything you want the coach to factor
  in — races, equipment, recovery tools, blackout days, injuries.

Not a tab: a full-screen launch splash shows briefly while the app opens,
with one short, original Claude-written line in an intense, no-excuses
training mindset — refreshed automatically once a day (cached on-device,
so Claude is only called once daily) — before handing off to the Stats
tab. Deliberately *not* a quote attributed to David Goggins, Kobe
Bryant, or any other real person — the backend's system prompt
(`backend/src/routes/chat.ts`) explicitly instructs Claude to write an
original line in that spirit rather than fabricate and misattribute a
quote to somebody real.

The whole UI uses one small, deliberate palette sampled straight from the
Go Harder Ai Training logo: a bright lime green (`#A8D80A`) and a
brushed-metal silver (`#C8C8C6`), both set against true black
(`Views/Theme.swift`). Strava's own "Connect with Strava" button keeps
Strava's brand orange per their usage guidelines — that one's
intentionally not part of the theme. Genuine warning states (a failed
connection, an elevated training-load status) use plain system red
instead, since red isn't in the logo and still needs to read as a
warning rather than an accent.

The app is forced to a black, dark-appearance theme
(`.preferredColorScheme(.dark)` in `TrainingMonitorApp`) regardless of
the device's system setting, so both accent colors were picked to read
clearly on true black — and a couple of low-opacity fills (the
training-status banner, the assistant chat bubble) were raised so they
stay visible against black instead of nearly disappearing into it.

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
3. The app icon (`TrainingMonitor/Assets.xcassets/AppIcon.appiconset`) is
   already set to the Go Harder Ai Training logo — swap the image there if
   you want a different one before shipping.

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

### Intervals.icu

No console setup either — generate a personal API key at
[intervals.icu → Settings → Developer](https://intervals.icu/settings)
(also shown there: your athlete ID, which looks like `i123456`). Enter
both in the app's Intervals.icu connect sheet. Field names for the
wellness response (`ctl`, `atl`, `restingHR`, `hrv`, etc.) come from
intervals.icu's community-documented API rather than a published formal
schema — if a field silently reads as missing, it likely means
intervals.icu renamed or moved it and `IntervalsWellness` in
`Models/IntervalsICUModels.swift` needs a small update.

### Push notifications

Turned on from the Stats tab's `•••` menu ("Enable Workout Reviews"),
which just asks for the standard iOS notification permission and
registers this device's APNs token with the backend
(`PUT /push/:athleteID/token`). From there it's fully automatic: the
backend's Strava webhook (see `backend/README.md` → *Strava webhook
setup*) sends a silent push the moment a new activity syncs, which wakes
the app in the background (`AppDelegate` + `WorkoutReviewGenerator`) to
gather that workout's own performance plus whatever recent Apple
Health/intervals.icu recovery data is available — entirely on-device,
since HealthKit data never leaves the phone — ask the backend's
`/chat/workout-review` for a short AI review, and post it as a
notification. The review also stays visible afterward as a small
"✨ ..." line under the matching activity in the Stats tab's recent-
activities list (`WorkoutReviewStore`, on-device only).

Requires the backend's optional APNs configuration (see
`backend/README.md` → *Push notifications setup*) — four environment
variables from an Apple Developer `.p8` auth key. Without that
configuration the menu toggle still works (permission gets requested,
the device still registers) but no push ever arrives, since the backend
has nowhere to send it; everything else in the app is unaffected either
way. On the Xcode side this needs the **Push Notifications** capability
and **Background Modes → Remote notifications** enabled — both already
declared in the checked-in `project.yml`/`Info.plist`/entitlements, so
this is normally nothing you need to touch unless you changed the bundle
ID (in which case re-add the capability in Xcode so it provisions under
your own Apple Developer account). The `aps-environment` entitlement
ships as `development` (sandbox) — switch it to `production` before
archiving for TestFlight/App Store, or let Xcode manage it automatically
with automatic signing.

### Compare groups

No console setup, no accounts, no login — the Compare page lets you
create a group (get a 6-character code back) or join one someone shared
with you. Whoever holds the code can join or read the group; that's the
entire access model, appropriate for sharing with people you actually
know, not a public product. This exists because Strava's API doesn't
support what a real cross-Strava leaderboard would need: there's no
athlete search endpoint, and no way to read another athlete's activity
data unless they've personally authorized your specific app via OAuth —
so "compare with any Strava user" genuinely isn't buildable, and this is
the closest legitimate substitute. Each connected athlete's relative
effort, hours, and mileage for the current calendar month get pushed to
the group automatically whenever the Stats tab refreshes (best-effort,
silent) — see `ViewModels/GroupCompareViewModel.swift` and
`backend/src/routes/groups.ts`.

### Calendar feed (`.ics`)

The Calendar tab's share-icon button shows a subscription URL
(`<backendBaseURL>/feed/<token>.ics`) you can add to Apple Calendar,
Google Calendar, or anything else that supports URL-based calendar
subscriptions. The token is a random, unguessable per-install value
generated on first use (`Services/CalendarFeedClient.swift`) — anyone
with the full URL can read that feed, so treat it like you would a Google
Calendar "private address" link. This is also the one piece of state the
otherwise-stateless backend holds; see `backend/README.md`.

### Strava webhooks (optional)

Purely a backend-side, one-time setup (see `backend/README.md` → *Strava
webhook setup*) — nothing to configure in the app. Once it's done, the
app's foreground check (`DashboardViewModel.refreshIfNewActivity`,
triggered from `DashboardView`'s `scenePhase` change) starts finding real
events instead of always getting `latestEventAt: null`. Skipping the
backend setup is harmless; the app just falls back to its normal refresh
triggers (pull-to-refresh, opening the Stats tab).

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
  App/            App entry point (@main), UIApplicationDelegateAdaptor
                  shim for APNs callbacks
  Config/         Client ID / backend URL constants
  Models/         Codable Strava/Google API models, unit conversions
  Services/       Keychain, Strava + Google + Intervals.icu + Groups +
                  Meals clients, backend client, webhook status polling,
                  coach chat client, local scheduled-workout store +
                  calendar feed uploads, HealthKit manager, free-text
                  preferences store, group membership store, meal ratings
                  store, weekly goals store, push-notification manager +
                  device-token registration + AI workout-review generator
                  and on-device store
  ViewModels/      Training-load + efficiency aggregation, calendar month
                  pagination, coach chat, Health, Steps, Meals, Google
                  Calendar, Intervals.icu, longest efforts, group compare
  Views/          SwiftUI screens and chart components
```

## Roadmap ideas (not yet built)

- Per-sport filtering (run/ride/swim/weight training) on the dashboard
- Push notifications for weekly summaries
- Goal setting (weekly distance/time targets) with progress rings
- Widgets / Live Activities for an in-progress activity

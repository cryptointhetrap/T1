# TrainingMonitor

An iOS app that connects to Strava to monitor your training, starting with a
training load / trends dashboard. Built as two pieces:

- **`ios/`** — the SwiftUI app (native, App Store target).
- **`backend/`** — a minimal Node/Express service that performs the Strava
  OAuth token exchange/refresh, so the Strava **client secret** never has to
  live inside the mobile app. It also proxies chat messages to Claude
  (Anthropic API) for the in-app coach, so the **Anthropic API key** stays
  server-side too. It does not store or proxy your activity data — the app
  talks to Strava directly for everything else.

## Why a backend at all?

Strava's OAuth flow is the standard `client_id` + `client_secret` grant.
Shipping the `client_secret` inside an iOS binary means anyone can extract
it, so a small server-side piece holds it instead and only ever hands the
app short-lived tokens.

## Getting started

1. **Register a Strava API app**: https://www.strava.com/settings/api
   (gives you a Client ID and Client Secret).
2. **Get an Anthropic API key** (for the Coach chat tab): https://console.anthropic.com
3. **(Optional) Set up a Google Cloud OAuth client** for Google Calendar
   sync — see `ios/README.md` → *Google Calendar setup*. Apple Health
   needs no external setup at all, and Intervals.icu just needs an API key
   from your own account (see below) — no console setup either.
4. **Run the backend** — see `backend/README.md`. For local development
   against the iOS Simulator, `http://localhost:8787` (the default) works
   out of the box. Deploy it somewhere reachable from the internet if you
   want the `.ics` calendar feed to work from other devices/apps.
5. **Build the iOS app** — see `ios/README.md`. Requires a Mac with Xcode
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
- Activity calendar: scrolls back through your entire history month by
  month (no fixed cutoff), with a colored dot per sport on days you were
  active; tap a day to see what you did
- Coach chat: ask Claude about your workouts and training trends — it's
  grounded in the same weekly/monthly/yearly stats and recent activities
  shown in the Training tab. Claude can also add, move, or cancel
  scheduled (future) workouts on your behalf, which then show up as
  hollow markers on the Calendar tab alongside completed activities
- Apple Health: sleep, resting heart rate, and HRV shown in a Recovery
  section on the Training tab and folded into the coach's context, so its
  advice can account for how well-recovered you are
- Google Calendar (optional, connect from the Training tab's `•••` menu):
  scheduled workouts are pushed there as real events, and Claude reads
  your upcoming events back so it avoids proposing a time that conflicts
- Intervals.icu (optional, connect from the Training tab's `•••` menu with
  a self-serve API key — no OAuth): pulls in intervals.icu's own
  CTL/ATL/form fitness-and-fatigue numbers alongside Apple Health in the
  Recovery section and the coach's context, and pushes scheduled workouts
  there as planned events, same as Google Calendar
- Aerobic efficiency trend: a monthly efficiency-factor trend per sport —
  real power-per-heartbeat for rides with a power meter, speed-per-
  heartbeat otherwise — computed from Strava's own activity summaries,
  shown as a chart on the Training tab and summarized for the coach
- Power data: average/weighted watts and kilojoules, shown on activities
  that have them and factored into the efficiency trend above
- Recent PRs: surfaces any run effort Strava currently ranks in your
  all-time top 3 for its distance, among your most recently synced runs
- Longest Efforts (separate page, linked from the Training tab): your
  top 10 longest-distance runs and top 10 longest-distance rides, across
  your entire Strava history
- Goals & preferences: an open free-text box (Coach tab, target-icon
  button) for anything the coach should know — races, equipment, recovery
  tools, blackout days, injuries — sent along with every chat message
- Calendar feed (Calendar tab, share-icon button): a subscribable `.ics`
  URL for your scheduled workouts, so Apple Calendar, Google Calendar, or
  any other app that supports URL calendar subscriptions can mirror your
  schedule read-only
- Strava webhooks (optional, one-time backend setup — see
  `backend/README.md`): the app checks a cheap status endpoint on
  foreground and only does a full resync when something's actually
  changed, instead of always re-fetching your whole activity list

## What's next

This is intentionally a thin first slice. Natural next additions, roughly
in order of how self-contained they are:

- Swim/other sports in the per-sport breakdown
- Weekly goal setting + progress rings
- Push notifications (e.g. a weekly recap, or an overload warning)
- Home screen widgets / Live Activities

Integrations that exist but weren't added here because they require a
partner-approved developer program (not something this app can self-serve
into, unlike Strava/Google/Intervals.icu): Wahoo, Hammerhead, Zwift,
Rouvy, and pushing structured workouts directly to head units. Worth
revisiting if you want to apply for that access yourself.

Tell me which of these (or something else) you want next and I'll build it
on top of this foundation.

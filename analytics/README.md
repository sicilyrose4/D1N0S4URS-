# Analytics

Tracks how many people use the Team Alarm prototype: https://sicilyrose4.github.io/team-alarm-tasks/

**Main metric: unique users.** One user = one phone or browser the first time it opens the app.

- **Live dashboard:** https://sicilyrose4.github.io/team-alarm-tasks/stats.html (same page as [`index.html`](index.html) here)
- **Latest snapshot:** [`latest.md`](latest.md)

## What gets counted

| Count | When it goes up |
|---|---|
| Unique users | First time a device opens the app |
| Daily users | First time a device opens the app that day |
| App opens | Every time the app loads |
| Player / coach sign-ups | Someone finishes onboarding as that role |
| Teams created | A coach makes a team |
| Team joins | A player joins with an invite, code, or QR link |
| Alarms created | Someone saves a new alarm |
| Alarms rang | An alarm goes off on a phone |
| "I'm up" taps / snoozes | Taps on the ringing screen |
| Excuse requests / approved / denied | A player asks out, and what the coach decided |

## How it works

- The app sends anonymous "+1" pings to a free counter service ([abacus](https://abacus.jasoncameron.dev), namespace `d1n0s4urs-team-alarm`). No names, teams, or personal info are sent.
- Only the real site counts. Local copies and test rooms (`?team=...`) are skipped, so testing doesn't inflate the numbers.
- [`snapshot.sh`](snapshot.sh) pulls the counts into `latest.md`. Run it with `bash analytics/snapshot.sh` from the repo root.
- [`.github/workflows/analytics.yml`](../.github/workflows/analytics.yml) runs that script and commits `latest.md` on every push to this branch, from the Actions tab, and every day once it's merged into `main`.

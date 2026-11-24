# D1N0S4URS

> Rewrite this file every time the project changes. Last updated: 2026-11-24

Most up-to-date live prototype: https://sicilyrose4.github.io/team-alarm-tasks/ 

- **Live analytics dashboard:** https://sicilyrose4.github.io/team-alarm-tasks/stats.html
- **Latest analytics snapshot:** [`analytics/latest.md`](analytics/latest.md)
- **Newest user test (Instagram reel, posted 2026-11-24):** https://www.instagram.com/p/DgI4vuIh5hR/

## What we're designing
A shared alarm clock focused on team practices/games

The team's alarm keeps ringing until everyone is up, so teammates hold each other accountable. Players see who on the team is awake, and they can "flash" a sleeping teammate's phone to wake them up.

## Who we're designing for
Teens/young adult athletes who are part of a team, and the coaches that lead the teams.

## Where we are right now

- The live prototype is a web app that runs on any phone. Players and coaches sign up, make or join a team, set alarms, and see each other wake up in real time.
- It counts anonymous usage (unique users, sign-ups, teams, alarms, wake-ups, excuses). This is our main way of measuring the test.
- On 2026-11-24 we started a public test: Quin posted a reel on Instagram pointing people to the live prototype. The numbers just before the reel went up (2026-11-24, 2:53 pm CST) were 3 unique users, 36 app opens, 5 teams, 3 alarms created, and 1 alarm that rang. Anything above these came after the reel.

## How we got here

| Date | What happened | Who |
|---|---|---|
| 11-02 – 11-03 | Set up the repo, team pages, interview template, and numbers tracker | Sicily, Saj |
| 11-03 – 11-09 | Each of us used 3 multiplayer apps and wrote down what made other people feel present ([`3 multiplayer notes/`](3%20multiplayer%20notes)) | Everyone |
| 11-04 | 7 interviews with college students about their days, their groups, and what gets in the way of connecting ([`interviews/`](interviews)) | Sicily (3), Quin (2), Saj (2) |
| 11-08 – 11-09 | Round 1 testing: a Figma question-and-answer app, and the first team alarm prototype ([`Round 1 testing/`](Round%201%20testing)) | Quin, Sicily |
| 11-09 | *Who's the Bot?*, a live phone party game we explored as a multiplayer prototype ([`app/`](app)) | Nathan |
| 11-11 | Multiplayer team alarm prototype goes live with a QR code ([`Alarm Prototype for 11-11/`](Alarm%20Prototype%20for%2011-11)); crit notes; risks and guardrails | Sicily, Nathan |
| 11-12 | Settled on our focus: a shared alarm for team athletes and coaches | Team |
| 11-16 | Round 2 testing of the alarm ([`Round 2 testing/`](Round%202%20testing)) | Quin, Sicily |
| 11-17 | *Clique Clock* iPhone app (SwiftUI, TestFlight build 5) ([`clique-clock/`](clique-clock)) | Nathan |
| 11-17 – 11-23 | Quin's UI variations: a web *Clique Clock* (branch `quin/clique-clock-ui`) and a restyled copy of the 11-11 prototype (`quin-alarm/`, branch `quin/alarm-prototype`) | Quin |
| 11-22 | Usage analytics: live dashboard, snapshot script, daily update ([`analytics/`](analytics)) | Sicily |
| 11-23 | Live prototype updates: close buttons on every pop-up, no Coach/Player labels, simpler start screen | Sicily |
| 11-24 | Public test: Instagram reel linking to the live prototype | Quin |

## What we've learned

### From interviews (11-04)
We started with a broad brief about bringing people together, and talked to busy college students.
- **Time is the biggest barrier.** Packed, unpredictable schedules make group plans fall apart.
- **People are around others all day but rarely connect.** Real connection happens in small, familiar groups.
- **Accountability to someone else works better than willpower.** One person said the only screen-time limit that worked was one someone else controlled.
- **Shared routines and activities build closeness.** Teams, the gym, and recurring projects keep people coming back.
- **Groups depend on one planner,** and that's fragile when the planner is busy or leaves.

These led us to a team tool built on a shared daily routine (waking up for practice), where teammates hold each other accountable.

### From multiplayer notes
Multiplayer feels real when a design gives people an identity (avatars, names, colors), shows what they're doing right now (cursors, typing dots, moving snakes), and lets their actions affect yours. Small signals like hearts or "joined" messages make a space feel alive.

### Round 1 testing (11-08 – 11-09)
- **Figma Ask/Answer app (Quin, 5 testers):** everyone liked the simple look and colors, but navigation was the big problem. "Type here" sent people back to the home screen, and the answer page was cluttered.
- **First team alarm (Sicily, tested with family using a high school baseball team as the example):** people felt the pressure of not wanting to let teammates down ("if everyone else is awake and I'm not I feel left behind"). Testers split on whether snoozing should be allowed. The avatar circles took a moment to understand.

### Round 2 testing (11-16)
- **Navigation is much better.** Nobody got lost during setup.
- **Everyone liked the visuals:** the 3D clock, the dark look, and the movement.
- **The "flash" wake-up is the standout feature.** One tester said it solves a real problem: "sometimes people be on dnd."
- **The biggest gap is after the alarm is set.** 3 of 5 testers didn't know whether to tap something or wait.
- **Turning the alarm off needs visible feedback.** One tester thought it hadn't worked.
- **Showing the last person up in red feels like punishment,** even though they're awake.
- **Live multiplayer didn't work in the Apple developer build,** so we moved the test to the web prototype.
- *"I would hate this but it would work lol."*

### Risks and guardrails (11-11)
Our core rule means one person can keep the whole team's alarm ringing, and most of our users are minors. [`team-alarm-risks.md`](team-alarm-risks.md) lists the risks (dead phones, griefing, shaming the last one up, privacy of wake times and rosters) and eight guardrails: a ring cap, an "out tomorrow" excuse, limits on coaches, safe joining, sensors that stay on the phone, minimal data, celebrating instead of shaming, and wake events the server can trust.

## Prototypes

| Prototype | What it is | Where |
|---|---|---|
| **Team Alarm (live)** | The multiplayer web alarm we're testing now | https://sicilyrose4.github.io/team-alarm-tasks/ (code in the `sicilyrose4/team-alarm-tasks` repo) |
| Clique Clock (iPhone) | SwiftUI app with real alarms (AlarmKit), widgets, and a Live Activity | [`clique-clock/`](clique-clock) |
| Quin's variations | Restyled versions in Quin's Figma UI | `quin-alarm/` and branch `quin/clique-clock-ui` |
| Who's the Bot? | Live party game exploring multiplayer | [`app/`](app), https://whos-the-bot.vercel.app |
| Round 1 Figma app | Ask/Answer question app | [Figma](https://www.figma.com/design/u8s8s1ItabKsIxPMgeFgjR/Bring-People-Together?node-id=1-4) |

## Team

- Nathan
- Sicily
- Quin 
- Saj 

## What's in this repo

- `README.md`: this file
- `log.md`: weekly work journal
- `numbers.md`: tally toward 100 people reached and 5 live interactions
- `team/`: one page per team member (role, to-dos, notes)
- `3 multiplayer notes/`: each person's notes on 3 multiplayer apps
- `interviews/`: one file per interview
- `Round 1 testing/`, `Round 2 testing/`: prototype test notes and takeaways
- `Crit notes/`: feedback from class critique
- `Alarm Prototype for 11-11/`: the live link and QR code
- `team-alarm-risks.md`: risks and guardrails
- `analytics/`: usage dashboard, snapshot script, and latest numbers
- `clique-clock/`: the iPhone app code
- `app/`: Who's the Bot?

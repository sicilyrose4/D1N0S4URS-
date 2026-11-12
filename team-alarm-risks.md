# Team Alarm: Risks and Guardrails

2026-11-11 · Nathan

The biggest risk is our core rule: the alarm keeps ringing for everyone until the last person is up, so one person, or one bad actor, controls the whole team's morning. Most of our users are minors, so privacy and bullying risks weigh more than usual.

## 1. The core rule

Every item here can leave a whole team's alarm ringing with no way to stop it.

| Risk | What happens | Guardrail |
| --- | --- | --- |
| One person can't stop it | Phone dead or off, alarm permission denied, sick, injured, traveling, lost phone, family emergency. The team rings forever. | Ring cap (for example 10 min), then quiet nudges. An "Out tomorrow" status, set by the player or coach the night before. |
| Griefing | Someone holds out on purpose to annoy the team, or snoozes forever. | Ring cap. Your own stop always ends your sound; others only get nudges. |
| Offline "I'm up" | Someone stops their alarm but the signal never reaches the server, so the team keeps ringing. | Background retry, a local cap, and the server times out stale players. |
| Out-of-sync schedules | The coach changes the time late at night and some phones never get it. Some ring, some don't. | Changes need notice (for example 8 hours) and a confirmed sync; otherwise the old time stays. |
| Edge cases | Away-trip time zones, daylight saving, two teams the same morning. | Store times in the team's time zone; one alarm per morning wins. |
| Household harm | Wakes roommates, siblings, parents, a newborn. | Vibrate-only option; the ring cap. |
| Health | Sleep loss, insomnia, medical conditions, disabilities (deaf players, wheelchair users). | Accessible stop options; the coach can excuse players privately. |

## 2. The base app (no sensors)

Even without sensors, wake times and rosters of minors are sensitive data.

| Type | Risk |
| --- | --- |
| Data leak | Wake times show a minor's daily routine: when the home is asleep or empty. |
| Data leak | The roster exposes minors' full names, faces and team. |
| Data leak | Lock screen previews and the Live Activity show teammates' names to anyone holding the phone. |
| Data leak | Wake history is close to health data; keeping it forever makes a breach worse. |
| Hack | Guessable 6-character join codes let a stranger into a team of minors; codes also spread in screenshots. |
| Hack | Impersonation: anyone can type any name. |
| Hack | A modified app fakes "I'm up" or marks someone else asleep. |
| Hack | A fake "coach" sets 3 AM alarms to harass people. |
| Bullying | "Last up" in red plus coach punishments ("last up runs laps") becomes public shaming or hazing. In Sicily's testing, players already said they felt "pressured" and "left behind". |
| Bullying | Screenshots of the list get posted to mock the late person. |
| Bullying | Snoozes are visible to everyone, labeling a struggling teammate. |
| Bullying | A controlling coach uses constant time changes and punishment rules. |
| Legal | COPPA (under 13 needs parent consent), FERPA and state student privacy laws if run through a school, adult-to-minor contact rules for coaches, App Store data rules. Not legal advice. |

## 3. If we add sensors to prove you're out of bed

These are out of scope for now. If we add any, the check runs on the phone and only "up: yes or no" ever leaves it.

| Add-on | How people cheat | What can go wrong |
| --- | --- | --- |
| Motion (steps, accelerometer) | Shake the phone in bed. A real early riser who leaves the phone on the nightstand is counted as asleep. | Motion data shows sleep quality and activity in bed, which is very sensitive. Shuts out wheelchair users and injured players. Battery drain. |
| Photo proof (selfie or bathroom sink) | An old photo, a photo of a photo, a friend's photo. | The worst one: photos of minors in bedrooms or pajamas reaching a team or adult coach is a child safety disaster. Rooms reveal home details. Face matching triggers biometric laws (Illinois BIPA). |
| Location (left the bedroom, arrived at the gym) | GPS spoofing apps; indoor GPS can't tell the bed from the kitchen. | The team or coach sees a minor's exact home, enabling stalking and abuse. Builds location history. "Always" location gets extra App Store review. |
| Apple Watch / HealthKit sleep | Take the watch off. | Health data under strict Apple rules. Unfair to players without a watch. |

## 4. Guardrails to build in

Eight design rules cover most of the risks above.

- [ ] **Ring cap:** the team ring stops after X minutes and falls back to nudges.
- [ ] **Out tomorrow:** players or the coach mark someone excused the night before.
- [ ] **Coach limits:** alarms only in a time window (for example 4 to 9 AM), notice before changes, players can mute or leave anytime.
- [ ] **Safe joining:** the coach approves joins, codes expire, guessing is rate-limited.
- [ ] **Sensors stay on the phone:** only "up: yes or no" is shared, never photos, coordinates or motion logs.
- [ ] **Minimal data:** initials and wake time only, hidden lock screen previews, history deleted after the season.
- [ ] **Celebrate first, don't shame last:** leaderboards and punishments are opt-in.
- [ ] **Trusted wake events:** only the server marks someone awake, from a signed-in phone.

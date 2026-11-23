# Quin's Alarm (copy of the 11-11 Team Alarm prototype)

Quin's own copy to redesign (UI and user flow). The original is Sicily's
[`sicilyrose4/team-alarm-tasks`](https://github.com/sicilyrose4/team-alarm-tasks)
(copied from commit `2a02320`, live at https://sicilyrose4.github.io/team-alarm-tasks/).
Editing this folder does not change the original.

Changes from the original, so the two stay separate:
- Multiplayer channel is `quin-alarm-v1/<team>` (original: `team-alarm-v2/<team>`), default team `quin-test`.
- Analytics are turned off (`TRACK = false`), so testing never adds to the team's numbers.
- Browser storage keys renamed (`quin-alarm-v1`, `qa-fresh`).
- `stats.html` was not copied.

## Quin's UI (11-23)

Restyled with the UI system from Quin's Figma frames "1/wake up screen" and "1/alarm demo"
(file "Bring People Together"): charcoal and bright green, Basketball + Gotham type
(`fonts/`, school-project use), square blocks with a green stripe, and a pulsing WAKE UP
screen with green ripples. The screens and flow are still the original prototype's.

## Try it

- Shared link: https://claude.ai/artifact/NwamAD4BcDYgGWD9B9wq7a. There, teammates sync through the
  artifact's own shared storage, since Claude artifact pages block outside servers.
- Locally: open `index.html` in a browser (two windows to see multiplayer). This uses the
  public MQTT brokers.

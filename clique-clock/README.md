# Clique Clock

The SwiftUI iPhone app behind the TestFlight builds. This is the code for build 5 (team ring).

## Run it

1. You need a Mac with Xcode 26.1 or newer.
2. Open `TeamAlarm.xcodeproj`.
3. Pick an iPhone simulator at the top and press Run (Cmd+R).
4. On the join screen, use the code `IXD415` to join the demo team.

The simulator needs no Apple account setup. To run on your own iPhone, select the TeamAlarm target, open Signing & Capabilities, and pick your own team. Real alarms (AlarmKit) only ring on a real phone; the simulator falls back to notifications.

## This branch: Quin's 2D version

Everything is 2D (no 3D models needed). The look comes from Quin's Figma frames "1/wake up screen" and "1/alarm demo": dark charcoal, bright green, Basketball and Gotham type.

- When the alarm rings, a full-screen WAKE UP pulses with rings rippling out. Tap anywhere to stop it.
- The home screen has a grey dial where teammates land as green shields when they wake. Under it is one bar per teammate: green is up, dark green is snoozing, red is still asleep, grey means the alarm hasn't rung yet.
- The fonts are in `Shared/Fonts/` (school project use only).
- There's also a web version you can try in a browser: open `web/clique-clock.html`, or use the link Quin shares.

## Making your own version

1. Make a branch: `git checkout -b yourname/idea`
2. Change things and run them in the simulator.
3. Push your branch and open a pull request so the group can look.

Nathan uploads the versions the group picks to TestFlight.

## Where things are

- `Shared/Theme.swift`: colors, fonts, buttons and the ripple rings
- `TeamAlarm/Stopwatch/AlarmHome.swift`: the home screen, dial, team bars, and WAKE UP screen
- `TeamAlarm/Onboarding.swift`: name, join team, notifications
- `TeamAlarm/TeamsTab.swift`, `TeamAlarm/SettingsTab.swift`: Teams and Settings sheets
- `TeamAlarm/AppState.swift`: app data and the AlarmKit alarm
- `TeamAlarmWidgets/`: Home Screen widget and Live Activity
- `Shared/`: models used by both the app and the widgets

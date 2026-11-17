# Clique Clock

The SwiftUI iPhone app behind the TestFlight builds. This is the code for build 5 (team ring).

## Run it

1. You need a Mac with Xcode 26.1 or newer.
2. Open `TeamAlarm.xcodeproj`.
3. Pick an iPhone simulator at the top and press Run (Cmd+R).
4. On the join screen, use the code `IXD415` to join the demo team.

The simulator needs no Apple account setup. To run on your own iPhone, select the TeamAlarm target, open Signing & Capabilities, and pick your own team. Real alarms (AlarmKit) only ring on a real phone; the simulator falls back to notifications.

## Not included

The two 3D models (`Stopwatch.usdz` and `Onboarding.usdz`, about 50MB) are left out to keep the repo light. The app still builds and runs without them, but the 3D stopwatch and onboarding objects won't show. Ask Nathan for the files and drop them into `TeamAlarm/Stopwatch/` and `TeamAlarm/Onboarding3D/`.

## Making your own version

1. Make a branch: `git checkout -b yourname/idea`
2. Change things and run them in the simulator.
3. Push your branch and open a pull request so the group can look.

Nathan uploads the versions the group picks to TestFlight.

## Where things are

- `TeamAlarm/Stopwatch/AlarmHome.swift`: the home screen, alarm picker, and team ring
- `TeamAlarm/Onboarding.swift`: name, join team, notifications
- `TeamAlarm/TeamsTab.swift`, `TeamAlarm/SettingsTab.swift`: Teams and Settings sheets
- `TeamAlarm/AppState.swift`: app data and the AlarmKit alarm
- `TeamAlarmWidgets/`: Home Screen widget and Live Activity
- `Shared/`: models used by both the app and the widgets

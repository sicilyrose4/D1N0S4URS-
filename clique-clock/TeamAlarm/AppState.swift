import SwiftUI
import AlarmKit
import ActivityKit
import UserNotifications
import WidgetKit
import AppIntents

struct TeamAlarmMeta: AlarmMetadata {
    var team: String
}

extension Notification.Name { static let ringNow = Notification.Name("ringNow") }

/// Runs when you slide the alarm off: logs the exact second you stopped it, then opens the app already marked up.
struct WakeUpIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Wake Up"
    static let openAppWhenRun = true
    func perform() async throws -> some IntentResult {
        let now = Date.now.timeIntervalSince1970
        await MainActor.run {
            UserDefaults.standard.set(now, forKey: "wokeAt")
            UserDefaults.standard.set(true, forKey: "pendingRing")
            NotificationCenter.default.post(name: .ringNow, object: nil)
        }
        return .result()
    }
}

@MainActor @Observable
final class AppState {
    var onboarded: Bool { didSet { UserDefaults.standard.set(onboarded, forKey: "onboarded") } }
    var first: String { didSet { UserDefaults.standard.set(first, forKey: "first") } }
    var last: String { didSet { UserDefaults.standard.set(last, forKey: "last") } }
    /// Your profile photo, saved on the phone; shows in Settings, the team list and your 3D chip.
    var photo: UIImage? { didSet { try? photo?.jpegData(compressionQuality: 0.85)?.write(to: Self.photoURL); if photo == nil { try? FileManager.default.removeItem(at: Self.photoURL) } } }
    static let photoURL = URL.documentsDirectory.appending(path: "profile.jpg")
    var teams: [Team] { didSet { save() } }     // saved on device; no database in the prototype
    /// Your own real alarm (prototype): the tester picks the time.
    var myAlarm: Date? { didSet { SharedStore.defaults.set(myAlarm?.timeIntervalSince1970, forKey: "myAlarm") } }
    var alarmsAllowed = false
    var lastError: String?
    @ObservationIgnored private var activity: Activity<TeamWakeAttributes>?

    init() {
        let d = UserDefaults.standard
        onboarded = d.bool(forKey: "onboarded")
        first = d.string(forKey: "first") ?? ""
        last = d.string(forKey: "last") ?? ""
        photo = UIImage(contentsOfFile: Self.photoURL.path())
        teams = (d.data(forKey: "teams")).flatMap { try? JSONDecoder().decode([Team].self, from: $0) } ?? []
        myAlarm = (SharedStore.defaults.object(forKey: "myAlarm") as? Double).map(Date.init(timeIntervalSince1970:))
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(teams), forKey: "teams")
        SharedStore.defaults.set(teams.first?.name, forKey: "team")
    }

    // MARK: Prototype team

    static let demoCode = "IXD415"

    /// Everyone in the TestFlight prototype joins the same team. Teammates are fake and wake on a schedule.
    static let demoTeam = Team(id: "ixd415", name: "IXD Demo", symbol: "basketball.fill", hour: 7, minute: 0, days: [],
                               coach: "Coach Wituk", rule: "Last up runs 2 laps", members: Array(Demo.members.prefix(8)),
                               practiceHour: 8, practiceMinute: 0)

    var initials: String {
        let i = "\(first.prefix(1))\(last.prefix(1))".uppercased()
        return i.isEmpty ? "ME" : i
    }
    var nextAlarm: (team: Team, date: Date)? { Demo.nextAlarm(teams) }

    // MARK: Teams

    func leave(_ team: Team) {
        teams.removeAll { $0.id == team.id }
        if let id = alarmID(team) { try? AlarmManager.shared.cancel(id: id) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: team.days.map { "\(team.id)-\($0)" })
    }

    /// Coach onboarding: make the team, return its 6-character join code.
    func createTeam(name: String, symbol: String, wake: (h: Int, m: Int), practice: (h: Int, m: Int), days: [Int]) -> String {
        let code = String((0..<6).map { _ in "ABCDEFGHJKMNPQRSTUVWXYZ23456789".randomElement()! })
        let coach = last.isEmpty ? "Coach" : "Coach \(last)"
        teams.insert(Team(id: code.lowercased(), name: name, symbol: symbol, hour: wake.h, minute: wake.m, days: days,
                          coach: coach, rule: "Last up runs 2 laps", members: Array(Demo.members.prefix(8)),
                          practiceHour: practice.h, practiceMinute: practice.m), at: 0)
        UserDefaults.standard.set(true, forKey: "coachMode")
        Task { await scheduleAlarms() }
        return code
    }

    func join(code: String) -> Bool {
        guard code.count == 6 else { return false }
        if code.uppercased() == Self.demoCode {
            if !teams.contains(where: { $0.id == Self.demoTeam.id }) { teams.insert(Self.demoTeam, at: 0) }
            return true
        }
        return false   // ponytail: only the prototype code works until there's a backend
    }

    // MARK: Permissions + AlarmKit

    func requestPermissions() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        do {
            alarmsAllowed = try await AlarmManager.shared.requestAuthorization() == .authorized
        } catch {
            lastError = "Alarms unavailable: \(error.localizedDescription)"
        }
        await scheduleAlarms()
    }

    private func alarmID(_ team: Team) -> UUID? {
        // Stable per team so leaving can cancel it. Team ids are at most 6 ASCII chars.
        let hex = team.id.utf8.prefix(6).map { String(format: "%02x", $0) }.joined()
        return UUID(uuidString: "00000000-0000-0000-0000-" + String(repeating: "0", count: 12 - hex.count) + hex)
    }

    private func attributes(_ title: String) -> AlarmAttributes<TeamAlarmMeta> {
        AlarmAttributes(presentation: AlarmPresentation(alert: .init(title: LocalizedStringResource(stringLiteral: title))),
                        metadata: TeamAlarmMeta(team: title), tintColor: .green)
    }

    /// Each team's coach-set alarm, repeating on its days.
    /// AlarmKit is denied in the simulator, so fall back to repeating notifications there.
    func scheduleAlarms() async {
        guard !UserDefaults.standard.bool(forKey: "coachMode") else { return }   // coaches aren't woken
        guard AlarmManager.shared.authorizationState == .authorized else { scheduleNotificationAlarms(); return }
        for team in teams where !team.days.isEmpty {
            guard let id = alarmID(team) else { continue }
            let days = team.days.compactMap { Locale.Weekday.from(calendarWeekday: $0) }
            let schedule = Alarm.Schedule.relative(.init(time: .init(hour: team.hour, minute: team.minute), repeats: .weekly(days)))
            do {
                _ = try await AlarmManager.shared.schedule(id: id, configuration: .alarm(schedule: schedule, attributes: attributes(team.name)))
            } catch {
                lastError = "Couldn't set \(team.name) alarm: \(error.localizedDescription)"
            }
        }
    }

    private func scheduleNotificationAlarms() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for team in teams where !team.days.isEmpty {
            for day in team.days {
                let c = UNMutableNotificationContent()
                c.title = team.name
                c.body = "Time to get up. Your team can see who's awake."
                c.sound = .defaultCritical
                c.interruptionLevel = .timeSensitive
                let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: team.hour, minute: team.minute, weekday: day), repeats: true)
                center.add(UNNotificationRequest(identifier: "\(team.id)-\(day)", content: c, trigger: trigger))
            }
        }
    }

    // MARK: Your alarm (prototype)

    static let myAlarmID = UUID(uuidString: "00000000-0000-0000-0000-00000000a1a7")!

    /// The ringing screen: just Stop. Stopping logs your wake second and opens the app, already marked up.
    private var wakeAttributes: AlarmAttributes<TeamAlarmMeta> {
        let team = teams.first?.name ?? "Team Alarm"
        // Only the system slide to stop: no second button
        let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: team),
                                            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill"))
        return AlarmAttributes(presentation: AlarmPresentation(alert: alert), metadata: TeamAlarmMeta(team: team), tintColor: .orange)
    }

    /// Set your own real alarm. `inOneMinute` rings 60 s from now for a quick test.
    func setMyAlarm(_ date: Date, inOneMinute: Bool = false) async {
        if AlarmManager.shared.authorizationState == .notDetermined { await requestPermissions() }
        let fire = inOneMinute ? Date.now.addingTimeInterval(60) : nextOccurrence(of: date)
        try? AlarmManager.shared.cancel(id: Self.myAlarmID)
        do {
            _ = try await AlarmManager.shared.schedule(id: Self.myAlarmID, configuration: .alarm(
                schedule: .fixed(fire), attributes: wakeAttributes, stopIntent: WakeUpIntent()))
        } catch {   // simulator: AlarmKit is denied, so a notification stands in; tapping it opens the wake-up
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["my-alarm"])
            let c = UNMutableNotificationContent()
            c.title = teams.first?.name ?? "Team Alarm"
            c.body = "Time to get up. Your team can see who's awake."
            c.sound = .defaultCritical
            c.interruptionLevel = .timeSensitive
            c.userInfo = ["ring": true]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fire.timeIntervalSinceNow), repeats: false)
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "my-alarm", content: c, trigger: trigger))
        }
        myAlarm = fire
        WidgetCenter.shared.reloadAllTimelines()
    }

    func clearMyAlarm() {
        try? AlarmManager.shared.cancel(id: Self.myAlarmID)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["my-alarm"])
        myAlarm = nil
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func nextOccurrence(of time: Date) -> Date {
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Calendar.current.nextDate(after: .now, matching: c, matchingPolicy: .nextTime) ?? time
    }

    /// A system alarm in one minute, or a notification where AlarmKit isn't allowed (the simulator).
    func testAlarm() async {
        if AlarmManager.shared.authorizationState == .notDetermined { await requestPermissions() }
        do {
            _ = try await AlarmManager.shared.schedule(id: UUID(), configuration: .alarm(schedule: .fixed(.now.addingTimeInterval(60)), attributes: attributes("Test alarm")))
            lastError = "System alarm set for 1 minute from now."
        } catch {
            notify("Test alarm", "Time to get up.", after: 60)
            lastError = "AlarmKit isn't available here, so a notification will fire in 1 minute instead."
        }
    }

    func notify(_ title: String, _ body: String, after seconds: TimeInterval = 1) {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: Live Activity (driven by the stopwatch wake-up)

    func startActivity(team: Team, state: TeamWakeAttributes.ContentState) {
        let old = activity // capture now; the Task runs after `activity` is replaced below
        Task { await old?.end(nil, dismissalPolicy: .immediate) }
        activity = try? Activity.request(attributes: TeamWakeAttributes(team: team.name, alarm: team.timeText),
                                         content: .init(state: state, staleDate: nil))
    }

    func updateActivity(_ state: TeamWakeAttributes.ContentState) {
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity?.update(content) }
    }

    func finishWake(_ state: TeamWakeAttributes.ContentState, lastLine: String) {
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity?.end(content, dismissalPolicy: .after(.now.addingTimeInterval(60 * 15))) }
        notify("Everyone's up", "\(lastLine) \(nextAlarm?.team.rule ?? "")")
    }
}

extension Locale.Weekday {
    static func from(calendarWeekday d: Int) -> Locale.Weekday? {
        [1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday, 5: .thursday, 6: .friday, 7: .saturday][d]
    }
}

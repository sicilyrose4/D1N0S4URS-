import Foundation
import ActivityKit

// Shared by the app and the widget extension.

/// App Group storage the widget can read: your alarm time and team name.
enum SharedStore {
    static let group = "group.edu.ixd415.TeamAlarm"
    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }
}

struct Team: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var symbol: String
    var hour: Int
    var minute: Int
    var days: [Int]          // Calendar weekdays, 1 = Sunday
    var coach: String
    var rule: String         // the coach's incentive or punishment
    var members: [Member]
    var practiceHour = 6     // coach sets practice time separately from the wake-up alarm
    var practiceMinute = 0

    var timeText: String { Team.format(hour: hour, minute: minute) }
    var practiceText: String { Team.format(hour: practiceHour, minute: practiceMinute) }
    var daysText: String {
        let names = Calendar.current.shortWeekdaySymbols
        return days.map { names[$0 - 1] }.joined(separator: ", ")
    }

    static func format(hour: Int, minute: Int) -> String {
        "\(hour % 12 == 0 ? 12 : hour % 12):\(String(format: "%02d", minute)) \(hour < 12 ? "AM" : "PM")"
    }

    /// Next time this team's alarm rings, from `now`.
    func nextDate(after now: Date = .now) -> Date? {
        days.compactMap { day in
            Calendar.current.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute, weekday: day), matchingPolicy: .nextTime)
        }.min()
    }
}

struct Member: Identifiable, Hashable, Codable {
    let id: String
    var first: String
    var last: String
    var initials: String { "\(first.prefix(1))\(last.prefix(1))".uppercased() }
}

enum Demo {
    static let members: [Member] = [
        ("Maya", "Kim"), ("Jordan", "Lee"), ("Devon", "Brooks"), ("Emma", "Hall"), ("Avery", "Ross"),
        ("Sam", "Park"), ("Grace", "King"), ("Leo", "Reyes"), ("Olivia", "Vance"), ("Quinn", "Young"), ("Taylor", "Cruz"),
    ].map { Member(id: "\($0)\($1)".lowercased(), first: $0, last: $1) }

    static let teams: [Team] = [
        Team(id: "bball", name: "Basketball", symbol: "basketball.fill", hour: 5, minute: 0, days: [2, 4, 6],
             coach: "Coach Rivera", rule: "Last up runs 2 laps", members: members, practiceHour: 6, practiceMinute: 0),
        Team(id: "fball", name: "Football", symbol: "football.fill", hour: 5, minute: 30, days: [3, 5],
             coach: "Coach Grant", rule: "Last up carries the water", members: Array(members.prefix(8)), practiceHour: 6, practiceMinute: 30),
    ]

    /// The soonest alarm across teams.
    static func nextAlarm(_ teams: [Team], now: Date = .now) -> (team: Team, date: Date)? {
        teams.compactMap { t in t.nextDate(after: now).map { (t, $0) } }.min { $0.1 < $1.1 }
    }
}

/// Live Activity while a team is waking up.
struct TeamWakeAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var up: Int
        var total: Int
        var waiting: [String]   // initials still asleep
        var firstUp: String?
    }
    var team: String
    var alarm: String
}

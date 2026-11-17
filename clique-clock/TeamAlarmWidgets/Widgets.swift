import WidgetKit
import SwiftUI
import ActivityKit

@main
struct TeamAlarmWidgets: WidgetBundle {
    var body: some Widget {
        NextAlarmWidget()
        TeamWakeLiveActivity()
    }
}

// MARK: - Next alarm (Home + Lock Screen)

struct NextAlarmEntry: TimelineEntry {
    let date: Date
    let team: String
    let time: String
    let when: Date
}

struct NextAlarmProvider: TimelineProvider {
    /// Your alarm and team, written by the app into the shared App Group.
    private func entry(at now: Date = .now) -> NextAlarmEntry {
        let d = SharedStore.defaults
        let when = (d.object(forKey: "myAlarm") as? Double).map(Date.init(timeIntervalSince1970:)).flatMap { $0 > now ? $0 : nil }
        return NextAlarmEntry(date: now, team: d.string(forKey: "team") ?? "Team Alarm",
                              time: when?.formatted(date: .omitted, time: .shortened) ?? "No alarm", when: when ?? now)
    }
    func placeholder(in context: Context) -> NextAlarmEntry { NextAlarmEntry(date: .now, team: "IXD Demo", time: "7:00 AM", when: .now) }
    func getSnapshot(in context: Context, completion: @escaping (NextAlarmEntry) -> Void) { completion(context.isPreview ? placeholder(in: context) : entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextAlarmEntry>) -> Void) {
        let e = entry()
        completion(Timeline(entries: [e], policy: e.when > e.date ? .after(e.when.addingTimeInterval(60)) : .never))
    }
}

struct NextAlarmView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextAlarmEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "alarm.fill").font(.caption)
                Text(entry.time.replacingOccurrences(of: " AM", with: "").replacingOccurrences(of: " PM", with: ""))
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Label(entry.team, systemImage: "alarm.fill").font(.caption)
                Text(entry.time).font(.system(.title2, design: .rounded).weight(.semibold))
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "alarm.fill").foregroundStyle(.orange)
                    Spacer()
                }
                Spacer()
                Text(entry.time).font(.system(size: 30, weight: .light, design: .rounded)).minimumScaleFactor(0.7)
                Text(entry.team).font(.subheadline.weight(.semibold))
                if entry.when > entry.date { Text(entry.when, style: .relative).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

struct NextAlarmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextAlarm", provider: NextAlarmProvider()) { entry in
            NextAlarmView(entry: entry).containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Next Alarm")
        .description("Your next alarm and team.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Live Activity while the team wakes up

private struct Initials: View {
    let text: String
    var up = false
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(up ? .green : .secondary)
            .frame(width: 26, height: 26)
            .background(up ? Color.green.opacity(0.2) : Color(white: 0.22), in: .circle)
    }
}

private struct Progress: View {
    let state: TeamWakeAttributes.ContentState
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.25))
                Capsule().fill(.green).frame(width: g.size.width * CGFloat(state.up) / CGFloat(max(1, state.total)))
            }
        }
        .frame(height: 6)
    }
}

struct TeamWakeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TeamWakeAttributes.self) { ctx in
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("\(ctx.attributes.team) · \(ctx.attributes.alarm)", systemImage: "alarm.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(ctx.state.up == ctx.state.total ? "Everyone's up" : "\(ctx.state.up) of \(ctx.state.total) up")
                        .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
                Progress(state: ctx.state)
                HStack(spacing: -6) {
                    ForEach(ctx.state.waiting.prefix(9), id: \.self) { Initials(text: $0) }
                    if ctx.state.waiting.count > 9 { Text("+\(ctx.state.waiting.count - 9)").font(.caption).padding(.leading, 10) }
                }
            }
            .padding(16)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(ctx.attributes.team, systemImage: "alarm.fill").font(.subheadline.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(ctx.state.up)/\(ctx.state.total)").font(.title3.monospacedDigit().weight(.semibold)).foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Progress(state: ctx.state)
                        HStack(spacing: -6) { ForEach(ctx.state.waiting.prefix(8), id: \.self) { Initials(text: $0) } }
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill").foregroundStyle(.green)
            } compactTrailing: {
                Text("\(ctx.state.up)/\(ctx.state.total)").monospacedDigit().foregroundStyle(.green)
            } minimal: {
                Text("\(ctx.state.up)").monospacedDigit().foregroundStyle(.green)
            }
        }
    }
}

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
                    .font(.display(20))
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Label(entry.team, systemImage: "alarm.fill").font(.caption)
                Text(entry.time).font(.display(26))
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "alarm.fill").foregroundStyle(Clique.green)
                    Spacer()
                }
                Spacer()
                Text(entry.time).font(.display(38)).foregroundStyle(Clique.green).minimumScaleFactor(0.6).lineLimit(1)
                Text(entry.team).font(.gothamBold(14))
                if entry.when > entry.date { Text(entry.when, style: .relative).font(.gotham(12)).foregroundStyle(.white.opacity(0.6)) }
            }
        }
    }
}

struct NextAlarmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextAlarm", provider: NextAlarmProvider()) { entry in
            NextAlarmView(entry: entry).containerBackground(Clique.ink, for: .widget)
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
            .font(.gothamBold(10))
            .foregroundStyle(up ? Clique.ink : .white.opacity(0.7))
            .frame(width: 26, height: 26)
            .background(up ? Clique.green : Clique.panel, in: .circle)
            .overlay(Circle().stroke(Clique.ink, lineWidth: 1.5))
    }
}

private struct Progress: View {
    let state: TeamWakeAttributes.ContentState
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(Clique.panel)
                Rectangle().fill(Clique.green).frame(width: g.size.width * CGFloat(state.up) / CGFloat(max(1, state.total)))
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
                        .font(.gothamBold(15))
                    Spacer()
                    Text(ctx.state.up == ctx.state.total ? "Everyone's up" : "\(ctx.state.up) of \(ctx.state.total) up")
                        .font(.display(22)).monospacedDigit().foregroundStyle(Clique.green)
                }
                Progress(state: ctx.state)
                HStack(spacing: -6) {
                    ForEach(ctx.state.waiting.prefix(9), id: \.self) { Initials(text: $0) }
                    if ctx.state.waiting.count > 9 { Text("+\(ctx.state.waiting.count - 9)").font(.caption).padding(.leading, 10) }
                }
            }
            .padding(16)
            .activityBackgroundTint(Clique.ink)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(ctx.attributes.team, systemImage: "alarm.fill").font(.subheadline.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(ctx.state.up)/\(ctx.state.total)").font(.display(26)).monospacedDigit().foregroundStyle(Clique.green)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Progress(state: ctx.state)
                        HStack(spacing: -6) { ForEach(ctx.state.waiting.prefix(8), id: \.self) { Initials(text: $0) } }
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill").foregroundStyle(Clique.green)
            } compactTrailing: {
                Text("\(ctx.state.up)/\(ctx.state.total)").font(.display(17)).monospacedDigit().foregroundStyle(Clique.green)
            } minimal: {
                Text("\(ctx.state.up)").font(.display(17)).monospacedDigit().foregroundStyle(Clique.green)
            }
        }
    }
}

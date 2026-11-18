import SwiftUI
import AVFoundation

// The alarm home screen, 2D. A dial at the top where teammates land as they wake,
// the big time, then one status bar per teammate. When the alarm rings, the full-screen
// WAKE UP takes over; tap anywhere to stop it. Teams and Settings open as sheets from the top corners.

struct Mate: Identifiable {
    let id: String
    let initials: String
    let name: String
    let wakeAt: Double?          // nil = you, woken by tapping the wake-up screen
    var snoozeAt: Double? = nil
    var photo: UIImage? = nil
    var isYou: Bool { wakeAt == nil }
}

enum MateStatus { case waiting, asleep, snoozing, up }

// ponytail: demo wake schedule (seconds after the alarm), swap for live teammate data when there is a backend
let demoSchedule: [(wake: Double, snooze: Double?)] = [(3.4, nil), (8.2, nil), (14.6, nil), (21.1, nil), (27.9, nil),
    (33.5, 11), (40.3, nil), (47.6, nil), (52.2, nil), (55.8, 30), (58.9, nil)]

/// `angle` is where the teammate's badge rests on the dial, in degrees from 12 o'clock.
struct Wake: Identifiable { let id: String; let rank: Int; let at: Double; let angle: Double }

func secondsToday(_ d: Date) -> Int {
    let c = Calendar.current.dateComponents([.hour, .minute, .second], from: d)
    return c.hour! * 3600 + c.minute! * 60 + c.second!
}

@MainActor @Observable final class Session {
    enum Phase { case idle, ringing, stopped }
    var phase = Phase.idle
    var team = Demo.teams[0]
    var mates: [Mate] = []
    var start: Date?
    var wakes: [Wake] = []
    var stoppedAt: Double?                       // when you tapped the wake-up screen
    var t: Double = 0                            // elapsed, refreshed by tick() so views update
    var elapsed: Double { start.map { Date().timeIntervalSince($0) } ?? 0 }
    var allUp: Bool { !mates.isEmpty && wakes.count == mates.count }
    var isCoach = false
    var alarmClock: Double = 0   // time of day the wake-up started (the real alarm, or Demo)
    @ObservationIgnored weak var app: AppState?   // feeds the Live Activity

    var activityState: TeamWakeAttributes.ContentState {
        .init(up: wakes.count, total: mates.count,
              waiting: mates.filter { wake(of: $0.id) == nil }.map(\.initials),
              firstUp: wakes.first.flatMap { w in mates.first { $0.id == w.id }?.initials })
    }

    /// Load the next team, everyone asleep. Safe to call again while idle (after Teams edits).
    func prepare(_ app: AppState) {
        guard phase == .idle else { return }
        self.app = app
        team = app.teams.first ?? AppState.demoTeam
        let you = Mate(id: "you", initials: app.initials, name: "\(app.first) \(app.last)".trimmingCharacters(in: .whitespaces), wakeAt: nil, photo: app.photo)
        isCoach = UserDefaults.standard.bool(forKey: "coachMode")
        mates = (isCoach ? [] : [you]) + zip(team.members, demoSchedule).map { m, s in   // a coach watches, isn't woken
            Mate(id: m.id, initials: m.initials, name: "\(m.first) \(m.last)", wakeAt: s.wake, snoozeAt: s.snooze)
        }
    }
    /// Start the team wake-up. With `youWokeAt` (the second you stopped the real alarm) you open already up.
    func ring(_ app: AppState, startedAt: Date = .now, youWokeAt: Date? = nil) {
        phase = .idle; prepare(app); wakes = []; stoppedAt = nil; start = startedAt; t = elapsed; phase = .ringing
        alarmClock = Double(secondsToday(startedAt))
        if let you = youWokeAt {
            let yt = max(0, you.timeIntervalSince(startedAt))
            for m in mates.filter({ ($0.wakeAt ?? .infinity) < yt }).sorted(by: { $0.wakeAt! < $1.wakeAt! }) { wake(m.id, at: m.wakeAt!) }
            wake("you", at: yt)
            stoppedAt = yt
            phase = .stopped
        }
        app.startActivity(team: team, state: activityState)
        if !isCoach && !allUp { TeamRinger.start() }   // the team rule: keeps ringing until the last one is up
    }
    func stop() { stoppedAt = elapsed; phase = .stopped; wake("you") }
    func reset(_ app: AppState) { TeamRinger.stop(); phase = .idle; start = nil; wakes = []; stoppedAt = nil; t = 0; prepare(app) }

    /// Called ~10x a second: advances the clock and wakes teammates on their demo schedule.
    func tick() {
        guard phase != .idle else { return }
        t = elapsed
        for m in mates { if let w = m.wakeAt, t >= w { wake(m.id) } }
    }

    func wake(_ id: String, at time: Double? = nil) {
        guard !wakes.contains(where: { $0.id == id }) else { return }
        let at = time ?? elapsed
        wakes.append(Wake(id: id, rank: wakes.count + 1, at: at, angle: restAngle(at)))
        if allUp { TeamRinger.stop() }
        if isCoach && allUp && phase == .ringing { stoppedAt = elapsed; phase = .stopped }   // coach view: done when the team is
        if allUp, let last = mates.first(where: { $0.id == id }) {
            app?.finishWake(activityState, lastLine: last.isYou ? "You were last." : "\(last.name) was last.")
        } else {
            app?.updateActivity(activityState)
        }
    }
    func wake(of id: String) -> Wake? { wakes.first { $0.id == id } }

    func status(_ m: Mate) -> MateStatus {
        if wake(of: m.id) != nil { return .up }
        if phase == .idle { return .waiting }
        if let s = m.snoozeAt, t >= s { return .snoozing }
        return .asleep
    }

    /// Where the second hand was when they woke, nudged so badges never overlap.
    private func restAngle(_ at: Double) -> Double {
        var a = (at.truncatingRemainder(dividingBy: 60)) / 60 * 360 + 6
        let gap = 17.0
        while wakes.contains(where: { abs(remainder($0.angle - a, 360)) < gap }) { a += gap }
        return a
    }
}

/// Looping in-app alarm sound, plays through the silent switch.
/// ponytail: foreground only (no background audio mode); the real version re-fires AlarmKit alarms from a server.
@MainActor enum TeamRinger {
    private static var player: AVAudioPlayer?
    static func start() {
        guard player == nil, let url = Bundle.main.url(forResource: "teamring", withExtension: "wav") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.play()
    }
    static func stop() { player?.stop(); player = nil }
}

// MARK: - UI

struct AlarmHome: View {
    @Environment(AppState.self) private var app
    @State private var session = Session()
    @State private var sheet: Corner?
    @State private var alarmSheet = false
    @Environment(\.scenePhase) private var scenePhase

    /// The real alarm's Stop / Wake Up (or the stand-in notification) asked to start the team wake-up.
    private func ringIfPending() {
        let d = UserDefaults.standard
        guard d.bool(forKey: "pendingRing") else { return }
        d.set(false, forKey: "pendingRing")
        let woke = (d.object(forKey: "wokeAt") as? Double).map(Date.init(timeIntervalSince1970:))
        let rang = app.myAlarm.flatMap { $0 <= (woke ?? .now) ? $0 : nil } ?? woke ?? .now
        app.myAlarm = nil
        withAnimation(.smooth) { session.ring(app, startedAt: rang, youWokeAt: woke) }
    }
    enum Corner: String, Identifiable { case teams, settings; var id: String { rawValue } }

    private var showWakeUp: Bool { session.phase == .ringing && !session.isCoach }

    var body: some View {
        ZStack(alignment: .top) {
            Clique.panel.ignoresSafeArea()
            Dial(session: session)
                .padding(.top, 54)
                .ignoresSafeArea(edges: .top)
            VStack(spacing: 0) {
                Color.clear.frame(height: 224 - 54)   // panel starts across the dial's middle
                panel
            }
            .ignoresSafeArea(edges: .top)
            .padding(.top, 54)

            if showWakeUp {
                WakeUpScreen(team: session.team.name) { withAnimation(.smooth(duration: 0.5)) { session.stop() } }
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 1.15))))
                    .zIndex(1)
            }
        }
        .overlay(alignment: .top) {  // Teams top left, Settings top right
            if !showWakeUp {
                HStack {
                    CornerButton(symbol: "person.2.fill", label: "Teams") { sheet = .teams }
                    Spacer()
                    CornerButton(symbol: "gearshape.fill", label: "Settings") { sheet = .settings }
                }
                .padding(.horizontal, 20)
            }
        }
        .task {   // drives teammates waking on the demo schedule
            while !Task.isCancelled {
                session.tick()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        .onAppear { session.prepare(app); ringIfPending() }
        .onReceive(NotificationCenter.default.publisher(for: .ringNow)) { _ in ringIfPending() }
        .onChange(of: scenePhase) { _, p in if p == .active { ringIfPending() } }
        .sheet(isPresented: $alarmSheet, onDismiss: { session.prepare(app) }) {
            Group { if session.isCoach { CoachAlarmSheet() } else { AlarmSheet() } }.presentationDetents([.medium, .large])
        }
        .sheet(item: $sheet, onDismiss: { session.prepare(app) }) { c in
            Group { if c == .teams { TeamsTab() } else { SettingsTab() } }
                .presentationDragIndicator(.visible)
        }
        .animation(.smooth(duration: 0.5), value: showWakeUp)
        .sensoryFeedback(.success, trigger: session.wakes.count)
    }

    /// The dark sheet: time, wake/practice line, the team, and the controls.
    private var panel: some View {
        VStack(spacing: 0) {
            ClockHeader(session: session, alarm: app.myAlarm)
                .padding(.top, 50)
            ScrollView {
                TeamList(session: session).padding(.top, 50).padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.06)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .bottom) { controls }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Clique.ink, in: UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25))
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder private var controls: some View {
        Group {
            switch session.phase {
            case .idle:
                HStack(spacing: 12) {
                    Button { alarmSheet = true } label: {
                        if session.isCoach {   // coach sets the team's time, not their own alarm
                            Text("Team \(session.team.timeText)")
                        } else {
                            Text(app.myAlarm.map { "Alarm \($0.formatted(date: .omitted, time: .shortened))" } ?? "Set Alarm")
                        }
                    }
                    .buttonStyle(.clique)
                    Button("Demo") { withAnimation(.smooth) { session.ring(app) } }
                        .buttonStyle(CliqueButtonStyle(prominent: false))
                        .frame(width: 120)
                }
            case .ringing:   // only the coach sees this: everyone else is on the wake-up screen
                Label("Tap a sleeper to flash them", systemImage: "flashlight.on.fill")
                    .font(.gothamBold(16)).foregroundStyle(Clique.green)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Clique.panel)
            case .stopped:  // recap stays up; Done goes back to the waiting screen
                Button("Done") { withAnimation(.smooth) { session.reset(app) } }
                    .buttonStyle(.clique)
            }
        }
        .padding(.horizontal, 25)
        .padding(.bottom, 34)
        .background(alignment: .bottom) {  // the list sinks under the controls
            LinearGradient(stops: [.init(color: Clique.ink.opacity(0), location: 0), .init(color: Clique.ink, location: 0.5)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 160)
                .allowsHitTesting(false)
        }
    }
}

// MARK: Dial

/// Grey dial with a red second hand. Teammates who are up sit on the rim as green shields with initials,
/// each landing where the hand was when they woke.
struct Dial: View {
    let session: Session

    var body: some View {
        ZStack {
            Circle().fill(Clique.stone)
            Circle().fill(Clique.face).padding(8)
            ForEach(Array(stride(from: 0, to: 360, by: 30)), id: \.self) { a in   // hour ticks
                Capsule().fill(Clique.stone.opacity(0.6))
                    .frame(width: 3, height: a % 90 == 0 ? 14 : 8)
                    .offset(y: -155)
                    .rotationEffect(.degrees(Double(a)))
            }
            ForEach(session.wakes) { w in
                DialBadge(initials: session.mates.first { $0.id == w.id }?.initials ?? "", angle: w.angle)
            }
            TimelineView(.animation) { tl in
                let seconds = session.phase == .idle
                    ? Double(secondsToday(tl.date) % 60) + tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
                    : session.elapsed
                Hand()
                    .fill(Clique.blood)
                    .frame(width: 5, height: 150)
                    .offset(y: -75)
                    .rotationEffect(.degrees(seconds.truncatingRemainder(dividingBy: 60) / 60 * 360))
            }
            Circle().fill(Clique.stone).frame(width: 25, height: 25)
        }
        .frame(width: 350, height: 350)
        .accessibilityElement()
        .accessibilityLabel("\(session.wakes.count) of \(session.mates.count) up")
    }
}

/// The second hand: a bar with a pointed tip.
struct Hand: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY + 30))
            p.addLine(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY + 30))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

/// A shield + initials, rotated to face out from the centre. Pops out from the hub when it appears.
struct DialBadge: View {
    let initials: String, angle: Double
    @State private var landed = false

    var body: some View {
        ZStack {
            Image("shield_tick").renderingMode(.template).resizable()
                .foregroundStyle(Clique.green)
                .frame(width: 30, height: 30)
                .offset(y: landed ? -153 : -20)
            Text(initials)
                .font(.gothamBold(20))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 2)
                .offset(y: landed ? -126 : -10)
                .opacity(landed ? 1 : 0)
        }
        .scaleEffect(landed ? 1 : 0.3)
        .rotationEffect(.degrees(angle))
        .onAppear { withAnimation(.spring(duration: 0.7, bounce: 0.45)) { landed = true } }
    }
}

// MARK: Time

/// Big time, then "woke at" / "practice at".
struct ClockHeader: View {
    let session: Session
    let alarm: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            // waiting: the real time. ringing or recap: the alarm's clock running from the team's wake time
            let s = session.phase == .idle ? secondsToday(tl.date) : Int(session.alarmClock + session.t)
            let h = s / 3600 % 24
            VStack(spacing: 20) {
                HStack(alignment: .center, spacing: 5) {
                    Text("\(h % 12 == 0 ? 12 : h % 12):\(String(format: "%02d", s / 60 % 60))")
                        .font(.display(96)).monospacedDigit()
                        .contentTransition(.numericText())
                    Text(h < 12 ? "AM" : "PM").font(.display(32))
                }
                .foregroundStyle(Clique.green)
                .frame(height: 65)
                HStack(spacing: 10) {
                    Text(lead).font(.gothamBold(20, relativeTo: .headline))
                    Text("practice at \(short(session.team.practiceHour, session.team.practiceMinute))").font(.gotham(20, relativeTo: .headline))
                }
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
    }

    private var lead: String {
        if session.isCoach && session.phase != .idle { return "\(session.wakes.count) of \(session.mates.count) up" }
        if let you = session.wake(of: "you") {
            let s = Int(session.alarmClock + you.at)
            return "woke at \(short(s / 3600 % 24, s / 60 % 60))"
        }
        if let alarm { let c = Calendar.current.dateComponents([.hour, .minute], from: alarm); return "alarm at \(short(c.hour!, c.minute!))" }
        return "no alarm set"
    }

    /// "8:35": no AM/PM, as in the design.
    private func short(_ h: Int, _ m: Int) -> String { "\(h % 12 == 0 ? 12 : h % 12):\(String(format: "%02d", m))" }
}

// MARK: Team

struct TeamList: View {
    let session: Session
    @State private var open: Mate?   // tapped teammate: their profile drawer

    var body: some View {
        // woken first in rank order, then everyone still asleep
        let up = session.wakes.compactMap { w in session.mates.first { $0.id == w.id } }
        let rest = session.mates.filter { session.wake(of: $0.id) == nil }
        VStack(spacing: 25) {
            ForEach(up + rest) { m in
                MateRow(mate: m, status: session.status(m), ringing: session.phase == .ringing)
                    .contentShape(Rectangle())
                    .onTapGesture { if !m.isYou { open = m } }
            }
        }
        .sheet(item: $open) { ProfileDrawer(mate: $0, session: session).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .animation(.spring(duration: 0.6, bounce: 0.2), value: session.wakes.count)
    }
}

extension MateStatus {
    var color: Color {
        switch self { case .up: Clique.green; case .snoozing: Clique.moss; case .asleep: Clique.blood; case .waiting: Clique.stone }
    }
    var barWidth: CGFloat {
        switch self { case .up, .snoozing: 120; case .waiting: 90; case .asleep: 15 }
    }
    var icon: String {
        switch self { case .up: "shield_tick"; case .snoozing: "timer"; case .asleep: "shield_cross"; case .waiting: "message_question" }
    }
    var label: String {
        switch self { case .up: "up"; case .snoozing: "snoozing"; case .asleep: "still asleep"; case .waiting: "alarm not rung yet" }
    }
}

/// A bar from the left edge whose length and colour show status, then the name, then a status icon.
struct MateRow: View {
    let mate: Mate, status: MateStatus, ringing: Bool
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 25) {
            Group {
                if status == .snoozing { ChamferBar().fill(status.color) } else { Rectangle().fill(status.color) }
            }
            .frame(width: status.barWidth, height: 50)
            .opacity(status == .asleep && ringing && pulse ? 0.45 : 1)   // sleepers throb while the alarm runs
            .shadow(color: status == .up ? Clique.green.opacity(0.35) : .clear, radius: 12)
            Text(mate.name)
                .font(.gothamBold(20, relativeTo: .headline))
                .foregroundStyle(status.color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Image(status.icon).renderingMode(.template).resizable()
                .foregroundStyle(status.color)
                .frame(width: 24, height: 24)
                .id(status)   // swap icons with a pop
                .transition(.scale(scale: 0.3).combined(with: .opacity))
        }
        .padding(.trailing, 25)
        .frame(height: 50)
        .animation(.spring(duration: 0.55, bounce: 0.35), value: status)
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever()) { pulse = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(mate.isYou ? "You" : mate.name), \(status.label)")
    }
}

// MARK: Wake up

/// Full-screen alarm: WAKE UP throbs, rings ripple out, the arrows nudge in. Tap anywhere to stop.
struct WakeUpScreen: View {
    let team: String
    let onStop: () -> Void

    var body: some View {
        ZStack {
            Clique.ink.ignoresSafeArea()
            Ripples(period: 1.4)
            TimelineView(.animation) { (tl: TimelineViewDefaultContext) in
                WakeUpMark(time: tl.date.timeIntervalSinceReferenceDate)
            }
            VStack {
                Text(team).font(.gothamBold(17)).foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 70)
                Spacer()
                Text("tap anywhere to stop").font(.gotham(17)).foregroundStyle(Clique.stone)
                    .padding(.bottom, 60)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onStop)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wake up. \(team) alarm.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Stops the alarm")
        .accessibilityAction(.default) { onStop() }
    }
}

/// WAKE UP over its bar, with the arrows. A 1.4 s wave drives the throb and the arrow nudge.
private struct WakeUpMark: View {
    let time: Double
    private var wave: Double { Foundation.sin(time / 1.4 * 2 * Double.pi) }
    private var beat: Double { (wave + 1) / 2 }   // 0...1, in step with the rings
    private var nudge: CGFloat { CGFloat(abs(wave) * 8) }

    var body: some View {
        ZStack {
            Rectangle().fill(Clique.panel).frame(width: 350, height: 15)
            Text("Wake Up")
                .font(.display(96)).textCase(.uppercase)
                .foregroundStyle(Clique.green)
                .shadow(color: Clique.green.opacity(0.25 + 0.35 * beat), radius: 18)
                .scaleEffect(1 + 0.08 * CGFloat(beat))
            HStack {
                arrow.rotationEffect(.degrees(90)).offset(x: nudge)
                Spacer()
                arrow.rotationEffect(.degrees(-90)).offset(x: -nudge)
            }
            .frame(width: 370)
        }
    }

    private var arrow: some View { Triangle().fill(Clique.green).frame(width: 21.65, height: 18.75) }
}

// MARK: Sheets

/// Pick your own real alarm time (prototype), or ring in a minute to try it.
struct AlarmSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var time = Calendar.current.date(byAdding: .minute, value: 2, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                DatePicker("Alarm", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden()
                Button("Set Alarm") { Task { await app.setMyAlarm(time); dismiss() } }
                    .buttonStyle(.clique)
                Button("Ring in 1 Minute") { Task { await app.setMyAlarm(.now, inOneMinute: true); dismiss() } }
                    .buttonStyle(.cliqueQuiet)
                if app.myAlarm != nil {
                    Button("Turn Off", role: .destructive) { app.clearMyAlarm(); dismiss() }
                        .font(.gothamBold(17)).foregroundStyle(Clique.blood).padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Clique.ink)
            .navigationTitle("Your Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

/// Coach: set the team's wake-up and practice times. The coach's own phone doesn't ring; players' phones do.
struct CoachAlarmSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var wake = Date.now
    @State private var practice = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Wake up", selection: $wake, displayedComponents: .hourAndMinute)
                    DatePicker("Practice", selection: $practice, displayedComponents: .hourAndMinute)
                } footer: {
                    Text("Your players' alarms ring at wake up. You aren't woken.")
                }
                .listRowBackground(Clique.panel)
            }
            .scrollContentBackground(.hidden)
            .background(Clique.ink)
            .navigationTitle(app.teams.first?.name ?? "Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save(); dismiss() } }
            }
            .onAppear {
                guard let t = app.teams.first else { return }
                wake = Calendar.current.date(from: DateComponents(hour: t.hour, minute: t.minute)) ?? .now
                practice = Calendar.current.date(from: DateComponents(hour: t.practiceHour, minute: t.practiceMinute)) ?? .now
            }
        }
    }

    private func save() {
        guard !app.teams.isEmpty else { return }
        let c = Calendar.current
        app.teams[0].hour = c.component(.hour, from: wake); app.teams[0].minute = c.component(.minute, from: wake)
        app.teams[0].practiceHour = c.component(.hour, from: practice); app.teams[0].practiceMinute = c.component(.minute, from: practice)
    }
}

struct CornerButton: View {
    let symbol: String, label: String, action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Clique.green)
                .frame(width: 44, height: 44)
                .background(Clique.ink, in: Circle())
        }
        .accessibilityLabel(label)
    }
}

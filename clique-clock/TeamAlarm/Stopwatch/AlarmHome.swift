import SwiftUI
import RealityKit
import CoreMotion
import AVFoundation

/// Phone tilt as a small lean target. The rest pose drifts back to however you hold the phone,
/// so only a fresh tilt moves things, like a heavy object settling. Simulator: no motion, stays zero.
@MainActor final class PhoneTilt {
    static let shared = PhoneTilt()
    private let motion = CMMotionManager()
    private var rest: SIMD2<Float>?
    private init() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1 / 60
        motion.startDeviceMotionUpdates()
    }
    /// Lean (yaw, pitch) in radians for this frame.
    func lean(_ dt: Float) -> SIMD2<Float> {
        guard let g = motion.deviceMotion?.gravity else { return .zero }
        let now = SIMD2<Float>(Float(g.x), Float(g.z))
        let r = rest ?? now
        rest = r + (now - r) * min(1, dt * 0.35)     // slow re-centre
        let d = now - r
        return simd_clamp(SIMD2(d.x * 0.55, -d.y * 0.45), SIMD2(repeating: -0.22), SIMD2(repeating: 0.22))
    }
}

// The alarm home screen: the 3D basalt stopwatch. It is the whole app now, no tab bar.
// Teams and Settings open as sheets from the top corners.

struct Mate: Identifiable {
    let id: String
    let initials: String
    let name: String
    let wakeAt: Double?          // nil = you, woken by the slider
    var snoozeAt: Double? = nil
    var photo: UIImage? = nil
    var isYou: Bool { wakeAt == nil }
}

extension UIImage {
    /// Square-cropped circle with transparent corners, for avatars and the 3D chip.
    func circle(_ side: CGFloat = 256) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: side, height: side)).addClip()
            let s = max(side / size.width, side / size.height)
            draw(in: CGRect(x: (side - size.width * s) / 2, y: (side - size.height * s) / 2, width: size.width * s, height: size.height * s))
        }
    }
}

// ponytail: demo wake schedule (seconds after the alarm), swap for live teammate data when there is a backend
let demoSchedule: [(wake: Double, snooze: Double?)] = [(3.4, nil), (8.2, nil), (14.6, nil), (21.1, nil), (27.9, nil),
    (33.5, 11), (40.3, nil), (47.6, nil), (52.2, nil), (55.8, 30), (58.9, nil)]

struct Wake: Identifiable { let id: String; let rank: Int; let at: Double }

@MainActor @Observable final class Session {
    enum Phase { case idle, ringing, stopped }
    var phase = Phase.idle
    var team = Demo.teams[0]
    var mates: [Mate] = []
    var start: Date?
    var wakes: [Wake] = []
    var stoppedAt: Double?                       // when you slid to stop
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
    /// Start the team wake-up. With `youWokeAt` (the second you stopped the real alarm) you open already up: no slider.
    func ring(_ app: AppState, startedAt: Date = .now, youWokeAt: Date? = nil) {
        phase = .idle; prepare(app); wakes = []; stoppedAt = nil; start = startedAt; phase = .ringing
        alarmClock = Double(ClockHeader.secondsToday(startedAt))
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
    func reset(_ app: AppState) { TeamRinger.stop(); phase = .idle; start = nil; wakes = []; stoppedAt = nil; prepare(app) }

    func wake(_ id: String, at t: Double? = nil) {
        guard !wakes.contains(where: { $0.id == id }) else { return }
        wakes.append(Wake(id: id, rank: wakes.count + 1, at: t ?? elapsed))
        if allUp { TeamRinger.stop() }
        if isCoach && allUp && phase == .ringing { stoppedAt = elapsed; phase = .stopped }   // coach view: done when the team is
        if allUp, let last = mates.first(where: { $0.id == id }) {
            app?.finishWake(activityState, lastLine: last.isYou ? "You were last." : "\(last.name) was last.")
        } else {
            app?.updateActivity(activityState)
        }
    }
    func wake(of id: String) -> Wake? { wakes.first { $0.id == id } }

    /// Glow level 0...1. Rises like a sunrise, breathes while ringing, settles once stopped. Continuous everywhere.
    func glow(at t: Double) -> Double {
        if phase == .idle { return 0.12 }  // pre-dawn
        let ring = 0.12 + 0.88 * ease(t / 3.2) - 0.07 * (1 - cos(t * 2 * .pi / 1.6)) * ease((t - 2) / 2)
        guard let s = stoppedAt else { return ring }
        let k = exp(-(t - s) / 0.9)
        let atStop = 0.12 + 0.88 * ease(s / 3.2)
        return 0.32 + (atStop - 0.32) * k - 0.07 * (1 - cos(t * 2 * .pi / 1.6)) * ease((t - 2) / 2) * k
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

private func ease(_ x: Double) -> Double { let t = min(max(x, 0), 1); return t * t * (3 - 2 * t) }

// MARK: - UI

struct AlarmHome: View {
    @Environment(AppState.self) private var app
    @State private var session = Session()
    @State private var rig = Rig()
    @State private var loaded = false   // ridge + watch fade in together once the model is ready, no flash
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

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = w * 1400 / 1179  // hero matches the Blender camera frame
            let top: CGFloat = 40                        // clear of the Dynamic Island and corner buttons
            ZStack(alignment: .top) {
                Color.black
                TimelineView(.animation) { tl in
                    let level = session.glow(at: session.elapsed)
                    ZStack(alignment: .top) {
                        Glow(level: level, crest: (top + 0.58 * h) / (top + h))  // runs to the top edge, no seam
                        ZStack {
                            Image(uiImage: UIImage(named: "ridge_dark")!).resizable()
                            Image(uiImage: UIImage(named: "ridge_lit")!).resizable().opacity(level)
                        }
                        .frame(width: w, height: h)
                        .mask(LinearGradient(stops: [.init(color: .black, location: 0.72), .init(color: .clear, location: 1)],
                                             startPoint: .top, endPoint: .bottom))  // ground melts into the black, no edge
                        .padding(.top, top)
                        .opacity(loaded ? 1 : 0)
                    }
                    .frame(width: w, height: top + h)
                    .onChange(of: level) { rig.glow = Float(level) }
                }
                RealityView { content in
                    rig.onReady = { withAnimation(.easeOut(duration: 0.7)) { loaded = true } }
                    await rig.build(content, session: session)
                }
                    .frame(width: w, height: h)
                    .padding(.top, top)
                    .opacity(loaded ? 1 : 0)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { rig.press($0.translation) }
                        .onEnded { rig.release($0.translation) })

                VStack(spacing: 0) {
                    Spacer().frame(height: top + h * 0.86).allowsHitTesting(false)
                    ClockHeader(session: session)  // fixed: the list scrolls under it
                    ScrollView {
                        TeamList(session: session).padding(.top, 14).padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.05),
                                                 .init(color: .black, location: 0.93), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .background(alignment: .top) {
                        LinearGradient(colors: [.clear, .black.opacity(0.85), .black], startPoint: .top, endPoint: .init(x: 0.5, y: 0.2))
                            .allowsHitTesting(false)
                    }
                    Group {
                        switch session.phase {
                        case .idle:
                            HStack(spacing: 12) {
                                Button { alarmSheet = true } label: {
                                    if session.isCoach {   // coach sets the team's time, not their own alarm
                                        Label("Team \(session.team.timeText)", systemImage: "person.3.fill")
                                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                                    } else {
                                        Label(app.myAlarm.map { $0.formatted(date: .omitted, time: .shortened) } ?? "Set Alarm", systemImage: "alarm.fill")
                                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                                    }
                                }
                                .buttonStyle(.glass)
                                Button { withAnimation(.smooth) { session.ring(app) } } label: {
                                    Label("Demo", systemImage: "play.fill").padding(.vertical, 6).padding(.horizontal, 4)
                                }
                                .buttonStyle(.glass)
                            }
                            .tint(.white)
                        case .ringing where session.isCoach:
                            Label("Tap a sleeper to flash them", systemImage: "flashlight.on.fill")
                                .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(.ultraThinMaterial, in: Capsule())
                        case .ringing:
                            SlideToStop { withAnimation(.smooth(duration: 0.5)) { session.stop() } }
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        case .stopped:  // recap stays up; Done goes back to the waiting screen
                            Button { withAnimation(.smooth) { session.reset(app) } } label: {
                                Text("Done").frame(maxWidth: .infinity).padding(.vertical, 6)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .background(alignment: .bottom) {  // black fades up behind the controls so the list sinks under them
                        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(0.85), location: 0.45),
                                               .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 200)
                            .padding(.bottom, -60)
                            .allowsHitTesting(false)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .top) {  // Teams top left, Settings top right. No tab bar: this screen is only the alarm.
                HStack {
                    CornerButton(symbol: "person.2.fill", label: "Teams") { sheet = .teams }
                    Spacer()
                    CornerButton(symbol: "gearshape.fill", label: "Settings") { sheet = .settings }
                }
                .padding(.horizontal, 20)
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
        .background(.black)
        .sensoryFeedback(.success, trigger: session.wakes.count)
    }
}

/// Sunrise bloom behind the ridge: a wide amber halo and a warm white core, both gaussian falloffs.
/// It climbs as it brightens. A faint noise layer dithers away banding in the dark gradient.
struct Glow: View {
    let level: Double, crest: Double
    static let dither = Image(uiImage: noiseImage())

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let cy = h * (crest + (1 - level) * 0.10)
            ZStack {
                halo(Color(red: 1, green: 0.48, blue: 0.2), level * 0.95)
                    .frame(width: w * 2.0, height: h * 1.05).position(x: w / 2, y: cy)
                halo(Color(red: 1, green: 0.86, blue: 0.7), level)
                    .frame(width: w * 0.85, height: h * 0.36).position(x: w / 2, y: cy)
                Rectangle().fill(.image(Self.dither)).opacity(0.03).blendMode(.plusLighter)
            }
        }
        .drawingGroup()
    }

    func halo(_ c: Color, _ a: Double) -> some View {
        let stops = stride(from: 0.0, through: 1.0, by: 0.1).map { x in
            Gradient.Stop(color: c.opacity(a * exp(-pow(x * 2.6, 2))), location: x)
        }
        return Rectangle().fill(EllipticalGradient(stops: stops))
    }

    static func noiseImage() -> UIImage {
        let n = 128
        let bytes = (0..<n * n).map { _ in UInt8.random(in: 0...255) }
        let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.data!.copyMemory(from: bytes, byteCount: bytes.count)
        return UIImage(cgImage: ctx.makeImage()!)
    }
}

/// Big digital time, then date and practice time. Stays put while the list scrolls.
struct ClockHeader: View {
    let session: Session
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            // waiting: the real time. ringing or recap: the alarm's clock running from the team's wake time
            let s = session.phase == .idle ? Self.secondsToday(tl.date) : Int(session.alarmClock + session.elapsed)
            let h = s / 3600 % 24
            VStack(spacing: 2) {
                (Text("\(h % 12 == 0 ? 12 : h % 12):\(String(format: "%02d", s / 60 % 60))")
                    + Text(h < 12 ? " AM" : " PM").font(.system(size: 26, weight: .semibold, design: .rounded)))
                    .font(.system(size: 58, weight: .semibold, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText())
                Text("\(Self.day()) | \(session.team.practiceText) Practice")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .shadow(color: .black.opacity(0.8), radius: 12)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
            .background {  // darken the ground behind the time so both lines read
                LinearGradient(colors: [.clear, .black.opacity(0.8), .black], startPoint: .top, endPoint: .bottom)
                    .padding(.top, -50)
            }
        }
    }

    static func secondsToday(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: d)
        return c.hour! * 3600 + c.minute! * 60 + c.second!
    }

    /// "Wednesday, Nov 11th"
    static func day(_ d: Date = .now) -> String {
        let n = Calendar.current.component(.day, from: d)
        let suffix = (11...13).contains(n % 100) ? "th" : [1: "st", 2: "nd", 3: "rd"][n % 10] ?? "th"
        return d.formatted(.dateTime.weekday(.wide)) + ", " + d.formatted(.dateTime.month(.abbreviated)) + " \(n)\(suffix)"
    }
}

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
                Button { Task { await app.setMyAlarm(time); dismiss() } } label: {
                    Text("Set Alarm").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent).tint(.orange)
                Button("Ring in 1 Minute") { Task { await app.setMyAlarm(.now, inOneMinute: true); dismiss() } }
                if app.myAlarm != nil {
                    Button("Turn Off", role: .destructive) { app.clearMyAlarm(); dismiss() }
                }
            }
            .padding(.horizontal, 24)
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
            }
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
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.14)))
                .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
        }
        .accessibilityLabel(label)
    }
}

struct TeamList: View {
    let session: Session
    @State private var open: Mate?   // tapped teammate: their profile drawer
    var body: some View {
        // woken first in rank order, then everyone still asleep
        let up = session.wakes.compactMap { w in session.mates.first { $0.id == w.id }.map { (mate: $0, wake: Optional(w)) } }
        let asleep = session.mates.filter { session.wake(of: $0.id) == nil }.map { (mate: $0, wake: Optional<Wake>.none) }
        VStack(spacing: 0) {
            ForEach(up + asleep, id: \.mate.id) { row in
                MateRow(mate: row.mate, wake: row.wake, color: color(row.mate, row.wake), alarmClock: session.alarmClock)
                    .contentShape(Rectangle())
                    .onTapGesture { if !row.mate.isYou { open = row.mate } }
            }
        }
        .padding(.horizontal, 20)
        .sheet(item: $open) { ProfileDrawer(mate: $0, session: session).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .animation(.spring(duration: 0.55, bounce: 0.15), value: session.wakes.count)
    }

    // green up, red last up (once everyone is), orange snoozed, gray asleep
    func color(_ m: Mate, _ w: Wake?) -> Color {
        if let w { return session.allUp && w.rank == session.mates.count ? .red : .green }
        if let s = m.snoozeAt, session.elapsed >= s { return .orange }
        return Color(white: 0.28)
    }
}

struct MateRow: View {
    let mate: Mate, wake: Wake?, color: Color, alarmClock: Double
    var body: some View {
        HStack(spacing: 12) {
            Text(wake.map { "\($0.rank)" } ?? "")
                .font(.system(size: 15, weight: .medium, design: .rounded)).monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .trailing)
            Text(mate.photo == nil ? mate.initials : "")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(wake == nil && color == Color(white: 0.28) ? Color(white: 0.7) : .white)
                .frame(width: 30, height: 30)
                .background(color.gradient, in: Circle())
                .overlay {   // your photo sits inside a thin status ring
                    if let p = mate.photo { Image(uiImage: p).resizable().scaledToFill().frame(width: 25, height: 25).clipShape(Circle()) }
                }
                .shadow(color: color.opacity(wake == nil ? 0 : 0.45), radius: 6)
                .overlay(alignment: .bottomTrailing) {
                    if mate.isYou {
                        Circle().fill(.blue).frame(width: 9, height: 9).overlay(Circle().stroke(.black, lineWidth: 1.5))
                    }
                }
            Text(mate.name)
                .font(.system(size: 17, weight: mate.isYou ? .semibold : .regular))
                .foregroundStyle(wake == nil ? .secondary : .primary)
            Spacer()
            Text(wake.map { clock($0.at) } ?? "")
                .font(.system(size: 17)).monospacedDigit()
        }
        .frame(height: 40)
        .shadow(color: .black.opacity(0.7), radius: 8)
        .transition(.opacity)
    }
    func clock(_ t: Double) -> String {
        let s = Int(alarmClock + t)
        return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }
}

/// iOS alarm style: drag the knob across to stop.
struct SlideToStop: View {
    let onStop: () -> Void
    @State private var x: CGFloat = 0
    @State private var done = false

    var body: some View {
        GeometryReader { geo in
            let knob: CGFloat = 56, travel = geo.size.width - knob - 8
            ZStack(alignment: .leading) {
                Capsule().fill(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.2), .orange], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
                    .shadow(color: .orange.opacity(0.35), radius: 18, y: 6)
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    Text("slide to stop")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                        .overlay {  // the classic shimmer sweeping left to right
                            LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: 70)
                                .offset(x: CGFloat((t.truncatingRemainder(dividingBy: 2.4)) / 2.4) * 260 - 130)
                        }
                        .mask(Text("slide to stop").font(.system(size: 19, weight: .regular)))
                        .frame(maxWidth: .infinity)
                        .padding(.leading, knob)
                        .opacity(1 - Double(x / travel) * 1.6)
                }
                Circle().fill(.white)
                    .overlay(Image(systemName: "chevron.right.2").font(.system(size: 20, weight: .semibold)).foregroundStyle(.orange))
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                    .padding(.leading, 4)
                    .offset(x: x)
                    .gesture(DragGesture()
                        .onChanged { v in if !done { x = min(max(v.translation.width, 0), travel) } }
                        .onEnded { _ in
                            if x > travel * 0.85 {
                                done = true
                                withAnimation(.spring(duration: 0.25)) { x = travel }
                                onStop()
                            } else {
                                withAnimation(.spring(duration: 0.45, bounce: 0.3)) { x = 0 }
                            }
                        })
            }
        }
        .frame(height: 64)
    }
}

// MARK: - 3D

/// Owns the loaded stopwatch and drives the hand + avatar chips each frame.
/// Chip and hand math is in the model's Blender frame: face normal = -Y, 12 o'clock = +Z.
@MainActor final class Rig {
    var session: Session!
    var root = Entity()
    var hand: Entity?
    var chips: [String: Chip] = [:]
    var glow: Float = 0
    var ibl: Entity?
    var rim: DirectionalLight?
    var sub: EventSubscription?
    var tilt: Entity?
    // finger tilt: drag leans the watch toward the finger, rubber-banded; springs back on release
    var lean = SIMD2<Float>.zero, leanV = SIMD2<Float>.zero, leanGoal = SIMD2<Float>.zero
    var touching = false
    let tap = UIImpactFeedbackGenerator(style: .soft)

    func press(_ d: CGSize) {
        if !touching { touching = true; tap.impactOccurred(intensity: 0.6) }
        let k: Float = 0.30  // max lean, radians (~17 deg)
        leanGoal = [k * tanh(Float(d.width) / 170), k * tanh(Float(d.height) / 170)]
    }
    func release(_ d: CGSize) {
        touching = false
        leanGoal = .zero
        if abs(d.width) + abs(d.height) < 6 { leanV += [0, -2.2] }  // a tap: little nod
    }

    /// Spring-driven avatar: grows out of the dial centre, rides the hand out, lands in the groove.
    final class Chip {
        let e: Entity; let born: Double; let rest: Float
        var pos = SIMD3<Float>(0, -0.37, 0), vel = SIMD3<Float>.zero
        var s: Float = 0.02, sv: Float = 0
        init(_ e: Entity, born: Double, rest: Float) { self.e = e; self.born = born; self.rest = rest }
    }

    var onReady: (() -> Void)?   // fires once the watch has actually been drawn, not just loaded
    private var frames = 0
    private static var cached: Entity?
    /// Load once, hand out clones (they share meshes and textures).
    static func stopwatch() async -> Entity? {
        if cached == nil { cached = try? await Entity(named: "Stopwatch") }
        return cached?.clone(recursive: true)
    }

    func build(_ content: RealityViewCameraContent, session: Session) async {
        self.session = session
        // onboarding preloads the watch, so landing on home after it is instant
        guard let model = await Rig.stopwatch() else { return }
        root = model.findEntity(named: "Stopwatch") ?? model
        hand = model.findEntity(named: "Hand_Seconds")

        let anchor = Entity()
        let tilt = Entity()
        tilt.addChild(model)
        anchor.addChild(tilt)
        content.add(anchor)
        self.tilt = tilt

        let cam = PerspectiveCamera()  // same frame as the Blender hero camera (85mm)
        cam.camera.fieldOfViewInDegrees = 26.5
        cam.position = [0, 0.05, 7.6]
        content.add(cam)

        if let env = try? await EnvironmentResource(equirectangular: studioImage()) {
            anchor.components.set(ImageBasedLightComponent(source: .single(env), intensityExponent: -0.6))
            model.visit { $0.components.set(ImageBasedLightReceiverComponent(imageBasedLight: anchor)) }
            ibl = anchor
        }
        let key = DirectionalLight()  // lighting B: low warm sun from the left, raking across the stone
        key.light.color = UIColor(red: 1, green: 0.8, blue: 0.62, alpha: 1)
        key.light.intensity = 3800
        key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 4, depthBias: 2)
        key.look(at: .zero, from: [-6.5, 1.0, 0.35], relativeTo: nil)
        content.add(key)

        let rim = DirectionalLight()  // warm sunrise from behind the ridge; tracks the glow
        rim.light.color = UIColor(red: 1, green: 0.7, blue: 0.45, alpha: 1)
        rim.look(at: .zero, from: [0, -0.6, -4], relativeTo: nil)
        content.add(rim)
        self.rim = rim

        sub = content.subscribe(to: SceneEvents.Update.self) { [weak self] e in self?.tick(Float(e.deltaTime)) }
    }

    func tick(_ dt: Float) {
        frames += 1
        if frames == 4 { onReady?(); onReady = nil }
        let t = session.elapsed
        if session.phase != .idle { for m in session.mates { if let w = m.wakeAt, t >= w { session.wake(m.id) } } }
        if session.wakes.isEmpty && !chips.isEmpty { chips.values.forEach { $0.e.removeFromParent() }; chips = [:] }  // back to idle
        let angle = Float(t.truncatingRemainder(dividingBy: 60) / 60 * 2 * .pi)
        hand?.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])

        rim?.light.intensity = 600 + 5200 * glow
        ibl?.components[ImageBasedLightComponent.self]?.intensityExponent = -0.9 + 0.7 * glow

        let dt0 = min(dt, 1 / 30)
        let w: Float = touching ? 14 : 6, z: Float = touching ? 1 : 0.5  // firm under the finger, heavy slow wobble otherwise
        leanV += (w * w * (leanGoal + PhoneTilt.shared.lean(dt0) - lean) - 2 * z * w * leanV) * dt0
        lean += leanV * dt0
        tilt?.orientation = simd_quatf(angle: lean.x, axis: [0, 1, 0]) * simd_quatf(angle: lean.y, axis: [1, 0, 0])

        for w in session.wakes where chips[w.id] == nil { spawn(w.id, at: angle, t: t) }
        let dt = min(dt, 1 / 30)
        for c in chips.values { step(c, handAngle: angle, t: t, dt: dt) }
    }

    func step(_ c: Chip, handAngle: Float, t: Double, dt: Float) {
        let u = Float(t - c.born)
        // target: ride out along the live hand for 0.9s, then the groove slot
        let target: SIMD3<Float>
        if u < 0.9 {
            let p = Float(ease(Double(u / 0.9)))
            target = polar(0.58 * p, handAngle, y: -0.40 - 0.05 * sin(p * .pi))
        } else {
            target = polar(0.71, c.rest, y: -0.33)
        }
        // critically damped position spring keeps it one continuous curve
        let w: Float = 13, z: Float = 1
        c.vel += (w * w * (target - c.pos) - 2 * z * w * c.vel) * dt
        c.pos += c.vel * dt
        // scale: underdamped spring for a soft pop, grows while it travels
        let goal: Float = u < 0.9 ? 0.35 + 0.75 * min(u / 0.9, 1) : 1
        let ws: Float = 11, zs: Float = 0.55
        c.sv += (ws * ws * (goal - c.s) - 2 * zs * ws * c.sv) * dt
        c.s += c.sv * dt
        c.e.position = c.pos
        c.e.scale = .init(repeating: max(c.s, 0.01))
    }

    func spawn(_ id: String, at handAngle: Float, t: Double) {
        // rest where the hand was, nudged so chips never overlap
        var a = handAngle + 0.12
        let gap: Float = 13 * .pi / 180
        let taken = chips.values.map(\.rest)
        while taken.contains(where: { abs(remainder($0 - a, 2 * .pi)) < gap }) { a += gap }
        let mate = session.mates.first { $0.id == id }
        let e = makeChip(mate?.initials ?? "", photo: mate?.photo)
        e.scale = .init(repeating: 0.02)
        e.position = [0, -0.37, 0]
        root.addChild(e)
        chips[id] = Chip(e, born: t, rest: a)
    }

    func polar(_ r: Float, _ a: Float, y: Float) -> SIMD3<Float> { [r * sin(a), y, r * cos(a)] }

    func makeChip(_ initials: String, photo: UIImage? = nil) -> Entity {
        let chip = Entity()
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(red: 0.16, green: 0.78, blue: 0.35, alpha: 1))
        m.roughness = 0.38
        m.clearcoat = 0.8
        m.clearcoatRoughness = 0.15
        let disc = ModelEntity(mesh: .generateCylinder(height: 0.024, radius: 0.075), materials: [m])
        chip.addChild(disc)

        if let cg = photo?.circle().cgImage, let tex = try? TextureResource(image: cg, options: .init(semantic: .color)) {
            // your photo on the chip face, inside a green rim
            var face = UnlitMaterial()
            face.color = .init(tint: .white, texture: .init(tex))
            face.opacityThreshold = 0.5
            let plane = ModelEntity(mesh: .generatePlane(width: 0.128, depth: 0.128), materials: [face])
            plane.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])  // face the viewer (-Y)
            plane.position = [0, -0.0125, 0]
            chip.addChild(plane)
            return chip
        }
        let base = UIFont.systemFont(ofSize: 0.062, weight: .bold)
        let font = UIFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: 0.062)
        let mesh = MeshResource.generateText(initials, extrusionDepth: 0.002, font: font)
        let text = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
        let c = mesh.bounds.center
        text.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])  // face the viewer (-Y)
        text.position = [-c.x, -0.0125, -c.y]
        chip.addChild(text)
        return chip
    }

    /// HDR studio: soft cool dome, two softboxes, warm sunrise band on the horizon.
    func studioImage() -> CGImage {
        let w = 512, h = 256
        var px = [Float](repeating: 0, count: w * h * 4)
        for j in 0..<h {
            let lat = (0.5 - (Float(j) + 0.5) / Float(h)) * .pi       // +pi/2 up
            for i in 0..<w {
                let lon = (Float(i) + 0.5) / Float(w) * 2 * .pi
                var r: Float = 0, g: Float = 0, b: Float = 0
                let up = max(sin(lat), 0)
                r += 0.10 * up; g += 0.11 * up; b += 0.13 * up                   // dome
                let back = pow(max(cos(lon - .pi), 0), 2)                         // only behind the watch
                let band = back * exp(-pow((lat - 0.05) / 0.12, 2))               // horizon sunrise
                r += 1.6 * band; g += 0.95 * band; b += 0.5 * band
                for box in [Float(0.6), 3.7] {                                    // softboxes, 35 deg up
                    let d = pow(remainder(lon - box, 2 * .pi) / 0.35, 2) + pow((lat - 0.6) / 0.22, 2)
                    let k = 3.2 * exp(-d * d)
                    r += k; g += k * 1.02; b += k * 1.06
                }
                let o = (j * w + i) * 4
                px[o] = r; px[o + 1] = g; px[o + 2] = b; px[o + 3] = 1
            }
        }
        let data = px.withUnsafeBufferPointer { Data(buffer: $0) } as CFData
        return CGImage(width: w, height: h, bitsPerComponent: 32, bitsPerPixel: 128, bytesPerRow: w * 16,
                       space: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                       provider: CGDataProvider(data: data)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }
}

extension Entity {
    func visit(_ f: (Entity) -> Void) { f(self); children.forEach { $0.visit(f) } }
}

import SwiftUI
import RealityKit
import PhotosUI

// Onboarding: one continuous 3D scene. The gear from the welcome flat lay springs into a new pose on every
// step, so tapping through feels like the camera stays put and the objects rearrange themselves.
// Player: Welcome, Coach or player, Name, Team code, Alarms.  Coach: Welcome, Coach or player, Team, Times, Share code.

enum Role { case coach, player }

enum Sport: String, CaseIterable, Identifiable {
    case basketball = "Basketball", football = "Football", baseball = "Baseball", soccer = "Soccer"
    var id: String { rawValue }
    var entity: String {
        switch self { case .basketball: "Basketball"; case .football: "AmFootball"; case .baseball: "Baseball"; case .soccer: "Soccer" }
    }
    var symbol: String {
        switch self { case .basketball: "basketball.fill"; case .football: "football.fill"; case .baseball: "baseball.fill"; case .soccer: "soccerball" }
    }
}

@MainActor @Observable final class OnboardFlow {
    var step = 0
    var role: Role?
    var sport = Sport.basketball
    var bounce = 0          // bumps the ball once per typed code character
    var count: Int { role == .coach ? 6 : 5 }   // coach adds team, times, code after the name
}

struct Onboarding: View {
    @Environment(AppState.self) private var app
    @State private var flow = OnboardFlow()
    @State private var stage = Stage()
    @State private var code = ""
    @State private var codeFailed = false
    @State private var teamName = ""
    @State private var wake = Self.time(5, 30)
    @State private var practice = Self.time(6, 30)
    @State private var days: Set<Int> = [2, 4, 6]
    @State private var teamCode = ""
    @FocusState private var focus: Int?
    @State private var photoPick: PhotosPickerItem?
    @State private var fullH: CGFloat = 0   // screen height without the keyboard, so text never jumps

    var body: some View {
        GeometryReader { geo in
            let H = max(geo.size.height, fullH)
            ZStack(alignment: .top) {
                // the home screen's sunrise glow; the basalt slab is the ridge
                Color.black
                Glow(level: 0.92, crest: 0.47).opacity(flow.step == 0 ? 1 : 0.3)
                RealityView { content in await stage.build(content, flow: flow) }
                    .onAppear { stage.aspect = Float(geo.size.width / geo.size.height); fullH = geo.size.height }
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { stage.press($0.translation) }
                        .onEnded { stage.release($0.translation) })
            }
            .ignoresSafeArea()
            .overlay { screen(H).frame(maxWidth: .infinity, maxHeight: .infinity) }
            .overlay(alignment: .topLeading) {
                if flow.step > 0 {
                    Button { go(flow.step - 1) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain).foregroundStyle(.white)
                    .padding(.leading, 20).padding(.top, 4)
                    .accessibilityLabel("Back")
                    .transition(.opacity)
                }
            }
        }
        .background(.black)
        .animation(.smooth(duration: 0.6), value: flow.step)
        .sensoryFeedback(.selection, trigger: flow.step)
    }

    // MARK: Screens

    @ViewBuilder private func screen(_ H: CGFloat) -> some View {
        switch flow.step {
        case 0:
            page(H, top: H * 0.62) {
                title(nil, "Rise as a team", "See who's up. Don't be last.")
            } cta: { cta("Get Started") { go(1) } }
        case 1:
            ZStack(alignment: .top) {
                title("Are you a", "Coach or player?", nil).padding(.top, 70)
                // tap the whistle (top) or the ball (bottom); they lean under your finger first
                roleHit("Coach", y: H * 0.36, h: H * 0.28) { pick(.coach) }
                roleHit("Player", y: H * 0.68, h: H * 0.28) { pick(.player) }
                VStack { Spacer(); dots }.padding(.bottom, 34)
            }
        case 2:
            page(H, top: H * 0.29) {
                title(nil, "What's your name?", nil)
                @Bindable var app = app
                VStack(spacing: 0) {
                    TextField("First name", text: $app.first).textContentType(.givenName).focused($focus, equals: 0)
                        .submitLabel(.next).onSubmit { focus = 1 }.padding(16)
                    Divider().padding(.leading, 16)
                    TextField("Last name", text: $app.last).textContentType(.familyName).focused($focus, equals: 1)
                        .submitLabel(.continue).padding(16)
                        .onSubmit { if !app.first.isBlank && !app.last.isBlank { go(3) } }
                }
                .background(Color(white: 0.11), in: .rect(cornerRadius: 14))
                HStack(spacing: 6) {
                    Text("Your team sees your initials.").foregroundStyle(.secondary)
                    PhotosPicker(app.photo == nil ? "Add Photo" : "Change Photo", selection: $photoPick, matching: .images)
                }
                .font(.footnote)
                .onChange(of: photoPick) { _, item in
                    Task { if let data = try? await item?.loadTransferable(type: Data.self) { app.photo = UIImage(data: data) } }
                }
            } cta: { cta("Continue", enabled: !app.first.isBlank && !app.last.isBlank) { go(3) } }
        case 3 where flow.role == .player:
            page(H, top: H * 0.28) {
                title(nil, "Join your team", codeFailed ? "No team found. Prototype code: \(AppState.demoCode)" : "Prototype code: \(AppState.demoCode)")
                codeBoxes
            } cta: { cta("Join", enabled: code.count == 6) {
                if app.join(code: code) { go(4) } else { codeFailed = true }
            } }
        case 4 where flow.role == .player:
            page(H, top: H * 0.5) {
                title(nil, "Turn on alarms", "Your coach sets the time.")
            } cta: {
                VStack(spacing: 6) {
                    cta("Allow Alarms") { Task { await app.requestPermissions(); finish() } }
                    Button("Not Now") { finish() }.foregroundStyle(.secondary).padding(.vertical, 6)
                }
            }
        case 3:
            page(H, top: H * 0.29) {
                title(nil, "Name your team", nil)
                TextField("Westside Warriors", text: $teamName).focused($focus, equals: 3).submitLabel(.done)
                    .padding(16).background(Color(white: 0.11), in: .rect(cornerRadius: 14))
                HStack(spacing: 8) {
                    ForEach(Sport.allCases) { s in
                        Button { flow.sport = s } label: {
                            VStack(spacing: 4) {
                                Image(systemName: s.symbol).font(.system(size: 18))
                                Text(s.rawValue).font(.caption2.weight(.medium))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(flow.sport == s ? Color.white.opacity(0.18) : Color(white: 0.11), in: .rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } cta: { cta("Continue", enabled: !teamName.isBlank) { go(4) } }
        case 4:
            page(H, top: H * 0.42) {
                title(nil, "Set the times", nil)
                VStack(spacing: 0) {
                    DatePicker("Wake up", selection: $wake, displayedComponents: .hourAndMinute).padding(.horizontal, 16).padding(.vertical, 8)
                    Divider().padding(.leading, 16)
                    DatePicker("Practice", selection: $practice, displayedComponents: .hourAndMinute).padding(.horizontal, 16).padding(.vertical, 8)
                }
                .background(Color(white: 0.11), in: .rect(cornerRadius: 14))
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { d in
                        Button { if days.contains(d) { days.remove(d) } else { days.insert(d) } } label: {
                            Text(Calendar.current.veryShortWeekdaySymbols[d - 1]).font(.subheadline.weight(.semibold))
                                .frame(width: 38, height: 38)
                                .background(days.contains(d) ? Color.white : Color(white: 0.11), in: Circle())
                                .foregroundStyle(days.contains(d) ? .black : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } cta: { cta("Continue", enabled: !days.isEmpty) { makeTeam(); go(5) } }
        default:
            page(H, top: H * 0.42) {
                VStack(spacing: 8) {
                    Text("Your team code").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Text(teamCode).font(.system(size: 44, weight: .bold, design: .monospaced)).tracking(4)
                    Text("Players join \(teamName) with this.").font(.subheadline).foregroundStyle(.secondary)
                }
            } cta: {
                VStack(spacing: 6) {
                    ShareLink(item: "Join \(teamName) on Team Alarm. Code: \(teamCode)") {
                        Text("Share Code").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color(white: 0.96)).foregroundStyle(.black)
                    .simultaneousGesture(TapGesture().onEnded { flow.bounce += 1 })
                    Button("Done") { finish() }.foregroundStyle(.secondary).padding(.vertical, 6)
                }
            }
        }
    }

    /// Text block that starts at `top`, then page dots and the button pinned to the bottom.
    private func page<C: View, B: View>(_ H: CGFloat, top: CGFloat, @ViewBuilder content: () -> C, @ViewBuilder cta: () -> B) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: top)
            content()
            Spacer(minLength: 0)
            dots
            cta()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, focus == nil ? 12 : 92)   // the floating keyboard covers more than its safe area
        .shadow(color: .black.opacity(0.6), radius: 10)
        .transition(.opacity)
        .id(flow.step)
    }

    private func title(_ eyebrow: String?, _ h1: String, _ sub: String?) -> some View {
        VStack(spacing: 6) {
            if let eyebrow { Text(eyebrow).font(.system(size: 17, weight: .medium)).foregroundStyle(.secondary) }
            Text(h1).font(.system(size: 34, weight: .bold)).multilineTextAlignment(.center)
            if let sub { Text(sub).font(.system(size: 17)).foregroundStyle(.secondary).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity)
    }

    /// Slide dots: one per screen.
    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<flow.count, id: \.self) { i in
                Circle().fill(i == flow.step ? Color.white : Color.white.opacity(0.25)).frame(width: 7, height: 7)
            }
        }
        .accessibilityElement().accessibilityLabel("Step \(flow.step + 1) of \(flow.count)")
    }

    private func cta(_ label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(Color(white: 0.96))
        .foregroundStyle(.black)
        .disabled(!enabled)
    }

    private func roleHit(_ label: String, y: CGFloat, h: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack { Spacer(); Text(label).font(.system(size: 22, weight: .bold)).shadow(color: .black, radius: 8) }
                .frame(maxWidth: .infinity).frame(height: h).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(y: y - h * 0.45)
        .accessibilityLabel(label)
    }

    private var codeBoxes: some View {
        ZStack {
            TextField("", text: $code).focused($focus, equals: 2).keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters).autocorrectionDisabled().opacity(0.01)
                .onChange(of: code) { old, v in
                    code = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                    codeFailed = false
                    if code.count > old.count { flow.bounce += 1 }
                    if code.count == 6 {   // full code: join without needing the button
                        Task { try? await Task.sleep(for: .milliseconds(350)); if code.count == 6, app.join(code: code) { go(4) } else if code.count == 6 { codeFailed = true } }
                    }
                }
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    let ch = i < code.count ? String(Array(code)[i]) : ""
                    Text(ch).font(.system(size: 26, weight: .semibold, design: .monospaced))
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Color(white: 0.11), in: .rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(i == code.count ? Color.white.opacity(0.5) : .clear))
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { focus = 2 }
        .onAppear { focus = 2 }
    }

    // MARK: Flow

    private func go(_ step: Int) {
        focus = nil
        if step <= 1 { flow.role = nil }
        flow.step = step
    }

    private func pick(_ role: Role) {
        flow.role = role
        go(2)
    }

    private func makeTeam() {
        let c = Calendar.current
        teamCode = app.createTeam(name: teamName.trimmingCharacters(in: .whitespaces), symbol: flow.sport.symbol,
                                  wake: (c.component(.hour, from: wake), c.component(.minute, from: wake)),
                                  practice: (c.component(.hour, from: practice), c.component(.minute, from: practice)),
                                  days: days.sorted())
    }

    private func finish() { withAnimation(.smooth(duration: 0.8)) { app.onboarded = true } }

    static func time(_ h: Int, _ m: Int) -> Date { Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? .now }
}

private extension String { var isBlank: Bool { trimmingCharacters(in: .whitespaces).isEmpty } }

// MARK: - 3D stage

/// Holds every onboarding object and springs each one toward the pose its current step asks for.
@MainActor final class Stage {
    enum Target {
        case home                                   // where it sits in the welcome flat lay
        case sink                                   // sink out of view, below where it was
        case screen(Float, Float, d: Float, k: Float = 1, yaw: Float = 0)  // screen fraction x, y, distance, scale
        case under(String)                          // a rock chip resting under another object
        case onDial(Float)                          // in the stopwatch groove at this clock angle
    }

    final class Item {
        let e: Entity
        let homeP: SIMD3<Float>, homeS: Float, homeQ: simd_quatf
        var p: SIMD3<Float>, v = SIMD3<Float>.zero, s: Float, sv: Float = 0, q: simd_quatf
        var spin = simd_quatf(angle: 0, axis: [0, 1, 0])   // accumulated rolling
        var goalP = SIMD3<Float>.zero, goalS: Float = 1
        var extraYaw: Float = 0
        init(_ e: Entity, s: Float) {
            self.e = e
            homeP = e.position; homeS = s; homeQ = e.orientation
            p = homeP; self.s = s; q = homeQ
        }
    }

    var flow: OnboardFlow!
    var items: [String: Item] = [:]
    var aspect: Float = 0.46
    let camPos = SIMD3<Float>(0, 0.5, 3.6)
    let fov: Float = 42 * .pi / 180
    var camFwd = SIMD3<Float>(0, 0, -1), camUp = SIMD3<Float>(0, 1, 0), camRight = SIMD3<Float>(1, 0, 0)
    var sub: EventSubscription?
    var time: Double = 0
    var lastBounce = 0
    var morphStart: Double?   // player "Turn on alarms": the ball spins fast and turns into the stopwatch
    // finger lean, same feel as the stopwatch
    var lean = SIMD2<Float>.zero, leanV = SIMD2<Float>.zero, leanGoal = SIMD2<Float>.zero
    var touching = false
    let tap = UIImpactFeedbackGenerator(style: .soft)

    func press(_ d: CGSize) {
        if !touching { touching = true; tap.impactOccurred(intensity: 0.5) }
        leanGoal = [0.35 * tanh(Float(d.width) / 170), 0.35 * tanh(Float(d.height) / 170)]
    }
    func release(_ d: CGSize) {
        touching = false; leanGoal = .zero
        if abs(d.width) + abs(d.height) < 6 { leanV += [0, -2.4] }
    }

    func build(_ content: RealityViewCameraContent, flow: OnboardFlow) async {
        self.flow = flow
        let world = Entity()
        content.add(world)
        if let scene = try? await Entity(named: "Onboarding") {
            world.addChild(scene)
            for n in ["Slab", "Bat", "AmFootball", "Soccer", "Baseball", "Basketball", "Whistle", "ChipW", "ChipB"] {
                guard let e = scene.findEntity(named: n) else { continue }
                world.addChild(e, preservingWorldTransform: true)   // flat, world-space transforms
                items[n] = Item(e, s: e.scale.x)
                if ["Slab", "ChipW", "ChipB"].contains(n) { darken(e) }   // scans read tan in RealityKit; push them to basalt
            }
        }
        if let sw = await Rig.stopwatch() {   // also warms the cache for the home screen
            world.addChild(sw)
            sw.position = [0, 3, -2]; sw.scale = .init(repeating: 0.165)
            items["Stopwatch"] = Item(sw, s: 0.165)
        }

        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = fov * 180 / .pi
        cam.look(at: [0, -0.02, -0.1], from: camPos, relativeTo: nil)
        content.add(cam)
        camFwd = normalize(cam.convert(direction: [0, 0, -1], to: nil))
        camUp = normalize(cam.convert(direction: [0, 1, 0], to: nil))
        camRight = normalize(cross(camFwd, camUp))

        // lighting B: low warm sun from the left, warm rim, soft studio reflections
        if let env = try? await EnvironmentResource(equirectangular: Rig().studioImage()) {
            world.components.set(ImageBasedLightComponent(source: .single(env), intensityExponent: -0.4))
            world.visit { $0.components.set(ImageBasedLightReceiverComponent(imageBasedLight: world)) }
        }
        let sun = DirectionalLight()
        sun.light.color = UIColor(red: 1, green: 0.8, blue: 0.6, alpha: 1)
        sun.light.intensity = 5200
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 5, depthBias: 2)
        sun.look(at: .zero, from: [-6, 2.2, 1.5], relativeTo: nil)
        content.add(sun)
        let fill = DirectionalLight()   // soft warm fill from front right so dark leather still reads
        fill.light.color = UIColor(red: 1, green: 0.86, blue: 0.72, alpha: 1)
        fill.light.intensity = 1400
        fill.look(at: [0, 0.2, 0], from: [2.5, 1.5, 4], relativeTo: nil)
        content.add(fill)
        let rim = DirectionalLight()
        rim.light.color = UIColor(red: 1, green: 0.68, blue: 0.42, alpha: 1)
        rim.light.intensity = 2600
        rim.look(at: .zero, from: [2.5, 2.5, -5], relativeTo: nil)
        content.add(rim)

        sub = content.subscribe(to: SceneEvents.Update.self) { [weak self] e in self?.tick(Float(e.deltaTime)) }
    }

    func darken(_ e: Entity) {
        e.visit { child in
            guard var model = child.components[ModelComponent.self] else { return }
            model.materials = model.materials.map { m in
                guard var pbr = m as? PhysicallyBasedMaterial else { return m }
                pbr.baseColor.tint = UIColor(white: 0.32, alpha: 1)
                return pbr
            }
            child.components.set(model)
        }
    }

    /// Ball → stopwatch: the ball grows to the watch's size and spins up, then swaps for the watch,
    /// which keeps spinning and slows to a stop. Scales are driven by time so the swap is crisp.
    private func morph(_ leanQ: simd_quatf) {
        let on = flow.role == .player && flow.step == 4
        guard on, let ball = items["Basketball"], let sw = items["Stopwatch"] else {
            if morphStart != nil { morphStart = nil; items.values.forEach { $0.extraYaw = 0 } }
            return
        }
        if morphStart == nil {
            morphStart = time
            sw.p = sw.goalP; sw.v = .zero   // the watch appears in place, not from above
        }
        let u = Float(time - morphStart!)
        func ease(_ x: Float) -> Float { let t = min(max(x, 0), 1); return 1 - pow(1 - t, 3) }
        func smooth(_ x: Float) -> Float { let t = min(max(x, 0), 1); return t * t * (3 - 2 * t) }
        let swap = smooth((u - 0.5) / 0.3)
        let ballSize = ball.homeS * 1.375                // ball radius 0.12 → watch case radius 0.165
        ball.s = ballSize * (0.4 + 0.6 * smooth(u / 0.4)) * (1 - swap); ball.sv = 0
        ball.extraYaw = 18 * .pi * ease(u / 1.0)
        sw.s = sw.homeS * swap; sw.sv = 0
        sw.extraYaw = -12 * .pi * (1 - ease((u - 0.5) / 1.2))
        for it in [ball, sw] {
            it.e.scale = .init(repeating: max(it.s, 0.001))
            it.e.orientation = leanQ * simd_quatf(angle: it.extraYaw, axis: [0, 1, 0]) * it.spin * it.q
        }
    }

    /// Point at a screen fraction (0...1 across, 0...1 down) `d` metres in front of the camera.
    func at(_ sx: Float, _ sy: Float, _ d: Float) -> SIMD3<Float> {
        let hy = d * tan(fov / 2), hx = hy * aspect
        return camPos + camFwd * d + camRight * ((sx - 0.5) * 2 * hx) + camUp * ((0.5 - sy) * 2 * hy)
    }

    /// Where every object goes on the current step.
    func targets() -> [String: Target] {
        let gear = ["Slab", "Bat", "AmFootball", "Soccer", "Baseball"]
        var t: [String: Target] = ["ChipW": .home, "ChipB": .home, "Stopwatch": .screen(0.5, -0.8, d: 1.8)]
        gear.forEach { t[$0] = .home }
        t["Basketball"] = .home; t["Whistle"] = .home
        guard flow.step > 0 else { return t }

        gear.forEach { t[$0] = .sink }
        t["Whistle"] = .screen(0.5, 0.41, d: 2.3, k: 1.25, yaw: 0.45); t["ChipW"] = .under("Whistle")
        t["Basketball"] = .screen(0.5, 0.66, d: 2.3, k: 1.05); t["ChipB"] = .under("Basketball")
        guard flow.step > 1, let role = flow.role else { return t }

        if role == .player {
            t["Whistle"] = .screen(0.35, 1.7, d: 2.3); t["ChipW"] = .screen(0.4, 1.8, d: 2.3)   // drops away
            switch flow.step {
            case 2: t["Basketball"] = .screen(0.5, 0.15, d: 2.6, k: 1.0)
            case 3: t["Basketball"] = .screen(0.5, 0.14, d: 3.0, k: 0.9)
            default:
                t["Stopwatch"] = .screen(0.5, 0.27, d: 2.3)
                t["Basketball"] = .screen(0.5, 0.27, d: 2.3)   // same spot: it spins and becomes the stopwatch (see morph)
                t["ChipB"] = .sink
                return t
            }
        } else {
            t["Basketball"] = .screen(1.8, 0.66, d: 2.3); t["ChipB"] = .screen(1.8, 0.75, d: 2.3)   // rolls off
            switch flow.step {
            case 2: t["Whistle"] = .screen(0.5, 0.15, d: 2.6, k: 1.2, yaw: 0.45)
            case 3:
                t["Whistle"] = .screen(0.38, 0.15, d: 2.6, k: 1.1, yaw: 0.45)
                t[flow.sport.entity] = .screen(0.7, 0.14, d: 2.6, k: flow.sport == .baseball ? 2.2 : 0.75,
                                               yaw: flow.sport == .football ? 2.24 : 0)   // sunlit side, away from the scan's club stamp
            case 4:
                t["Whistle"] = .screen(0.82, 0.11, d: 2.6, k: 0.7, yaw: 0.9); t["ChipW"] = .sink
                t["Stopwatch"] = .screen(0.55, 0.26, d: 2.3)
            default:
                t["Whistle"] = .screen(0.5, 0.22, d: 2.0, k: 1.15, yaw: 0.45)
            }
        }
        return t
    }

    func tick(_ dt0: Float) {
        guard flow != nil else { return }
        let dt = min(dt0, 1 / 30)
        time += Double(dt)
        let w: Float = touching ? 14 : 6, z: Float = touching ? 1 : 0.5
        leanV += (w * w * (leanGoal + PhoneTilt.shared.lean(dt) - lean) - 2 * z * w * leanV) * dt
        lean += leanV * dt
        let leanQ = simd_quatf(angle: lean.x, axis: [0, 1, 0]) * simd_quatf(angle: lean.y, axis: [1, 0, 0])

        if flow.bounce != lastBounce {   // a hop for the ball (code typed) or the whistle (shared)
            lastBounce = flow.bounce
            items[flow.role == .coach ? "Whistle" : "Basketball"]?.v.y += 1.1
        }

        let goals = targets()
        // resolve absolute goals first so chips can sit under their object
        for (n, it) in items {
            switch goals[n] ?? .home {
            case .home: it.goalP = it.homeP; it.goalS = it.homeS
            case .sink: it.goalP = it.homeP - [0, 3.0, 0.6]; it.goalS = it.homeS
            case let .screen(x, y, d, k, _):
                let bob = Float(sin(time * 1.3 + Double(n.count))) * 0.008
                it.goalP = at(x, y, d) + [0, bob, 0]; it.goalS = it.homeS * k
            case .under, .onDial: break
            }
        }
        for (n, it) in items {
            if case let .onDial(a) = goals[n], let sw = items["Stopwatch"] {
                let r = 0.71 * sw.goalS   // groove radius, model units are case radius 1
                it.goalP = sw.goalP + [r * sin(a), r * cos(a), 0.4 * sw.goalS]; it.goalS = it.homeS * 0.22
            }
            if case let .under(parent) = goals[n], let p = items[parent] {
                it.goalP = p.goalP - [0, (parent == "Whistle" ? 0.07 : 0.135) * p.goalS / p.homeS, 0.02]; it.goalS = it.homeS * 0.62 * p.goalS / p.homeS
            }
        }
        for (n, it) in items {
            var yaw: Float = 0
            if case let .screen(_, _, _, _, y) = goals[n] { yaw = y }
            let sw: Float = 7.5, sz: Float = 0.8
            it.v += (sw * sw * (it.goalP - it.p) - 2 * sz * sw * it.v) * dt
            it.p += it.v * dt
            it.sv += (sw * sw * (it.goalS - it.s) - 2 * 0.6 * sw * it.sv) * dt
            it.s += it.sv * dt
            if n == "Basketball" || n == "Soccer" {   // balls roll in the direction they travel
                let flat = SIMD3<Float>(it.v.x, 0, it.v.z) + [0, 0, 0.0001]
                let speed = length(it.v)
                if speed > 0.02 { it.spin = simd_quatf(angle: speed * dt / 0.12, axis: normalize(cross([0, 1, 0], flat + [it.v.y * 0.3, 0, 0]))) * it.spin }
            }
            let goalQ = simd_quatf(angle: yaw, axis: [0, 1, 0]) * it.homeQ
            it.q = simd_slerp(it.q, goalQ, min(1, dt * 6))
            it.e.position = it.p
            it.e.scale = .init(repeating: max(it.s, 0.001))
            it.e.orientation = leanQ * simd_quatf(angle: it.extraYaw, axis: [0, 1, 0]) * it.spin * it.q
        }
        morph(leanQ)
    }
}

import SwiftUI
import RealityKit
import AVFoundation

/// Tap a teammate in the list: a drawer with their status, a few stats, and a 3D flashlight.
/// Tapping the flashlight "flashes their phone". Prototype: it strobes the beam and YOUR phone's torch;
/// a real remote flash needs a server and only works in limited cases (see `RemoteFlash` note below).
struct ProfileDrawer: View {
    let mate: Mate
    let session: Session
    @State private var light = Flashlight()
    @State private var flashes = 0

    private var wake: Wake? { session.wake(of: mate.id) }
    private var snoozed: Bool { wake == nil && (mate.snoozeAt.map { session.elapsed >= $0 } ?? false) }
    private var asleep: Bool { wake == nil }
    private var first: String { mate.name.components(separatedBy: " ").first ?? mate.name }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                avatar
                VStack(alignment: .leading, spacing: 3) {
                    Text(mate.name).font(.title2.bold())
                    Text(status).font(.subheadline).foregroundStyle(statusColor)
                }
                Spacer()
            }
            .padding(.top, 28)

            HStack(spacing: 10) {
                stat("Avg wake", fake("6:0", 1...9) + " AM")
                stat("Streak", fake("", 2...9) + " days")
                stat("Last up", fake("", 0...3) + "×")
            }

            RealityView { content in await light.build(content) }
                .frame(height: 230)
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { light.press($0.translation) }
                    .onEnded { v in light.release(v.translation); if abs(v.translation.width) + abs(v.translation.height) < 6 { flash() } })

            Button { flash() } label: {
                Label(asleep ? "Flash \(first)'s Phone" : "\(first) is up", systemImage: "flashlight.on.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(asleep ? .orange : Color(white: 0.3))
            .disabled(!asleep)
            Text("Prototype: flashes your own phone for now.").font(.footnote).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .background(Color(white: 0.07))
        .sensoryFeedback(.impact(weight: .heavy), trigger: flashes)
    }

    private func flash() {
        guard asleep else { return }
        flashes += 1
        light.strobe()
        Torch.strobe()
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(asleep ? (snoozed ? Color.orange : Color(white: 0.25)) : Color.green)
            if let p = mate.photo { Image(uiImage: p).resizable().scaledToFill().clipShape(Circle()).padding(3) }
            else { Text(mate.initials).font(.system(size: 22, weight: .semibold, design: .rounded)) }
        }
        .frame(width: 64, height: 64)
    }

    private var status: String {
        if let w = wake {
            let s = Int(session.alarmClock + w.at)
            return String(format: "Up at %d:%02d:%02d · #%d", (s / 3600 % 12 == 0 ? 12 : s / 3600 % 12), s / 60 % 60, s % 60, w.rank)
        }
        return snoozed ? "Snoozed" : "Still asleep"
    }
    private var statusColor: Color { wake != nil ? .green : snoozed ? .orange : .secondary }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.headline, design: .rounded)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Color(white: 0.12), in: .rect(cornerRadius: 12))
    }

    /// ponytail: stable fake stats per teammate until there's real history
    private func fake(_ prefix: String, _ r: ClosedRange<Int>) -> String {
        let h = mate.id.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
        return prefix + String(r.lowerBound + abs(h) % (r.count))
    }
}

/// Your phone's torch: three quick flashes. No-op where there's no torch (simulator).
enum Torch {
    static func strobe() {
        guard let d = AVCaptureDevice.default(for: .video), d.hasTorch else { return }
        Task {
            for _ in 0..<5 {
                try? d.lockForConfiguration(); d.torchMode = .on; d.unlockForConfiguration()
                try? await Task.sleep(for: .milliseconds(120))
                try? d.lockForConfiguration(); d.torchMode = .off; d.unlockForConfiguration()
                try? await Task.sleep(for: .milliseconds(140))
            }
        }
    }
}

/// A 3D flashlight built from primitives: anodized body, wider head, glowing lens, a beam cone.
@MainActor final class Flashlight {
    private let root = Entity()
    private var lens: ModelEntity?
    private var beam: ModelEntity?
    private var flashUntil: Double = 0
    private var time: Double = 0
    private var sub: EventSubscription?
    var lean = SIMD2<Float>.zero, leanV = SIMD2<Float>.zero, leanGoal = SIMD2<Float>.zero
    var touching = false

    func press(_ d: CGSize) {
        touching = true
        leanGoal = [0.5 * tanh(Float(d.width) / 160), 0.5 * tanh(Float(d.height) / 160)]
    }
    func release(_ d: CGSize) { touching = false; leanGoal = .zero }
    func strobe() { flashUntil = time + 2.0 }

    func build(_ content: RealityViewCameraContent) async {
        var metal = PhysicallyBasedMaterial()
        metal.baseColor = .init(tint: UIColor(red: 0.95, green: 0.42, blue: 0.08, alpha: 1))   // anodized orange
        metal.metallic = 0.85; metal.roughness = 0.32
        var steel = PhysicallyBasedMaterial()
        steel.baseColor = .init(tint: UIColor(white: 0.75, alpha: 1))
        steel.metallic = 1.0; steel.roughness = 0.2

        let body = ModelEntity(mesh: .generateCylinder(height: 0.17, radius: 0.022), materials: [metal])
        let head = ModelEntity(mesh: .generateCylinder(height: 0.055, radius: 0.033), materials: [metal])
        head.position.y = 0.11
        let bezel = ModelEntity(mesh: .generateCylinder(height: 0.008, radius: 0.035), materials: [steel])
        bezel.position.y = 0.139
        let lens = ModelEntity(mesh: .generateCylinder(height: 0.004, radius: 0.029), materials: [UnlitMaterial(color: UIColor(white: 0.25, alpha: 1))])
        lens.position.y = 0.143
        let button = ModelEntity(mesh: .generateBox(size: [0.012, 0.022, 0.01], cornerRadius: 0.003), materials: [steel])
        button.position = [0, 0.03, 0.022]
        var glow = UnlitMaterial(color: UIColor(red: 1, green: 0.93, blue: 0.78, alpha: 1))
        glow.blending = .transparent(opacity: 0.22)
        let beam = ModelEntity(mesh: .generateCone(height: 0.5, radius: 0.16), materials: [glow])
        beam.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])   // apex at the lens, opening outward
        beam.position.y = 0.143 + 0.25
        beam.isEnabled = false
        [body, head, bezel, lens, button, beam].forEach { root.addChild($0) }
        self.lens = lens; self.beam = beam

        let holder = Entity()
        holder.addChild(root)
        holder.orientation = simd_quatf(angle: -0.95, axis: [0, 0, 1]) * simd_quatf(angle: 0.35, axis: [1, 0, 0])  // lens up and to the right
        holder.position = [-0.02, -0.03, 0]
        content.add(holder)

        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = 34
        cam.position = [0, 0, 0.62]
        content.add(cam)
        if let env = try? await EnvironmentResource(equirectangular: Rig().studioImage()) {
            holder.components.set(ImageBasedLightComponent(source: .single(env), intensityExponent: 1.2))
            holder.visit { $0.components.set(ImageBasedLightReceiverComponent(imageBasedLight: holder)) }
        }
        let key = DirectionalLight()
        key.light.color = UIColor(red: 1, green: 0.86, blue: 0.72, alpha: 1)
        key.light.intensity = 9000
        key.look(at: .zero, from: [-1, 0.8, 1.2], relativeTo: nil)
        content.add(key)
        let rim = DirectionalLight()
        rim.light.intensity = 5000
        rim.look(at: .zero, from: [1.2, 0.4, -0.8], relativeTo: nil)
        content.add(rim)
        sub = content.subscribe(to: SceneEvents.Update.self) { [weak self] e in self?.tick(Float(e.deltaTime)) }
    }

    private func tick(_ dt0: Float) {
        let dt = min(dt0, 1 / 30)
        time += Double(dt)
        let w: Float = touching ? 14 : 6, z: Float = touching ? 1 : 0.5
        leanV += (w * w * (leanGoal + PhoneTilt.shared.lean(dt) * 1.5 - lean) - 2 * z * w * leanV) * dt
        lean += leanV * dt
        root.orientation = simd_quatf(angle: lean.x, axis: [0, 1, 0]) * simd_quatf(angle: lean.y, axis: [1, 0, 0])
        // strobe: beam and lens blink three times
        let on = time < flashUntil && Int((flashUntil - time) / 0.2) % 2 == 0
        beam?.isEnabled = on
        lens?.model?.materials = [UnlitMaterial(color: on ? UIColor(red: 1, green: 0.95, blue: 0.82, alpha: 1) : UIColor(white: 0.25, alpha: 1))]
    }
}

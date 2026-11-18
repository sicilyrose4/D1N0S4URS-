import SwiftUI
import AVFoundation

/// Tap a teammate in the list: a drawer with their status, a few stats, and a big flashlight button.
/// Tapping it "flashes their phone". Prototype: it strobes the button and YOUR phone's torch;
/// a real remote flash needs a server.
struct ProfileDrawer: View {
    let mate: Mate
    let session: Session
    @State private var flashes = 0
    @State private var flashUntil = Date.distantPast

    private var status: MateStatus { session.status(mate) }
    private var asleep: Bool { status != .up }
    private var first: String { mate.name.components(separatedBy: " ").first ?? mate.name }

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 16) {
                avatar
                VStack(alignment: .leading, spacing: 6) {
                    Text(mate.name).font(.display(34)).textCase(.uppercase).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    HStack(spacing: 6) {
                        Image(status.icon).renderingMode(.template).resizable().frame(width: 18, height: 18)
                        Text(statusText).font(.gothamBold(15))
                    }
                    .foregroundStyle(status == .waiting ? Color.white.opacity(0.6) : status.color == Clique.moss ? Clique.green.opacity(0.6) : status.color)
                }
                Spacer()
            }
            .padding(.top, 32)

            HStack(spacing: 10) {
                stat("Avg wake", fake("6:0", 1...9) + " AM")
                stat("Streak", fake("", 2...9) + " days")
                stat("Last up", fake("", 0...3) + "×")
            }

            flashlight
                .frame(maxHeight: .infinity)

            Button(asleep ? "Flash \(first)'s Phone" : "\(first) is up") { flash() }
                .buttonStyle(CliqueButtonStyle(prominent: asleep, size: 26))
                .disabled(!asleep)
            Text("Prototype: flashes your own phone for now.").font(.gotham(13)).foregroundStyle(Clique.stone)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .background(Clique.ink)
        .sensoryFeedback(.impact(weight: .heavy), trigger: flashes)
    }

    private func flash() {
        guard asleep else { return }
        flashes += 1
        flashUntil = .now.addingTimeInterval(2)
        Torch.strobe()
    }

    /// A big round lamp. While flashing it strobes white and throws rings outward, like the wake-up screen.
    private var flashlight: some View {
        TimelineView(.animation) { tl in
            let left = flashUntil.timeIntervalSince(tl.date)
            let on = left > 0 && Int(left / 0.2) % 2 == 0
            ZStack {
                if left > 0 {
                    ForEach(0..<3, id: \.self) { k in
                        let p = (((2 - left) / 0.7 + Double(k) / 3).truncatingRemainder(dividingBy: 1))
                        Circle().stroke(Clique.green, lineWidth: 4 - 3 * p)
                            .frame(width: 170 + 170 * p, height: 170 + 170 * p)
                            .opacity(1 - p)
                    }
                }
                Circle().stroke(Clique.green.opacity(asleep ? 1 : 0.3), lineWidth: 2).frame(width: 210, height: 210)
                Circle().fill(on ? Color.white : Clique.panel).frame(width: 170, height: 170)
                    .shadow(color: on ? .white.opacity(0.8) : .clear, radius: 40)
                Image(systemName: on ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(on ? Clique.ink : asleep ? Clique.green : Clique.stone)
            }
            .frame(maxWidth: .infinity)
        }
        .contentShape(Circle())
        .onTapGesture(perform: flash)
        .accessibilityHidden(true)   // the button below does the same thing
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(status.color)
            if let p = mate.photo { Image(uiImage: p).resizable().scaledToFill().clipShape(Circle()).padding(4) }
            else { Text(mate.initials).font(.gothamBold(24)).foregroundStyle(status == .up ? Clique.ink : .white) }
        }
        .frame(width: 72, height: 72)
    }

    private var statusText: String {
        if let w = session.wake(of: mate.id) {
            let s = Int(session.alarmClock + w.at)
            return String(format: "Up at %d:%02d:%02d · #%d", (s / 3600 % 12 == 0 ? 12 : s / 3600 % 12), s / 60 % 60, s % 60, w.rank)
        }
        switch status {
        case .snoozing: return "Snoozing"
        case .waiting: return "Alarm hasn't rung yet"
        default: return "Still asleep"
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.gothamBold(17)).monospacedDigit().foregroundStyle(Clique.green)
            Text(label).font(.gotham(12)).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Clique.panel)
    }

    /// ponytail: stable fake stats per teammate until there's real history
    private func fake(_ prefix: String, _ r: ClosedRange<Int>) -> String {
        let h = mate.id.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
        return prefix + String(r.lowerBound + abs(h) % (r.count))
    }
}

/// Your phone's torch: quick flashes. No-op where there's no torch (simulator).
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

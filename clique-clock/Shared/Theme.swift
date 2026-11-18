import SwiftUI

// Quin's 2D look, from the Figma "1/wake up screen" and "1/alarm demo" frames.
// Shared by the app and the widgets.

enum Clique {
    static let ink = Color(hex: 0x151515)      // screen background
    static let panel = Color(hex: 0x2D2D2D)    // raised surfaces, the wake-up bar
    static let green = Color(hex: 0x4CE232)    // awake, primary
    static let moss = Color(hex: 0x184610)     // snoozing
    static let stone = Color(hex: 0x5B5B5B)    // not rung yet, dial rim
    static let face = Color(hex: 0xA7A7A7)     // dial face
    static let blood = Color(hex: 0x990909)    // still asleep, the hand
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension Font {
    /// The big block type ("WAKE UP", the time). Fixed size so it never outgrows the layout.
    static func display(_ size: CGFloat) -> Font { .custom("Basketball", fixedSize: size) }
    static func gothamBold(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font { .custom("Gotham-Bold", size: size, relativeTo: style) }
    static func gothamMedium(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font { .custom("Gotham-Medium", size: size, relativeTo: style) }
    static func gotham(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font { .custom("Gotham-Book", size: size, relativeTo: style) }
}

/// Square-edged block button: green fill with dark display type, or a dark panel with green type.
struct CliqueButtonStyle: ButtonStyle {
    var prominent = true
    var size: CGFloat = 30
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(size))
            .textCase(.uppercase)
            .lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(prominent ? Clique.ink : Clique.green)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 12)
            .background(prominent ? Clique.green : Clique.panel)
            .opacity(enabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CliqueButtonStyle {
    static var clique: CliqueButtonStyle { CliqueButtonStyle() }
    static var cliqueQuiet: CliqueButtonStyle { CliqueButtonStyle(prominent: false) }
}

/// The snoozing bar: a block with its bottom-right corner cut off.
struct ChamferBar: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + r.width * 0.75, y: r.maxY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.closeSubpath()
        }
    }
}

/// Equilateral triangle pointing up; rotate it to point elsewhere.
struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

/// The wake-up rings: a thick inner ring and thin outer ring that breathe, plus ripples that keep
/// expanding out of the inner ring and fading. `intensity` 0...1 dims everything for quieter screens.
struct Ripples: View {
    var inner: CGFloat = 504
    var outer: CGFloat = 710
    var period: Double = 1.6
    var intensity: Double = 1

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let breathe = sin(t * 2 * .pi / period)
            ZStack {
                ForEach(0..<3, id: \.self) { k in
                    let p = ((t / period + Double(k) / 3).truncatingRemainder(dividingBy: 1))
                    Circle()
                        .stroke(Clique.green, lineWidth: 5 - 4 * p)
                        .frame(width: inner + (outer * 1.5 - inner) * p, height: inner + (outer * 1.5 - inner) * p)
                        .opacity((1 - p) * 0.55 * intensity)
                }
                Circle().stroke(Clique.green, lineWidth: 5)
                    .frame(width: inner, height: inner)
                    .scaleEffect(1 + 0.025 * breathe)
                    .opacity(intensity)
                Circle().stroke(Clique.green, lineWidth: 2)
                    .frame(width: outer, height: outer)
                    .scaleEffect(1 + 0.03 * sin(t * 2 * .pi / period - 0.9))
                    .opacity(intensity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

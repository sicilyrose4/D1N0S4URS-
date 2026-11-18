import SwiftUI
import PhotosUI

// Onboarding, 2D. Green rings ripple behind the welcome, then each step is big block type over the dark screen.
// Player: Welcome, Coach or player, Name, Team code, Alarms.  Coach: Welcome, Coach or player, Team, Times, Share code.

enum Role { case coach, player }

enum Sport: String, CaseIterable, Identifiable {
    case basketball = "Basketball", football = "Football", baseball = "Baseball", soccer = "Soccer"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .basketball: "basketball.fill"; case .football: "football.fill"; case .baseball: "baseball.fill"; case .soccer: "soccerball" }
    }
}

@MainActor @Observable final class OnboardFlow {
    var step = 0
    var role: Role?
    var sport = Sport.basketball
    var count: Int { role == .coach ? 6 : 5 }   // coach adds team, times, code after the name
}

struct Onboarding: View {
    @Environment(AppState.self) private var app
    @State private var flow = OnboardFlow()
    @State private var code = ""
    @State private var codeFailed = false
    @State private var teamName = ""
    @State private var wake = Self.time(5, 30)
    @State private var practice = Self.time(6, 30)
    @State private var days: Set<Int> = [2, 4, 6]
    @State private var teamCode = ""
    @FocusState private var focus: Int?
    @State private var photoPick: PhotosPickerItem?

    var body: some View {
        ZStack {
            Clique.ink.ignoresSafeArea()
            Ripples(inner: 300, outer: 440, period: 2.4, intensity: flow.step == 0 ? 1 : 0.18)
                .offset(y: flow.step == 0 ? -60 : -240)
                .ignoresSafeArea()
            screen.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topLeading) {
            if flow.step > 0 {
                Button { go(flow.step - 1) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Clique.green)
                        .frame(width: 44, height: 44)
                        .background(Clique.panel, in: Circle())
                }
                .padding(.leading, 20).padding(.top, 4)
                .accessibilityLabel("Back")
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.6), value: flow.step)
        .sensoryFeedback(.selection, trigger: flow.step)
    }

    // MARK: Screens

    @ViewBuilder private var screen: some View {
        switch flow.step {
        case 0:
            page(top: 0, centered: true) {
                VStack(spacing: 14) {
                    Text("Clique Clock").font(.display(64)).textCase(.uppercase).foregroundStyle(Clique.green)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .modifier(Throb())
                    Text("Rise as a team. Don't be last.").font(.gotham(18)).foregroundStyle(.white)
                }
            } cta: { cta("Get Started") { go(1) } }
        case 1:
            page(top: 90) {
                title("Are you a", "Coach or player?", nil)
                VStack(spacing: 25) {
                    roleCard("Coach", symbol: "whistle", note: "Set the time. Watch them rise.") { pick(.coach) }
                    roleCard("Player", symbol: "figure.run", note: "Join with your coach's code.") { pick(.player) }
                }
                .padding(.top, 20)
            } cta: { EmptyView() }
        case 2:
            page(top: 90) {
                title(nil, "What's your name?", nil)
                @Bindable var app = app
                VStack(spacing: 0) {
                    TextField("First name", text: $app.first).textContentType(.givenName).focused($focus, equals: 0)
                        .submitLabel(.next).onSubmit { focus = 1 }.padding(16)
                    Rectangle().fill(Clique.ink).frame(height: 2)
                    TextField("Last name", text: $app.last).textContentType(.familyName).focused($focus, equals: 1)
                        .submitLabel(.continue).padding(16)
                        .onSubmit { if !app.first.isBlank && !app.last.isBlank { go(3) } }
                }
                .font(.gothamBold(18))
                .background(Clique.panel)
                HStack(spacing: 6) {
                    Text("Your team sees your initials.").foregroundStyle(.white.opacity(0.6))
                    PhotosPicker(app.photo == nil ? "Add Photo" : "Change Photo", selection: $photoPick, matching: .images)
                        .foregroundStyle(Clique.green)
                }
                .font(.gotham(14))
                .onChange(of: photoPick) { _, item in
                    Task { if let data = try? await item?.loadTransferable(type: Data.self) { app.photo = UIImage(data: data) } }
                }
            } cta: { cta("Continue", enabled: !app.first.isBlank && !app.last.isBlank) { go(3) } }
        case 3 where flow.role == .player:
            page(top: 90) {
                title(nil, "Join your team", codeFailed ? "No team found. Prototype code: \(AppState.demoCode)" : "Prototype code: \(AppState.demoCode)")
                codeBoxes
            } cta: { cta("Join", enabled: code.count == 6) {
                if app.join(code: code) { go(4) } else { codeFailed = true }
            } }
        case 4 where flow.role == .player:
            page(top: 70) {
                MiniDial().padding(.bottom, 20)
                title(nil, "Turn on alarms", "Your coach sets the time.")
            } cta: {
                VStack(spacing: 8) {
                    cta("Allow Alarms") { Task { await app.requestPermissions(); finish() } }
                    Button("Not Now") { finish() }.font(.gothamBold(16)).foregroundStyle(.white.opacity(0.6)).padding(.vertical, 6)
                }
            }
        case 3:
            page(top: 90) {
                title(nil, "Name your team", nil)
                TextField("Westside Warriors", text: $teamName).focused($focus, equals: 3).submitLabel(.done)
                    .font(.gothamBold(18))
                    .padding(16).background(Clique.panel)
                HStack(spacing: 8) {
                    ForEach(Sport.allCases) { s in
                        let on = flow.sport == s
                        Button { flow.sport = s } label: {
                            VStack(spacing: 6) {
                                Image(systemName: s.symbol).font(.system(size: 20))
                                Text(s.rawValue).font(.gothamMedium(11))
                            }
                            .foregroundStyle(on ? Clique.ink : Clique.green)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(on ? Clique.green : Clique.panel)
                            .scaleEffect(on ? 1.05 : 1)
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(duration: 0.3, bounce: 0.5), value: on)
                    }
                }
            } cta: { cta("Continue", enabled: !teamName.isBlank) { go(4) } }
        case 4:
            page(top: 90) {
                title(nil, "Set the times", nil)
                VStack(spacing: 0) {
                    DatePicker("Wake up", selection: $wake, displayedComponents: .hourAndMinute).padding(.horizontal, 16).padding(.vertical, 8)
                    Rectangle().fill(Clique.ink).frame(height: 2)
                    DatePicker("Practice", selection: $practice, displayedComponents: .hourAndMinute).padding(.horizontal, 16).padding(.vertical, 8)
                }
                .font(.gothamBold(17))
                .background(Clique.panel)
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { d in
                        let on = days.contains(d)
                        Button { if on { days.remove(d) } else { days.insert(d) } } label: {
                            Text(Calendar.current.veryShortWeekdaySymbols[d - 1]).font(.gothamBold(15))
                                .frame(width: 40, height: 40)
                                .background(on ? Clique.green : Clique.panel, in: Circle())
                                .foregroundStyle(on ? Clique.ink : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } cta: { cta("Continue", enabled: !days.isEmpty) { makeTeam(); go(5) } }
        default:
            page(top: 0, centered: true) {
                VStack(spacing: 10) {
                    Text("Your team code").font(.gothamBold(16)).foregroundStyle(.white.opacity(0.7))
                    Text(teamCode).font(.display(64)).tracking(4).foregroundStyle(Clique.green).modifier(Throb())
                    Text("Players join \(teamName) with this.").font(.gotham(16)).foregroundStyle(.white.opacity(0.7))
                }
            } cta: {
                VStack(spacing: 8) {
                    ShareLink(item: "Join \(teamName) on Clique Clock. Code: \(teamCode)") { Text("Share Code") }
                        .buttonStyle(.clique)
                    Button("Done") { finish() }.font(.gothamBold(16)).foregroundStyle(.white.opacity(0.6)).padding(.vertical, 6)
                }
            }
        }
    }

    /// Content from `top` (or centred), then page dots and the button pinned to the bottom.
    private func page<C: View, B: View>(top: CGFloat, centered: Bool = false, @ViewBuilder content: () -> C, @ViewBuilder cta: () -> B) -> some View {
        VStack(spacing: 18) {
            if centered { Spacer() } else { Spacer().frame(height: top) }
            content()
            Spacer(minLength: 0)
            dots
            cta()
        }
        .padding(.horizontal, 25)
        .padding(.bottom, 12)
        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 24)), removal: .opacity))
        .id(flow.step)
    }

    private func title(_ eyebrow: String?, _ h1: String, _ sub: String?) -> some View {
        VStack(spacing: 10) {
            if let eyebrow { Text(eyebrow).font(.gothamBold(17)).foregroundStyle(.white.opacity(0.7)) }
            Text(h1).font(.display(44)).textCase(.uppercase).foregroundStyle(Clique.green)
                .multilineTextAlignment(.center).minimumScaleFactor(0.6)
            if let sub { Text(sub).font(.gotham(17)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity)
    }

    /// Slide dots: one per screen, the current one a long green bar.
    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<flow.count, id: \.self) { i in
                Capsule().fill(i == flow.step ? Clique.green : Clique.stone)
                    .frame(width: i == flow.step ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.4), value: flow.step)
        .accessibilityElement().accessibilityLabel("Step \(flow.step + 1) of \(flow.count)")
    }

    private func cta(_ label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.clique)
            .disabled(!enabled)
    }

    /// A big block like the homepage cards: a green bar on the left, label in block type.
    private func roleCard(_ label: String, symbol: String, note: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Rectangle().fill(Clique.green).frame(width: 15)
                VStack(alignment: .leading, spacing: 6) {
                    Text(label).font(.display(44)).textCase(.uppercase).foregroundStyle(Clique.green)
                    Text(note).font(.gotham(14)).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: symbol).font(.system(size: 30, weight: .semibold)).foregroundStyle(Clique.green)
                    .padding(.trailing, 22)
            }
            .frame(height: 120)
            .background(Clique.panel)
        }
        .buttonStyle(PressScale())
    }

    private var codeBoxes: some View {
        ZStack {
            TextField("", text: $code).focused($focus, equals: 2).keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters).autocorrectionDisabled().opacity(0.01)
                .onChange(of: code) { _, v in
                    code = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                    codeFailed = false
                    if code.count == 6 {   // full code: join without needing the button
                        Task { try? await Task.sleep(for: .milliseconds(350)); if code.count == 6, app.join(code: code) { go(4) } else if code.count == 6 { codeFailed = true } }
                    }
                }
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    let ch = i < code.count ? String(Array(code)[i]) : ""
                    Text(ch).font(.display(36)).foregroundStyle(codeFailed ? Clique.blood : Clique.green)
                        .frame(maxWidth: .infinity).frame(height: 60)
                        .background(Clique.panel)
                        .overlay(alignment: .bottom) {   // the next box to fill gets a green underline
                            Rectangle().fill(i == code.count ? Clique.green : .clear).frame(height: 4)
                        }
                        .scaleEffect(ch.isEmpty ? 1 : 1.04)
                        .animation(.spring(duration: 0.25, bounce: 0.6), value: ch)
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

/// Slow scale pulse, like WAKE UP.
struct Throb: ViewModifier {
    @State private var big = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(big ? 1.05 : 1)
            .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever()) { big = true } }
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

/// The home dial in miniature: a sweeping hand and three badges landing, for the "Turn on alarms" step.
private struct MiniDial: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let sweep = (t * 60).truncatingRemainder(dividingBy: 360)   // one turn every 6 s
            ZStack {
                Circle().fill(Clique.stone)
                Circle().fill(Clique.face).padding(5)
                ForEach([20.0, 120, 230], id: \.self) { a in
                    let shown = sweep > a
                    Image("shield_tick").renderingMode(.template).resizable()
                        .foregroundStyle(Clique.green)
                        .frame(width: 20, height: 20)
                        .scaleEffect(shown ? 1 : 0.2)
                        .opacity(shown ? 1 : 0)
                        .offset(y: -78)
                        .rotationEffect(.degrees(a))
                        .animation(.spring(duration: 0.5, bounce: 0.5), value: shown)
                }
                Hand().fill(Clique.blood).frame(width: 4, height: 80).offset(y: -40).rotationEffect(.degrees(sweep))
                Circle().fill(Clique.stone).frame(width: 16, height: 16)
            }
            .frame(width: 190, height: 190)
        }
        .accessibilityHidden(true)
    }
}

private extension String { var isBlank: Bool { trimmingCharacters(in: .whitespaces).isEmpty } }

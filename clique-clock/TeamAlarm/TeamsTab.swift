import SwiftUI

struct TeamsTab: View {
    @Environment(AppState.self) private var app
    @State private var joining = false

    var body: some View {
        NavigationStack {
            List {
                if app.teams.isEmpty {
                    ContentUnavailableView("No Teams", systemImage: "person.3", description: Text("Join with a code from your coach."))
                }
                ForEach(app.teams) { team in
                    NavigationLink(value: team) { TeamRow(team: team) }
                }
            }
            .navigationTitle("Teams")
            .navigationDestination(for: Team.self) { TeamDetail(team: $0) }
            .toolbar {
                Button { joining = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Join Team")
            }
            .sheet(isPresented: $joining) { JoinSheet() }
            .animation(.snappy, value: app.teams)
        }
    }
}

private struct TeamRow: View {
    let team: Team
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: team.symbol)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(Color(white: 0.18), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(team.name).font(.headline)
                Text("\(team.timeText) · \(team.daysText)").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TeamDetail: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let team: Team
    @State private var confirmLeave = false
    @AppStorage("coachMode") private var coachMode = false
    private var live: Team { app.teams.first { $0.id == team.id } ?? team }  // reflects coach edits

    var body: some View {
        List {
            Section {
                VStack(spacing: 4) {
                    Text(live.timeText).font(.system(size: 56, weight: .thin, design: .rounded).monospacedDigit())
                    Text("\(live.daysText) · Practice \(live.practiceText)").foregroundStyle(.secondary)
                    if !coachMode {
                        HStack(spacing: 4) { Image(systemName: "lock.fill"); Text("Set by \(team.coach)") }
                            .font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            if coachMode, let i = app.teams.firstIndex(where: { $0.id == team.id }) {
                Section("Coach") {  // prototype stand-in for the coach's own app
                    DatePicker("Wake Up", selection: time(i, \.hour, \.minute), displayedComponents: .hourAndMinute)
                    DatePicker("Practice", selection: time(i, \.practiceHour, \.practiceMinute), displayedComponents: .hourAndMinute)
                }
            }
            Section("Coach's Rule") {
                Label(team.rule, systemImage: "figure.run")
            }
            Section("\(team.members.count + 1) Members") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                    VStack(spacing: 4) {
                        AvatarView(initials: app.initials, state: .up, isYou: true, size: 44, photo: app.photo)
                        Text("You").font(.caption2).foregroundStyle(.secondary)
                    }
                    ForEach(team.members) { m in
                        VStack(spacing: 4) {
                            AvatarView(initials: m.initials, state: .asleep, size: 44)
                            Text(m.first).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            Section {
                Button("Leave Team", role: .destructive) { confirmLeave = true }
                    .frame(maxWidth: .infinity)
            } footer: {
                Text("You'll need a new code from \(team.coach) to rejoin.")
            }
        }
        .navigationTitle(team.name)
        .onDisappear { if coachMode { Task { await app.scheduleAlarms() } } }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Leave \(team.name)?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave \(team.name)", role: .destructive) {
                dismiss()
                app.leave(team)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(app.teams.count == 1
                 ? "This is your only team. You won't get any alarms until you join another."
                 : "You'll stop getting the \(team.timeText) alarm and leave the team's rankings.")
        }
    }
}

extension TeamDetail {
    /// Binds a DatePicker to an hour + minute pair on the live team.
    func time(_ i: Int, _ h: WritableKeyPath<Team, Int>, _ m: WritableKeyPath<Team, Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: app.teams[i][keyPath: h], minute: app.teams[i][keyPath: m])) ?? .now
        } set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            app.teams[i][keyPath: h] = c.hour ?? 0
            app.teams[i][keyPath: m] = c.minute ?? 0
        }
    }
}

private struct JoinSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var failed = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("ABC123", text: $code)
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .padding(.vertical, 14)
                    .background(Color(white: 0.11), in: .rect(cornerRadius: 14))
                    .onChange(of: code) { _, v in code = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6)); failed = false }
                Text(failed ? "No team found for that code." : "Get the 6-character code from your coach.")
                    .font(.footnote).foregroundStyle(failed ? .red : .secondary)
                Spacer()
            }
            .padding(24)
            .navigationTitle("Join Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") { if app.join(code: code) { dismiss() } else { failed = true } }
                        .disabled(code.count != 6)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}

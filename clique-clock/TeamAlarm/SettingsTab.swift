import SwiftUI
import PhotosUI

struct SettingsTab: View {
    @Environment(AppState.self) private var app
    @State private var pick: PhotosPickerItem?
    @AppStorage("sound") private var sound = "Radar"
    @AppStorage("vibrate") private var vibrate = true
    @AppStorage("teammateAlerts") private var teammateAlerts = true
    @AppStorage("liveActivity") private var liveActivity = true
    @AppStorage("coachMode") private var coachMode = false

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            AvatarView(initials: app.initials, state: .up, size: 88, photo: app.photo)
                            PhotosPicker(app.photo == nil ? "Add Photo" : "Change Photo", selection: $pick, matching: .images)
                                .font(.subheadline)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section("Name") {
                    TextField("First name", text: $app.first)
                    TextField("Last name", text: $app.last)
                }
                .listRowBackground(Clique.panel)
                Section("Alarm") {
                    Picker("Sound", selection: $sound) {
                        ForEach(["Radar", "Apex", "Beacon", "Chimes"], id: \.self) { Text($0) }
                    }
                    Toggle("Vibration", isOn: $vibrate)
                }
                .listRowBackground(Clique.panel)
                Section {
                    Toggle("Teammate Wake-Ups", isOn: $teammateAlerts)
                    Toggle("Live Activity", isOn: $liveActivity)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Your team always sees when you snooze.")
                }
                .listRowBackground(Clique.panel)
                Section {
                    Toggle("Coach Mode", isOn: $coachMode)
                    Button("Send Test Notification") { app.notify("Basketball", "Maya is up. 3 of 12 up.") }
                    Button("Test Alarm in 1 Minute") { Task { await app.testAlarm() } }
                    Button("Replay Onboarding") { app.onboarded = false }
                } header: {
                    Text("Prototype")
                } footer: {
                    if let e = app.lastError { Text(e) }
                }
                .listRowBackground(Clique.panel)
            }
            .scrollContentBackground(.hidden)
            .background(Clique.ink)
            .navigationTitle("Settings")
            .onChange(of: pick) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) { app.photo = UIImage(data: data) }
                }
            }
        }
    }
}

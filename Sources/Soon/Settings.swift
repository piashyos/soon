import EventKit
import ServiceManagement
import SwiftUI

/// Every setting lives in UserDefaults (defaults registered in App); the app reacts via didChangeNotification.
struct SettingsView: View {
    let calendars: [EKCalendar]
    let sendTest: @MainActor () -> Void

    @AppStorage("language") private var language = "system"
    @AppStorage("titleLength") private var titleLength = 20
    @AppStorage("notify10") private var notify10 = true
    @AppStorage("notify1") private var notify1 = true
    @AppStorage("notifyAll") private var notifyAll = false
    @State private var hidden = Set(UserDefaults.standard.stringArray(forKey: "hiddenCalendars") ?? [])
    @State private var login = SMAppService.mainApp.status == .enabled
    @State private var allowed: Bool?

    var body: some View {
        // `language` is read here, so switching it re-renders every L() below
        let _ = language
        Form {
            Section(L("General")) {
                Picker(L("Language"), selection: $language) {
                    Text(L("System")).tag("system")
                    Text("English").tag("en")
                    Text("Русский").tag("ru")
                }
                Toggle(L("Launch at Login"), isOn: Binding(get: { login }, set: setLogin))
                Picker(L("Title length in menu bar"), selection: $titleLength) {
                    Text(L("Hide title")).tag(0)
                    ForEach([10, 15, 20, 25, 30, 40], id: \.self) { Text(L("%d characters", $0)).tag($0) }
                }
            }

            Section(L("Notifications")) {
                if allowed == false {
                    Label(L("Notifications for Soon are turned off in System Settings"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Toggle(L("10 minutes before"), isOn: $notify10)
                Toggle(L("1 minute before"), isOn: $notify1)
                Toggle(L("All events, not only calls"), isOn: $notifyAll)
                HStack {
                    Button(L("Send Test Notification"), action: sendTest)
                    Spacer()
                    Button(L("System Notification Settings…")) {
                        open("x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(Bundle.main.bundleIdentifier ?? "")")
                    }
                }
            }

            if !calendars.isEmpty {
                Section(L("Calendars")) {
                    ForEach(calendars, id: \.calendarIdentifier) { c in
                        Toggle(isOn: visible(c.calendarIdentifier)) {
                            HStack {
                                Circle().fill(Color(nsColor: c.color)).frame(width: 10, height: 10)
                                Text(c.title)
                                Text(c.source.title).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 560)
        // re-check when coming back from System Settings
        .task { allowed = await notificationsAllowed() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { allowed = await notificationsAllowed() }
        }
    }

    private func visible(_ id: String) -> Binding<Bool> {
        Binding(get: { !hidden.contains(id) }, set: { on in
            if on { hidden.remove(id) } else { hidden.insert(id) }
            UserDefaults.standard.set(Array(hidden), forKey: "hiddenCalendars")
        })
    }

    private func setLogin(_ on: Bool) {
        let app = SMAppService.mainApp
        do { if on { try app.register() } else { try app.unregister() } } catch { NSLog("Soon: login item \(error)") }
        if app.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        login = app.status == .enabled
    }
}

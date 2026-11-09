import AppKit
import EventKit
import UserNotifications

func notificationsAllowed() async -> Bool {
    await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
}

extension App: UNUserNotificationCenterDelegate {
    func setUpNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategories()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            NSLog("Soon: notifications granted=\(granted) error=\(String(describing: error))")
            Task { @MainActor in self.checkNotificationAccess() }
        }
        // leftovers from a crash/kill: re-add if still wanted, otherwise the diff removes them
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier)
            Task { @MainActor in self.reschedule(ids) }
        }
    }

    /// Called every tick: when access flips to allowed (prompt answered, or enabled later in
    /// System Settings), re-add everything that was scheduled while it was denied.
    func checkNotificationAccess() {
        Task {
            let ok = await notificationsAllowed()
            if ok && !notificationsWereAllowed { reschedule(Array(scheduled.keys)) }
            notificationsWereAllowed = ok
        }
    }

    /// Forget the signatures of these ids so the next diff re-adds (or removes) them.
    func reschedule(_ ids: [String]) {
        for id in ids { scheduled[id] = "" }
        refresh()
    }

    func applicationWillTerminate(_: Notification) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Re-run on language change so the "Join" button title follows.
    func registerCategories() {
        let join = UNNotificationAction(identifier: "join", title: L("Join call"), options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: "call", actions: [join], intentIdentifiers: []),
        ])
    }

    /// Pre-schedules 10/1-minute reminders for the next 24h. Diff-based: an unchanged
    /// request is never removed and re-added, so one about to fire can't be lost.
    func scheduleNotifications(now: Date) {
        let d = UserDefaults.standard
        let offsets = [10, 1].filter { d.bool(forKey: "notify\($0)") }
        let everyEvent = d.bool(forKey: "notifyAll")

        var wanted: [String: (sig: String, request: UNNotificationRequest)] = [:]
        for e in events where e.startDate < now + 86400 && (everyEvent || e.meeting != nil) {
            for m in offsets {
                let fire = e.startDate - TimeInterval(m * 60)
                guard fire > now else { continue }
                // recurring occurrences share identifiers, so the start time is part of the id
                let id = "\(e.calendarItemIdentifier)|\(e.startDate.timeIntervalSince1970)|\(m)"
                let c = content(for: e, minutes: m)
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
                let request = UNNotificationRequest(identifier: id, content: c,
                                                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
                wanted[id] = ("\(fire)|\(c.title)|\(c.body)|\(c.userInfo["url"] ?? "")", request)
            }
        }

        let center = UNUserNotificationCenter.current()
        let stale = scheduled.keys.filter { wanted[$0] == nil }
        if !stale.isEmpty { center.removePendingNotificationRequests(withIdentifiers: stale) }
        for (id, w) in wanted where scheduled[id] != w.sig {
            center.add(w.request)
            NSLog("Soon: scheduled \(w.request.content.title) — \(w.request.content.body)")
        }
        scheduled = wanted.mapValues(\.sig)
    }

    func content(for e: EKEvent, minutes: Int) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = e.title ?? ""
        c.body = L(minutes == 1 ? "Starts in 1 minute" : "Starts in 10 minutes") + " · " + time(e.startDate)
        c.sound = .default
        if let m = e.meeting {
            c.subtitle = m.service
            c.categoryIdentifier = "call"
            c.userInfo = ["url": m.url.absoluteString]
        }
        return c
    }

    /// Fires now, with a Join button pointing at the next call (or the Meet home page).
    func sendTestNotification() {
        let c = UNMutableNotificationContent()
        c.title = L("Test notification")
        c.body = L("Starts in 1 minute")
        c.sound = .default
        c.categoryIdentifier = "call"
        c.userInfo = ["url": events.lazy.compactMap(\.meeting).first?.url.absoluteString ?? "https://meet.google.com/"]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test-\(UUID())", content: c, trigger: nil))
    }

    nonisolated func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Both the "Join" button and a click on the notification open the call.
    nonisolated func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier,
              let s = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: s) else { return }
        await MainActor.run { _ = NSWorkspace.shared.open(url) }
    }
}

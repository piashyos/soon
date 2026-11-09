import AppKit
import EventKit
import SwiftUI

/// NSMenuItem that runs a closure.
@MainActor
final class Action: NSMenuItem {
    private var run: @MainActor () -> Void = {}

    convenience init(_ title: String, symbol: String? = nil, key: String = "", run: @escaping @MainActor () -> Void) {
        self.init(title: title, action: #selector(fire), keyEquivalent: key)
        self.run = run
        target = self
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
    }

    @objc private func fire() { run() }
}

extension EKEvent {
    var meeting: Meeting? { findMeeting(in: [url?.absoluteString, location, notes]) }
    var declined: Bool { attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined }
    /// All-day or 24h+: listed in the menu, never in the status bar.
    var isLong: Bool { isAllDay || endDate.timeIntervalSince(startDate) >= 86400 }
}

func bar(_ color: NSColor?) -> NSImage {
    let color = color ?? .controlAccentColor
    return NSImage(size: NSSize(width: 4, height: 14), flipped: false) { rect in
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).fill()
        return true
    }
}

func info(_ title: String) -> NSMenuItem { NSMenuItem(title: title, action: nil, keyEquivalent: "") }

func open(_ url: String) { URL(string: url).map { _ = NSWorkspace.shared.open($0) } }

private let settingKeys = ["language", "titleLength", "notify10", "notify1", "notifyAll", "hiddenCalendars"]

@MainActor
final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = EKEventStore()
    let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var events: [EKEvent] = []  // timed, sorted
    var long: [EKEvent] = []    // all-day / multi-day, sorted
    var scheduled: [String: String] = [:]  // notification id -> signature
    var settingsWindow: NSWindow?
    var settingsSnapshot = ""
    var notificationsWereAllowed = false

    var hidden: Set<String> { Set(UserDefaults.standard.stringArray(forKey: "hiddenCalendars") ?? []) }
    var authorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    func applicationWillFinishLaunching(_: Notification) {
        UserDefaults.standard.register(defaults: [
            "language": "system", "titleLength": 20, "notify10": true, "notify1": true, "notifyAll": false,
        ])
        settingsSnapshot = snapshot()
        setUpNotifications()  // delegate must be set before launch finishes
    }

    func applicationDidFinishLaunching(_: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        status.menu = menu

        // queue: .main — some of these (EKEventStoreChanged, defaults) can be posted off the main thread
        func observe(_ center: NotificationCenter, _ name: Notification.Name, _ run: @escaping @MainActor (App) -> Void) {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in MainActor.assumeIsolated { run(self) } }
        }
        for name in [Notification.Name.EKEventStoreChanged, .NSCalendarDayChanged, .NSSystemTimeZoneDidChange] {
            observe(.default, name) { $0.refresh() }
        }
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification) { $0.refresh() }
        observe(.default, UserDefaults.didChangeNotification) { $0.settingsChanged() }

        // .common mode keeps ticking while the menu is open
        let timer = Timer(timeInterval: 30, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)

        store.requestFullAccessToEvents { _, _ in
            Task { @MainActor in self.refresh() }
        }
        refresh()
        if CommandLine.arguments.contains("--settings") { openSettings() }
    }

    @objc func tick() {
        refresh()
        checkNotificationAccess()
    }

    func snapshot() -> String {
        settingKeys.map { "\(UserDefaults.standard.object(forKey: $0) ?? "")" }.joined(separator: "|")
    }

    /// Any in-process defaults write posts didChange; react only when one of ours changed.
    func settingsChanged() {
        let s = snapshot()
        guard s != settingsSnapshot else { return }
        settingsSnapshot = s
        registerCategories()
        settingsWindow?.title = L("Soon Settings")
        refresh()
    }

    /// Must not write to UserDefaults (settingsChanged observes it).
    @objc func refresh() {
        let now = Date()
        defer { scheduleNotifications(now: now) }
        guard let button = status.button else { return }
        guard authorized else {
            events = []
            long = []
            button.image = NSImage(systemSymbolName: "calendar.badge.exclamationmark", accessibilityDescription: "Soon")
            button.title = ""
            return
        }
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: now))!
        let calendars = store.calendars(for: .event).filter { !hidden.contains($0.calendarIdentifier) }
        let all = calendars.isEmpty ? [] : store.events(matching: store.predicateForEvents(withStart: now, end: end, calendars: calendars))
            .filter { $0.endDate > now && !$0.declined }
            .sorted { $0.startDate < $1.startDate }
        events = all.filter { !$0.isLong }
        long = all.filter(\.isLong)

        if let e = events.first, e.startDate <= now || cal.isDateInToday(e.startDate) {
            button.image = bar(e.calendar.color)
            button.imagePosition = .imageLeading
            button.title = statusText(title: e.title ?? "", start: e.startDate, end: e.endDate, now: now,
                                      maxLength: UserDefaults.standard.integer(forKey: "titleLength"))
        } else {
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Soon")
            button.imagePosition = .imageOnly
            button.title = ""
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
        menu.removeAllItems()
        let now = Date()
        let cal = Calendar.current

        if !authorized {
            menu.addItem(Action(L("Grant Calendar Access…"), symbol: "lock") {
                open("x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
            })
        } else {
            if let next = events.first {
                menu.addItem(.sectionHeader(title: next.startDate <= now
                    ? L("Now · %@ left", duration(next.endDate.timeIntervalSince(now)))
                    : L("Upcoming in %@", duration(next.startDate.timeIntervalSince(now)))))
                menu.addItem(eventItem(next))
                if let m = next.meeting {
                    menu.addItem(Action(L("Join %@ meeting", m.service), symbol: "video") { NSWorkspace.shared.open(m.url) })
                }
            } else if long.isEmpty {
                menu.addItem(.sectionHeader(title: L("No upcoming events")))
            }

            // Everything else grouped by day (ongoing multi-day events once, under today):
            // all-day first, then timed; up to 3 distinct days counting the "next" event's day.
            func day(_ e: EKEvent) -> Date { cal.startOfDay(for: max(e.startDate, now)) }
            let rest = (long + events.dropFirst()).sorted {
                (day($0), $0.isLong ? 0 : 1, $0.startDate) < (day($1), $1.isLong ? 0 : 1, $1.startDate)
            }
            var days = events.first.map { [day($0)] } ?? []
            var lastDay: Date?
            for e in rest {
                let d = day(e)
                if !days.contains(d) {
                    if days.count == 3 { break }
                    days.append(d)
                }
                if d != lastDay {
                    menu.addItem(.sectionHeader(title: dayTitle(d)))
                    lastDay = d
                }
                menu.addItem(eventItem(e))
            }
        }

        menu.addItem(.separator())
        menu.addItem(Action(L("Open Calendar"), key: "1") { open("file:///System/Applications/Calendar.app") })
        menu.addItem(Action(L("Settings…"), key: ",") { [self] in openSettings() })
        menu.addItem(.separator())
        menu.addItem(Action(L("Quit Soon"), key: "q") { NSApp.terminate(nil) })
    }

    func dayTitle(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return L("Today") }
        if cal.isDateInTomorrow(d) { return L("Tomorrow") }
        return d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().locale(Lang.current.locale))
    }

    func eventItem(_ e: EKEvent) -> NSMenuItem {
        let when = e.isLong ? spanLabel(start: e.startDate, end: e.endDate) : time(e.startDate)
        let item = NSMenuItem(title: "\(when) · \(truncate(e.title ?? "", 50))", action: nil, keyEquivalent: "")
        item.image = bar(e.calendar.color)

        let sub = NSMenu()
        sub.addItem(info(e.isAllDay ? when
            : e.isLong ? (e.startDate..<e.endDate).formatted(Date.IntervalFormatStyle(date: .abbreviated, time: .shortened, locale: Lang.current.locale))
            : "\(time(e.startDate)) – \(time(e.endDate))"))
        if let loc = e.location, !loc.isEmpty { sub.addItem(info(truncate(loc, 60))) }
        sub.addItem(info(e.calendar.title))
        sub.addItem(.separator())
        if let m = e.meeting {
            sub.addItem(Action(L("Join %@ meeting", m.service), symbol: "video") { NSWorkspace.shared.open(m.url) })
            sub.addItem(Action(L("Copy Meeting Link"), symbol: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(m.url.absoluteString, forType: .string)
            })
        }
        // ponytail: best-effort deep link, recurring events may open the first occurrence
        let id = e.calendarItemIdentifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        sub.addItem(Action(L("Open in Calendar"), symbol: "calendar") { open("ical://ekevent/\(id)?method=show&options=more") })
        item.submenu = sub
        return item
    }

    // MARK: Settings window

    func openSettings() {
        let calendars = authorized
            ? store.calendars(for: .event).sorted { ($0.source.title, $0.title) < ($1.source.title, $1.title) }
            : []
        settingsWindow?.close()  // rebuilt each time so the calendar list is fresh
        let w = NSWindow(contentViewController: NSHostingController(rootView:
            SettingsView(calendars: calendars, sendTest: { [self] in sendTestNotification() })))
        w.title = L("Soon Settings")
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.center()
        settingsWindow = w
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.run()

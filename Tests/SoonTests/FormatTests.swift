import Foundation
import Testing
@testable import Soon

@Test func meetingLinks() {
    let meet = findMeeting(in: [nil, "Room 5", "Join with Google Meet: https://meet.google.com/abc-defg-hij?authuser=0"])
    #expect(meet == Meeting(service: "Google Meet", url: URL(string: "https://meet.google.com/abc-defg-hij")!))
    #expect(findMeeting(in: ["<a href=\"https://us02web.zoom.us/j/123456?pwd=xYz\">join</a>."])?.url.absoluteString == "https://us02web.zoom.us/j/123456?pwd=xYz")
    #expect(findMeeting(in: ["https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0"])?.service == "Teams")
    #expect(findMeeting(in: ["https://docs.google.com/document/d/1", nil]) == nil)
}

@Test func durations() {
    #expect(duration(115 * 60, .en) == "1h 55m")
    #expect(duration(114 * 60 + 1, .en) == "1h 55m")
    #expect(duration(10, .en) == "1m")
    #expect(duration(120 * 60, .en) == "2h")
    #expect(duration(26 * 3600, .en) == "1d 2h")
    #expect(duration(115 * 60, .ru) == "1 ч 55 мин")
}

@Test func spans() {
    let cal = Calendar.current
    let day = cal.startOfDay(for: Date())
    let next = cal.date(byAdding: .day, value: 1, to: day)!
    #expect(spanLabel(start: day, end: next, .en) == "All day")
    #expect(spanLabel(start: day, end: next - 1, .en) == "All day")
    #expect(spanLabel(start: day, end: next, .ru) == "Весь день")
    #expect(spanLabel(start: day, end: cal.date(byAdding: .day, value: 3, to: day)!, .en) != "All day")
}

@Test func statusLine() {
    let now = Date()
    let long = "Statra Daily Meetings and More"
    let (start, end) = (now + 115 * 60, now + 145 * 60)
    #expect(statusText(title: long, start: start, end: end, now: now, maxLength: 22, .en) == "Statra Daily Meetings… in 1h 55m")
    #expect(statusText(title: long, start: start, end: end, now: now, maxLength: 10, .en) == "Statra Da… in 1h 55m")
    #expect(statusText(title: long, start: start, end: end, now: now, maxLength: 0, .en) == "in 1h 55m")
    #expect(statusText(title: "Sync", start: now - 60, end: now + 25 * 60, now: now, maxLength: 20, .en) == "Sync · 25m left")
    #expect(statusText(title: "Sync", start: now + 30, end: now + 600, now: now, maxLength: 20, .en) == "Sync · now")
    #expect(statusText(title: "Sync", start: now + 30, end: now + 600, now: now, maxLength: 0, .en) == "now")
    #expect(statusText(title: "Sync", start: start, end: end, now: now, maxLength: 20, .ru) == "Sync через 1 ч 55 мин")
    #expect(statusText(title: "Sync", start: now - 60, end: now + 25 * 60, now: now, maxLength: 20, .ru) == "Sync · осталось 25 мин")
}

@Test func timeKeepsHourCycle() {
    let d = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
    // switching the language must not switch 24h <-> 12h
    #expect(time(d, .en) == d.formatted(date: .omitted, time: .shortened))
}

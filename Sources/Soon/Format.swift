import Foundation

struct Meeting: Equatable {
    let service: String
    let url: URL
}

private let services: [(name: String, pattern: String)] = [
    ("Google Meet", #"https://meet\.google\.com/[\w/-]+"#),
    ("Zoom", #"https://([\w-]+\.)?zoom\.(us|com)/(j|my|w)/[^\s"'<>]+"#),
    ("Teams", #"https://teams\.(microsoft|live)\.com/(l/meetup-join|meet)/[^\s"'<>]+"#),
    ("Webex", #"https://[\w-]+\.webex\.com/[^\s"'<>]+"#),
]

/// First known video-call link in the given texts (event url, location, notes — in priority order).
func findMeeting(in texts: [String?]) -> Meeting? {
    for text in texts.compactMap({ $0 }) {
        for s in services {
            if let r = text.range(of: s.pattern, options: .regularExpression),
               let url = URL(string: text[r].trimmingCharacters(in: CharacterSet(charactersIn: ".,;:)"))) {
                return Meeting(service: s.name, url: url)
            }
        }
    }
    return nil
}

/// 115 min -> "1h 55m" / "1 ч 55 мин", rounds up to whole minutes.
func duration(_ seconds: TimeInterval, _ lang: Lang = .current) -> String {
    let m = max(1, Int((seconds / 60).rounded(.up)))
    let (d, h, mi) = (L("d", lang), L("h", lang), L("m", lang))
    if m >= 1440 { return "\(m / 1440)\(d) \(m % 1440 / 60)\(h)" }
    if m < 60 { return "\(m)\(mi)" }
    return m % 60 == 0 ? "\(m / 60)\(h)" : "\(m / 60)\(h) \(m % 60)\(mi)"
}

func truncate(_ s: String, _ max: Int) -> String {
    s.count > max ? s.prefix(max - 1).trimmingCharacters(in: .whitespaces) + "…" : s
}

func time(_ d: Date, _ lang: Lang = .current) -> String {
    d.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: lang.locale))
}

/// "All day" for a single day, otherwise the day range, e.g. "Nov 9 – 11".
func spanLabel(start: Date, end: Date, _ lang: Lang = .current) -> String {
    let last = end.addingTimeInterval(-1)  // all-day events end at the next midnight or 23:59:59
    if Calendar.current.isDate(start, inSameDayAs: last) { return L("All day", lang) }
    return (start..<last).formatted(.interval.month(.abbreviated).day().locale(lang.locale))
}

/// Menu bar text: "Daily Meeting in 1h 55m" / "Daily Meeting · now" / "Daily Meeting · 25m left".
/// `maxLength` 0 hides the title: "in 1h 55m".
func statusText(title: String, start: Date, end: Date, now: Date, maxLength: Int, _ lang: Lang = .current) -> String {
    let upcoming = start.timeIntervalSince(now) >= 60
    let when = now >= start ? L("%@ left", duration(end.timeIntervalSince(now), lang), lang)
        : upcoming ? L("in %@", duration(start.timeIntervalSince(now), lang), lang)
        : L("now", lang)
    guard maxLength > 0 else { return when }
    let t = truncate(title, maxLength)
    return upcoming ? "\(t) \(when)" : "\(t) · \(when)"
}

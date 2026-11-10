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

private let trailing = CharacterSet(charactersIn: ".,;:)")

/// First known video-call link in the given texts (event url, location, notes — in priority order).
func findMeeting(in texts: [String?]) -> Meeting? {
    for text in texts.compactMap({ $0 }) {
        for s in services {
            if let r = text.range(of: s.pattern, options: .regularExpression),
               let url = URL(string: text[r].trimmingCharacters(in: trailing)) {
                return Meeting(service: s.name, url: url)
            }
        }
    }
    return nil
}

/// Invitation boilerplate, not something the organizer attached: Meet's "Learn more" and dial-in pages, Teams help.
private let boilerplate: Set<String> = ["support.google.com", "tel.meet", "aka.ms"]

/// Other http(s) links in the texts (docs, boards…), in order, without duplicates,
/// without the call's own site (its dial-in / settings pages) and invitation boilerplate.
func findLinks(in texts: [String?], except meeting: Meeting? = nil) -> [URL] {
    let call = meeting?.url.host()
    var seen = Set<String>()
    return texts.compactMap { $0?.replacingOccurrences(of: "&amp;", with: "&") }  // notes can be HTML
        .flatMap { $0.matches(of: #/https?://[^\s"'<>]+/#) }
        .compactMap { URL(string: $0.output.trimmingCharacters(in: trailing)) }
        .filter { url in
            guard let host = url.host(), !boilerplate.contains(host) else { return false }
            if let call, host == call || host.hasSuffix("." + call) { return false }
            return seen.insert(url.absoluteString).inserted
        }
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

import AppKit

/// host -> site icon (nil: the site has none). Per launch; URLCache keeps the files across launches.
@MainActor private var favicons: [String: NSImage?] = [:]

/// Puts the site's icon on a menu item: right away if cached, otherwise once loaded (an open menu updates).
/// Until then, or if the site has none, the item keeps its own image.
@MainActor func withFavicon(_ item: NSMenuItem, _ url: URL) -> NSMenuItem {
    guard let host = url.host() else { return item }
    if let cached = favicons[host] {
        if let cached { item.image = cached }
        return item
    }
    Task { [weak item] in
        do {
            let icon = try await loadFavicon(host)
            favicons.updateValue(icon, forKey: host)  // stores nil too: don't ask that site again
            if let icon { item?.image = icon }
        } catch {}  // offline etc.: try again on the next menu open
    }
    return item
}

/// https://host/favicon.ico, else the home page's <link rel="icon">.
@MainActor private func loadFavicon(_ host: String) async throws -> NSImage? {
    guard let home = URL(string: "https://\(host)/") else { return nil }
    var icon = NSImage(data: try await get(home.appending(path: "favicon.ico")))
    if icon == nil,
       let href = iconHref(in: String(decoding: try await get(home), as: UTF8.self)),
       let url = URL(string: href, relativeTo: home) {
        icon = NSImage(data: try await get(url))
    }
    icon?.size = NSSize(width: 16, height: 16)  // .ico files carry up to 256px
    return icon
}

/// Body of a 200 response, empty otherwise.
private func get(_ url: URL) async throws -> Data {
    let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 10)
    let (data, response) = try await URLSession.shared.data(for: request)
    return (response as? HTTPURLResponse)?.statusCode == 200 ? data : Data()
}

/// href of the page's <link rel="icon"> or "shortcut icon" (not apple-touch-icon / mask-icon).
func iconHref(in html: String) -> String? {
    var rest = html[..<(html.range(of: "</head>", options: .caseInsensitive)?.lowerBound ?? html.endIndex)]
    while let tag = rest.range(of: #"<link\s[^>]*>"#, options: [.regularExpression, .caseInsensitive]) {
        let t = rest[tag]
        if t.range(of: #"\srel=["']?(shortcut )?icon["'\s/>]"#, options: [.regularExpression, .caseInsensitive]) != nil,
           let href = t.range(of: #"\shref=["']?[^"'\s>]+"#, options: [.regularExpression, .caseInsensitive]) {
            return t[href].dropFirst(6).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        rest = rest[tag.upperBound...]
    }
    return nil
}

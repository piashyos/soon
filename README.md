# Soon

A small macOS menu bar app that shows your next calendar event and a countdown, e.g. `▍Daily Meeting in 1h 55m`. Click it to see the upcoming events (including all-day and multi-day ones), join the call (Google Meet, Zoom, Teams, Webex), copy the meeting link, open files and links attached to the event (shown with the service's icon), or open the event in Calendar.

Notifications 10 minutes and 1 minute before each call, with a **Join call** button. English and Russian.

Written in Swift with AppKit and EventKit. No dependencies, ~800 KB universal binary.

## Install

Requires macOS 14 or later (Apple Silicon or Intel).

1. Download `Soon-<version>.dmg` from [Releases](https://github.com/piashyos/soon/releases/latest), open it and drag **Soon** to **Applications**. Launch it from there, not from the disk image.
2. The app is not notarized by Apple, so macOS blocks the first launch. Open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to Soon. You only need to do this once.
   Alternatively, in Terminal: `xattr -dr com.apple.quarantine /Applications/Soon.app`
3. Allow calendar and notification access when prompted.

## Setup

1. Add your Google (or other) account under **System Settings → Internet Accounts** with Calendars enabled. Soon reads events through macOS Calendar and does not connect to Google itself. Its only network requests load site icons (favicons) for links in your events.
2. To get changes quickly, open **Calendar.app → Settings → Accounts** and set *Refresh Calendars* to *Every minute*.
3. **Settings… (⌘,)** in the menu: language, launch at login, title length, notifications, calendars.
   For reminders that stay on screen until clicked, set **System Settings → Notifications → Soon** to *Alerts*.
   Focus / Do Not Disturb holds them back.

## Development

```sh
swift test             # tests for link detection and formatting
./build.sh             # build/Soon.app
./build.sh install     # build, copy to /Applications, launch
./build.sh dmg         # build/Soon-<version>.dmg for a release
```

If calendar access gets stuck, run `tccutil reset Calendar com.vorislove.soon` and launch the app again.

## License

MIT, see [LICENSE](LICENSE).

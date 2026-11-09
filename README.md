# Soon

A small macOS menu bar app that shows your next calendar event and a countdown, e.g. `▍Daily Meeting in 1h 55m`. Click it to see the upcoming events (including all-day and multi-day ones), join the call (Google Meet, Zoom, Teams, Webex), copy the meeting link, or open the event in Calendar.

Notifications 10 minutes and 1 minute before each call, with a **Join call** button. English and Russian.

Written in Swift with AppKit and EventKit. No dependencies, ~400 KB binary.

## Setup

1. Add your Google (or other) account under **System Settings → Internet Accounts** with Calendars enabled. Soon reads events through macOS Calendar and does not connect to Google itself.
2. To get changes quickly, open **Calendar.app → Settings → Accounts** and set *Refresh Calendars* to *Every minute*.
3. Build and install:
   ```sh
   ./build.sh install   # builds, copies to /Applications, launches
   ```
4. Allow calendar and notification access when prompted.
5. **Settings… (⌘,)** in the menu: language, launch at login, title length, notifications, calendars.
   For reminders that stay on screen until clicked, set **System Settings → Notifications → Soon** to *Alerts*.
   Focus / Do Not Disturb holds them back.

## Development

```sh
swift test       # tests for link detection and formatting
./build.sh       # build/Soon.app
```

If calendar access gets stuck, run `tccutil reset Calendar com.vorislove.soon` and launch the app again.

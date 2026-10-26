# Roadmap

A small macOS viewer for a project's `issues.html`.

It is a standard document app, not a web browser: you open an HTML file with
File > Open (or drag it onto the Dock icon), it renders in a window, and
File > Close / Quit behave as usual. Links inside the page (`#anchors`) work in
place. Any link that leaves the page opens in your default browser.

## Requirements

- macOS 14 or later
- Xcode 16 or later to build

## Build and run

Open `Roadmap.xcodeproj` in Xcode and press Run.

From the command line:

```sh
xcodebuild -project Roadmap.xcodeproj -scheme Roadmap -configuration Release \
  -derivedDataPath build build
open build/Build/Products/Release/Roadmap.app
```

To open a file in it from the command line, give `open -a` an absolute path:

```sh
open -a "$PWD/build/Build/Products/Release/Roadmap.app" path/to/issues.html
```

If `xcode-select -p` points at the Command Line Tools rather than Xcode,
prefix the command with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## How it works

Three Swift files in `Roadmap/`:

- `RoadmapApp.swift`: a SwiftUI `DocumentGroup(viewing:)`, which supplies the
  File menu, Open Recent and window management. There is no New or Save.
- `HTMLDocument.swift`: a read-only `FileDocument` for `public.html`.
- `WebView.swift`: a `WKWebView` wrapper. Its navigation delegate lets
  same-page links through and hands every other clicked link to
  `NSWorkspace.shared.open`.

The app is sandboxed with read-only access to files the user opens. It also
has the outgoing-network entitlement: WebKit's helper processes need it even
to render a local page, and without it the window stays blank. The page
is expected to be self-contained (inline CSS and JS), which is how
`issues.html` is generated. Relative references to sibling files will not load.

## Distributing outside the App Store

To let people download it from a website without Gatekeeper warnings, the app
must be signed with a Developer ID certificate and notarized by Apple. This
needs a paid Apple Developer Program membership.

1. In Xcode, select the Roadmap target > Signing & Capabilities and choose your
   team.
2. Product > Archive.
3. In the Organizer, Distribute App > Direct Distribution. Xcode signs with
   Developer ID, submits for notarization, and staples the ticket.
4. Export the notarized `Roadmap.app`, zip it (or put it in a `.dmg`) and
   publish that.

Hardened Runtime, which notarization requires, is already enabled.

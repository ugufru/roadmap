# Roadmap

A small macOS viewer for a project's `issues.html`.

It is a standard document app, not a web browser: you open an HTML file with
File > Open (or drag it onto the Dock icon), it renders in a window, and
File > Close / Quit behave as usual. Links inside the page (`#anchors`) work in
place. Any link that leaves the page opens in your default browser.

The window follows the file: when `issues.html` is regenerated, the page
reloads and keeps its scroll position. Leave it open beside your editor or
terminal and it stays current.

On launch the app shows the Open panel. Open Recent remembers files across
launches.

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

An AppKit document app, in three Swift files in `Roadmap/`:

- `AppDelegate.swift`: starts the app, builds the menus, and shows the Open
  panel when there is no document. There is no New or Save.
- `HTMLDocument.swift`: an `NSDocument` for `public.html`. It never reports
  unsaved changes and has no undo manager, so typing in the page (a search
  field, say) is never treated as an edit, and closing a window or quitting
  never asks anything.
- `PageWindowController.swift`: the window, holding a `WKWebView`. Same-page
  links work in place; every other clicked link goes to
  `NSWorkspace.shared.open`. It watches the file and reloads the page,
  keeping the scroll position, whenever the file is rewritten or replaced
  (for example when `issues.html` is regenerated).

It uses AppKit rather than SwiftUI's `DocumentGroup` because SwiftUI's
document class can't be told that a document never has changes to save.

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

## License

MIT. See [LICENSE](LICENSE).

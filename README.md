# BeTrue.

A photo and video gallery for iPhone on the Pexels API. I built it with SwiftUI for iOS 16 and later, in Swift 6, as MVVM with a router, and with no third-party libraries.

- Photos: an endless curated feed in a two-column masonry grid, with search, recent searches and filters.
- Videos: popular videos in the same grid, with quality and length filters.
- A full-screen viewer that grows out of the tile and flies back into it. It has pinch and double-tap zoom, drag to dismiss, share and credits.
- Offline: the last lists you saw open without a connection.
- Light and dark appearance.

## Run it

1. `cp Config/Secrets.example.plist BeTrue/App/Secrets.plist`
2. Put your Pexels API key in `BeTrue/App/Secrets.plist` under `PexelsAPIKey`. Git ignores the file. Or add a `PEXELS_API_KEY` environment variable to the scheme.
3. Open `BeTrue.xcodeproj`, pick an iPhone simulator on iOS 16.0 or later and run.

Without a key, the app starts and shows how to add one.

## Tests

- 184 unit test cases in 14 suites (Swift Testing, no network) and 9 UI tests in 3 classes (XCTest).
- Run them with `xcodebuild test -scheme BeTrue -destination 'platform=iOS Simulator,name=iPhone 14 Pro,OS=16.0'`.
- The gallery journey test uses the live API and skips itself without a key. The scroll stress test only runs with `BETRUE_STRESS=1`.

## How it's built

- `App/` builds the services once and handles routing: the selected tab, the viewer and alerts.
- `Core/` holds networking, the image loader, pagination and the Core Data store. It knows nothing about Pexels.
- `Features/` has one folder per feature: Photos, Videos and Viewer. Each view model sits next to its view, with `Models/`, `Network/` and `Views/` beside them.
- Services go in through protocols, so every view model and repository is tested with fakes.

## Trade-offs

- **The viewer flies from the tile's frame in the window, not with `matchedGeometryEffect`.** `matchedGeometryEffect` put the image in the wrong place across the tabs' hosting layers. The cost: I measure the tile's frame myself. If the screen rotates while the viewer is open, the saved frame is out of date, so the image fades out instead of flying back.
- **The flight waits a fixed 0.5 s before any heavy work.** iOS 16 has no animation completion, so the video player and the full-size image wait on a timer. On iOS 17, `withAnimation(completion:)` would replace it.
- **Offline keeps only a little.** For each kind, the first page of the 20 newest lists is saved in Core Data. Images are kept only on Wi-Fi without Low Data Mode. The store stays tiny, but a deep scroll isn't available offline.
- **80 items per page**, the API maximum. Every request counts against the hourly limit, so I ask for fewer, larger pages and start loading the next one well before the end.
- **My own image pipeline instead of `AsyncImage` or a library.** Images are downsampled off the main thread to the size they're shown, with a 96 MB memory cache and a 200 MB disk cache. It's more code to own, but scrolling stays smooth and memory stays bounded.
- **UIKit where SwiftUI on iOS 16 falls short.** Zoom uses a `UIScrollView`, since iOS 16 has no SwiftUI magnify gesture. Video uses `AVPlayerViewController` for aspect fill and a switch to video with no black flash.
- **Folders, not Swift packages.** At this size, packages would mean `public` everywhere and slower builds. `Core` would be the first to move out.

## Limitations

- iPhone only. There's no iPad layout, and the viewer doesn't page between items.
- English and French only. Photo captions and names stay as Pexels sends them.
- Video search exists in the repository, but no screen uses it yet.
- Offline, the viewer shows the grid-size image if the full-size one was never downloaded.
- A video's still from Pexels can be a different moment than its first frame. On a slow connection, the switch shows as a short fade.
- Accessibility gaps: Reduce Transparency and Increase Contrast aren't handled, and a few buttons (recent-search chips, the search field's Cancel and clear buttons) are under 44 pt.
- Performance was only measured on the iOS 16.0 simulator: about 62–97 MB over 150 fast swipes. It still needs a device run with Animation Hitches.

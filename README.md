# Pelagica tvOS app

This is the tvOS app for [Pelagica](https://github.com/PelagicaApp/pelagica), a client for [Jellyfin](https://jellyfin.org).

## Installation

### App Store

> The app isn't yet available on the App Store.

### TestFlight

> The app isn't yet available on TestFlight.

### Building it yourself

1. Install [Xcode](https://apps.apple.com/app/xcode/id497799835) 26 or later (the project targets tvOS 26.5).
2. Clone the repository:

```bash
git clone https://github.com/PelagicaApp/pelagica-atv.git
cd pelagica-atv
```

3. Open `Pelagica.xcodeproj` in Xcode. Swift Package Manager will automatically resolve the [jellyfin-sdk-swift](https://github.com/jellyfin/jellyfin-sdk-swift) dependency on first build.
4. Select the `Pelagica` scheme and an Apple TV simulator or a physical Apple TV as the run destination.
5. If deploying to a physical Apple TV, select your own team under the target's _Signing & Capabilities_ tab so Xcode can code-sign the build.
6. Build and run (`Cmd+R`).

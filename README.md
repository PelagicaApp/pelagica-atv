# Pelagica for Apple TV

This is the Apple TV app for [Pelagica](https://github.com/PelagicaApp/pelagica), a client for [Jellyfin](https://jellyfin.org).

![Home](./.github/assets/pelagica-appletv-home.png)

### Screenshots

<table>
  <tr>
    <td>
      <img src="./.github/assets/pelagica-appletv-series.png" />
    </td>
    <td>
      <img src="./.github/assets/pelagica-appletv-homerows.png" />
    </td>
  </tr>
  <tr>
    <td>
      <img src="./.github/assets/pelagica-appletv-library.png" />
    </td>
    <td>
      <img src="./.github/assets/pelagica-appletv-search.png" />
    </td>
  </tr>
</table>

> Screenshots may include media artwork used for demonstration purposes only.

## Libraries and playback

The library browser supports `unknown`, `movies`, `tvshows`, `mixed`, `music`, `musicvideos`, `trailers`, `homevideos`, `boxsets`, `books`, `photos`, `livetv`, `playlists`, and `folders`. Libraries without a `CollectionType` are also shown. The client handles `mixed` responses without modifying the generated Jellyfin SDK.

- Browse nested folders, virtual collections, playlists, photo albums, artists, music albums, and seasons. Playlist order and repeated entries are preserved.
- Open video items with the existing player; series keep their episode-oriented details.
- View photos in their original aspect ratio, including full-screen viewing.
- Books, audio, audiobooks, and live TV channels have metadata views instead of unsupported playback controls. This does not add a book reader, audio player, live TV playback engine, or download support.
- The default home includes libraries. Server-configured home sections and library selections remain in control.

## Installation

### App Store

> The app isn't yet available on the App Store yet.

### TestFlight

You can join the [TestFlight beta](https://testflight.apple.com/join/CUsEZtDK) to try out beta builds of Pelagica for Apple TV. TestFlight builds may be unstable and are not guaranteed to work.

### Building it yourself

1. Install [Xcode](https://apps.apple.com/app/xcode/id497799835) 26 or later (the project targets tvOS 26.5).
2. Clone the repository:

```bash
git clone https://github.com/PelagicaApp/pelagica-atv.git
cd pelagica-atv
```

3. Open `Pelagica.xcodeproj` in Xcode. Swift Package Manager will automatically resolve the project's dependencies, including [jellyfin-sdk-swift](https://github.com/jellyfin/jellyfin-sdk-swift), on first build.
4. Select the `Pelagica` scheme and an Apple TV simulator or a physical Apple TV as the run destination.
5. If deploying to a physical Apple TV, select your own team under the target's _Signing & Capabilities_ tab so Xcode can code-sign the build.
6. Build and run (`Cmd+R`).

### Tests

The shared `Pelagica` scheme includes `PelagicaTests`, covering collection decoding, untyped libraries, container routing, and supported playback boundaries.

```bash
xcodebuild test \
  -project Pelagica.xcodeproj \
  -scheme Pelagica \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation) (at 1080p)'
```

Choose an installed tvOS 26.5 or later simulator if its name differs.

## Discord

For discussions about Pelagica, join the [JellyfinCommunity](https://discord.gg/VKqprjh3Wr) and head to the `#pelagica` channel.

## Disclaimer

This project is a third-party frontend for Jellyfin and is not affiliated with the Jellyfin project.

Jellyfin is a media server designed to organize and stream legally obtained media. This project does not provide, host, or encourage access to pirated content.

The movie posters and images shown in the examples are not owned by me and are only used for demonstration purposes. All rights belong to their respective owners.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](./LICENSE) file for details.

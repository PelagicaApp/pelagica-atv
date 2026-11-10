# Deep Links

Pelagica registers the `pelagica://` URL scheme on iOS and tvOS.
If you aren't signed in yet, the link opens once you are.

| Link | Opens |
| --- | --- |
| `pelagica://home` | Home tab |
| `pelagica://library` | Library tab |
| `pelagica://library/{libraryId}` | A library's items |
| `pelagica://search` | Search tab |
| `pelagica://search?q={query}` | Search with the query filled in |
| `pelagica://settings` | Settings (a sheet on iOS, a tab on tvOS) |
| `pelagica://item/{itemId}` | Detail page of a movie, series, season, episode, … |
| `pelagica://play/{itemId}` | Starts playback, resuming where you left off. Folders such as series open their detail page instead |
| `pelagica://person/{personId}` | Detail page of an actor, director, … |
| `pelagica://seerr/movie/{tmdbId}` | Seerr page of a movie |
| `pelagica://seerr/tv/{tmdbId}` | Seerr page of a TV show |

IDs are Jellyfin item IDs, as shown in the Jellyfin web URL (`…/details?id={itemId}`).

## Testing

```bash
xcrun simctl openurl booted "pelagica://search?q=matrix"
```

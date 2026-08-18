# Walking Buddy

A tiny macOS desktop companion that walks across the screen, turns around at
the edges, and can be dragged to a new position.

## Features

- Eight included original characters
- Automatic seasonal character selection
- Five character sizes
- Slow, normal, and fast movement
- Drag-and-drop positioning that continues walking after release
- Works across Spaces and alongside full-screen apps
- Menu-bar controls with no Dock icon

## Download

Download `Walking-Buddy-macOS.zip` from the latest GitHub Release, unzip it,
and move **Walking Buddy.app** into Applications.

The beta release is ad-hoc signed, not Apple-notarized. The first time it opens,
macOS may require Control-clicking the app, choosing **Open**, and confirming.
Never bypass a warning for a download you do not trust.

## Controls

Click the character icon in the menu bar to choose a character, change its
size or speed, pause movement, reset it to the bottom, or quit. Drag the
character itself and release it anywhere on the visible screen.

## Build from source

Requirements: macOS 13 or later and Xcode Command Line Tools.

```bash
./scripts/build.sh
open ".build/Walking Buddy.app"
```

The downloadable archive is created at `.build/Walking-Buddy-macOS.zip`.

## Contributing

Fork the repository, create a branch, make your change, run the build script,
and open a pull request. See [CONTRIBUTING.md](CONTRIBUTING.md).

Only submit artwork that you created or have permission to distribute. Do not
submit sprites extracted from commercial games, apps, or other copyrighted
works.

## License

Code and included original artwork are available under the MIT License. See
[LICENSE](LICENSE).

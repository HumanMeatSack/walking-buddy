# Walking Buddy

A tiny macOS and Windows desktop companion that walks across the screen, turns
around at the edges, and can be dragged to a new position.

## Features

- Eight included original characters
- Automatic seasonal character selection
- Five character sizes
- Slow, normal, and fast movement
- Drag-and-drop positioning that continues walking after release
- Native macOS menu-bar and Windows system-tray controls
- No regular app window or taskbar/Dock icon
- Preferences are remembered between launches

## Download

Choose the file for your computer from the latest GitHub Release:

- **Windows 10/11 (64-bit):** `Walking-Buddy-Windows-x64.zip`
- **macOS 13 or later:** `Walking-Buddy-macOS.zip`

On Windows, unzip the download and run **Walking Buddy.exe**. It is
self-contained, so no separate .NET installation is required. The current beta
is not code-signed and Windows may show an Unknown Publisher or SmartScreen
notice. If you do not trust the download, build it from source instead.

On macOS, unzip the download and move **Walking Buddy.app** into Applications.

The beta release is ad-hoc signed, not Apple-notarized. The first time it opens,
macOS may require Control-clicking the app, choosing **Open**, and confirming.
Never bypass a warning for a download you do not trust.

## Controls

On macOS, click the character icon in the menu bar. On Windows, left-click or
right-click the Walking Buddy system-tray icon. Use the menu to choose a
character, change its size or speed, pause movement, reset it to the bottom, or
quit. Drag the character itself and release it anywhere on the visible screen.

## Build from source

### macOS

Requirements: macOS 13 or later and Xcode Command Line Tools.

```bash
./scripts/build.sh
open ".build/Walking Buddy.app"
```

The downloadable archive is created at `.build/Walking-Buddy-macOS.zip`.

### Windows

Requirements: Windows 10/11 and the .NET 8 SDK.

```powershell
.\scripts\build-windows.ps1
```

The self-contained archive is created at
`.build\Walking-Buddy-Windows-x64.zip`.

## Contributing

Fork the repository, create a branch, make your change, run the build script,
and open a pull request. See [CONTRIBUTING.md](CONTRIBUTING.md).

Only submit artwork that you created or have permission to distribute. Do not
submit sprites extracted from commercial games, apps, or other copyrighted
works.

## License

Code and included original artwork are available under the MIT License. See
[LICENSE](LICENSE).

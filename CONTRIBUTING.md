# Contributing

Thanks for helping improve Walking Buddy.

## Development workflow

1. Fork the repository and create a focused branch.
2. Make one logical change at a time.
3. Run the relevant build script and launch the resulting app:
   - macOS: `./scripts/build.sh`
   - Windows: `.\scripts\build-windows.ps1`
4. Confirm movement, turning, dragging, and menu controls.
5. Open a pull request describing the change and how it was tested.

## Character artwork

New characters should be transparent PNG files with tightly trimmed empty
space and visible pixels touching the bottom edge. Keep artwork reasonably
sized and optimize PNG files before committing them.

You must own the artwork or have explicit permission to redistribute it under
this project's MIT License. Do not submit extracted commercial-game sprites,
brand mascots, copyrighted characters, or unlicensed fan art.

## Code style

- Prefer clear Swift or C# and small, focused methods.
- Preserve drag bounds and bottom alignment at every size.
- Keep the app dependency-free unless a dependency materially improves it.
- Avoid changes that require Accessibility or Screen Recording permission.

# CleanMac

CleanMac is a lightweight macOS menu bar app that temporarily disables keyboard input so you can clean your keyboard without accidental typing. Mouse and trackpad input stay active.

## Features

- One-click keyboard lock and unlock from the menu bar
- Clear menu bar status icons for locked and unlocked state
- Media keys are blocked while the lock is active
- Caps Lock is remapped during the lock and restored on unlock
- Automatically unlocks after wake from sleep

## Requirements

- macOS 13 or later
- Accessibility permission enabled for the app

## Run from source

```bash
swift run
```

This is the fastest way to run the app locally while developing.

## Build the app bundle

```bash
./scripts/build-app.sh
```

The build script creates a distributable app bundle at `dist/CleanMac.app` and a zip archive at `dist/CleanMac.zip`.
By default the app is ad-hoc signed. For public distribution on other Macs, you should rebuild it with a Developer ID identity and notarize it.
To update the app branding, replace `logo.png`, `logo.jpg`, or `logo.jpeg` in the project root and rebuild. The scripts regenerate both the menu bar logo and the app icon automatically.

## Install locally

```bash
./scripts/install-app.sh
```

This installs the app to `/Applications/CleanMac.app`.

If macOS does not seem to remember Accessibility permission for one launch mode, remove the existing permission entry, then grant it again for the exact variant you are using:

- `swift run` for local development
- `/Applications/CleanMac.app` for the installed app

## Install from GitHub release

The current public release is not notarized yet. On a different Mac, Gatekeeper may block it even though the app bundle itself is valid.

If macOS refuses to open the app after download, use one of these options:

```bash
xattr -dr com.apple.quarantine /Applications/CleanMac.app
```

or right click the app in Finder, choose `Open`, and confirm the dialog.

For a fully frictionless download experience, the release must be signed with a Developer ID certificate and notarized by Apple.

## Usage

- Left click the menu bar icon to lock or unlock the keyboard
- Right click the icon to open the app menu
- If prompted, grant Accessibility access in System Settings
- The menu bar icon changes between unlocked and locked states when the keyboard lock is toggled

## Notes

- The app blocks all connected keyboards, not only the built-in MacBook keyboard
- Caps Lock LED behavior depends on keyboard firmware and may still flash briefly
- If Accessibility behaves inconsistently, macOS TCC state may need to be reset for the exact app variant you are launching
- CleanMac is intended for direct distribution outside the Mac App Store
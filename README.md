<p align="center">
<img alt="Alan Becker's Stickfigures Unofficial Logo" src="https://github.com/Skittlq/alan-beckers-stickfigures-unofficial/blob/main/repository-images/absu-logo.png?raw=true"
style="max-width: 702px; width:100%;">
</p>

<p align="center">
    <img alt="Alan Becker's Stickfigures Unofficial Logo" src="https://github.com/Skittlq/alan-beckers-stickfigures-unofficial/blob/main/repository-images/key-art.png?raw=true" style="border-radius:20px;">
</p>

## Introduction

### **Disclaimer: This is an unofficial version and is not endorsed or affiliated with Alan Becker.**

### **Note: This application is supported for Windows and macOS. Linux is not supported.**

This is a customised stand-alone app of Kilkakon's Shimeji-ees dedicated towards providing an easy way to download, install and receive updates for Alan Becker's suite of stickfigures to roam around and give you company on your desktop. The animations, behaviours and actions are all created and provided by [**Stickwave/@StickLaserPhase**](https://x.com/StickLaserPhase) (Thank you so much!) with my own little tweaks.

## Installation Guide

### Java Installation

This app requires Java to be installed. You can download Java from the following link: [Java Download](https://www.java.com/en/download/)

### Download Link

Download the installer from the latest release: [**alan-beckers-stickfigures-installer**](https://github.com/Skittlq/alan-beckers-stickfigures-unofficial/releases/latest).

### Installation and Running the Application / Updating the Application

#### Windows

1. If updating, exit out of the app by either dismissing all stickfigures, or exiting out from the system tray icon.
2. Download the installer.
3. Run the installer and follow the on-screen instructions.
4. The application will automatically add itself as a shortcut to the Start Menu, Desktop, and will start up automatically when you turn on your computer.
5. Use the tray menu's **Choose Stickfigure...** action, or edit `conf/settings.properties`, to choose which stickfigure sets are active.

#### macOS

1. Install Java if it is not already available. You can check by running `java -version` in Terminal.
2. Download the macOS DMG from the latest GitHub release.
3. Open the DMG and drag `Alan Beckers Stickfigures.app` to Applications.
4. Open the app. It shows a settings/status window and adds an `ABS` item to the macOS menu bar.
5. Use the menu bar item to turn the stickfigures on or off, restart them, open logs, or quit the wrapper.
6. In Settings, check only the stickfigure colors you want enabled. Disabled stickfigures are hidden the next time the Java app starts.
7. If macOS blocks the unsigned launcher, Control-click the app, choose **Open**, then confirm.

macOS launcher output is written to `~/Library/Logs/AlanBeckersStickfigures.log`.

### Shared Desktop Features

- Windows and macOS both ship the same patched Java stickfigure runtime, image sets, behavior files, and bundled Java compatibility libraries.
- Right-click a stickfigure and choose **Hold Pointer** to make only that stickfigure hold onto the mouse pointer until you choose another behavior.
- Disabled stickfigure sets are controlled by `ActiveShimeji` in `conf/settings.properties`. Windows uses the installed Java app's config directly; macOS writes the setting into its runtime copy under `~/Library/Application Support/AlanBeckersStickfigures/JavaRuntime`.
- Windows keeps the original Shimeji-ee native window support for interactive desktop windows. macOS adds a native wrapper that publishes normal desktop window bounds so the existing Shimeji behaviors can land, sit, crawl, and walk along those windows.

### macOS Desktop Notes

When launched through the macOS app, the macOS environment treats all connected displays as one continuous desktop, keeps the menu bar as a real top edge, and avoids using the Dock's invisible reserved strip as a raised floor. When you drag near the visible Dock, the launcher briefly exposes an estimated Dock surface so the stickfigures can react to the visible Dock area instead of empty space. The launcher tracks window bounds passively; throwing or moving other apps' windows is still disabled on macOS because that requires Accessibility permission.

### macOS Development Build

Build and run the local macOS app:

```bash
./script/build_and_run.sh --verify
```

Build the distributable DMG:

```bash
./script/package_macos.sh
```

The DMG is written to `dist/Alan-Beckers-Stickfigures-macOS.dmg`. The app is ad-hoc signed for local validation, but not notarized.
The local `dist/` directory is ignored by Git.

### Windows Development Build

Build the Windows installer on Windows with JDK 17+ and WiX Toolset installed:

```powershell
.\script\package_windows.ps1
```

The installer is written to `dist/Alan-Beckers-Stickfigures-Windows.exe`.

### GitHub Releases

`.github/workflows/release.yml` builds release assets when a tag like `v1.0.0` is pushed, or when the workflow is run manually. The GitHub release includes:

- `Alan-Beckers-Stickfigures-macOS.dmg`
- `Alan-Beckers-Stickfigures-Windows.exe`
- `Alan-Beckers-Stickfigures-source-<tag>.zip`
- GitHub's standard Source code archives for the tag

## Future Plans (Ordered in Priority)

- ~~Add Sound Effects (Toggleable).~~
- ~~Fix Hugging Animation with Hollow Heads.~~
- ~~Re-animate all sprites. In the process, add extra frames for improved animation fluidity and life, and transitions between actions, fix the hollow head's height and head shape.~~
- ~~Add ~~victim~~, ~~The Dark Lord~~, King Orange.~~
- ~~Add new custom interactions such as small hand to hand fights, or weaponed fights.~~
- ~~Possibly add objects like the couch for them to sit on?~~
- ~~Unlikely, but maybe add Mercenaries.~~
- ~~Unlikely, but possibly other side characters like Corn-dog Man.~~

- All future plans are halted as I do not have the time to work on this project, however I have started a new project of creating my own Shimeji-ee like app to make creating desktop pets beginner friendly, while also being very customisable and powerful. It will use Godot Engine as the back bone. [Follow the development](https://github.com/Skittlq/s-pets)

## Additional Sources

- Based On [Kilkakon's Shimeji-ee](https://kilkakon.com/shimeji/)
- Featuring characters by [Alan Becker on YouTube](https://x.com/StickLaserPhase)
- Shimeji-ee Behaviour, Actions & Sprites by [Stickwave/@StickLaserPhase](https://x.com/StickLaserPhase) in [Google Drive](https://drive.google.com/file/d/1PdWAU91kAKg2lqcAiTdNGhNflqoHKU6N/view)

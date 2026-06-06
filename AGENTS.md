# AGENTS.md

<!-- BEGIN CODEX AGENTS MEMORY BOOTSTRAP -->
## Project Memory

This section is managed by the `agents-memory-bootstrap` skill. Keep durable project facts here; keep secrets, tokens, cookies, and machine-local credentials out of this file.

## Project Snapshot

- Root: `/Users/ziadsaleemi/Repositories/alan-beckers-stickfigures-unofficial`
- Primary stack: Not detected; inspect the repo before choosing commands.
- Deployment/runtime signals: GitHub Actions

## Working Commands

- Not detected. Inspect project docs before running install, build, test, or deploy commands.

## Project Structure

- `src`
- `lib`

## Environment And Secrets

- No safe example env file detected. Do not read or commit secret-bearing .env files unless explicitly required.

## Relevant Codex Skills

Use the smallest relevant skill set; do not load every skill by default.

- `agents-memory-bootstrap`: Use to refresh this file after stack, command, deployment, or workflow changes.
- `github:gh-fix-ci`: Use when CI fails or workflow changes are needed.
- `lesson-learned`: Use to apply durable engineering lessons across implementation, debugging, review, and deployment.
- `parity-audit`: Use when docs, tests, UI, API behavior, or deployment state may have drifted.
- `security-best-practices`: Use for auth, secrets, dependency, permission, and production-safety changes.
- `self-improvement-retro`: Use when the same mistake or workflow friction repeats and should become process.
- `session-recovery`: Use when resuming interrupted work or inheriting a dirty branch.

## Operating Rules

- Read this file before making project changes.
- Prefer the commands and conventions above; update them when they become stale.
- Inspect current git status before editing and preserve unrelated user changes.
- For behavior changes, add or update focused tests when practical, then run the relevant verification command.
- For UI changes, verify responsive layout and browser behavior when a runnable app is available.
- For deployment, auth, billing, data migration, or permission changes, identify rollback and safety implications before applying the change.

## Maintenance

- Refresh this managed section after dependency, script, deployment, directory, or workflow changes.
- Move durable project-specific lessons into the non-managed part of `AGENTS.md` when they should be curated by humans.
- Move repeated cross-project lessons into the global lesson workflow instead of duplicating them here.
<!-- END CODEX AGENTS MEMORY BOOTSTRAP -->

## Curated Project Notes

- This is a packaged Java/Swing Shimeji-ee desktop app. The primary runnable artifact is `AlansStickfigures.jar`; most original app code is committed as `.class` files under `Shimeji-ee/`.
- macOS support is patched into the JAR with `com.group_finity.mascot.mac.NativeFactoryImpl`, which bridges the app's macOS factory lookup to a macOS environment plus dedicated per-pixel transparent sprite windows.
- macOS window awareness is split between Swift and Java: the native wrapper publishes the topmost usable window bounds to `~/Library/Application Support/AlanBeckersStickfigures/window-bounds.tsv`, passes that path as `-Dshimeji.macWindowBoundsFile`, and `com.group_finity.mascot.mac.MacEnvironment` maps it into the legacy `activeIE` behavior API.
- `com.group_finity.mascot.mac.MacEnvironment` exposes one continuous multi-display `workArea` with the menu-bar top inset only; do not use macOS Dock insets as the floor because they include invisible reserved space.
- The macOS wrapper estimates the visible Dock rectangle from Dock settings and briefly publishes it as the active window surface when the cursor is over the Dock, so drag/drop near the Dock can react to the visible Dock without raising the whole screen floor.
- `src/com/group_finity/mascot/Mascot$7.java` replaces the original right-click "Follow Cursor" menu action with a single-mascot "Hold Pointer" action by setting the selected mascot to the existing hidden `Dragged` behavior.
- `src/com/group_finity/mascot/mac/MacTranslucentWindow.java` and `src/com/group_finity/mascot/mac/MacNativeImage.java` are the macOS sprite rendering path. Keep macOS on this modern per-pixel transparent window path; the legacy generic JNA transparent-window mask can retain old action silhouettes on modern macOS.
- `src/com/group_finity/mascot/generic/GenericTranslucentWindow.java` replaces the generic transparent window to clear the native mask and alpha buffer before each repaint, avoiding stale sprite shadows behind changing actions on generic rendering.
- `src/com/group_finity/mascot/win/WindowsTranslucentWindow.java` replaces the Windows layered window to synchronously refresh per-pixel alpha with `UpdateLayeredWindow`, avoiding stale sprite shadows in the Windows package.
- Shared Java runtime changes, including Hold Pointer, transparent-window repaint fixes, `ActiveShimeji`, and bundled Nashorn compatibility libraries, apply to both Windows and macOS packages because both package `AlansStickfigures.jar`, `conf`, `img`, and `lib`.
- Modern Java support is patched with bundled `lib/nashorn-core-15.7.jar` and ASM dependencies plus compatibility classes under `src/jdk/nashorn/api/scripting/`.
- Use direct `java -jar AlansStickfigures.jar` only for basic Java startup checks. Use `./script/build_and_run.sh --verify` for macOS wrapper, menu-bar, and window-awareness changes.
- The native macOS wrapper source lives in `macos/AlanBeckersStickfiguresLauncher/main.swift`; it builds a regular AppKit app with a menu-bar `ABS` controller, settings/status window, Java child-process start/stop controls, and enabled-stickfigure checkboxes.
- The macOS wrapper copies bundled Java resources to `~/Library/Application Support/AlanBeckersStickfigures/JavaRuntime`, writes the selected `ActiveShimeji` list into that runtime `conf/settings.properties`, and launches Java from that writable copy.
- Use `./script/build_and_run.sh --verify` to build and launch the generated app in `dist/`, then verify both the native wrapper and Java child stay running.
- Use `./script/package_macos.sh` to build `dist/Alan-Beckers-Stickfigures-macOS.dmg`.
- Local macOS packages are ad-hoc signed by default. Public GitHub release DMGs require `MACOS_CODESIGN_IDENTITY` with a Developer ID Application identity plus Team API-key notarization credentials; do not tag a public macOS release until those GitHub secrets are configured.
- The release workflow imports `MACOS_CERTIFICATE_P12`, signs with hardened runtime, notarizes the DMG, staples the ticket, and validates with `spctl`. Missing signing/notarization secrets should fail the macOS release job rather than publish an untrusted DMG.
- Use `./script/package_windows.ps1` on Windows with JDK 17+ and WiX Toolset to build `dist/Alan-Beckers-Stickfigures-Windows.exe`.
- `.github/workflows/release.yml` builds macOS DMG, Windows EXE, and a source ZIP, then creates or updates a GitHub Release for tag pushes or manual workflow dispatch.
- `RunMac.command` is a root-level direct-JAR fallback launcher; the menu-bar/settings experience comes from the generated macOS app bundle.

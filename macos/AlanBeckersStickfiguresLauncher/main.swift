import Cocoa
import CoreGraphics
import Darwin
import Foundation

private enum DefaultsKey {
    static let autoStart = "autoStartStickfigures"
    static let keepAlive = "restartStickfiguresIfTheyExit"
    static let enabledImageSets = "enabledStickfigureImageSets"
}

private struct WindowSnapshot {
    let ownerPID: pid_t
    let bounds: CGRect
    let title: String
}

private enum DockEdge {
    case bottom
    case left
    case right
}

private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenu = NSMenu()
    private var toggleMenuItem = NSMenuItem()
    private var restartMenuItem = NSMenuItem()
    private var settingsWindow: NSWindow?
    private var statusValueLabel: NSTextField?
    private var javaPathLabel: NSTextField?
    private var startStopButton: NSButton?
    private var autoStartCheckbox: NSButton?
    private var keepAliveCheckbox: NSButton?
    private var imageSetCheckboxes: [String: NSButton] = [:]
    private var javaProcess: Process?
    private var logFileHandle: FileHandle?
    private var windowBoundsTimer: Timer?
    private var dockSnapshotUntil: Date?
    private var intentionallyStopped = false

    private var applicationSupportURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("AlanBeckersStickfigures", isDirectory: true)
    }

    private var windowBoundsURL: URL {
        applicationSupportURL.appendingPathComponent("window-bounds.tsv")
    }

    private var runtimeJavaURL: URL {
        applicationSupportURL.appendingPathComponent("JavaRuntime", isDirectory: true)
    }

    private var javaResourcesURL: URL {
        Bundle.main.resourceURL!.appendingPathComponent("Java", isDirectory: true)
    }

    private var jarURL: URL {
        javaResourcesURL.appendingPathComponent("AlansStickfigures.jar")
    }

    private var runtimeJarURL: URL {
        runtimeJavaURL.appendingPathComponent("AlansStickfigures.jar")
    }

    private var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("AlanBeckersStickfigures.log")
    }

    private var isRunning: Bool {
        javaProcess?.isRunning == true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        registerDefaultSettings()
        configureStatusItem()
        startWindowBoundsPublisher()
        showSettingsWindow()

        if UserDefaults.standard.bool(forKey: DefaultsKey.autoStart) {
            startStickfigures(showErrors: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowBoundsTimer?.invalidate()
        windowBoundsTimer = nil
        writeHiddenWindowBounds()
        stopStickfigures(force: true)
    }

    func windowWillClose(_ notification: Notification) {
        updateStatus()
    }

    private func registerDefaultSettings() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: DefaultsKey.autoStart) == nil {
            defaults.set(true, forKey: DefaultsKey.autoStart)
        }
        if defaults.object(forKey: DefaultsKey.keepAlive) == nil {
            defaults.set(false, forKey: DefaultsKey.keepAlive)
        }
        if defaults.object(forKey: DefaultsKey.enabledImageSets) == nil {
            defaults.set(availableImageSetNames(), forKey: DefaultsKey.enabledImageSets)
        }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "ABS"
        statusItem?.button?.toolTip = "Alan Beckers Stickfigures"
        statusItem?.menu = statusMenu
        updateStatusMenu()
    }

    private func updateStatusMenu() {
        statusMenu.removeAllItems()

        let titleItem = NSMenuItem(title: "Alan Beckers Stickfigures", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        statusMenu.addItem(titleItem)

        statusMenu.addItem(NSMenuItem.separator())

        toggleMenuItem = NSMenuItem(
            title: isRunning ? "Turn Off Stickfigures" : "Turn On Stickfigures",
            action: #selector(toggleStickfigures),
            keyEquivalent: ""
        )
        toggleMenuItem.target = self
        statusMenu.addItem(toggleMenuItem)

        restartMenuItem = NSMenuItem(title: "Restart Stickfigures", action: #selector(restartStickfigures), keyEquivalent: "")
        restartMenuItem.target = self
        restartMenuItem.isEnabled = isRunning
        statusMenu.addItem(restartMenuItem)

        statusMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        let logItem = NSMenuItem(title: "Open Log", action: #selector(openLog), keyEquivalent: "")
        logItem.target = self
        statusMenu.addItem(logItem)

        let revealItem = NSMenuItem(title: "Show App in Finder", action: #selector(showAppInFinder), keyEquivalent: "")
        revealItem.target = self
        statusMenu.addItem(revealItem)

        statusMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)
    }

    @objc private func showSettingsWindow() {
        if settingsWindow == nil {
            settingsWindow = buildSettingsWindow()
        }

        updateStatus()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Alan Beckers Stickfigures"
        window.center()
        window.delegate = self

        let titleLabel = NSTextField(labelWithString: "Alan Beckers Stickfigures")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 20)

        let subtitleLabel = NSTextField(labelWithString: "Control the desktop stickfigures from the menu bar.")
        subtitleLabel.textColor = .secondaryLabelColor

        statusValueLabel = NSTextField(labelWithString: "")
        statusValueLabel?.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        javaPathLabel = NSTextField(wrappingLabelWithString: "")
        javaPathLabel?.textColor = .secondaryLabelColor
        javaPathLabel?.font = NSFont.systemFont(ofSize: 12)

        startStopButton = NSButton(title: "", target: self, action: #selector(toggleStickfigures))
        let restartButton = NSButton(title: "Restart", target: self, action: #selector(restartStickfigures))
        let logButton = NSButton(title: "Open Log", target: self, action: #selector(openLog))
        let finderButton = NSButton(title: "Show App in Finder", target: self, action: #selector(showAppInFinder))

        autoStartCheckbox = NSButton(
            checkboxWithTitle: "Turn on stickfigures when this app opens",
            target: self,
            action: #selector(autoStartChanged)
        )
        keepAliveCheckbox = NSButton(
            checkboxWithTitle: "Restart stickfigures if they exit unexpectedly",
            target: self,
            action: #selector(keepAliveChanged)
        )

        let buttonRow = NSStackView(views: [startStopButton!, restartButton, logButton, finderButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY

        let enabledLabel = NSTextField(labelWithString: "Enabled stickfigures")
        enabledLabel.font = NSFont.boldSystemFont(ofSize: 13)

        let imageSetGrid = buildImageSetGrid()

        let stack = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            statusValueLabel!,
            javaPathLabel!,
            buttonRow,
            autoStartCheckbox!,
            keepAliveCheckbox!,
            enabledLabel,
            imageSetGrid
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])

        window.contentView = contentView
        return window
    }

    @objc private func toggleStickfigures() {
        if isRunning {
            stopStickfigures(force: false)
        } else {
            startStickfigures(showErrors: true)
        }
    }

    @objc private func restartStickfigures() {
        stopStickfigures(force: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            self?.startStickfigures(showErrors: true)
        }
    }

    private func startStickfigures(showErrors: Bool) {
        guard !isRunning else {
            updateStatus()
            return
        }

        guard FileManager.default.fileExists(atPath: jarURL.path) else {
            if showErrors {
                presentError("AlansStickfigures.jar was not found in the app bundle.")
            }
            updateStatus()
            return
        }

        guard let javaPath = resolveJavaPath() else {
            if showErrors {
                presentError("Java is required. Install Java, then reopen the app.")
            }
            updateStatus()
            return
        }

        do {
            try prepareRuntimeJavaResources()

            let process = Process()
            process.executableURL = URL(fileURLWithPath: javaPath)
            process.arguments = [
                "-Dshimeji.macWindowBoundsFile=\(windowBoundsURL.path)",
                "-Djava.util.logging.config.file=\(runtimeJavaURL.appendingPathComponent("conf/logging.properties").path)",
                "-jar",
                runtimeJarURL.lastPathComponent
            ]
            process.currentDirectoryURL = runtimeJavaURL

            let logHandle = try openLogFileHandle()
            writeLogLine("Starting stickfigures.", to: logHandle)
            writeLogLine("Java: \(javaPath)", to: logHandle)
            writeLogLine("Runtime: \(runtimeJavaURL.path)", to: logHandle)
            writeLogLine("Enabled sets: \(selectedImageSetNames().joined(separator: "/"))", to: logHandle)
            process.standardOutput = logHandle
            process.standardError = logHandle
            logFileHandle = logHandle

            intentionallyStopped = false
            process.terminationHandler = { [weak self] terminatedProcess in
                DispatchQueue.main.async {
                    self?.handleStickfiguresExit(terminatedProcess)
                }
            }

            try process.run()
            javaProcess = process
        } catch {
            appendLogLine("Failed to start stickfigures: \(error.localizedDescription)")
            if showErrors {
                presentError("Could not start the stickfigures: \(error.localizedDescription)")
            }
            try? logFileHandle?.close()
            logFileHandle = nil
        }

        updateStatus()
    }

    private func availableImageSetNames() -> [String] {
        let imageSetsURL = javaResourcesURL.appendingPathComponent("img", isDirectory: true)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: imageSetsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let directoryNames = urls.compactMap { url -> String? in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  values.isDirectory == true else {
                return nil
            }
            return url.lastPathComponent
        }

        let preferredOrder = ["Blue", "Orange", "Red", "TDL", "Yellow", "Green", "Purple", "TCO", "victim"]
        let knownNames = preferredOrder.filter { directoryNames.contains($0) }
        let extraNames = directoryNames
            .filter { !preferredOrder.contains($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        return knownNames + extraNames
    }

    private func selectedImageSetNames() -> [String] {
        let availableNames = availableImageSetNames()
        guard !availableNames.isEmpty else {
            return []
        }

        let availableSet = Set(availableNames)
        let storedNames = UserDefaults.standard.stringArray(forKey: DefaultsKey.enabledImageSets) ?? availableNames
        let selectedNames = storedNames.filter { availableSet.contains($0) }
        return selectedNames.isEmpty ? availableNames : selectedNames
    }

    private func setSelectedImageSetNames(_ names: [String]) {
        let availableNames = availableImageSetNames()
        let availableSet = Set(availableNames)
        let selectedNames = names.filter { availableSet.contains($0) }
        let safeSelection = selectedNames.isEmpty ? Array(availableNames.prefix(1)) : selectedNames
        UserDefaults.standard.set(safeSelection, forKey: DefaultsKey.enabledImageSets)
    }

    private func buildImageSetGrid() -> NSStackView {
        imageSetCheckboxes.removeAll()

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 8

        let names = availableImageSetNames()
        guard !names.isEmpty else {
            let emptyLabel = NSTextField(labelWithString: "No bundled stickfigures found.")
            emptyLabel.textColor = .secondaryLabelColor
            container.addArrangedSubview(emptyLabel)
            return container
        }

        let selectedNames = Set(selectedImageSetNames())
        var currentRow: NSStackView?

        for (index, name) in names.enumerated() {
            if index % 3 == 0 {
                let row = NSStackView()
                row.orientation = .horizontal
                row.alignment = .centerY
                row.spacing = 16
                container.addArrangedSubview(row)
                currentRow = row
            }

            let checkbox = NSButton(checkboxWithTitle: name, target: self, action: #selector(imageSetChanged(_:)))
            checkbox.state = selectedNames.contains(name) ? .on : .off
            checkbox.widthAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
            currentRow?.addArrangedSubview(checkbox)
            imageSetCheckboxes[name] = checkbox
        }

        return container
    }

    @objc private func imageSetChanged(_ sender: NSButton) {
        let selectedNames = imageSetCheckboxes
            .filter { $0.value.state == .on }
            .map { $0.key }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        if selectedNames.isEmpty {
            sender.state = .on
            setSelectedImageSetNames([sender.title])
        } else {
            setSelectedImageSetNames(selectedNames)
        }

        updateStatus()
        if isRunning {
            restartStickfigures()
        }
    }

    private func prepareRuntimeJavaResources() throws {
        try ensureApplicationSupportDirectory()

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: runtimeJavaURL.path) {
            try fileManager.removeItem(at: runtimeJavaURL)
        }

        try fileManager.copyItem(at: javaResourcesURL, to: runtimeJavaURL)
        try updateRuntimeSettings()
    }

    private func updateRuntimeSettings() throws {
        let settingsURL = runtimeJavaURL
            .appendingPathComponent("conf", isDirectory: true)
            .appendingPathComponent("settings.properties")
        let activeShimeji = selectedImageSetNames().joined(separator: "/")
        var settingsContent = (try? String(contentsOf: settingsURL, encoding: .utf8)) ?? ""

        settingsContent = replacingSettingsProperty(
            in: settingsContent,
            key: "AlwaysShowShimejiChooser",
            value: "false"
        )
        settingsContent = replacingSettingsProperty(
            in: settingsContent,
            key: "ActiveShimeji",
            value: activeShimeji
        )

        try settingsContent.write(to: settingsURL, atomically: true, encoding: .utf8)
    }

    private func replacingSettingsProperty(in content: String, key: String, value: String) -> String {
        let replacement = "\(key)=\(value)"
        var replaced = false
        var lines = content.components(separatedBy: .newlines)
        if lines.last == "" {
            lines.removeLast()
        }

        for index in lines.indices {
            if isSettingsPropertyLine(lines[index], key: key) {
                lines[index] = replacement
                replaced = true
                break
            }
        }

        if !replaced {
            lines.append(replacement)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func isSettingsPropertyLine(_ line: String, key: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(key) else {
            return false
        }

        let remainder = String(trimmed.dropFirst(key.count))
        return remainder.hasPrefix("=") || remainder.hasPrefix(":") || remainder.hasPrefix(" ") || remainder.hasPrefix("\t")
    }

    private func ensureApplicationSupportDirectory() throws {
        try FileManager.default.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
    }

    private func startWindowBoundsPublisher() {
        windowBoundsTimer?.invalidate()
        try? ensureApplicationSupportDirectory()
        publishWindowBounds()

        windowBoundsTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.publishWindowBounds()
        }
    }

    private func publishWindowBounds() {
        guard let snapshot = findInteractiveWindow() else {
            writeHiddenWindowBounds()
            return
        }

        let bounds = snapshot.bounds.integral
        guard bounds.width > 0, bounds.height > 0 else {
            writeHiddenWindowBounds()
            return
        }

        let line = [
            "1",
            String(Int(bounds.origin.x)),
            String(Int(bounds.origin.y)),
            String(Int(bounds.width)),
            String(Int(bounds.height)),
            sanitizeWindowTitle(snapshot.title)
        ].joined(separator: "\t") + "\n"

        try? ensureApplicationSupportDirectory()
        try? line.write(to: windowBoundsURL, atomically: true, encoding: .utf8)
    }

    private func writeHiddenWindowBounds() {
        try? ensureApplicationSupportDirectory()
        try? "0\t0\t0\t0\t0\t\n".write(to: windowBoundsURL, atomically: true, encoding: .utf8)
    }

    private func findInteractiveWindow() -> WindowSnapshot? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let candidates = windowInfo.compactMap { windowSnapshot(from: $0) }
        guard !candidates.isEmpty else {
            return syntheticDockSnapshot()
        }

        let dockSnapshot = syntheticDockSnapshot()
        let mouseLocation = CGEvent(source: nil)?.location
        if let mouseLocation = mouseLocation,
           let windowUnderMouse = candidates.first(where: { $0.bounds.contains(mouseLocation) }) {
            return windowUnderMouse
        }

        if let dockSnapshot = dockSnapshot,
           let mouseLocation = mouseLocation,
           dockSnapshot.bounds.contains(mouseLocation) {
            dockSnapshotUntil = Date().addingTimeInterval(6.0)
            return dockSnapshot
        }

        if let dockSnapshot = dockSnapshot,
           let until = dockSnapshotUntil,
           until > Date() {
            return dockSnapshot
        }

        if let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
           let frontmostWindow = candidates.first(where: { $0.ownerPID == frontmostPID }) {
            return frontmostWindow
        }

        return candidates.first
    }

    private func syntheticDockSnapshot() -> WindowSnapshot? {
        guard !dockAutohideEnabled() else {
            return nil
        }

        let screenDock = visibleDockScreenAndEdge()
        guard let screen = screenDock.screen,
              let edge = screenDock.edge,
              screenDock.inset > 0 else {
            return nil
        }

        let frame = screen.frame
        let inset = screenDock.inset
        let dockLength = estimatedDockLength(maxLength: edge == .bottom ? frame.width : frame.height)
        let bounds: CGRect

        switch edge {
        case .bottom:
            bounds = CGRect(
                x: frame.midX - dockLength / 2.0,
                y: frame.maxY - inset,
                width: dockLength,
                height: inset
            )
        case .left:
            bounds = CGRect(
                x: frame.minX,
                y: frame.maxY - ((frame.height + dockLength) / 2.0),
                width: inset,
                height: dockLength
            )
        case .right:
            bounds = CGRect(
                x: frame.maxX - inset,
                y: frame.maxY - ((frame.height + dockLength) / 2.0),
                width: inset,
                height: dockLength
            )
        }

        return WindowSnapshot(ownerPID: 0, bounds: bounds.integral, title: "Dock")
    }

    private func visibleDockScreenAndEdge() -> (screen: NSScreen?, edge: DockEdge?, inset: CGFloat) {
        let preferredEdge = dockPreferredEdge()
        var bestScreen: NSScreen?
        var bestEdge: DockEdge?
        var bestInset: CGFloat = 0

        for screen in NSScreen.screens {
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            let insets: [(DockEdge, CGFloat)] = [
                (.bottom, max(0, visibleFrame.minY - frame.minY)),
                (.left, max(0, visibleFrame.minX - frame.minX)),
                (.right, max(0, frame.maxX - visibleFrame.maxX))
            ]

            for (edge, inset) in insets where inset >= 12 {
                let preferredBonus: CGFloat = edge == preferredEdge ? 1000 : 0
                if inset + preferredBonus > bestInset + (bestEdge == preferredEdge ? 1000 : 0) {
                    bestScreen = screen
                    bestEdge = edge
                    bestInset = inset
                }
            }
        }

        return (bestScreen, bestEdge, bestInset)
    }

    private func dockPreferredEdge() -> DockEdge {
        switch dockDefaults()?.string(forKey: "orientation") {
        case "left":
            return .left
        case "right":
            return .right
        default:
            return .bottom
        }
    }

    private func estimatedDockLength(maxLength: CGFloat) -> CGFloat {
        let defaults = dockDefaults()
        let tileSize = max(24, CGFloat(defaults?.integer(forKey: "tilesize") ?? 48))
        let persistentApps = defaults?.array(forKey: "persistent-apps")?.count ?? 0
        let persistentOthers = defaults?.array(forKey: "persistent-others")?.count ?? 0
        let recentApps = dockShowsRecentApps() ? 3 : 0
        let iconCount = max(6, persistentApps + persistentOthers + recentApps + 2)
        let estimatedLength = CGFloat(iconCount) * (tileSize + 8) + 72

        return min(maxLength, max(300, estimatedLength))
    }

    private func dockAutohideEnabled() -> Bool {
        guard let value = dockDefaults()?.object(forKey: "autohide") else {
            return false
        }

        return boolValue(value)
    }

    private func dockShowsRecentApps() -> Bool {
        guard let value = dockDefaults()?.object(forKey: "show-recents") else {
            return true
        }

        return boolValue(value)
    }

    private func dockDefaults() -> UserDefaults? {
        UserDefaults(suiteName: "com.apple.dock")
    }

    private func boolValue(_ value: Any) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            return ["1", "true", "yes"].contains(string.lowercased())
        }

        return false
    }

    private func windowSnapshot(from info: [String: Any]) -> WindowSnapshot? {
        guard let layerNumber = info[kCGWindowLayer as String] as? NSNumber,
              layerNumber.intValue == 0,
              let ownerPIDNumber = info[kCGWindowOwnerPID as String] as? NSNumber,
              let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary) else {
            return nil
        }

        let ownerPID = pid_t(ownerPIDNumber.int32Value)
        if ownerPID == getpid() {
            return nil
        }

        if let javaPID = javaProcess?.processIdentifier, ownerPID == javaPID {
            return nil
        }

        let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""
        if shouldIgnoreWindowOwner(ownerName) {
            return nil
        }

        let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0
        guard alpha > 0.01,
              bounds.width >= 120,
              bounds.height >= 80,
              bounds.origin.x.isFinite,
              bounds.origin.y.isFinite,
              bounds.width.isFinite,
              bounds.height.isFinite else {
            return nil
        }

        let windowName = info[kCGWindowName as String] as? String ?? ""
        let title = windowName.isEmpty ? ownerName : "\(ownerName): \(windowName)"
        return WindowSnapshot(ownerPID: ownerPID, bounds: bounds, title: title)
    }

    private func shouldIgnoreWindowOwner(_ ownerName: String) -> Bool {
        if ownerName.localizedCaseInsensitiveContains("Alan Beckers Stickfigures") {
            return true
        }

        let ignoredOwners: Set<String> = [
            "Control Center",
            "Dock",
            "Notification Center",
            "SystemUIServer",
            "Window Server"
        ]
        return ignoredOwners.contains(ownerName)
    }

    private func sanitizeWindowTitle(_ title: String) -> String {
        let cleaned = title
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return String(cleaned.prefix(256))
    }

    private func stopStickfigures(force: Bool) {
        intentionallyStopped = true
        guard let process = javaProcess else {
            updateStatus()
            return
        }

        if process.isRunning {
            appendLogLine(force ? "Stopping stickfigures immediately." : "Stopping stickfigures.")
            process.terminate()
            let processID = process.processIdentifier

            if force {
                Thread.sleep(forTimeInterval: 0.5)
                if process.isRunning {
                    kill(processID, SIGKILL)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if process.isRunning {
                        kill(processID, SIGKILL)
                    }
                }
            }
        }

        updateStatus()
    }

    private func handleStickfiguresExit(_ process: Process) {
        if javaProcess === process {
            javaProcess = nil
        }

        if let logFileHandle {
            writeLogLine("Stickfigures exited with status \(process.terminationStatus).", to: logFileHandle)
        }
        try? logFileHandle?.close()
        logFileHandle = nil
        updateStatus()

        if UserDefaults.standard.bool(forKey: DefaultsKey.keepAlive), !intentionallyStopped {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startStickfigures(showErrors: false)
            }
        }
    }

    private func updateStatus() {
        let statusText = isRunning ? "Status: on" : "Status: off"
        statusValueLabel?.stringValue = statusText
        javaPathLabel?.stringValue = "Java app: \(runtimeJavaURL.path)"
        startStopButton?.title = isRunning ? "Turn Off" : "Turn On"
        autoStartCheckbox?.state = UserDefaults.standard.bool(forKey: DefaultsKey.autoStart) ? .on : .off
        keepAliveCheckbox?.state = UserDefaults.standard.bool(forKey: DefaultsKey.keepAlive) ? .on : .off
        let selectedNames = Set(selectedImageSetNames())
        for (name, checkbox) in imageSetCheckboxes {
            checkbox.state = selectedNames.contains(name) ? .on : .off
        }
        statusItem?.button?.title = isRunning ? "ABS On" : "ABS"
        updateStatusMenu()
    }

    @objc private func autoStartChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: DefaultsKey.autoStart)
    }

    @objc private func keepAliveChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: DefaultsKey.keepAlive)
    }

    private func resolveJavaPath() -> String? {
        if let javaHome = captureOutput("/usr/libexec/java_home", arguments: []), !javaHome.isEmpty {
            let javaPath = "\(javaHome)/bin/java"
            if isUsableJava(at: javaPath) {
                return javaPath
            }
        }

        let candidates = ["/usr/bin/java", "/opt/homebrew/bin/java", "/usr/local/bin/java"]
        return candidates.first { isUsableJava(at: $0) }
    }

    private func isUsableJava(at path: String) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-version"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func captureOutput(_ executable: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func openLogFileHandle() throws -> FileHandle {
        let logsDirectory = logURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        return handle
    }

    private func writeLogLine(_ message: String, to handle: FileHandle) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        guard let data = "[\(timestamp)] \(message)\n".data(using: .utf8) else {
            return
        }

        handle.write(data)
        try? handle.synchronize()
    }

    private func appendLogLine(_ message: String) {
        guard let handle = try? openLogFileHandle() else {
            return
        }

        writeLogLine(message, to: handle)
        try? handle.close()
    }

    private func ensureLogHasVisibleContent() {
        let size = (try? logURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if size == 0 {
            appendLogLine("Log opened. Status: \(isRunning ? "on" : "off"). Java output and wrapper events appear here.")
        }
    }

    @objc private func openLog() {
        ensureLogHasVisibleContent()
        NSWorkspace.shared.open(logURL)
    }

    @objc private func showAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    @objc private func quitApplication() {
        stopStickfigures(force: true)
        NSApp.terminate(nil)
    }

    private func presentError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Alan Beckers Stickfigures"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

@main
private struct LauncherApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

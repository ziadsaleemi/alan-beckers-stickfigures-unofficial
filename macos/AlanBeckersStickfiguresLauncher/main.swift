import Cocoa
import CoreGraphics
import Foundation

private enum DefaultsKey {
    static let autoStart = "autoStartStickfigures"
    static let keepAlive = "restartStickfiguresIfTheyExit"
    static let enabledImageSets = "enabledStickfigureImageSets"
}

private enum MascotAction: String {
    case stand
    case sit
    case walk
    case run
    case dash
    case fall
    case dragged
    case thrown
    case land
    case holdPointer
    case climbWall
    case climbCeiling
    case grabWall
    case grabCeiling
    case trip
    case dance

    var repeatsAnimation: Bool {
        switch self {
        case .land, .trip:
            return false
        case .stand, .sit, .walk, .run, .dash, .fall, .dragged, .thrown, .holdPointer,
             .climbWall, .climbCeiling, .grabWall, .grabCeiling, .dance:
            return true
        }
    }
}

private enum Motion {
    static let walkSpeed: CGFloat = 2.4
    static let runSpeed: CGFloat = 4.8
    static let dashSpeed: CGFloat = 6.4
    static let climbSpeed: CGFloat = 3.6
    static let ceilingSpeed: CGFloat = 4.2
    static let tripSlideSpeed: CGFloat = 3.2
    static let dropTolerance: CGFloat = 18
    static let throwReleaseSpeed: CGFloat = 3
    static let throwVelocityLimit: CGFloat = 18
    static let freshDragVelocityAge: TimeInterval = 0.12
}

private struct PoseFrame {
    let imageName: String
    let anchor: CGPoint
    let velocity: CGVector
    let duration: Int
}

private final class ActionClip {
    let name: String
    let frames: [PoseFrame]
    private let totalDuration: Int

    init(name: String, frames: [PoseFrame]) {
        self.name = name
        self.frames = frames
        self.totalDuration = max(1, frames.reduce(0) { $0 + max(1, $1.duration) })
    }

    var duration: Int {
        totalDuration
    }

    func frame(at tick: Int, repeats: Bool = true) -> PoseFrame? {
        guard !frames.isEmpty else {
            return nil
        }

        var remaining = repeats ? tick % totalDuration : min(max(0, tick), totalDuration - 1)
        for frame in frames {
            remaining -= max(1, frame.duration)
            if remaining < 0 {
                return frame
            }
        }

        return frames.last
    }
}

private final class ActionXMLParser: NSObject, XMLParserDelegate {
    private var currentActionName: String?
    private var currentFrames: [PoseFrame] = []
    private var insideAnimation = false
    private(set) var clips: [String: ActionClip] = [:]

    static func parse(url: URL) -> [String: ActionClip] {
        guard let parser = XMLParser(contentsOf: url) else {
            return [:]
        }

        let delegate = ActionXMLParser()
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.parse()
        return delegate.clips
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "Action":
            currentActionName = attributeDict["Name"]
            currentFrames = []
        case "Animation":
            insideAnimation = currentActionName != nil && (currentFrames.isEmpty || currentActionName == "Pinched")
        case "Pose" where insideAnimation:
            guard let imageName = attributeDict["Image"] else {
                return
            }
            currentFrames.append(PoseFrame(
                imageName: imageName.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
                anchor: parsePoint(attributeDict["ImageAnchor"], fallback: CGPoint(x: 64, y: 128)),
                velocity: parseVelocity(attributeDict["Velocity"]),
                duration: max(1, parseInt(attributeDict["Duration"], fallback: 1))
            ))
        default:
            return
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "Animation":
            insideAnimation = false
        case "Action":
            if let name = currentActionName, !currentFrames.isEmpty, clips[name] == nil {
                clips[name] = ActionClip(name: name, frames: currentFrames)
            }
            currentActionName = nil
            currentFrames = []
        default:
            return
        }
    }

    private func parsePoint(_ rawValue: String?, fallback: CGPoint) -> CGPoint {
        guard let rawValue else {
            return fallback
        }

        let parts = rawValue.split(separator: ",")
        guard parts.count == 2,
              let x = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let y = Double(parts[1].trimmingCharacters(in: .whitespaces)) else {
            return fallback
        }

        return CGPoint(x: x, y: y)
    }

    private func parseVelocity(_ rawValue: String?) -> CGVector {
        let point = parsePoint(rawValue, fallback: .zero)
        return CGVector(dx: point.x, dy: point.y)
    }

    private func parseInt(_ rawValue: String?, fallback: Int) -> Int {
        guard let rawValue,
              let value = Int(rawValue.trimmingCharacters(in: .whitespaces)) else {
            return fallback
        }

        return value
    }
}

private final class ImageSet {
    let name: String
    let directoryURL: URL
    let clips: [String: ActionClip]
    private var imageCache: [String: NSImage] = [:]
    private var visibleBoundsCache: [String: CGRect] = [:]
    private var upperBodyBoundsCache: [String: CGRect] = [:]
    private var stillClipCache: [String: ActionClip] = [:]

    init(name: String, directoryURL: URL) {
        self.name = name
        self.directoryURL = directoryURL
        self.clips = ActionXMLParser.parse(url: directoryURL
            .appendingPathComponent("conf", isDirectory: true)
            .appendingPathComponent("actions.xml"))
    }

    func clip(named preferredName: String, fallback fallbackNames: [String] = []) -> ActionClip? {
        if let clip = clips[preferredName] {
            return clip
        }

        for fallbackName in fallbackNames {
            if let clip = clips[fallbackName] {
                return clip
            }
        }

        return clips.values.first
    }

    func stillClip(
        named actionName: String,
        preferredImages: [String],
        fallback fallbackNames: [String] = []
    ) -> ActionClip? {
        let cacheKey = ([actionName] + preferredImages + fallbackNames).joined(separator: "|")
        if let clip = stillClipCache[cacheKey] {
            return clip
        }

        let sourceClip = clip(named: actionName, fallback: fallbackNames)
        guard let sourceClip,
              let frame = preferredImages.compactMap({ preferredImage in
                  sourceClip.frames.first { $0.imageName == preferredImage }
              }).first ?? sourceClip.frames.first else {
            return nil
        }

        let clip = ActionClip(name: "\(actionName)-Still", frames: [PoseFrame(
            imageName: frame.imageName,
            anchor: frame.anchor,
            velocity: .zero,
            duration: 250
        )])
        stillClipCache[cacheKey] = clip
        return clip
    }

    func pointerHoldClip() -> ActionClip? {
        switch name.lowercased() {
        case "tdl":
            return stillClip(
                named: "Pinched",
                preferredImages: ["pinch03.png"],
                fallback: ["Stand"]
            )
        case "tco":
            return stillClip(
                named: "GrabCeiling",
                preferredImages: ["hang01.png"],
                fallback: ["Pinched", "Falling", "Stand"]
            )
        case "victim":
            return stillClip(
                named: "Pinched",
                preferredImages: ["pinch01.png"],
                fallback: ["Stand"]
            )
        default:
            return stillClip(
                named: "Pinched",
                preferredImages: ["pinch04.png", "pinch03.png", "pinch05.png"],
                fallback: ["Resisting", "Falling", "Stand"]
            )
        }
    }

    func landingClip() -> ActionClip? {
        return clip(named: "StandFromFloor", fallback: ["Bouncing", "Stand"])
    }

    func landingToStandAnchorAdjustment(from landingFrame: PoseFrame, lookRight: Bool) -> CGFloat {
        guard let standFrame = clip(named: "Stand")?.frames.first else {
            return 0
        }

        let offset: (PoseFrame, Bool) -> CGFloat = name.lowercased() == "victim"
            ? upperBodyCenterOffset
            : visibleCenterOffset

        return offset(landingFrame, lookRight) - offset(standFrame, lookRight)
    }

    func image(named imageName: String) -> NSImage? {
        if let image = imageCache[imageName] {
            return image
        }

        let url = directoryURL.appendingPathComponent(imageName)
        guard let data = try? Data(contentsOf: url),
              let representation = NSBitmapImageRep(data: data) else {
            return nil
        }

        let pixelSize = NSSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        representation.size = pixelSize
        visibleBoundsCache[imageName] = visibleBounds(in: representation, fallbackSize: pixelSize)
        upperBodyBoundsCache[imageName] = visibleBounds(
            in: representation,
            fallbackSize: pixelSize,
            maxY: Int(CGFloat(representation.pixelsHigh) * 0.56)
        )

        let image = NSImage(size: pixelSize)
        image.addRepresentation(representation)
        image.cacheMode = NSImage.CacheMode.never

        imageCache[imageName] = image
        return image
    }

    private func visibleCenterOffset(for frame: PoseFrame, lookRight: Bool) -> CGFloat {
        guard let image = image(named: frame.imageName) else {
            return 0
        }

        let bounds = visibleBoundsCache[frame.imageName] ?? CGRect(origin: .zero, size: image.size)
        return centerOffset(bounds.midX, anchorX: frame.anchor.x, lookRight: lookRight)
    }

    private func upperBodyCenterOffset(for frame: PoseFrame, lookRight: Bool) -> CGFloat {
        guard let image = image(named: frame.imageName) else {
            return 0
        }

        let bounds = upperBodyBoundsCache[frame.imageName]
            ?? visibleBoundsCache[frame.imageName]
            ?? CGRect(origin: .zero, size: image.size)
        return centerOffset(bounds.midX, anchorX: frame.anchor.x, lookRight: lookRight)
    }

    private func centerOffset(_ centerX: CGFloat, anchorX: CGFloat, lookRight: Bool) -> CGFloat {
        lookRight ? anchorX - centerX : centerX - anchorX
    }

    private func visibleBounds(
        in representation: NSBitmapImageRep,
        fallbackSize: NSSize,
        maxY: Int? = nil
    ) -> CGRect {
        guard representation.hasAlpha else {
            return CGRect(origin: .zero, size: fallbackSize)
        }

        var minX = representation.pixelsWide
        var minY = representation.pixelsHigh
        var maxOpaqueX = -1
        var maxOpaqueY = -1

        let yLimit = min(maxY ?? representation.pixelsHigh, representation.pixelsHigh)
        for y in 0..<yLimit {
            for x in 0..<representation.pixelsWide {
                guard let color = representation.colorAt(x: x, y: y),
                      color.alphaComponent > 0.01 else {
                    continue
                }

                minX = min(minX, x)
                minY = min(minY, y)
                maxOpaqueX = max(maxOpaqueX, x)
                maxOpaqueY = max(maxOpaqueY, y)
            }
        }

        guard maxOpaqueX >= minX, maxOpaqueY >= minY else {
            return CGRect(origin: .zero, size: fallbackSize)
        }

        return CGRect(
            x: CGFloat(minX),
            y: CGFloat(minY),
            width: CGFloat(maxOpaqueX - minX + 1),
            height: CGFloat(maxOpaqueY - minY + 1)
        )
    }
}

private struct PlatformSurface {
    let rect: CGRect
    let title: String
}

private final class DesktopWorld {
    private(set) var platforms: [PlatformSurface] = []
    private var lastRefresh = Date.distantPast

    func refreshIfNeeded() {
        guard Date().timeIntervalSince(lastRefresh) > 0.35 else {
            return
        }

        lastRefresh = Date()
        platforms = windowPlatforms() + dockPlatform()
    }

    var desktopFrame: CGRect {
        let screens = NSScreen.screens.map { $0.frame }
        guard let first = screens.first else {
            return CGRect(x: 0, y: 0, width: 1440, height: 900)
        }

        return screens.dropFirst().reduce(first) { $0.union($1) }
    }

    func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
            ?? NSScreen.screens.first { point.x >= $0.frame.minX && point.x <= $0.frame.maxX }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    func floorY(atX x: CGFloat) -> CGFloat {
        let point = CGPoint(x: x, y: 0)
        if let screen = screen(containing: point) {
            return screen.frame.minY + 8
        }

        return desktopFrame.minY + 8
    }

    func ceilingY(atX x: CGFloat) -> CGFloat {
        let point = CGPoint(x: x, y: 0)
        if let screen = screen(containing: point) {
            return screen.visibleFrame.maxY - 12
        }

        return desktopFrame.maxY - 12
    }

    func leftWallX(near point: CGPoint) -> CGFloat {
        screen(containing: point)?.frame.minX ?? desktopFrame.minX
    }

    func rightWallX(near point: CGPoint) -> CGFloat {
        screen(containing: point)?.frame.maxX ?? desktopFrame.maxX
    }

    func surfaceBelow(anchor: CGPoint, tolerance: CGFloat = 96) -> PlatformSurface? {
        refreshIfNeeded()
        var best: PlatformSurface?
        var bestY = floorY(atX: anchor.x)

        for platform in platforms where platform.rect.minX - 24 <= anchor.x && anchor.x <= platform.rect.maxX + 24 {
            let top = platform.rect.maxY
            guard top <= anchor.y + 8, anchor.y - top <= tolerance else {
                continue
            }

            if top > bestY {
                best = platform
                bestY = top
            }
        }

        return best
    }

    func groundY(for anchor: CGPoint) -> CGFloat {
        surfaceBelow(anchor: anchor)?.rect.maxY ?? floorY(atX: anchor.x)
    }

    func randomPointOnFloor() -> CGPoint {
        let frame = desktopFrame
        let x = CGFloat.random(in: (frame.minX + 120)...max(frame.minX + 121, frame.maxX - 120))
        return CGPoint(x: x, y: floorY(atX: x))
    }

    private func windowPlatforms() -> [PlatformSurface] {
        let ignoredOwners: Set<String> = [
            "Alan Beckers Stickfigures",
            "Control Center",
            "Dock",
            "Notification Center",
            "SystemUIServer",
            "Window Server"
        ]
        let maxY = desktopFrame.maxY
        let currentPID = getpid()

        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return windowInfo.compactMap { info -> PlatformSurface? in
            guard let layer = info[kCGWindowLayer as String] as? NSNumber,
                  layer.intValue == 0,
                  let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPID.int32Value != currentPID,
                  let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary) else {
                return nil
            }

            let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""
            if ignoredOwners.contains(ownerName) || ownerName.localizedCaseInsensitiveContains("Alan Beckers Stickfigures") {
                return nil
            }

            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0
            guard alpha > 0.01, bounds.width >= 160, bounds.height >= 100 else {
                return nil
            }

            let converted = CGRect(
                x: bounds.minX,
                y: maxY - bounds.minY - bounds.height,
                width: bounds.width,
                height: bounds.height
            )
            let title = (info[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? ownerName
            return PlatformSurface(rect: converted.integral, title: title)
        }
    }

    private func dockPlatform() -> [PlatformSurface] {
        guard !dockAutohideEnabled() else {
            return []
        }

        guard let screen = NSScreen.screens.max(by: { dockInset(on: $0) < dockInset(on: $1) }) else {
            return []
        }

        let inset = dockInset(on: screen)
        guard inset >= 12 else {
            return []
        }

        let frame = screen.frame
        let edge = dockPreferredEdge()
        let maxLength = edge == "bottom" ? frame.width : frame.height
        let dockLength = estimatedDockLength(maxLength: maxLength)
        let rect: CGRect

        switch edge {
        case "left":
            rect = CGRect(
                x: frame.minX,
                y: frame.midY - dockLength / 2,
                width: inset,
                height: dockLength
            )
        case "right":
            rect = CGRect(
                x: frame.maxX - inset,
                y: frame.midY - dockLength / 2,
                width: inset,
                height: dockLength
            )
        default:
            rect = CGRect(
                x: frame.midX - dockLength / 2,
                y: frame.minY,
                width: dockLength,
                height: inset
            )
        }

        return [PlatformSurface(rect: rect.integral, title: "Dock")]
    }

    private func dockInset(on screen: NSScreen) -> CGFloat {
        let frame = screen.frame
        let visible = screen.visibleFrame
        switch dockPreferredEdge() {
        case "left":
            return max(0, visible.minX - frame.minX)
        case "right":
            return max(0, frame.maxX - visible.maxX)
        default:
            return max(0, visible.minY - frame.minY)
        }
    }

    private func dockPreferredEdge() -> String {
        UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") ?? "bottom"
    }

    private func dockAutohideEnabled() -> Bool {
        guard let value = UserDefaults(suiteName: "com.apple.dock")?.object(forKey: "autohide") else {
            return false
        }

        return boolValue(value)
    }

    private func estimatedDockLength(maxLength: CGFloat) -> CGFloat {
        let defaults = UserDefaults(suiteName: "com.apple.dock")
        let tileSize = max(24, CGFloat(defaults?.integer(forKey: "tilesize") ?? 48))
        let appCount = defaults?.array(forKey: "persistent-apps")?.count ?? 0
        let otherCount = defaults?.array(forKey: "persistent-others")?.count ?? 0
        let recentCount = boolValue(defaults?.object(forKey: "show-recents") ?? true) ? 3 : 0
        let iconCount = max(6, appCount + otherCount + recentCount + 2)
        return min(maxLength, max(300, CGFloat(iconCount) * (tileSize + 8) + 72))
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
}

private final class MascotWindow: NSPanel {
    init(size: CGSize) {
        super.init(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class SpriteView: NSView {
    weak var mascot: Mascot?
    var image: NSImage?
    var lookRight = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    private func configureLayer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    override var isFlipped: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill(using: .clear)

        guard let image else {
            return
        }

        NSGraphicsContext.current?.imageInterpolation = .none
        if lookRight {
            guard let context = NSGraphicsContext.current?.cgContext else {
                return
            }
            context.saveGState()
            context.translateBy(x: bounds.maxX, y: bounds.minY)
            context.scaleBy(x: -1, y: 1)
            image.draw(in: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
            context.restoreGState()
        } else {
            image.draw(in: bounds)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        mascot?.controller?.beginDrag(mascot: mascot!, event: event)
    }

    override func mouseDragged(with event: NSEvent) {
        mascot?.controller?.continueDrag(mascot: mascot!, event: event)
    }

    override func mouseUp(with event: NSEvent) {
        mascot?.controller?.endDrag(mascot: mascot!, event: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let mascot else {
            return
        }

        let menu = NSMenu()
        let hold = NSMenuItem(title: "Hold Pointer", action: #selector(MascotController.holdPointerFromMenu(_:)), keyEquivalent: "")
        hold.representedObject = mascot
        hold.target = mascot.controller
        menu.addItem(hold)

        let release = NSMenuItem(title: "Release Pointer", action: #selector(MascotController.releasePointerFromMenu(_:)), keyEquivalent: "")
        release.representedObject = mascot
        release.target = mascot.controller
        menu.addItem(release)

        menu.addItem(.separator())

        let dismiss = NSMenuItem(title: "Hide This Stickfigure", action: #selector(MascotController.hideMascotFromMenu(_:)), keyEquivalent: "")
        dismiss.representedObject = mascot
        dismiss.target = mascot.controller
        menu.addItem(dismiss)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

private final class Mascot {
    let id: Int
    let imageSet: ImageSet
    let window: MascotWindow
    let view: SpriteView
    weak var controller: MascotController?

    var anchor: CGPoint
    var lookRight = false
    var action: MascotAction = .fall
    var actionTick = 0
    var targetX: CGFloat?
    var targetY: CGFloat?
    var velocity = CGVector(dx: 0, dy: 0)
    var lastDragLocation: CGPoint?
    var lastDragVelocity = CGVector(dx: 0, dy: 0)
    var lastDragUpdate = Date.distantPast
    var nextDecisionTick = 0
    var wallSide: CGFloat = -1
    private var renderedImageName: String?
    private var renderedLookRight = false
    private var renderedSize = CGSize.zero
    private var needsImmediateRender = false

    init(id: Int, imageSet: ImageSet, anchor: CGPoint, controller: MascotController) {
        self.id = id
        self.imageSet = imageSet
        self.anchor = anchor
        self.controller = controller
        self.view = SpriteView(frame: CGRect(x: 0, y: 0, width: 128, height: 128))
        self.window = MascotWindow(size: CGSize(width: 128, height: 128))
        view.mascot = self
        window.contentView = view
        choose(.fall)
        render()
        window.orderFrontRegardless()
    }

    func choose(_ newAction: MascotAction, targetX: CGFloat? = nil, targetY: CGFloat? = nil) {
        action = newAction
        actionTick = 0
        needsImmediateRender = true
        self.targetX = targetX
        self.targetY = targetY

        switch newAction {
        case .thrown:
            velocity = limitedThrowVelocity(lastDragVelocity)
            updateLookDirectionFromVelocity()
        case .fall:
            velocity.dy = min(velocity.dy, -2)
            updateLookDirectionFromVelocity()
        case .stand, .sit, .land:
            velocity = .zero
            nextDecisionTick = Int.random(in: 55...180)
        case .grabWall, .grabCeiling:
            velocity = .zero
            nextDecisionTick = Int.random(in: 24...55)
        case .trip:
            velocity = CGVector(dx: lookRight ? Motion.tripSlideSpeed : -Motion.tripSlideSpeed, dy: 0)
        case .walk, .run, .dash, .dragged, .holdPointer, .climbWall, .climbCeiling, .dance:
            velocity = .zero
        }
    }

    func close() {
        window.orderOut(nil)
    }

    func step(in world: DesktopWorld) {
        actionTick += 1

        switch action {
        case .holdPointer:
            let mouse = NSEvent.mouseLocation
            anchor = anchorForPointer(mouse)
        case .dragged:
            break
        case .thrown:
            stepThrown(in: world)
        case .fall:
            stepFall(in: world)
        case .land:
            stepLanding(in: world)
        case .walk, .run, .dash:
            stepHorizontalMove(in: world)
        case .climbWall:
            stepWallClimb(in: world)
        case .climbCeiling:
            stepCeilingMove(in: world)
        case .trip:
            stepTrip(in: world)
            if actionTick > currentClipDuration(defaultDuration: 90) {
                choose(.stand)
            }
        case .dance:
            _ = settleOnGround(in: world)
            if actionTick > currentClipDuration(defaultDuration: 90) {
                choose(.stand)
            }
        case .grabWall:
            lookRight = wallSide > 0
            if actionTick > nextDecisionTick {
                choose(.climbWall, targetY: world.ceilingY(atX: anchor.x))
            }
        case .grabCeiling:
            clampSpriteTop(to: world.ceilingY(atX: anchor.x))
            if actionTick > nextDecisionTick {
                choose(.climbCeiling, targetX: randomTargetX(in: world))
            }
        case .stand, .sit:
            if settleOnGround(in: world), actionTick > nextDecisionTick {
                chooseNextBehavior(in: world)
            }
        }

        keepInsideDesktop(world)
        let immediate = needsImmediateRender || action == .dragged || action == .holdPointer
        render(immediate: immediate)
        needsImmediateRender = false
    }

    func beginDrag(at mouse: CGPoint) {
        lastDragLocation = mouse
        lastDragVelocity = .zero
        lastDragUpdate = Date()
        choose(.dragged)
        anchor = anchorForPointer(mouse)
        render(immediate: true)
    }

    func drag(to mouse: CGPoint) {
        if let lastDragLocation {
            lastDragVelocity = CGVector(dx: mouse.x - lastDragLocation.x, dy: mouse.y - lastDragLocation.y)
        }
        lastDragLocation = mouse
        lastDragUpdate = Date()
        anchor = anchorForPointer(mouse)
        render(immediate: true)
    }

    func endDrag() {
        if shouldThrowFromDrag() {
            choose(.thrown)
        } else {
            velocity = .zero
            choose(.fall)
        }
    }

    func holdPointer() {
        let mouse = NSEvent.mouseLocation
        choose(.holdPointer)
        anchor = anchorForPointer(mouse)
        render(immediate: true)
    }

    func releasePointer() {
        velocity = .zero
        choose(.fall)
    }

    private func chooseNextBehavior(in world: DesktopWorld) {
        let roll = Int.random(in: 0..<100)

        if roll < 38 {
            choose(.walk, targetX: randomTargetX(in: world))
        } else if roll < 56 {
            choose(.run, targetX: randomTargetX(in: world))
        } else if roll < 67 {
            choose(.sit)
        } else if roll < 77 {
            choose(.trip)
        } else if roll < 84 {
            choose(.dance)
        } else if roll < 92 {
            runTowardWall(in: world)
        } else {
            choose(.stand)
        }
    }

    private func runTowardWall(in world: DesktopWorld) {
        let left = world.leftWallX(near: anchor) + 8
        let right = world.rightWallX(near: anchor) - 8
        let goRight = abs(anchor.x - left) > abs(anchor.x - right)
        wallSide = goRight ? 1 : -1
        choose(.dash, targetX: goRight ? right : left)
    }

    private func stepHorizontalMove(in world: DesktopWorld) {
        guard let targetX else {
            choose(.stand)
            return
        }

        lookRight = targetX > anchor.x
        let direction: CGFloat = lookRight ? 1 : -1
        anchor.x += movementSpeed() * direction
        guard settleOnGround(in: world) else {
            return
        }

        let reached = lookRight ? anchor.x >= targetX : anchor.x <= targetX
        if reached {
            anchor.x = targetX
            if abs(targetX - world.leftWallX(near: anchor)) < 24 || abs(targetX - world.rightWallX(near: anchor)) < 24 {
                choose(.grabWall)
            } else {
                choose(Bool.random() ? .stand : .sit)
            }
        }
    }

    private func stepWallClimb(in world: DesktopWorld) {
        guard let targetY else {
            choose(.fall)
            return
        }

        lookRight = wallSide > 0
        let direction: CGFloat = targetY > anchor.y ? 1 : -1
        anchor.y += Motion.climbSpeed * direction
        anchor.x = wallSide < 0 ? world.leftWallX(near: anchor) + 8 : world.rightWallX(near: anchor) - 8

        let ceiling = world.ceilingY(atX: anchor.x)
        let reached = direction > 0 ? anchor.y >= targetY : anchor.y <= targetY
        let visibleTop = currentSpriteRect()?.maxY ?? anchor.y
        if reached || visibleTop >= ceiling || actionTick > 180 {
            anchor.y = ceiling
            choose(.grabCeiling)
        }
    }

    private func stepCeilingMove(in world: DesktopWorld) {
        guard let targetX else {
            choose(.grabCeiling)
            return
        }

        let ceiling = world.ceilingY(atX: anchor.x)
        anchor.y = ceiling
        lookRight = targetX > anchor.x
        let direction: CGFloat = lookRight ? 1 : -1
        anchor.x += Motion.ceilingSpeed * direction
        clampSpriteTop(to: ceiling)
        let reached = lookRight ? anchor.x >= targetX : anchor.x <= targetX
        if reached || actionTick > 180 {
            choose(.fall)
        }
    }

    private func stepFall(in world: DesktopWorld) {
        velocity.dy -= 0.65
        velocity.dx *= 0.98
        updateLookDirectionFromVelocity()
        anchor.x += velocity.dx
        anchor.y += velocity.dy

        let ground = world.groundY(for: anchor)
        if anchor.y <= ground {
            anchor.y = ground
            velocity = .zero
            choose(.land)
        }
    }

    private func stepThrown(in world: DesktopWorld) {
        velocity.dy -= 0.6
        velocity.dx *= 0.985
        updateLookDirectionFromVelocity()
        anchor.x += velocity.dx
        anchor.y += velocity.dy

        let ground = world.groundY(for: anchor)
        if anchor.y <= ground {
            anchor.y = ground
            velocity = .zero
            choose(.land)
        }
    }

    private func stepLanding(in world: DesktopWorld) {
        _ = settleOnGround(in: world)
        if actionTick >= currentClipDuration(defaultDuration: 18) {
            if let landingFrame = currentFrame() {
                anchor.x += imageSet.landingToStandAnchorAdjustment(from: landingFrame, lookRight: lookRight)
            }
            choose(.stand)
        }
    }

    private func stepTrip(in world: DesktopWorld) {
        anchor.x += velocity.dx
        velocity.dx *= 0.88
        _ = settleOnGround(in: world)
    }

    private func movementSpeed() -> CGFloat {
        switch action {
        case .walk:
            return Motion.walkSpeed
        case .run:
            return Motion.runSpeed
        case .dash:
            return Motion.dashSpeed
        default:
            return Motion.walkSpeed
        }
    }

    private func updateLookDirectionFromVelocity() {
        guard abs(velocity.dx) > 0.35 else {
            return
        }

        lookRight = velocity.dx > 0
    }

    private func shouldThrowFromDrag() -> Bool {
        let age = Date().timeIntervalSince(lastDragUpdate)
        guard age <= Motion.freshDragVelocityAge else {
            return false
        }

        return hypot(lastDragVelocity.dx, lastDragVelocity.dy) >= Motion.throwReleaseSpeed
    }

    private func limitedThrowVelocity(_ rawVelocity: CGVector) -> CGVector {
        let speed = hypot(rawVelocity.dx, rawVelocity.dy)
        guard speed > Motion.throwVelocityLimit else {
            return rawVelocity
        }

        let scale = Motion.throwVelocityLimit / speed
        return CGVector(dx: rawVelocity.dx * scale, dy: rawVelocity.dy * scale)
    }

    private func anchorForPointer(_ mouse: CGPoint) -> CGPoint {
        let offset = pointerGrabAnchorOffset()
        return CGPoint(x: mouse.x + offset.dx, y: mouse.y + offset.dy)
    }

    private func pointerGrabAnchorOffset() -> CGVector {
        guard let frame = currentFrame(),
              let image = imageSet.image(named: frame.imageName) else {
            return CGVector(dx: 0, dy: -116)
        }

        let size = image.size
        let anchorX = lookRight ? size.width - frame.anchor.x : frame.anchor.x
        let anchorInWindow = CGPoint(x: anchorX, y: size.height - frame.anchor.y)
        let grabX = lookRight ? size.width - frame.anchor.x : frame.anchor.x
        let grabYFromTop = min(6, max(0, size.height * 0.05))
        let grabInWindow = CGPoint(x: grabX, y: size.height - grabYFromTop)
        return CGVector(dx: anchorInWindow.x - grabInWindow.x, dy: anchorInWindow.y - grabInWindow.y)
    }

    @discardableResult
    private func settleOnGround(in world: DesktopWorld) -> Bool {
        let ground = world.groundY(for: anchor)
        if ground < anchor.y - Motion.dropTolerance {
            choose(.fall)
            return false
        }

        anchor.y = ground
        return true
    }

    private func keepInsideDesktop(_ world: DesktopWorld) {
        let frame = world.desktopFrame.insetBy(dx: 8, dy: 0)
        if anchor.x < frame.minX {
            anchor.x = frame.minX
            wallSide = -1
            if action != .dragged && action != .holdPointer {
                choose(.grabWall)
            }
        } else if anchor.x > frame.maxX {
            anchor.x = frame.maxX
            wallSide = 1
            if action != .dragged && action != .holdPointer {
                choose(.grabWall)
            }
        }

        let ceiling = world.ceilingY(atX: anchor.x)
        guard let rect = currentSpriteRect(), rect.maxY > ceiling else {
            return
        }

        switch action {
        case .dragged, .holdPointer:
            break
        case .grabCeiling, .climbCeiling:
            clampSpriteTop(to: ceiling)
        case .climbWall:
            anchor.y = ceiling
            choose(.grabCeiling)
        default:
            anchor.y -= rect.maxY - ceiling
            velocity.dy = min(velocity.dy, 0)
            if action != .fall {
                choose(.fall)
            }
        }
    }

    private func randomTargetX(in world: DesktopWorld) -> CGFloat {
        let frame = world.desktopFrame
        let minX = frame.minX + 80
        let maxX = frame.maxX - 80
        guard minX < maxX else {
            return anchor.x
        }
        return CGFloat.random(in: minX...maxX)
    }

    private func currentFrame() -> PoseFrame? {
        let clip = clipForCurrentAction()
        return clip?.frame(at: actionTick, repeats: action.repeatsAnimation)
    }

    private func currentClipDuration(defaultDuration: Int) -> Int {
        clipForCurrentAction()?.duration ?? defaultDuration
    }

    private func clipForCurrentAction() -> ActionClip? {
        switch action {
        case .stand:
            return imageSet.clip(named: "Stand")
        case .sit:
            return imageSet.clip(named: "SitAndLookAtMouse", fallback: ["Sit"])
        case .walk:
            return imageSet.clip(named: "Walk")
        case .run:
            return imageSet.clip(named: "Run", fallback: ["Dash", "Walk"])
        case .dash:
            return imageSet.clip(named: "Dash", fallback: ["Run", "Walk"])
        case .fall, .thrown:
            return imageSet.clip(named: "Falling", fallback: ["Stand"])
        case .land:
            return imageSet.landingClip()
        case .dragged, .holdPointer:
            return imageSet.pointerHoldClip()
        case .climbWall:
            return imageSet.clip(named: "ClimbWall", fallback: ["GrabWall"])
        case .climbCeiling:
            return imageSet.clip(named: "ClimbCeiling", fallback: ["GrabCeiling"])
        case .grabWall:
            return imageSet.clip(named: "GrabWall", fallback: ["Stand"])
        case .grabCeiling:
            return imageSet.clip(named: "GrabCeiling", fallback: ["Stand"])
        case .trip:
            return imageSet.clip(named: "Tripping", fallback: ["StandFromFloor", "Stand"])
        case .dance:
            return imageSet.clip(named: "Dance", fallback: ["Stand"])
        }
    }

    private func render(immediate: Bool = false) {
        guard let frame = currentFrame(),
              let image = imageSet.image(named: frame.imageName) else {
            return
        }

        let rect = spriteRect(for: frame, image: image)
        let frameChanged = renderedImageName != frame.imageName || renderedLookRight != lookRight || renderedSize != rect.size
        if frameChanged {
            view.frame = CGRect(origin: .zero, size: rect.size)
            view.image = image
            view.lookRight = lookRight
            view.needsDisplay = true
            renderedImageName = frame.imageName
            renderedLookRight = lookRight
            renderedSize = rect.size
        }

        window.setFrame(rect, display: false)
        if frameChanged || immediate {
            view.needsDisplay = true
            if immediate {
                view.displayIfNeeded()
            }
        }
    }

    private func currentSpriteRect() -> CGRect? {
        guard let frame = currentFrame(),
              let image = imageSet.image(named: frame.imageName) else {
            return nil
        }

        return spriteRect(for: frame, image: image)
    }

    private func clampSpriteTop(to ceiling: CGFloat) {
        guard let rect = currentSpriteRect(), rect.maxY > ceiling else {
            return
        }

        anchor.y -= rect.maxY - ceiling
    }

    private func spriteRect(for frame: PoseFrame, image: NSImage) -> CGRect {
        let size = image.size
        let anchorX = lookRight ? size.width - frame.anchor.x : frame.anchor.x
        let anchorInWindow = CGPoint(x: anchorX, y: size.height - frame.anchor.y)
        let origin = CGPoint(x: anchor.x - anchorInWindow.x, y: anchor.y - anchorInWindow.y)
        return CGRect(origin: origin, size: size)
    }
}

private final class MascotController: NSObject {
    private let world = DesktopWorld()
    private var timer: Timer?
    private var nextID = 1
    private(set) var mascots: [Mascot] = []
    private var imageSets: [ImageSet] = []
    var isRunning: Bool {
        timer != nil
    }
    var onStatusChanged: (() -> Void)?

    func loadImageSets(from imageRootURL: URL) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: imageRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            imageSets = []
            return
        }

        let names = urls.compactMap { url -> String? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return nil
            }
            return url.lastPathComponent
        }
        let preferred = ["Blue", "Orange", "Red", "TDL", "Yellow", "Green", "Purple", "TCO", "victim"]
        let ordered = preferred.filter { names.contains($0) } + names.filter { !preferred.contains($0) }.sorted()
        imageSets = ordered.map { ImageSet(name: $0, directoryURL: imageRootURL.appendingPathComponent($0, isDirectory: true)) }
    }

    func availableImageSetNames() -> [String] {
        imageSets.map(\.name)
    }

    func start(selectedNames: [String]) {
        stop()
        let selected = Set(selectedNames)
        let enabledSets = imageSets.filter { selected.contains($0.name) || selected.isEmpty }
        guard !enabledSets.isEmpty else {
            onStatusChanged?()
            return
        }

        for imageSet in enabledSets {
            let mascot = Mascot(id: nextID, imageSet: imageSet, anchor: world.randomPointOnFloor(), controller: self)
            nextID += 1
            mascots.append(mascot)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
        onStatusChanged?()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        mascots.forEach { $0.close() }
        mascots.removeAll()
        onStatusChanged?()
    }

    func restart(selectedNames: [String]) {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.start(selectedNames: selectedNames)
        }
    }

    func hideDisabled(selectedNames: [String]) {
        guard isRunning else {
            return
        }
        restart(selectedNames: selectedNames)
    }

    func beginDrag(mascot: Mascot, event: NSEvent) {
        mascot.beginDrag(at: NSEvent.mouseLocation)
    }

    func continueDrag(mascot: Mascot, event: NSEvent) {
        mascot.drag(to: NSEvent.mouseLocation)
    }

    func endDrag(mascot: Mascot, event: NSEvent) {
        mascot.endDrag()
    }

    @objc func holdPointerFromMenu(_ sender: NSMenuItem) {
        (sender.representedObject as? Mascot)?.holdPointer()
    }

    @objc func releasePointerFromMenu(_ sender: NSMenuItem) {
        (sender.representedObject as? Mascot)?.releasePointer()
    }

    @objc func hideMascotFromMenu(_ sender: NSMenuItem) {
        guard let mascot = sender.representedObject as? Mascot else {
            return
        }
        mascot.close()
        mascots.removeAll { $0 === mascot }
    }

    private func tick() {
        world.refreshIfNeeded()
        mascots.forEach { $0.step(in: world) }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let controller = MascotController()
    private var statusItem: NSStatusItem?
    private var statusMenu = NSMenu()
    private var settingsWindow: NSWindow?
    private var statusValueLabel: NSTextField?
    private var resourcePathLabel: NSTextField?
    private var startStopButton: NSButton?
    private var autoStartCheckbox: NSButton?
    private var keepAliveCheckbox: NSButton?
    private var imageSetCheckboxes: [String: NSButton] = [:]

    private var resourcesURL: URL {
        Bundle.main.resourceURL!.appendingPathComponent("Stickfigures", isDirectory: true)
    }

    private var imageRootURL: URL {
        resourcesURL.appendingPathComponent("img", isDirectory: true)
    }

    private var logURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)

        return baseURL
            .appendingPathComponent("Alan Beckers Stickfigures", isDirectory: true)
            .appendingPathComponent("AlanBeckersStickfigures.log")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerDefaultSettings()
        controller.loadImageSets(from: imageRootURL)
        controller.onStatusChanged = { [weak self] in
            self?.updateStatus()
        }
        configureStatusItem()
        showSettingsWindow()
        appendLogLine("Native Swift app launched.")

        if UserDefaults.standard.bool(forKey: DefaultsKey.autoStart) {
            controller.start(selectedNames: selectedImageSetNames())
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
        appendLogLine("Native Swift app exited.")
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
        statusMenu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: controller.isRunning ? "Turn Off Stickfigures" : "Turn On Stickfigures",
            action: #selector(toggleStickfigures),
            keyEquivalent: ""
        )
        toggleItem.target = self
        statusMenu.addItem(toggleItem)

        let restartItem = NSMenuItem(title: "Restart Stickfigures", action: #selector(restartStickfigures), keyEquivalent: "")
        restartItem.target = self
        restartItem.isEnabled = controller.isRunning
        statusMenu.addItem(restartItem)

        statusMenu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        let logItem = NSMenuItem(title: "Open Log", action: #selector(openLog), keyEquivalent: "")
        logItem.target = self
        statusMenu.addItem(logItem)

        let revealItem = NSMenuItem(title: "Show App in Finder", action: #selector(showAppInFinder), keyEquivalent: "")
        revealItem.target = self
        statusMenu.addItem(revealItem)

        statusMenu.addItem(.separator())

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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Alan Beckers Stickfigures"
        window.center()
        window.delegate = self

        let titleLabel = NSTextField(labelWithString: "Alan Beckers Stickfigures")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 20)

        let subtitleLabel = NSTextField(labelWithString: "Native macOS desktop stickfigures.")
        subtitleLabel.textColor = .secondaryLabelColor

        statusValueLabel = NSTextField(labelWithString: "")
        statusValueLabel?.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        resourcePathLabel = NSTextField(wrappingLabelWithString: "")
        resourcePathLabel?.textColor = .secondaryLabelColor
        resourcePathLabel?.font = NSFont.systemFont(ofSize: 12)

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
            checkboxWithTitle: "Restart stickfigures if they stop",
            target: self,
            action: #selector(keepAliveChanged)
        )

        let buttonRow = NSStackView(views: [startStopButton!, restartButton, logButton, finderButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY

        let enabledLabel = NSTextField(labelWithString: "Enabled stickfigures")
        enabledLabel.font = NSFont.boldSystemFont(ofSize: 13)

        let stack = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            statusValueLabel!,
            resourcePathLabel!,
            buttonRow,
            autoStartCheckbox!,
            keepAliveCheckbox!,
            enabledLabel,
            buildImageSetGrid()
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

    private func buildImageSetGrid() -> NSStackView {
        imageSetCheckboxes.removeAll()
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 8

        let names = availableImageSetNames()
        if names.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No bundled stickfigures found.")
            emptyLabel.textColor = .secondaryLabelColor
            container.addArrangedSubview(emptyLabel)
            return container
        }

        let selectedNames = Set(selectedImageSetNames())
        var row: NSStackView?
        for (index, name) in names.enumerated() {
            if index % 3 == 0 {
                let nextRow = NSStackView()
                nextRow.orientation = .horizontal
                nextRow.alignment = .centerY
                nextRow.spacing = 16
                container.addArrangedSubview(nextRow)
                row = nextRow
            }

            let checkbox = NSButton(checkboxWithTitle: name, target: self, action: #selector(imageSetChanged(_:)))
            checkbox.state = selectedNames.contains(name) ? .on : .off
            checkbox.widthAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
            row?.addArrangedSubview(checkbox)
            imageSetCheckboxes[name] = checkbox
        }

        return container
    }

    private func availableImageSetNames() -> [String] {
        controller.availableImageSetNames()
    }

    private func selectedImageSetNames() -> [String] {
        let available = availableImageSetNames()
        guard !available.isEmpty else {
            return []
        }

        let availableSet = Set(available)
        let stored = UserDefaults.standard.stringArray(forKey: DefaultsKey.enabledImageSets) ?? available
        let selected = stored.filter { availableSet.contains($0) }
        return selected.isEmpty ? available : selected
    }

    private func setSelectedImageSetNames(_ names: [String]) {
        let available = availableImageSetNames()
        let availableSet = Set(available)
        let selected = names.filter { availableSet.contains($0) }
        UserDefaults.standard.set(selected.isEmpty ? Array(available.prefix(1)) : selected, forKey: DefaultsKey.enabledImageSets)
    }

    @objc private func toggleStickfigures() {
        if controller.isRunning {
            controller.stop()
        } else {
            controller.start(selectedNames: selectedImageSetNames())
        }
    }

    @objc private func restartStickfigures() {
        controller.restart(selectedNames: selectedImageSetNames())
    }

    @objc private func imageSetChanged(_ sender: NSButton) {
        let selected = imageSetCheckboxes
            .filter { $0.value.state == .on }
            .map { $0.key }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        if selected.isEmpty {
            sender.state = .on
            setSelectedImageSetNames([sender.title])
        } else {
            setSelectedImageSetNames(selected)
        }

        controller.hideDisabled(selectedNames: selectedImageSetNames())
        updateStatus()
    }

    @objc private func autoStartChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: DefaultsKey.autoStart)
    }

    @objc private func keepAliveChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: DefaultsKey.keepAlive)
    }

    private func updateStatus() {
        statusValueLabel?.stringValue = controller.isRunning ? "Status: on" : "Status: off"
        resourcePathLabel?.stringValue = "Assets: \(resourcesURL.path)"
        startStopButton?.title = controller.isRunning ? "Turn Off" : "Turn On"
        autoStartCheckbox?.state = UserDefaults.standard.bool(forKey: DefaultsKey.autoStart) ? .on : .off
        keepAliveCheckbox?.state = UserDefaults.standard.bool(forKey: DefaultsKey.keepAlive) ? .on : .off
        let selectedNames = Set(selectedImageSetNames())
        for (name, checkbox) in imageSetCheckboxes {
            checkbox.state = selectedNames.contains(name) ? .on : .off
        }
        statusItem?.button?.title = controller.isRunning ? "ABS On" : "ABS"
        updateStatusMenu()
    }

    @objc private func openLog() {
        ensureLogHasVisibleContent()
        NSWorkspace.shared.open(logURL)
    }

    @objc private func showAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    @objc private func quitApplication() {
        controller.stop()
        NSApp.terminate(nil)
    }

    private func ensureLogHasVisibleContent() {
        let size = (try? logURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if size == 0 {
            appendLogLine("Log opened. Native Swift events appear here.")
        }
    }

    private func appendLogLine(_ message: String) {
        let directory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: logURL) else {
            return
        }

        do {
            try handle.seekToEnd()
        } catch {
            return
        }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        if let data = "[\(timestamp)] \(message)\n".data(using: .utf8) {
            handle.write(data)
            try? handle.synchronize()
        }
        try? handle.close()
    }
}

private var retainedDelegate: AppDelegate?

@main
private struct NativeApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        retainedDelegate = delegate
        app.delegate = delegate
        app.run()
    }
}

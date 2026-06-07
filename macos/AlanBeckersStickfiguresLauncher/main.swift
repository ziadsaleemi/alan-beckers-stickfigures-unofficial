import Cocoa
import CoreGraphics
import Foundation

private enum DefaultsKey {
    static let autoStart = "autoStartStickfigures"
    static let keepAlive = "restartStickfiguresIfTheyExit"
    static let enabledImageSets = "enabledStickfigureImageSets"
    static let aiEnabled = "localAIEnabled"
    static let ollamaBaseURL = "ollamaBaseURL"
    static let ollamaModel = "ollamaModel"
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
    case storyApproach
    case climbWall
    case climbCeiling
    case grabWall
    case grabCeiling
    case trip
    case dance
    case lookAtMouse
    case sitLookUp
    case sitLegsUp
    case sitLegsDown
    case dangleLegs
    case sprawl
    case chaseMouse
    case cursorHate
    case cursorSpite
    case lassoSpin
    case stabbing
    case followPartner
    case copyPartner
    case guardPartner
    case ambush
    case hugPartner
    case tugOfWar
    case highFive
    case argument
    case comfortPartner
    case teamPose
    case tradePlaces
    case buildTogether
    case victimTrap
    case patrolPair
    case playChase
    case spar
    case tease
    case celebrate
    case observePartner

    static let aiBehaviorChoices: [MascotAction] = [
        .stand,
        .sit,
        .walk,
        .run,
        .dash,
        .trip,
        .dance,
        .lookAtMouse,
        .sitLookUp,
        .sitLegsUp,
        .sitLegsDown,
        .dangleLegs,
        .sprawl,
        .chaseMouse,
        .climbWall,
        .cursorHate,
        .cursorSpite,
        .lassoSpin,
        .stabbing,
        .followPartner,
        .copyPartner,
        .guardPartner,
        .ambush,
        .hugPartner,
        .tugOfWar,
        .highFive,
        .argument,
        .comfortPartner,
        .teamPose,
        .tradePlaces,
        .buildTogether,
        .victimTrap,
        .patrolPair,
        .playChase,
        .spar,
        .tease,
        .celebrate,
        .observePartner
    ]

    var repeatsAnimation: Bool {
        switch self {
        case .land, .trip:
            return false
        case .stand, .sit, .walk, .run, .dash, .fall, .dragged, .thrown, .holdPointer,
             .storyApproach, .climbWall, .climbCeiling, .grabWall, .grabCeiling,
             .dance, .lookAtMouse, .sitLookUp, .sitLegsUp, .sitLegsDown,
             .dangleLegs, .sprawl, .chaseMouse, .cursorHate, .cursorSpite,
             .lassoSpin, .stabbing, .followPartner, .copyPartner, .guardPartner,
             .ambush, .hugPartner, .tugOfWar, .highFive, .argument,
             .comfortPartner, .teamPose, .tradePlaces, .buildTogether,
             .victimTrap, .patrolPair, .playChase, .spar, .tease, .celebrate,
             .observePartner:
            return true
        }
    }

    var isAIFloorPose: Bool {
        switch self {
        case .dance, .lookAtMouse, .sitLookUp, .sitLegsUp, .sitLegsDown, .dangleLegs,
             .sprawl, .cursorHate, .cursorSpite, .lassoSpin, .stabbing:
            return true
        default:
            return false
        }
    }

    var isStoryInteraction: Bool {
        switch self {
        case .storyApproach, .followPartner, .copyPartner, .guardPartner, .ambush,
             .hugPartner, .tugOfWar, .highFive, .argument, .comfortPartner,
             .teamPose, .tradePlaces, .buildTogether, .victimTrap, .patrolPair,
             .playChase, .spar, .tease, .celebrate, .observePartner:
            return true
        default:
            return false
        }
    }

    var needsContactStaging: Bool {
        switch self {
        case .copyPartner, .guardPartner, .ambush, .hugPartner, .tugOfWar,
             .highFive, .argument, .comfortPartner, .teamPose, .buildTogether,
             .victimTrap, .tease, .celebrate, .observePartner:
            return true
        default:
            return false
        }
    }

    var contactDistance: CGFloat {
        switch self {
        case .hugPartner:
            return 22
        case .tugOfWar, .highFive, .comfortPartner:
            return 34
        case .argument, .tease, .victimTrap, .ambush:
            return 58
        case .buildTogether, .teamPose, .copyPartner, .celebrate:
            return 76
        case .guardPartner, .observePartner:
            return 96
        default:
            return 84
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

private enum StoryBeat: String, CaseIterable {
    case colorGangWarmup
    case playfulChase
    case rivalSpar
    case victimScheme
    case trainingDrill
    case rescueMoment
    case desktopPatrol
    case watchAndReact
    case celebration
    case quietReset

    var title: String {
        switch self {
        case .colorGangWarmup:
            return "color gang warmup"
        case .playfulChase:
            return "playful chase"
        case .rivalSpar:
            return "TCO and TDL rivalry"
        case .victimScheme:
            return "victim scheme"
        case .trainingDrill:
            return "training drill"
        case .rescueMoment:
            return "rescue moment"
        case .desktopPatrol:
            return "desktop patrol"
        case .watchAndReact:
            return "watch and react"
        case .celebration:
            return "shared celebration"
        case .quietReset:
            return "quiet reset"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .rivalSpar, .victimScheme:
            return TimeInterval.random(in: 7...11)
        case .colorGangWarmup, .playfulChase, .celebration, .trainingDrill,
             .rescueMoment, .desktopPatrol:
            return TimeInterval.random(in: 9...15)
        case .watchAndReact, .quietReset:
            return TimeInterval.random(in: 6...10)
        }
    }
}

private enum LocalAIError: LocalizedError {
    case invalidURL
    case missingModel
    case invalidResponse
    case serverError(Int)
    case invalidDecision

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Check the Ollama URL."
        case .missingModel:
            return "Choose a local Ollama model."
        case .invalidResponse:
            return "Ollama returned an unexpected response."
        case .serverError(let statusCode):
            return "Ollama returned HTTP \(statusCode)."
        case .invalidDecision:
            return "The model did not choose a supported action."
        }
    }
}

private struct OllamaModelInfo: Decodable {
    struct Details: Decodable {
        let parameterSize: String?
        let quantizationLevel: String?

        private enum CodingKeys: String, CodingKey {
            case parameterSize = "parameter_size"
            case quantizationLevel = "quantization_level"
        }
    }

    let name: String?
    let model: String?
    let size: Int64?
    let details: Details?
    let capabilities: [String]?

    var modelName: String? {
        let candidate = model ?? name
        guard let candidate, !candidate.isEmpty else {
            return nil
        }
        return candidate
    }

    var supportsChatCompletion: Bool {
        guard let capabilities else {
            return true
        }
        return capabilities.contains("completion") || capabilities.contains("tools")
    }
}

private struct OllamaTagsResponse: Decodable {
    let models: [OllamaModelInfo]
}

private struct OllamaChatMessage: Decodable {
    let content: String
}

private struct OllamaChatResponse: Decodable {
    let message: OllamaChatMessage?
}

private struct LocalAIActionDecision: Decodable {
    let action: String
}

private final class LocalAIPlanner {
    static let defaultBaseURL = "http://127.0.0.1:11434"

    private let session: URLSession
    private let decoder = JSONDecoder()

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 10
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func normalizedBaseURLString(from rawValue: String) -> String {
        normalizedBaseURL(from: rawValue)?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            ?? Self.defaultBaseURL
    }

    func fetchModels(baseURLString: String, completion: @escaping (Result<[String], Error>) -> Void) {
        guard let url = endpoint("/api/tags", baseURLString: baseURLString) else {
            DispatchQueue.main.async {
                completion(.failure(LocalAIError.invalidURL))
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        session.dataTask(with: request) { [decoder] data, response, error in
            let result: Result<[String], Error>
            defer {
                DispatchQueue.main.async {
                    completion(result)
                }
            }

            if let error {
                result = .failure(error)
                return
            }

            guard let http = response as? HTTPURLResponse else {
                result = .failure(LocalAIError.invalidResponse)
                return
            }

            guard (200..<300).contains(http.statusCode) else {
                result = .failure(LocalAIError.serverError(http.statusCode))
                return
            }

            guard let data else {
                result = .failure(LocalAIError.invalidResponse)
                return
            }

            do {
                let tags = try decoder.decode(OllamaTagsResponse.self, from: data)
                let names = tags.models.filter(\.supportsChatCompletion).compactMap(\.modelName)
                    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                result = .success(names)
            } catch {
                result = .failure(error)
            }
        }.resume()
    }

    func requestAction(
        baseURLString: String,
        model: String,
        characterName: String,
        currentAction: MascotAction,
        availableActions: [MascotAction],
        environmentSummary: String,
        nearbyCharacters: String,
        completion: @escaping (MascotAction?) -> Void
    ) {
        let selectedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedModel.isEmpty else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        guard let url = endpoint("/api/chat", baseURLString: baseURLString),
              let body = chatRequestBody(
                model: selectedModel,
                characterName: characterName,
                currentAction: currentAction,
                availableActions: availableActions,
                environmentSummary: environmentSummary,
                nearbyCharacters: nearbyCharacters
              ) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        session.dataTask(with: request) { [decoder] data, response, error in
            let action: MascotAction?
            defer {
                DispatchQueue.main.async {
                    completion(action)
                }
            }

            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let data,
                  let chat = try? decoder.decode(OllamaChatResponse.self, from: data),
                  let content = chat.message?.content.trimmingCharacters(in: .whitespacesAndNewlines),
                  let decisionData = Self.jsonData(from: content),
                  let decision = try? decoder.decode(LocalAIActionDecision.self, from: decisionData),
                  let suggested = MascotAction(rawValue: decision.action),
                  availableActions.contains(suggested) else {
                action = nil
                return
            }

            action = suggested
        }.resume()
    }

    private func chatRequestBody(
        model: String,
        characterName: String,
        currentAction: MascotAction,
        availableActions: [MascotAction],
        environmentSummary: String,
        nearbyCharacters: String
    ) -> Data? {
        let allowed = availableActions.map(\.rawValue)
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "action": [
                    "type": "string",
                    "enum": allowed
                ]
            ],
            "required": ["action"]
        ]
        let profile = characterProfile(for: characterName)
        let userPrompt = [
            "character": characterName,
            "characterProfile": profile,
            "currentAction": currentAction.rawValue,
            "allowedActions": allowed.joined(separator: ", "),
            "actionHints": actionHints(for: availableActions),
            "environment": environmentSummary,
            "nearbyCharacters": nearbyCharacters,
            "instruction": "Choose one safe next desktop companion action. Prefer character personality, low-key continuity, and actions that fit the current desktop situation. Use high-energy pair actions only when they clearly fit nearby characters. Respond with exactly one allowed action."
        ].map { "\($0.key): \($0.value)" }.joined(separator: "\n")

        let payload: [String: Any] = [
            "model": model,
            "stream": false,
            "keep_alive": "5m",
            "format": schema,
            "messages": [
                [
                    "role": "system",
                    "content": "You select animation actions for a local desktop stickfigure. Return JSON only. Pick only from allowedActions. Do not ask for screenshots, window titles, files, private data, or actions outside the list."
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ],
            "options": [
                "temperature": 0.7,
                "num_predict": 40
            ]
        ]

        return try? JSONSerialization.data(withJSONObject: payload)
    }

    private func actionHints(for actions: [MascotAction]) -> String {
        actions.map { action in
            switch action {
            case .followPartner:
                return "followPartner=one character leads while another tags along"
            case .copyPartner:
                return "copyPartner=copycat or synchronized pose with a nearby character"
            case .guardPartner:
                return "guardPartner=watch over or block beside a nearby character"
            case .ambush:
                return "ambush=quick prank or surprise attack beat with nearby character"
            case .hugPartner:
                return "hugPartner=close-contact hug using paired interaction sprites"
            case .tugOfWar:
                return "tugOfWar=two characters pull against each other"
            case .highFive:
                return "highFive=close celebratory contact with another character"
            case .argument:
                return "argument=face-to-face disagreement or challenge"
            case .comfortPartner:
                return "comfortPartner=help or console a nearby character"
            case .teamPose:
                return "teamPose=stand together as a group pose"
            case .tradePlaces:
                return "tradePlaces=two characters cross paths and swap sides"
            case .buildTogether:
                return "buildTogether=two characters inspect or work on the same thing"
            case .victimTrap:
                return "victimTrap=victim-style trap or lasso beat with a nearby character"
            case .patrolPair:
                return "patrolPair=two characters walk together and watch the desktop"
            case .playChase:
                return "playChase=playful two-character chase"
            case .spar:
                return "spar=short pretend fight or rivalry beat with nearby character"
            case .tease:
                return "tease=taunt, prank, or dramatic reaction toward nearby character"
            case .celebrate:
                return "celebrate=playful shared dance or happy reaction"
            case .observePartner:
                return "observePartner=watch a nearby character quietly"
            case .chaseMouse:
                return "chaseMouse=run toward the pointer"
            case .cursorHate, .cursorSpite, .lassoSpin, .stabbing:
                return "\(action.rawValue)=victim-style suspicious or hostile bit"
            default:
                return "\(action.rawValue)=solo action"
            }
        }.joined(separator: "; ")
    }

    private static func jsonData(from content: String) -> Data? {
        if let data = content.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}"),
              start <= end else {
            return nil
        }

        let json = String(content[start...end])
        return json.data(using: .utf8)
    }

    private func characterProfile(for characterName: String) -> String {
        switch characterName.lowercased() {
        case "orange":
            return "curious all-rounder and leader; explores, trips, dances, and checks the desktop"
        case "blue":
            return "calm playful helper; tends to sit, wander, dance, and inspect nearby motion"
        case "green":
            return "performer and showoff; prefers dance, dash, and expressive poses"
        case "yellow":
            return "technical builder; prefers looking, sitting, inspecting, and deliberate movement"
        case "red":
            return "impulsive and energetic; prefers chase, run, dash, trip, and playful movement"
        case "purple":
            return "restless and dramatic; prefers climbing, dashing, and quiet poses"
        case "tco":
            return "powerful intense fighter; prefers dash, climb, stand, and sudden movement"
        case "tdl":
            return "aggressive dramatic rival; prefers dash, climb, sprawl, and intense movement"
        case "victim":
            return "watchful desktop antagonist; prefers cursor-aware, lasso, work, and suspicious idle actions"
        default:
            return "desktop companion; prefer varied safe movement and idle poses"
        }
    }

    private func endpoint(_ endpointPath: String, baseURLString: String) -> URL? {
        guard let baseURL = normalizedBaseURL(from: baseURLString),
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let rootPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = rootPath.isEmpty ? endpointPath : "/\(rootPath)\(endpointPath)"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private func normalizedBaseURL(from rawValue: String) -> URL? {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            value = Self.defaultBaseURL
        }
        if !value.contains("://") {
            value = "http://\(value)"
        }

        guard var components = URLComponents(string: value),
              components.scheme != nil,
              components.host != nil else {
            return nil
        }

        if let apiRange = components.path.range(of: "/api") {
            components.path = String(components.path[..<apiRange.lowerBound])
        }
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !components.path.isEmpty {
            components.path = "/\(components.path)"
        }
        components.query = nil
        components.fragment = nil
        return components.url
    }
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

    func hasClip(named name: String) -> Bool {
        clips[name] != nil
    }

    func supportsAIAction(_ action: MascotAction) -> Bool {
        switch action {
        case .storyApproach:
            return false
        case .stand:
            return hasClip(named: "Stand")
        case .sit:
            return hasClip(named: "SitAndLookAtMouse") || hasClip(named: "Sit")
        case .walk:
            return hasClip(named: "Walk")
        case .run:
            return hasClip(named: "Run") || hasClip(named: "Dash") || hasClip(named: "Walk")
        case .dash, .climbWall:
            return hasClip(named: "Dash") && hasClip(named: "GrabWall")
        case .trip:
            return hasClip(named: "Tripping") || hasClip(named: "StandFromFloor")
        case .dance:
            return hasClip(named: "Dance")
        case .lookAtMouse:
            return hasClip(named: "SitAndLookAtMouse") || hasClip(named: "SitAndFaceMouse") || hasClip(named: "Sit")
        case .sitLookUp:
            return hasClip(named: "SitAndLookUp")
        case .sitLegsUp:
            return hasClip(named: "SitWithLegsUp")
        case .sitLegsDown:
            return hasClip(named: "SitWithLegsDown")
        case .dangleLegs:
            return hasClip(named: "SitAndDangleLegs")
        case .sprawl:
            return hasClip(named: "Sprawl")
        case .chaseMouse:
            return hasClip(named: "Run") || hasClip(named: "Walk")
        case .cursorHate:
            return hasClip(named: "CursorHate")
        case .cursorSpite:
            return hasClip(named: "CursorSpite")
        case .lassoSpin:
            return hasClip(named: "LassoSpin")
        case .stabbing:
            return hasClip(named: "Stabbing")
        case .followPartner:
            return hasClip(named: "RoleFollow") || hasClip(named: "Run") || hasClip(named: "Walk")
        case .copyPartner:
            return hasClip(named: "RoleCopy")
                || hasClip(named: "Dance")
                || hasClip(named: "SitAndLookAtMouse")
                || hasClip(named: "SitAndLookUp")
                || hasClip(named: "Stand")
        case .guardPartner:
            return hasClip(named: "RoleGuard")
                || hasClip(named: "Stand")
                || hasClip(named: "SitAndLookAtMouse")
                || hasClip(named: "Run")
                || hasClip(named: "Walk")
        case .ambush:
            return hasClip(named: "RoleAmbush")
                || hasClip(named: "Dash")
                || hasClip(named: "Run")
                || hasClip(named: "Stabbing")
                || hasClip(named: "CursorHate")
        case .hugPartner:
            return hasClip(named: "RoleHugGive")
                || hasClip(named: "RoleHugReceive")
                || hasClip(named: "HuggingSolidAction")
                || hasClip(named: "HuggedSolidAction")
                || hasClip(named: "Stand")
        case .tugOfWar:
            return hasClip(named: "RoleTugPull")
                || hasClip(named: "RoleTugPulled")
                || hasClip(named: "HuggingSolidAction")
                || hasClip(named: "HuggedSolidAction")
                || hasClip(named: "Run")
                || hasClip(named: "Sprawl")
        case .highFive:
            return hasClip(named: "RoleHighFive") || hasClip(named: "Dance") || hasClip(named: "Stand")
        case .argument:
            return hasClip(named: "RoleArgument")
                || hasClip(named: "CursorSpite")
                || hasClip(named: "CursorHate")
                || hasClip(named: "Stabbing")
                || hasClip(named: "Stand")
        case .comfortPartner:
            return hasClip(named: "RoleRescueGive")
                || hasClip(named: "RoleRescueReceive")
                || hasClip(named: "RoleComfortGive")
                || hasClip(named: "RoleComfortReceive")
                || hasClip(named: "HuggingSolidAction")
                || hasClip(named: "SitAndLookAtMouse")
                || hasClip(named: "Sprawl")
                || hasClip(named: "Stand")
        case .teamPose:
            return hasClip(named: "RoleTeamPose") || hasClip(named: "Stand") || hasClip(named: "Dance")
        case .tradePlaces:
            return hasClip(named: "RoleTradePlace") || hasClip(named: "Run") || hasClip(named: "Walk")
        case .buildTogether:
            return hasClip(named: "RoleBuildTogether")
                || hasClip(named: "SitAndLookAtMouse")
                || hasClip(named: "SitAndLookUp")
                || hasClip(named: "CursorHate")
                || hasClip(named: "Stand")
        case .victimTrap:
            return name.lowercased() == "victim"
                && (hasClip(named: "RoleVictimTrap")
                    || hasClip(named: "LassoSpin")
                    || hasClip(named: "Stabbing")
                    || hasClip(named: "CursorHate"))
        case .patrolPair:
            return hasClip(named: "RolePatrol") || hasClip(named: "Walk") || hasClip(named: "Run")
        case .playChase:
            return hasClip(named: "RolePlayChaseLead")
                || hasClip(named: "RolePlayChaseFollow")
                || hasClip(named: "Run")
                || hasClip(named: "Walk")
        case .spar:
            return hasClip(named: "RoleSparAttack")
                || hasClip(named: "RoleSparBlock")
                || hasClip(named: "Dash")
                || hasClip(named: "Run")
                || hasClip(named: "Tripping")
        case .tease:
            return hasClip(named: "RoleTease")
                || hasClip(named: "RoleTeaseReaction")
                || hasClip(named: "CursorSpite")
                || hasClip(named: "CursorHate")
                || hasClip(named: "Stabbing")
                || hasClip(named: "Dance")
                || hasClip(named: "Sprawl")
                || hasClip(named: "Stand")
        case .celebrate:
            return hasClip(named: "RoleCelebrate") || hasClip(named: "Dance") || hasClip(named: "SitAndLookUp") || hasClip(named: "Stand")
        case .observePartner:
            return hasClip(named: "RoleObserve") || hasClip(named: "SitAndLookAtMouse") || hasClip(named: "SitAndLookUp") || hasClip(named: "Stand")
        case .fall, .dragged, .thrown, .land, .holdPointer, .climbCeiling, .grabWall, .grabCeiling:
            return false
        }
    }

    func supportedAIActions() -> [MascotAction] {
        MascotAction.aiBehaviorChoices.filter { supportsAIAction($0) }
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
    weak var storyPartner: Mascot?
    var storyRole = 0
    var storyEndTick = 0
    var queuedStoryAction: MascotAction?
    var storyContactDistance: CGFloat = 84
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
        if !newAction.isStoryInteraction {
            clearStoryInteraction()
        }
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
        case .storyApproach:
            velocity = .zero
        case .dance, .lookAtMouse, .sitLookUp, .sitLegsUp, .sitLegsDown, .dangleLegs,
             .sprawl, .cursorHate, .cursorSpite, .lassoSpin, .stabbing, .copyPartner,
             .guardPartner, .hugPartner, .tugOfWar, .highFive, .argument,
             .comfortPartner, .teamPose, .buildTogether, .victimTrap, .tease,
             .celebrate, .observePartner:
            velocity = .zero
            nextDecisionTick = Int.random(in: 75...210)
        case .walk, .run, .dash, .dragged, .holdPointer, .climbWall, .climbCeiling,
             .chaseMouse, .followPartner, .ambush, .tradePlaces, .patrolPair,
             .playChase, .spar:
            velocity = .zero
        }
    }

    func beginStoryInteraction(
        _ interaction: MascotAction,
        with partner: Mascot,
        role: Int,
        duration: Int,
        targetX: CGFloat? = nil,
        forceApproach: Bool = false
    ) {
        let shouldApproach = (forceApproach || interaction.needsContactStaging)
            && abs(partner.anchor.x - anchor.x) > interaction.contactDistance + 6
        queuedStoryAction = shouldApproach ? interaction : nil
        storyContactDistance = interaction.contactDistance
        choose(shouldApproach ? .storyApproach : interaction, targetX: targetX)
        storyPartner = partner
        storyRole = role
        storyEndTick = duration
    }

    var isInStoryInteraction: Bool {
        storyPartner != nil
    }

    private func clearStoryInteraction() {
        storyPartner = nil
        storyRole = 0
        storyEndTick = 0
        queuedStoryAction = nil
        storyContactDistance = 84
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
        case .storyApproach:
            stepStoryApproach(in: world)
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
        case .chaseMouse:
            stepChaseMouse(in: world)
        case .followPartner:
            stepFollowPartner(in: world)
        case .ambush:
            stepAmbush(in: world)
        case .tradePlaces:
            stepTradePlaces(in: world)
        case .patrolPair:
            stepPatrolPair(in: world)
        case .playChase:
            stepPlayChase(in: world)
        case .spar:
            stepSpar(in: world)
        case .copyPartner:
            stepCopyPartner(in: world)
        case .guardPartner:
            stepGuardPartner(in: world)
        case .hugPartner, .tugOfWar, .highFive, .argument, .comfortPartner,
             .teamPose, .buildTogether, .victimTrap:
            stepCloseStoryPose(in: world)
        case .trip:
            stepTrip(in: world)
            if actionTick > currentClipDuration(defaultDuration: 90) {
                choose(.stand)
            }
        case .dance, .lookAtMouse, .sitLookUp, .sitLegsUp, .sitLegsDown, .dangleLegs,
             .sprawl, .cursorHate, .cursorSpite, .lassoSpin, .stabbing, .tease,
             .celebrate, .observePartner:
            _ = settleOnGround(in: world)
            faceStoryPartnerIfNeeded()
            if actionTick > nextDecisionTick {
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
        if let suggestedAction = controller?.consumeAISuggestion(for: self) {
            chooseBehavior(suggestedAction, in: world)
            return
        }

        chooseBehavior(fallbackBehaviorAction(), in: world)
    }

    private func chooseBehavior(_ suggestedAction: MascotAction, in world: DesktopWorld) {
        switch suggestedAction {
        case .walk:
            choose(.walk, targetX: randomTargetX(in: world))
        case .run:
            choose(.run, targetX: randomTargetX(in: world))
        case .dash, .climbWall:
            runTowardWall(in: world)
        case .sit:
            choose(.sit)
        case .trip:
            choose(.trip)
        case .dance:
            choose(.dance)
        case .lookAtMouse:
            lookRight = NSEvent.mouseLocation.x > anchor.x
            choose(.lookAtMouse)
        case .sitLookUp, .sitLegsUp, .sitLegsDown, .dangleLegs, .sprawl,
             .cursorHate, .cursorSpite, .lassoSpin, .stabbing:
            choose(suggestedAction)
        case .chaseMouse:
            choose(.chaseMouse)
        case .followPartner, .copyPartner, .guardPartner, .ambush, .hugPartner,
             .tugOfWar, .highFive, .argument, .comfortPartner, .teamPose,
             .tradePlaces, .buildTogether, .victimTrap, .patrolPair,
             .playChase, .spar, .tease, .celebrate, .observePartner:
            if controller?.beginStoryInteraction(suggestedAction, initiatedBy: self, in: world) == true {
                return
            }
            chooseBehavior(fallbackSoloAction(for: suggestedAction), in: world)
        case .stand:
            choose(.stand)
        default:
            choose(.stand)
        }
    }

    private func fallbackSoloAction(for interaction: MascotAction) -> MascotAction {
        switch interaction {
        case .hugPartner:
            return imageSet.supportsAIAction(.comfortPartner) ? .comfortPartner : .stand
        case .tugOfWar:
            return imageSet.supportsAIAction(.run) ? .run : .sprawl
        case .highFive, .teamPose:
            return imageSet.supportsAIAction(.dance) ? .dance : .stand
        case .argument:
            if imageSet.supportsAIAction(.cursorSpite) {
                return .cursorSpite
            }
            return imageSet.supportsAIAction(.lookAtMouse) ? .lookAtMouse : .stand
        case .comfortPartner:
            return imageSet.supportsAIAction(.lookAtMouse) ? .lookAtMouse : .stand
        case .tradePlaces, .patrolPair:
            return imageSet.supportsAIAction(.run) ? .run : .walk
        case .buildTogether:
            return imageSet.supportsAIAction(.lookAtMouse) ? .lookAtMouse : .sit
        case .victimTrap:
            if imageSet.supportsAIAction(.lassoSpin) {
                return .lassoSpin
            }
            return imageSet.supportsAIAction(.stabbing) ? .stabbing : .dash
        case .followPartner:
            return imageSet.supportsAIAction(.chaseMouse) ? .chaseMouse : .walk
        case .copyPartner:
            return imageSet.supportsAIAction(.dance) ? .dance : .lookAtMouse
        case .guardPartner:
            return imageSet.supportsAIAction(.lookAtMouse) ? .lookAtMouse : .stand
        case .ambush:
            return imageSet.supportsAIAction(.dash) ? .dash : .run
        case .playChase:
            return imageSet.supportsAIAction(.chaseMouse) ? .chaseMouse : .run
        case .spar:
            return imageSet.supportsAIAction(.dash) ? .dash : .run
        case .tease:
            if imageSet.supportsAIAction(.cursorSpite) {
                return .cursorSpite
            }
            return imageSet.supportsAIAction(.sprawl) ? .sprawl : .lookAtMouse
        case .celebrate:
            return imageSet.supportsAIAction(.dance) ? .dance : .sitLookUp
        case .observePartner:
            return imageSet.supportsAIAction(.lookAtMouse) ? .lookAtMouse : .stand
        default:
            return .stand
        }
    }

    private func fallbackBehaviorAction() -> MascotAction {
        let supported = Set(supportedAIActions())
        let weighted: [MascotAction] = [
            .walk, .walk, .walk, .walk,
            .run, .run,
            .sit, .sit,
            .stand, .stand,
            .lookAtMouse, .sitLookUp,
            .sitLegsUp, .sitLegsDown, .dangleLegs,
            .sprawl,
            .trip,
            .dance,
            .chaseMouse,
            .climbWall,
            .cursorHate, .cursorSpite, .lassoSpin, .stabbing
        ].filter { supported.contains($0) }

        return weighted.randomElement() ?? .stand
    }

    func supportedAIActions() -> [MascotAction] {
        let actions = imageSet.supportedAIActions()
        return actions.isEmpty ? [.stand] : actions
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

    private func stepChaseMouse(in world: DesktopWorld) {
        let mouse = NSEvent.mouseLocation
        lookRight = mouse.x > anchor.x
        let distance = mouse.x - anchor.x
        let step = min(abs(distance), Motion.runSpeed) * (distance >= 0 ? 1 : -1)
        anchor.x += step
        guard settleOnGround(in: world) else {
            return
        }

        if abs(distance) < 36 || actionTick > 135 {
            choose(imageSet.supportsAIAction(.lookAtMouse) ? .lookAtMouse : .stand)
        }
    }

    private func stepStoryApproach(in world: DesktopWorld) {
        guard let partner = storyPartner, let queuedStoryAction else {
            choose(.stand)
            return
        }

        let delta = partner.anchor.x - anchor.x
        let distance = abs(delta)
        let directionToPartner: CGFloat = delta >= 0 ? 1 : -1
        lookRight = directionToPartner > 0

        if distance > storyContactDistance {
            let speed = min(Motion.runSpeed + 0.8, max(Motion.walkSpeed, (distance - storyContactDistance) / 11))
            anchor.x += speed * directionToPartner
            guard settleOnGround(in: world) else {
                return
            }
        }

        if distance <= storyContactDistance + 2 || actionTick > 210 {
            self.queuedStoryAction = nil
            choose(queuedStoryAction, targetX: targetX)
            storyPartner = partner
            storyContactDistance = queuedStoryAction.contactDistance
            if storyEndTick < 70 {
                storyEndTick = Int.random(in: 90...150)
            }
        }
    }

    private func stepFollowPartner(in world: DesktopWorld) {
        guard let partner = storyPartner else {
            choose(.stand)
            return
        }

        if storyRole == 1 {
            if targetX == nil {
                let directionAway: CGFloat = anchor.x >= partner.anchor.x ? 1 : -1
                targetX = anchor.x + directionAway * CGFloat.random(in: 180...380)
            }

            guard let targetX else {
                choose(.stand)
                return
            }

            lookRight = targetX > anchor.x
            let direction: CGFloat = lookRight ? 1 : -1
            anchor.x += Motion.walkSpeed * direction
            _ = settleOnGround(in: world)
            let reached = lookRight ? anchor.x >= targetX : anchor.x <= targetX
            if reached || actionTick > max(storyEndTick, 110) {
                choose(imageSet.supportsAIAction(.celebrate) ? .celebrate : .stand)
            }
            return
        }

        let delta = partner.anchor.x - anchor.x
        let directionToPartner: CGFloat = delta >= 0 ? 1 : -1
        let distance = abs(delta)
        lookRight = directionToPartner > 0

        let preferredGap: CGFloat = 92
        if distance > preferredGap {
            let speed = min(Motion.runSpeed, max(Motion.walkSpeed, (distance - preferredGap) / 12))
            anchor.x += speed * directionToPartner
        } else if distance < preferredGap * 0.55 {
            anchor.x -= Motion.walkSpeed * 0.75 * directionToPartner
        }

        guard settleOnGround(in: world) else {
            return
        }

        if actionTick > max(storyEndTick, 110) {
            choose(imageSet.supportsAIAction(.observePartner) ? .observePartner : .stand)
        }
    }

    private func stepAmbush(in world: DesktopWorld) {
        guard let partner = storyPartner else {
            choose(.stand)
            return
        }

        let delta = partner.anchor.x - anchor.x
        let directionToPartner: CGFloat = delta >= 0 ? 1 : -1
        let distance = abs(delta)
        lookRight = directionToPartner > 0

        if storyRole == 1 {
            if distance < 140 && actionTick < max(storyEndTick, 55) {
                anchor.x -= (Motion.walkSpeed + 0.7) * directionToPartner
                _ = settleOnGround(in: world)
                return
            }

            if actionTick > max(storyEndTick, 65) {
                choose(fallbackReactionAction())
            }
            return
        }

        if distance > 58 && actionTick < max(storyEndTick, 50) {
            anchor.x += Motion.dashSpeed * directionToPartner
            _ = settleOnGround(in: world)
            return
        }

        choose(sparFinishAction())
    }

    private func stepTradePlaces(in world: DesktopWorld) {
        guard let partner = storyPartner else {
            choose(.stand)
            return
        }

        if targetX == nil {
            targetX = partner.anchor.x
        }

        guard let targetX else {
            choose(.stand)
            return
        }

        lookRight = targetX > anchor.x
        let delta = targetX - anchor.x
        if abs(delta) > 12 && actionTick < max(storyEndTick, 90) {
            anchor.x += min(Motion.runSpeed + 0.6, max(2, abs(delta) / 10)) * (delta >= 0 ? 1 : -1)
            _ = settleOnGround(in: world)
            return
        }

        choose(imageSet.supportsAIAction(.celebrate) ? .celebrate : .stand)
    }

    private func stepPatrolPair(in world: DesktopWorld) {
        guard let partner = storyPartner else {
            choose(.stand)
            return
        }

        if targetX == nil {
            let direction: CGFloat = storyRole == 0 ? (Bool.random() ? 1 : -1) : (partner.lookRight ? 1 : -1)
            targetX = anchor.x + direction * CGFloat.random(in: 220...520)
        }

        guard let targetX else {
            choose(.stand)
            return
        }

        lookRight = targetX > anchor.x
        let delta = targetX - anchor.x
        anchor.x += min(Motion.walkSpeed + 0.6, max(1.6, abs(delta) / 18)) * (delta >= 0 ? 1 : -1)
        guard settleOnGround(in: world) else {
            return
        }

        let reached = abs(delta) < 14
        let partnerDistance = abs(partner.anchor.x - anchor.x)
        if partnerDistance > 180 {
            self.targetX = partner.anchor.x + (anchor.x < partner.anchor.x ? -82 : 82)
        }

        if reached || actionTick > max(storyEndTick, 130) {
            choose(imageSet.supportsAIAction(.guardPartner) ? .guardPartner : .stand)
        }
    }

    private func stepPlayChase(in world: DesktopWorld) {
        guard let partner = storyPartner else {
            choose(.stand)
            return
        }

        let delta = partner.anchor.x - anchor.x
        let directionToPartner: CGFloat = delta >= 0 ? 1 : -1
        let chaser = storyRole == 0
        lookRight = chaser ? directionToPartner > 0 : directionToPartner < 0

        let speed = chaser ? Motion.runSpeed : Motion.walkSpeed + 1.2
        let movementDirection = chaser ? directionToPartner : -directionToPartner
        anchor.x += speed * movementDirection
        guard settleOnGround(in: world) else {
            return
        }

        if actionTick > max(storyEndTick, 80) || abs(delta) < 42 {
            choose(chaser ? (imageSet.supportsAIAction(.celebrate) ? .celebrate : .stand) : fallbackReactionAction())
        }
    }

    private func stepSpar(in world: DesktopWorld) {
        guard let partner = storyPartner else {
            choose(.stand)
            return
        }

        let delta = partner.anchor.x - anchor.x
        lookRight = delta > 0
        let distance = abs(delta)
        if distance > 52 && actionTick < max(storyEndTick, 50) {
            anchor.x += min(Motion.dashSpeed, max(2, distance / 12)) * (delta >= 0 ? 1 : -1)
            _ = settleOnGround(in: world)
            return
        }

        choose(sparFinishAction())
    }

    private func stepCopyPartner(in world: DesktopWorld) {
        guard storyPartner != nil else {
            choose(.stand)
            return
        }

        _ = settleOnGround(in: world)
        faceStoryPartnerIfNeeded()
        if actionTick > max(storyEndTick, 90) {
            choose(imageSet.supportsAIAction(.celebrate) ? .celebrate : .stand)
        }
    }

    private func stepGuardPartner(in world: DesktopWorld) {
        guard let partner = storyPartner else {
            choose(.stand)
            return
        }

        let side: CGFloat = storyRole == 0 ? -1 : 1
        let desiredX = partner.anchor.x + side * 88
        let delta = desiredX - anchor.x
        if abs(delta) > 12 {
            anchor.x += min(Motion.walkSpeed, abs(delta)) * (delta >= 0 ? 1 : -1)
        }

        lookRight = storyRole == 0 ? false : true
        guard settleOnGround(in: world) else {
            return
        }

        if actionTick > max(storyEndTick, 95) {
            choose(imageSet.supportsAIAction(.observePartner) ? .observePartner : .stand)
        }
    }

    private func stepCloseStoryPose(in world: DesktopWorld) {
        guard let partner = storyPartner else {
            choose(.stand)
            return
        }

        _ = settleOnGround(in: world)
        faceStoryPartnerIfNeeded()
        tightenCloseContactSpacingIfNeeded()

        if action == .tugOfWar {
            let directionAway: CGFloat = anchor.x >= partner.anchor.x ? 1 : -1
            anchor.x += sin(CGFloat(actionTick) / 3.0) * 0.7 * directionAway
        }

        if actionTick > max(storyEndTick, currentClipDuration(defaultDuration: 110)) {
            switch action {
            case .hugPartner, .comfortPartner, .highFive, .teamPose, .buildTogether:
                choose(imageSet.supportsAIAction(.celebrate) ? .celebrate : .stand)
            case .tugOfWar, .argument, .victimTrap:
                choose(fallbackReactionAction())
            default:
                choose(.stand)
            }
        }
    }

    private func tightenCloseContactSpacingIfNeeded() {
        guard actionTick <= 2,
              storyRole == 0,
              action.needsContactStaging,
              let partner = storyPartner else {
            return
        }

        let distance = abs(partner.anchor.x - anchor.x)
        guard distance > storyContactDistance + 2 else {
            return
        }

        let side: CGFloat = anchor.x <= partner.anchor.x ? -1 : 1
        anchor.x = partner.anchor.x + side * storyContactDistance
    }

    private func faceStoryPartnerIfNeeded() {
        guard let partner = storyPartner else {
            return
        }

        lookRight = partner.anchor.x > anchor.x
    }

    private func isGuardRepositioning() -> Bool {
        guard let partner = storyPartner, action == .guardPartner else {
            return false
        }

        let side: CGFloat = storyRole == 0 ? -1 : 1
        let desiredX = partner.anchor.x + side * 88
        return abs(desiredX - anchor.x) > 12
    }

    private func fallbackReactionAction() -> MascotAction {
        if imageSet.supportsAIAction(.sprawl) {
            return .sprawl
        }
        if imageSet.supportsAIAction(.trip) {
            return .trip
        }
        return imageSet.supportsAIAction(.lookAtMouse) ? .lookAtMouse : .stand
    }

    private func sparFinishAction() -> MascotAction {
        if imageSet.supportsAIAction(.stabbing), Bool.random() {
            return .stabbing
        }
        if imageSet.supportsAIAction(.lassoSpin), Bool.random() {
            return .lassoSpin
        }
        if imageSet.supportsAIAction(.cursorHate), Bool.random() {
            return .cursorHate
        }
        if imageSet.supportsAIAction(.trip), Bool.random() {
            return .trip
        }
        if imageSet.supportsAIAction(.sprawl) {
            return .sprawl
        }
        return .stand
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
        case .run, .chaseMouse:
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
        case .storyApproach:
            return imageSet.clip(named: "Run", fallback: ["Walk", "Dash", "Stand"])
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
        case .lookAtMouse:
            return imageSet.clip(named: "SitAndLookAtMouse", fallback: ["SitAndFaceMouse", "Sit", "Stand"])
        case .sitLookUp:
            return imageSet.clip(named: "SitAndLookUp", fallback: ["SitAndLookAtMouse", "Sit", "Stand"])
        case .sitLegsUp:
            return imageSet.clip(named: "SitWithLegsUp", fallback: ["Sit", "Stand"])
        case .sitLegsDown:
            return imageSet.clip(named: "SitWithLegsDown", fallback: ["Sit", "Stand"])
        case .dangleLegs:
            return imageSet.clip(named: "SitAndDangleLegs", fallback: ["SitWithLegsDown", "Sit", "Stand"])
        case .sprawl:
            return imageSet.clip(named: "Sprawl", fallback: ["Sit", "Stand"])
        case .chaseMouse:
            return imageSet.clip(named: "Run", fallback: ["Walk", "Dash", "Stand"])
        case .cursorHate:
            return imageSet.clip(named: "CursorHate", fallback: ["SitAndLookAtMouse", "Stand"])
        case .cursorSpite:
            return imageSet.clip(named: "CursorSpite", fallback: ["CursorHate", "Stand"])
        case .lassoSpin:
            return imageSet.clip(named: "LassoSpin", fallback: ["Stand"])
        case .stabbing:
            return imageSet.clip(named: "Stabbing", fallback: ["CursorHate", "Stand"])
        case .followPartner:
            return imageSet.clip(named: "RoleFollow", fallback: ["Run", "Walk", "Dash", "Stand"])
        case .copyPartner:
            return imageSet.clip(named: "RoleCopy", fallback: ["Dance", "SitAndLookAtMouse", "SitAndLookUp", "Stand"])
        case .guardPartner:
            if isGuardRepositioning() {
                return imageSet.clip(named: "Walk", fallback: ["Run", "Stand"])
            }
            return imageSet.clip(named: "RoleGuard", fallback: ["Stand", "SitAndLookAtMouse", "Walk"])
        case .ambush:
            return imageSet.clip(named: "RoleAmbush", fallback: ["Dash", "Run", "Stabbing", "CursorHate", "Stand"])
        case .hugPartner:
            if storyRole == 1 {
                return imageSet.clip(named: "RoleHugReceive", fallback: ["HuggedSolidAction", "HuggingSolidAction", "SitAndLookAtMouse", "Stand"])
            }
            return imageSet.clip(named: "RoleHugGive", fallback: ["HuggingSolidAction", "HuggedSolidAction", "SitAndLookAtMouse", "Stand"])
        case .tugOfWar:
            if storyRole == 1 {
                return imageSet.clip(named: "RoleTugPulled", fallback: ["HuggedSolidAction", "Sprawl", "Run", "Stand"])
            }
            return imageSet.clip(named: "RoleTugPull", fallback: ["HuggingSolidAction", "Run", "Sprawl", "Stand"])
        case .highFive:
            return imageSet.clip(named: "RoleHighFive", fallback: ["Dance", "Stand"])
        case .argument:
            return imageSet.clip(named: "RoleArgument", fallback: ["CursorSpite", "CursorHate", "Stabbing", "Stand"])
        case .comfortPartner:
            if storyRole == 1 {
                return imageSet.clip(named: "RoleRescueReceive", fallback: ["RoleComfortReceive", "Sprawl", "SitAndLookAtMouse", "Sit", "Stand"])
            }
            return imageSet.clip(named: "RoleRescueGive", fallback: ["RoleComfortGive", "HuggingSolidAction", "SitAndLookAtMouse", "SitAndLookUp", "Stand"])
        case .teamPose:
            return imageSet.clip(named: "RoleTeamPose", fallback: ["Stand", "Dance", "SitAndLookAtMouse"])
        case .tradePlaces:
            return imageSet.clip(named: "RoleTradePlace", fallback: ["Run", "Walk", "Dash", "Stand"])
        case .buildTogether:
            return imageSet.clip(named: "RoleBuildTogether", fallback: ["SitAndLookAtMouse", "SitAndLookUp", "CursorHate", "Sit", "Stand"])
        case .victimTrap:
            if imageSet.name.lowercased() == "victim" {
                return imageSet.clip(named: "RoleVictimTrap", fallback: ["LassoSpin", "Stabbing", "CursorHate", "Dash", "Stand"])
            }
            return imageSet.clip(named: "RoleTrapReaction", fallback: ["Sprawl", "Tripping", "SitAndLookAtMouse", "Stand"])
        case .patrolPair:
            return imageSet.clip(named: "RolePatrol", fallback: ["Walk", "Run", "Stand"])
        case .playChase:
            if storyRole == 1 {
                return imageSet.clip(named: "RolePlayChaseFollow", fallback: ["Run", "Walk", "Dash", "Stand"])
            }
            return imageSet.clip(named: "RolePlayChaseLead", fallback: ["Run", "Walk", "Dash", "Stand"])
        case .spar:
            if storyRole == 1 {
                return imageSet.clip(named: "RoleSparBlock", fallback: ["Dash", "Run", "Walk", "Tripping", "Stand"])
            }
            return imageSet.clip(named: "RoleSparAttack", fallback: ["Dash", "Run", "Walk", "Tripping", "Stand"])
        case .tease:
            if storyRole == 1 {
                return imageSet.clip(named: "RoleTeaseReaction", fallback: ["Sprawl", "CursorHate", "SitAndLookAtMouse", "Stand"])
            }
            return imageSet.clip(named: "RoleTease", fallback: ["CursorSpite", "CursorHate", "Stabbing", "Dance", "Sprawl", "Stand"])
        case .celebrate:
            return imageSet.clip(named: "RoleCelebrate", fallback: ["Dance", "SitAndLookUp", "SitAndLookAtMouse", "Stand"])
        case .observePartner:
            return imageSet.clip(named: "RoleObserve", fallback: ["SitAndLookAtMouse", "SitAndLookUp", "Sit", "Stand"])
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
    private let aiPlanner = LocalAIPlanner()
    private var timer: Timer?
    private var nextID = 1
    private(set) var mascots: [Mascot] = []
    private var imageSets: [ImageSet] = []
    private var pendingAIRequests = Set<Int>()
    private var aiSuggestions: [Int: MascotAction] = [:]
    private var lastAISuggestionAt: [Int: Date] = [:]
    private var activeStoryBeat: StoryBeat?
    private var activeStoryCast = Set<Int>()
    private var storyBeatEndDate = Date.distantPast
    private var nextStoryBeatDate = Date.distantPast
    private var storyBeatCursor = 0
    var isRunning: Bool {
        timer != nil
    }
    var onStatusChanged: (() -> Void)?
    var onAIEvent: ((String) -> Void)?

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

        aiSuggestions.removeAll()
        lastAISuggestionAt.removeAll()
        activeStoryBeat = nil
        activeStoryCast.removeAll()
        storyBeatEndDate = Date.distantPast
        nextStoryBeatDate = Date().addingTimeInterval(TimeInterval.random(in: 4...8))
        storyBeatCursor = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
        onStatusChanged?()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pendingAIRequests.removeAll()
        aiSuggestions.removeAll()
        lastAISuggestionAt.removeAll()
        activeStoryBeat = nil
        activeStoryCast.removeAll()
        storyBeatEndDate = Date.distantPast
        nextStoryBeatDate = Date.distantPast
        storyBeatCursor = 0
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
        pendingAIRequests.remove(mascot.id)
        aiSuggestions.removeValue(forKey: mascot.id)
        lastAISuggestionAt.removeValue(forKey: mascot.id)
        activeStoryCast.remove(mascot.id)
        mascots.removeAll { $0 === mascot }
    }

    func consumeAISuggestion(for mascot: Mascot) -> MascotAction? {
        guard localAIEnabled, activeStoryBeat == nil else {
            return nil
        }

        if let suggestion = aiSuggestions.removeValue(forKey: mascot.id) {
            requestAISuggestion(for: mascot)
            return suggestion
        }

        requestAISuggestion(for: mascot)
        return nil
    }

    func beginStoryInteraction(_ interaction: MascotAction, initiatedBy mascot: Mascot, in world: DesktopWorld) -> Bool {
        guard interaction.isStoryInteraction,
              !mascot.isInStoryInteraction,
              let partner = bestStoryPartner(for: mascot, interaction: interaction),
              !partner.isInStoryInteraction else {
            return false
        }

        return startStoryInteraction(interaction, first: mascot, second: partner, source: "AI")
    }

    private func tick() {
        world.refreshIfNeeded()
        updateStoryDirector()
        mascots.forEach { $0.step(in: world) }
    }

    private var localAIEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.aiEnabled)
            && !(UserDefaults.standard.string(forKey: DefaultsKey.ollamaModel) ?? "").isEmpty
    }

    private func requestAISuggestion(for mascot: Mascot) {
        guard localAIEnabled,
              activeStoryBeat == nil,
              !mascot.isInStoryInteraction else {
            return
        }

        let now = Date()
        if let last = lastAISuggestionAt[mascot.id], now.timeIntervalSince(last) < 60 {
            return
        }

        guard pendingAIRequests.insert(mascot.id).inserted else {
            return
        }

        lastAISuggestionAt[mascot.id] = now
        let id = mascot.id
        let characterName = mascot.imageSet.name
        let currentAction = mascot.action
        let availableActions = mascot.supportedAIActions().filter { $0.isStoryInteraction && $0 != .storyApproach }
        let environmentSummary = aiEnvironmentSummary(for: mascot)
        let nearbyCharacters = aiNearbyCharacters(for: mascot)
        let baseURL = UserDefaults.standard.string(forKey: DefaultsKey.ollamaBaseURL) ?? LocalAIPlanner.defaultBaseURL
        let model = UserDefaults.standard.string(forKey: DefaultsKey.ollamaModel) ?? ""

        guard !availableActions.isEmpty else {
            pendingAIRequests.remove(id)
            return
        }

        aiPlanner.requestAction(
            baseURLString: baseURL,
            model: model,
            characterName: characterName,
            currentAction: currentAction,
            availableActions: availableActions,
            environmentSummary: environmentSummary,
            nearbyCharacters: nearbyCharacters
        ) { [weak self] action in
            guard let self else {
                return
            }

            self.pendingAIRequests.remove(id)
            guard self.activeStoryBeat == nil,
                  self.mascots.contains(where: { $0.id == id }) else {
                return
            }

            if let action {
                self.aiSuggestions[id] = action
                if action.isStoryInteraction {
                    self.onAIEvent?("AI cued \(action.rawValue) for \(characterName).")
                }
            }
        }
    }

    private func updateStoryDirector() {
        guard localAIEnabled, mascots.count >= 2 else {
            if activeStoryBeat != nil {
                finishStoryBeat()
            }
            return
        }

        let now = Date()
        if activeStoryBeat != nil, now >= storyBeatEndDate {
            finishStoryBeat()
        }

        guard activeStoryBeat == nil, now >= nextStoryBeatDate else {
            return
        }

        startNextStoryBeat()
    }

    private func startNextStoryBeat() {
        let ready = storyReadyMascots()
        guard ready.count >= 2 else {
            nextStoryBeatDate = Date().addingTimeInterval(TimeInterval.random(in: 4...8))
            return
        }

        let beat = chooseStoryBeat(from: ready)
        guard let cast = runStoryBeat(beat, readyMascots: ready), !cast.isEmpty else {
            nextStoryBeatDate = Date().addingTimeInterval(TimeInterval.random(in: 6...10))
            return
        }

        activeStoryBeat = beat
        activeStoryCast = cast
        aiSuggestions.removeAll()
        storyBeatEndDate = Date().addingTimeInterval(beat.duration)
        onAIEvent?("Story beat started: \(beat.title) with \(storyCastNames(for: cast)).")
    }

    private func finishStoryBeat() {
        if let beat = activeStoryBeat {
            onAIEvent?("Story beat finished: \(beat.title).")
        }
        activeStoryBeat = nil
        activeStoryCast.removeAll()
        aiSuggestions.removeAll()
        nextStoryBeatDate = Date().addingTimeInterval(TimeInterval.random(in: 8...16))
    }

    private func chooseStoryBeat(from ready: [Mascot]) -> StoryBeat {
        let names = Set(ready.map { $0.imageSet.name.lowercased() })
        let colorCount = ready.filter { Self.colorGangNames.contains($0.imageSet.name.lowercased()) }.count
        var candidates: [StoryBeat] = []

        if names.contains("tco") && names.contains("tdl") {
            candidates.append(.rivalSpar)
        }

        if names.contains("victim") && !names.intersection(["tco", "tdl", "orange", "yellow"]).isEmpty {
            candidates.append(.victimScheme)
        }

        if colorCount >= 3 {
            candidates += [.colorGangWarmup, .trainingDrill, .celebration]
        }

        if colorCount >= 2 {
            candidates += [.playfulChase, .rescueMoment, .desktopPatrol]
        }

        candidates += [.watchAndReact, .quietReset]
        let beat = candidates[storyBeatCursor % candidates.count]
        storyBeatCursor += 1
        return beat
    }

    private func runStoryBeat(_ beat: StoryBeat, readyMascots: [Mascot]) -> Set<Int>? {
        var used = Set<Int>()

        switch beat {
        case .colorGangWarmup:
            let colors = colorGangMascots(from: readyMascots)
            if let orange = firstReady(named: ["orange"], from: colors, excluding: used),
               let green = firstReady(named: ["green", "blue", "yellow"], from: colors, excluding: used) {
                startStoryPair(.highFive, first: orange, second: green, used: &used)
            }
            if let red = firstReady(named: ["red"], from: colors, excluding: used),
               let target = firstReady(named: ["blue", "yellow", "purple", "green"], from: colors, excluding: used) {
                startStoryPair(.tradePlaces, first: red, second: target, used: &used)
            }
            for mascot in colors where !used.contains(mascot.id) && used.count < 5 {
                startSoloRole(.teamPose, mascot: mascot, partner: usedPartner(from: used), used: &used)
            }

        case .playfulChase:
            let colors = colorGangMascots(from: readyMascots)
            let leader = firstReady(named: ["red", "orange", "green", "blue"], from: colors, excluding: used)
                ?? colors.filter { !used.contains($0.id) }.randomElement()
            let partner = nearestStoryPartner(for: leader, in: colors, excluding: used)
            startStoryPair(.playChase, first: leader, second: partner, used: &used)
            if let watcher = firstReady(named: ["yellow", "purple"], from: colors, excluding: used) {
                startSoloRole(.observePartner, mascot: watcher, partner: leader, used: &used)
            }

        case .rivalSpar:
            let tco = firstReady(named: ["tco"], from: readyMascots, excluding: used)
            let tdl = firstReady(named: ["tdl"], from: readyMascots, excluding: used)
            if !startStoryPair(.argument, first: tdl ?? tco, second: tco ?? tdl, used: &used),
               !startStoryPair(.spar, first: tdl ?? tco, second: tco ?? tdl, used: &used) {
                let fighter = firstReady(named: ["tco", "tdl"], from: readyMascots, excluding: used)
                startStoryPair(.spar, first: fighter, second: nearestStoryPartner(for: fighter, in: readyMascots, excluding: used), used: &used)
            }
            if let victim = firstReady(named: ["victim"], from: readyMascots, excluding: used) {
                startSoloRole(.observePartner, mascot: victim, partner: tco ?? tdl, used: &used)
            }
            if let yellow = firstReady(named: ["yellow"], from: readyMascots, excluding: used) {
                startSoloRole(.guardPartner, mascot: yellow, partner: tco ?? tdl, used: &used)
            }

        case .victimScheme:
            let victim = firstReady(named: ["victim"], from: readyMascots, excluding: used)
            let target = firstReady(named: ["tco", "tdl", "orange", "yellow"], from: readyMascots, excluding: used)
                ?? nearestStoryPartner(for: victim, in: readyMascots, excluding: used)
            startStoryPair(.victimTrap, first: victim, second: target, used: &used)
            if let orange = firstReady(named: ["orange"], from: readyMascots, excluding: used) {
                startSoloRole(.guardPartner, mascot: orange, partner: target ?? victim, used: &used)
            }
            if let watcher = firstReady(named: ["yellow", "blue", "green"], from: readyMascots, excluding: used) {
                startSoloRole(.observePartner, mascot: watcher, partner: victim, used: &used)
            }

        case .trainingDrill:
            let colors = colorGangMascots(from: readyMascots)
            let coach = firstReady(named: ["orange", "green", "yellow"], from: colors, excluding: used)
                ?? colors.filter { !used.contains($0.id) }.randomElement()
            let student = nearestStoryPartner(for: coach, in: colors.isEmpty ? readyMascots : colors, excluding: used)
            startStoryPair(.copyPartner, first: coach, second: student, used: &used)
            if let fighter = firstReady(named: ["tco", "tdl"], from: readyMascots, excluding: used),
               let target = nearestStoryPartner(for: fighter, in: readyMascots, excluding: used) {
                startStoryPair(.teamPose, first: fighter, second: target, used: &used)
            }
            if let yellow = firstReady(named: ["yellow"], from: readyMascots, excluding: used),
               let helper = firstReady(named: ["blue", "green"], from: readyMascots, excluding: used) {
                startStoryPair(.buildTogether, first: yellow, second: helper, used: &used)
            }

        case .rescueMoment:
            let helper = firstReady(named: ["orange", "blue", "green", "yellow"], from: readyMascots, excluding: used)
                ?? readyMascots.randomElement()
            let target = firstReady(named: ["victim", "red", "purple", "tdl"], from: readyMascots, excluding: used)
                ?? nearestStoryPartner(for: helper, in: readyMascots, excluding: used)
            startStoryPair(.comfortPartner, first: helper, second: target, used: &used)
            if let guardMascot = firstReady(named: ["tco", "orange", "yellow"], from: readyMascots, excluding: used) {
                startSoloRole(.guardPartner, mascot: guardMascot, partner: helper, used: &used)
            }

        case .desktopPatrol:
            let lead = firstReady(named: ["yellow", "orange", "tco", "blue"], from: readyMascots, excluding: used)
                ?? readyMascots.randomElement()
            let partner = nearestStoryPartner(for: lead, in: readyMascots, excluding: used)
            startStoryPair(.patrolPair, first: lead, second: partner, used: &used)
            if let follower = firstReady(named: ["green", "red", "purple"], from: readyMascots, excluding: used) {
                startSoloRole(.followPartner, mascot: follower, partner: lead, used: &used)
            }

        case .watchAndReact:
            let observer = firstReady(named: ["yellow", "victim", "blue"], from: readyMascots, excluding: used)
                ?? readyMascots.randomElement()
            let subject = firstReady(named: ["tco", "tdl", "orange", "green", "red"], from: readyMascots, excluding: used)
                ?? nearestStoryPartner(for: observer, in: readyMascots, excluding: used)
            startSoloRole(.observePartner, mascot: observer, partner: subject, used: &used)
            if let subject, !used.contains(subject.id) {
                startSoloRole(randomExpressiveAction(for: subject), mascot: subject, partner: observer, used: &used)
            }

        case .celebration:
            let first = firstReady(named: ["orange", "green", "blue"], from: readyMascots, excluding: used)
                ?? readyMascots.randomElement()
            let second = nearestStoryPartner(for: first, in: readyMascots, excluding: used)
            startStoryPair(.hugPartner, first: first, second: second, used: &used)
            for mascot in colorGangMascots(from: readyMascots) where !used.contains(mascot.id) && used.count < 5 {
                startSoloRole(randomCelebrationAction(for: mascot), mascot: mascot, partner: first, used: &used)
            }

        case .quietReset:
            let pairLead = firstReady(named: ["yellow", "blue", "victim"], from: readyMascots, excluding: used)
                ?? readyMascots.randomElement()
            let partner = nearestStoryPartner(for: pairLead, in: readyMascots, excluding: used)
            startStoryPair(.buildTogether, first: pairLead, second: partner, used: &used)
            for mascot in readyMascots where !used.contains(mascot.id) && used.count < 4 {
                startSoloRole(randomQuietAction(for: mascot), mascot: mascot, partner: pairLead, used: &used)
            }
        }

        return used.isEmpty ? nil : used
    }

    @discardableResult
    private func startStoryInteraction(_ interaction: MascotAction, first mascot: Mascot, second partner: Mascot, source: String) -> Bool {
        let duration = Int.random(in: 78...150)
        guard interaction.isStoryInteraction,
              mascot !== partner,
              isAvailableForStory(mascot),
              isAvailableForStory(partner),
              mascot.imageSet.supportsAIAction(interaction) else {
            return false
        }

        switch interaction {
        case .followPartner:
            mascot.beginStoryInteraction(.followPartner, with: partner, role: 0, duration: Int.random(in: 120...190))
            partner.beginStoryInteraction(partner.imageSet.supportsAIAction(.followPartner) ? .followPartner : .observePartner, with: mascot, role: 1, duration: Int.random(in: 120...190))
        case .copyPartner:
            mascot.beginStoryInteraction(.copyPartner, with: partner, role: 0, duration: Int.random(in: 100...170))
            partner.beginStoryInteraction(partner.imageSet.supportsAIAction(.copyPartner) ? .copyPartner : .observePartner, with: mascot, role: 1, duration: Int.random(in: 100...170))
        case .guardPartner:
            mascot.beginStoryInteraction(.guardPartner, with: partner, role: 0, duration: Int.random(in: 100...170))
            partner.beginStoryInteraction(partner.imageSet.supportsAIAction(.observePartner) ? .observePartner : .stand, with: mascot, role: 1, duration: Int.random(in: 100...170))
        case .ambush:
            mascot.beginStoryInteraction(.ambush, with: partner, role: 0, duration: Int.random(in: 46...86))
            partner.beginStoryInteraction(partner.imageSet.supportsAIAction(.ambush) ? .ambush : teaseReaction(for: partner), with: mascot, role: 1, duration: Int.random(in: 55...95))
        case .hugPartner:
            mascot.beginStoryInteraction(.hugPartner, with: partner, role: 0, duration: Int.random(in: 110...175), forceApproach: true)
            partner.beginStoryInteraction(.hugPartner, with: mascot, role: 1, duration: Int.random(in: 110...175), forceApproach: true)
        case .tugOfWar:
            mascot.beginStoryInteraction(.tugOfWar, with: partner, role: 0, duration: Int.random(in: 120...185), forceApproach: true)
            partner.beginStoryInteraction(.tugOfWar, with: mascot, role: 1, duration: Int.random(in: 120...185), forceApproach: true)
        case .highFive:
            mascot.beginStoryInteraction(.highFive, with: partner, role: 0, duration: Int.random(in: 80...125), forceApproach: true)
            partner.beginStoryInteraction(partner.imageSet.supportsAIAction(.highFive) ? .highFive : .teamPose, with: mascot, role: 1, duration: Int.random(in: 80...125), forceApproach: true)
        case .argument:
            mascot.beginStoryInteraction(.argument, with: partner, role: 0, duration: Int.random(in: 105...165), forceApproach: true)
            partner.beginStoryInteraction(partner.imageSet.supportsAIAction(.argument) ? .argument : .guardPartner, with: mascot, role: 1, duration: Int.random(in: 105...165), forceApproach: true)
        case .comfortPartner:
            mascot.beginStoryInteraction(.comfortPartner, with: partner, role: 0, duration: Int.random(in: 110...175), forceApproach: true)
            partner.beginStoryInteraction(partner.imageSet.supportsAIAction(.comfortPartner) ? .comfortPartner : fallbackComfortReaction(for: partner), with: mascot, role: 1, duration: Int.random(in: 110...175), forceApproach: true)
        case .teamPose:
            mascot.beginStoryInteraction(.teamPose, with: partner, role: 0, duration: Int.random(in: 95...150), forceApproach: true)
            partner.beginStoryInteraction(partner.imageSet.supportsAIAction(.teamPose) ? .teamPose : .observePartner, with: mascot, role: 1, duration: Int.random(in: 95...150), forceApproach: true)
        case .tradePlaces:
            let firstTarget = partner.anchor.x
            let secondTarget = mascot.anchor.x
            mascot.beginStoryInteraction(.tradePlaces, with: partner, role: 0, duration: Int.random(in: 95...145), targetX: firstTarget)
            partner.beginStoryInteraction(.tradePlaces, with: mascot, role: 1, duration: Int.random(in: 95...145), targetX: secondTarget)
        case .buildTogether:
            mascot.beginStoryInteraction(.buildTogether, with: partner, role: 0, duration: Int.random(in: 120...190), forceApproach: true)
            partner.beginStoryInteraction(partner.imageSet.supportsAIAction(.buildTogether) ? .buildTogether : .observePartner, with: mascot, role: 1, duration: Int.random(in: 120...190), forceApproach: true)
        case .victimTrap:
            mascot.beginStoryInteraction(.victimTrap, with: partner, role: 0, duration: Int.random(in: 90...145), forceApproach: true)
            partner.beginStoryInteraction(fallbackTrapReaction(for: partner), with: mascot, role: 1, duration: Int.random(in: 90...145), forceApproach: true)
        case .patrolPair:
            let direction: CGFloat = mascot.anchor.x <= partner.anchor.x ? 1 : -1
            mascot.beginStoryInteraction(.patrolPair, with: partner, role: 0, duration: Int.random(in: 130...205), targetX: mascot.anchor.x + direction * CGFloat.random(in: 240...520))
            partner.beginStoryInteraction(.patrolPair, with: mascot, role: 1, duration: Int.random(in: 130...205), targetX: partner.anchor.x + direction * CGFloat.random(in: 240...520))
        case .playChase:
            mascot.beginStoryInteraction(.playChase, with: partner, role: 0, duration: duration)
            partner.beginStoryInteraction(.playChase, with: mascot, role: 1, duration: duration)
        case .spar:
            mascot.beginStoryInteraction(.spar, with: partner, role: 0, duration: Int.random(in: 44...78))
            partner.beginStoryInteraction(.spar, with: mascot, role: 1, duration: Int.random(in: 44...78))
        case .tease:
            mascot.beginStoryInteraction(.tease, with: partner, role: 0, duration: duration)
            partner.beginStoryInteraction(teaseReaction(for: partner), with: mascot, role: 1, duration: duration)
        case .celebrate:
            mascot.beginStoryInteraction(.celebrate, with: partner, role: 0, duration: duration)
            partner.beginStoryInteraction(partner.imageSet.supportsAIAction(.celebrate) ? .celebrate : .observePartner, with: mascot, role: 1, duration: duration)
        case .observePartner:
            mascot.beginStoryInteraction(.observePartner, with: partner, role: 0, duration: duration)
        default:
            return false
        }

        onAIEvent?("\(source) started \(interaction.rawValue) between \(mascot.imageSet.name) and \(partner.imageSet.name).")
        return true
    }

    @discardableResult
    private func startStoryPair(_ interaction: MascotAction, first: Mascot?, second: Mascot?, used: inout Set<Int>) -> Bool {
        guard let first, let second else {
            return false
        }

        guard startStoryInteraction(interaction, first: first, second: second, source: "Story") else {
            return false
        }

        used.insert(first.id)
        used.insert(second.id)
        return true
    }

    @discardableResult
    private func startSoloRole(_ action: MascotAction, mascot: Mascot?, partner: Mascot?, used: inout Set<Int>) -> Bool {
        guard let mascot,
              !used.contains(mascot.id),
              isAvailableForStory(mascot) else {
            return false
        }

        if action.isStoryInteraction, let partner, partner !== mascot, mascot.imageSet.supportsAIAction(action) {
            mascot.beginStoryInteraction(action, with: partner, role: 0, duration: Int.random(in: 90...150))
        } else if mascot.imageSet.supportsAIAction(action) || action == .stand || action == .sit {
            mascot.choose(action)
        } else {
            mascot.choose(.stand)
        }

        used.insert(mascot.id)
        return true
    }

    private func storyReadyMascots() -> [Mascot] {
        mascots.filter(isAvailableForStory)
    }

    private func isAvailableForStory(_ mascot: Mascot) -> Bool {
        !mascot.isInStoryInteraction
            && mascot.action != .dragged
            && mascot.action != .holdPointer
            && mascot.action != .fall
            && mascot.action != .thrown
            && mascot.action != .land
    }

    private func firstReady(named names: [String], from mascots: [Mascot], excluding used: Set<Int>) -> Mascot? {
        let lowerNames = names.map { $0.lowercased() }
        for name in lowerNames {
            if let mascot = mascots.first(where: { $0.imageSet.name.lowercased() == name && !used.contains($0.id) }) {
                return mascot
            }
        }
        return nil
    }

    private func colorGangMascots(from mascots: [Mascot]) -> [Mascot] {
        mascots.filter { Self.colorGangNames.contains($0.imageSet.name.lowercased()) }
    }

    private func nearestStoryPartner(for mascot: Mascot?, in candidates: [Mascot], excluding used: Set<Int>) -> Mascot? {
        guard let mascot else {
            return candidates.first { !used.contains($0.id) }
        }

        return candidates
            .filter { $0 !== mascot && !used.contains($0.id) && isAvailableForStory($0) }
            .min { lhs, rhs in
                hypot(lhs.anchor.x - mascot.anchor.x, lhs.anchor.y - mascot.anchor.y)
                    < hypot(rhs.anchor.x - mascot.anchor.x, rhs.anchor.y - mascot.anchor.y)
            }
    }

    private func usedPartner(from used: Set<Int>) -> Mascot? {
        mascots.first { used.contains($0.id) }
    }

    private func storyCastNames(for ids: Set<Int>) -> String {
        let names = mascots
            .filter { ids.contains($0.id) }
            .map(\.imageSet.name)
            .sorted()
        return names.isEmpty ? "available cast" : names.joined(separator: ", ")
    }

    private func randomCelebrationAction(for mascot: Mascot) -> MascotAction {
        let preferred: [MascotAction] = [.dance, .celebrate, .copyPartner, .sitLookUp, .lookAtMouse]
        for action in preferred where mascot.imageSet.supportsAIAction(action) {
            return action
        }
        return .stand
    }

    private func randomExpressiveAction(for mascot: Mascot) -> MascotAction {
        let preferred: [MascotAction]
        switch mascot.imageSet.name.lowercased() {
        case "victim":
            preferred = [.cursorSpite, .lassoSpin, .cursorHate, .stabbing, .lookAtMouse]
        case "tco", "tdl":
            preferred = [.dash, .climbWall, .stand]
        case "red":
            preferred = [.run, .dash, .trip, .dance]
        case "green":
            preferred = [.dance, .dash, .run]
        default:
            preferred = [.dance, .lookAtMouse, .sitLookUp, .walk]
        }

        return preferred.first { mascot.imageSet.supportsAIAction($0) } ?? .stand
    }

    private func randomQuietAction(for mascot: Mascot) -> MascotAction {
        let preferred: [MascotAction] = [.sitLegsDown, .dangleLegs, .sitLookUp, .lookAtMouse, .sit]
        for action in preferred where mascot.imageSet.supportsAIAction(action) {
            return action
        }
        return .stand
    }

    private static let colorGangNames: Set<String> = ["orange", "blue", "green", "yellow", "red", "purple"]

    private func aiEnvironmentSummary(for mascot: Mascot) -> String {
        let anchor = mascot.anchor
        let ground = world.groundY(for: anchor)
        let surface = world.surfaceBelow(anchor: anchor, tolerance: 120)
        let surfaceDescription: String
        if surface?.title == "Dock" {
            surfaceDescription = "near visible Dock surface"
        } else if surface != nil {
            surfaceDescription = "on or near a normal app window surface"
        } else {
            surfaceDescription = "on desktop floor"
        }

        let leftDistance = abs(anchor.x - world.leftWallX(near: anchor))
        let rightDistance = abs(world.rightWallX(near: anchor) - anchor.x)
        let ceilingDistance = abs(world.ceilingY(atX: anchor.x) - anchor.y)
        let mouse = NSEvent.mouseLocation
        let mouseDistance = hypot(mouse.x - anchor.x, mouse.y - anchor.y)
        let mouseDirection = mouse.x >= anchor.x ? "right" : "left"

        return [
            surfaceDescription,
            "heightFromGround=\(Int(anchor.y - ground))",
            "leftWall=\(Int(leftDistance))",
            "rightWall=\(Int(rightDistance))",
            "ceiling=\(Int(ceilingDistance))",
            "mouse=\(mouseDirection) \(Int(mouseDistance))px away"
        ].joined(separator: "; ")
    }

    private func aiNearbyCharacters(for mascot: Mascot) -> String {
        let neighbors = mascots.compactMap { other -> String? in
            guard other !== mascot else {
                return nil
            }

            let distance = hypot(other.anchor.x - mascot.anchor.x, other.anchor.y - mascot.anchor.y)
            guard distance < 700 else {
                return nil
            }

            let direction = other.anchor.x >= mascot.anchor.x ? "right" : "left"
            return "\(other.imageSet.name) \(direction) \(Int(distance))px"
        }

        return neighbors.isEmpty ? "none nearby" : neighbors.joined(separator: ", ")
    }

    private func bestStoryPartner(for mascot: Mascot, interaction: MascotAction) -> Mascot? {
        mascots
            .filter { candidate in
                candidate !== mascot
                    && !candidate.isInStoryInteraction
                    && candidate.action != .dragged
                    && candidate.action != .holdPointer
            }
            .min { lhs, rhs in
                storyPartnerScore(lhs, for: mascot, interaction: interaction)
                    < storyPartnerScore(rhs, for: mascot, interaction: interaction)
            }
    }

    private func storyPartnerScore(_ candidate: Mascot, for mascot: Mascot, interaction: MascotAction) -> CGFloat {
        let distance = hypot(candidate.anchor.x - mascot.anchor.x, candidate.anchor.y - mascot.anchor.y)
        let cappedDistance = min(distance, 900)
        return cappedDistance - storyAffinityBonus(between: mascot.imageSet.name, and: candidate.imageSet.name, interaction: interaction)
    }

    private func storyAffinityBonus(between first: String, and second: String, interaction: MascotAction) -> CGFloat {
        let a = first.lowercased()
        let b = second.lowercased()
        let pair = Set([a, b])

        switch interaction {
        case .victimTrap:
            if a == "victim" && ["tco", "tdl", "orange", "yellow"].contains(b) {
                return 620
            }
            if b == "victim" && ["tco", "tdl", "orange", "yellow"].contains(a) {
                return 500
            }
        case .argument:
            if pair == Set(["tco", "tdl"]) {
                return 560
            }
            if pair.contains("victim") {
                return 260
            }
        case .hugPartner, .highFive, .teamPose, .comfortPartner:
            if pair.isSubset(of: Set(["red", "blue", "green", "yellow", "orange", "purple"])) {
                return 380
            }
            if pair.contains("orange") || pair.contains("blue") {
                return 220
            }
        case .buildTogether:
            if pair.contains("yellow") {
                return 460
            }
            if pair.isSubset(of: Set(["blue", "green", "orange", "yellow"])) {
                return 280
            }
        case .tradePlaces, .patrolPair, .tugOfWar:
            if pair.isSubset(of: Set(["red", "blue", "green", "yellow", "orange", "purple"])) {
                return 330
            }
            if pair.contains("red") || pair.contains("tdl") {
                return 220
            }
        case .ambush:
            if pair.contains("victim") && (pair.contains("tco") || pair.contains("tdl") || pair.contains("orange")) {
                return 520
            }
            if pair == Set(["tco", "tdl"]) {
                return 420
            }
            if pair.contains("red") || pair.contains("purple") {
                return 220
            }
        case .followPartner, .copyPartner, .guardPartner:
            if pair.isSubset(of: Set(["red", "blue", "green", "yellow", "orange", "purple"])) {
                return 340
            }
            if pair.contains("yellow") || pair.contains("orange") {
                return 220
            }
        case .spar, .tease:
            if pair == Set(["tco", "tdl"]) {
                return 520
            }
            if pair.contains("victim") && (pair.contains("tco") || pair.contains("tdl") || pair.contains("orange")) {
                return 430
            }
            if pair.contains("red") || pair.contains("purple") {
                return 180
            }
        case .playChase:
            if pair.isSubset(of: Set(["red", "blue", "green", "yellow", "orange", "purple"])) {
                return 360
            }
            if pair.contains("red") || pair.contains("orange") {
                return 240
            }
        case .celebrate:
            if pair == Set(["orange", "green"]) {
                return 420
            }
            if pair.isSubset(of: Set(["red", "blue", "green", "yellow", "orange"])) {
                return 300
            }
        case .observePartner:
            if pair.contains("yellow") || pair.contains("victim") {
                return 220
            }
        default:
            break
        }

        return 0
    }

    private func teaseReaction(for mascot: Mascot) -> MascotAction {
        if mascot.imageSet.supportsAIAction(.tease) {
            return .tease
        }
        if mascot.imageSet.supportsAIAction(.playChase), Bool.random() {
            return .playChase
        }
        if mascot.imageSet.supportsAIAction(.sprawl), Bool.random() {
            return .sprawl
        }
        return mascot.imageSet.supportsAIAction(.observePartner) ? .observePartner : .stand
    }

    private func fallbackComfortReaction(for mascot: Mascot) -> MascotAction {
        if mascot.imageSet.supportsAIAction(.comfortPartner) {
            return .comfortPartner
        }
        if mascot.imageSet.supportsAIAction(.sprawl) {
            return .sprawl
        }
        if mascot.imageSet.supportsAIAction(.sit) {
            return .sit
        }
        return .observePartner
    }

    private func fallbackTrapReaction(for mascot: Mascot) -> MascotAction {
        if mascot.imageSet.supportsAIAction(.sprawl) {
            return .sprawl
        }
        if mascot.imageSet.supportsAIAction(.trip) {
            return .trip
        }
        if mascot.imageSet.supportsAIAction(.guardPartner) {
            return .guardPartner
        }
        return .stand
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate {
    private static let appDisplayName = "Alan Beckers Stickfigures"
    private static let appSubtitle = "Your Own Stickman Companions!"

    private let controller = MascotController()
    private let aiPlanner = LocalAIPlanner()
    private var statusItem: NSStatusItem?
    private var statusMenu = NSMenu()
    private var settingsWindow: NSWindow?
    private var statusValueLabel: NSTextField?
    private var resourcePathLabel: NSTextField?
    private var startStopButton: NSButton?
    private var restartButton: NSButton?
    private var autoStartCheckbox: NSButton?
    private var keepAliveCheckbox: NSButton?
    private var aiEnabledCheckbox: NSButton?
    private var ollamaURLField: NSTextField?
    private var ollamaModelPopup: NSPopUpButton?
    private var loadOllamaModelsButton: NSButton?
    private var aiStatusLabel: NSTextField?
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
        controller.onAIEvent = { [weak self] message in
            self?.appendLogLine(message)
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        appendLogLine("App reopen requested.")
        showSettingsWindow()
        return true
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
        if defaults.object(forKey: DefaultsKey.aiEnabled) == nil {
            defaults.set(false, forKey: DefaultsKey.aiEnabled)
        }
        if defaults.object(forKey: DefaultsKey.ollamaBaseURL) == nil {
            defaults.set(LocalAIPlanner.defaultBaseURL, forKey: DefaultsKey.ollamaBaseURL)
        }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "ABS"
        statusItem?.button?.toolTip = Self.appDisplayName
        statusItem?.menu = statusMenu
        updateStatusMenu()
    }

    private func updateStatusMenu() {
        statusMenu.removeAllItems()

        let titleItem = NSMenuItem(title: Self.appDisplayName, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        statusMenu.addItem(titleItem)

        let subtitleItem = NSMenuItem(title: Self.appSubtitle, action: nil, keyEquivalent: "")
        subtitleItem.isEnabled = false
        statusMenu.addItem(subtitleItem)
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

        let chooseItem = NSMenuItem(title: "Choose Stickfigures...", action: #selector(showSettingsWindow), keyEquivalent: "")
        chooseItem.target = self
        statusMenu.addItem(chooseItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        let logItem = NSMenuItem(title: "Open Logs", action: #selector(openLog), keyEquivalent: "")
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
        settingsWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 760),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = Self.appDisplayName
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()
        window.delegate = self

        let titleLabel = makeLabel(Self.appDisplayName, font: NSFont.boldSystemFont(ofSize: 24))
        let subtitleLabel = makeLabel(Self.appSubtitle, font: NSFont.systemFont(ofSize: 14), color: .secondaryLabelColor)

        let headerStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 4

        statusValueLabel = makeStatusPill()
        startStopButton = NSButton(title: "", target: self, action: #selector(toggleStickfigures))
        configureButton(startStopButton!, emphasized: true)
        startStopButton?.widthAnchor.constraint(greaterThanOrEqualToConstant: 112).isActive = true

        let statusControls = NSStackView(views: [statusValueLabel!, startStopButton!])
        statusControls.orientation = .horizontal
        statusControls.alignment = .centerY
        statusControls.spacing = 10

        let statusPanel = makePanel([
            makeControlRow(
                title: "Stickfigures",
                detail: "Show desktop companions across your connected screens.",
                control: statusControls
            )
        ])

        autoStartCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(autoStartChanged))
        keepAliveCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(keepAliveChanged))

        let stayInMenuBarCheckbox = lockedCheckbox()
        let dockAndWindowCheckbox = lockedCheckbox()
        let holdPointerCheckbox = lockedCheckbox()

        let preferencesPanel = makeSection(
            title: "Behavior",
            subtitle: "Keep the desktop rules predictable on macOS and Windows.",
            rows: [
                makeControlRow(
                    title: "Start at login",
                    detail: "Turn on stickfigures when this app opens.",
                    control: autoStartCheckbox!
                ),
                makeControlRow(
                    title: "Stay in menu bar",
                    detail: "Keep the ABS controls available from the top bar.",
                    control: stayInMenuBarCheckbox
                ),
                makeControlRow(
                    title: "Respect Dock and windows",
                    detail: "Use visible Dock edges and normal windows as surfaces.",
                    control: dockAndWindowCheckbox
                ),
                makeControlRow(
                    title: "Hold pointer from right click",
                    detail: "Right click a stickfigure to make it hold the mouse pointer.",
                    control: holdPointerCheckbox
                ),
                makeControlRow(
                    title: "Restart if stopped",
                    detail: "Bring the stickfigures back if the engine exits unexpectedly.",
                    control: keepAliveCheckbox!
                )
            ]
        )

        let charactersPanel = makeSection(
            title: "Enabled Stickfigures",
            subtitle: "Only checked characters appear on the desktop.",
            rows: [buildImageSetGrid()]
        )

        let aiPanel = buildAISettingsPanel()

        restartButton = NSButton(title: "Restart", target: self, action: #selector(restartStickfigures))
        configureButton(restartButton!)
        let logButton = NSButton(title: "Open Logs", target: self, action: #selector(openLog))
        configureButton(logButton)
        let finderButton = NSButton(title: "Show App in Finder", target: self, action: #selector(showAppInFinder))
        configureButton(finderButton)

        let buttonRow = NSStackView(views: [restartButton!, logButton, finderButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.distribution = .gravityAreas
        buttonRow.spacing = 8

        resourcePathLabel = makeLabel("", font: NSFont.systemFont(ofSize: 11), color: .tertiaryLabelColor)

        let stack = NSStackView(views: [headerStack, statusPanel, preferencesPanel, aiPanel, charactersPanel, buttonRow, resourcePathLabel!])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.addSubview(stack)
        resourcePathLabel?.lineBreakMode = .byTruncatingMiddle

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -22),
            headerStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusPanel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            preferencesPanel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            aiPanel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            charactersPanel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            resourcePathLabel!.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        window.contentView = contentView
        return window
    }

    private func buildAISettingsPanel() -> NSView {
        aiEnabledCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(aiEnabledChanged(_:)))

        ollamaURLField = NSTextField(string: UserDefaults.standard.string(forKey: DefaultsKey.ollamaBaseURL) ?? LocalAIPlanner.defaultBaseURL)
        ollamaURLField?.placeholderString = LocalAIPlanner.defaultBaseURL
        ollamaURLField?.delegate = self
        ollamaURLField?.target = self
        ollamaURLField?.action = #selector(ollamaURLChanged(_:))
        ollamaURLField?.widthAnchor.constraint(equalToConstant: 250).isActive = true

        loadOllamaModelsButton = NSButton(title: "Load Models", target: self, action: #selector(loadOllamaModels))
        configureButton(loadOllamaModelsButton!)

        let urlControls = NSStackView(views: [ollamaURLField!, loadOllamaModelsButton!])
        urlControls.orientation = .horizontal
        urlControls.alignment = .centerY
        urlControls.spacing = 8

        ollamaModelPopup = NSPopUpButton()
        ollamaModelPopup?.target = self
        ollamaModelPopup?.action = #selector(ollamaModelChanged(_:))
        ollamaModelPopup?.widthAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true
        populateOllamaModelPopup(with: storedOllamaModel().map { [$0] } ?? [])

        aiStatusLabel = makeLabel("", font: NSFont.systemFont(ofSize: 11), color: .secondaryLabelColor)
        aiStatusLabel?.maximumNumberOfLines = 2

        let panel = makeSection(
            title: "Local AI",
            subtitle: "Use Ollama on this Mac for occasional behavior choices.",
            rows: [
                makeControlRow(
                    title: "Enable AI behavior",
                    detail: "Keep animation local and optional.",
                    control: aiEnabledCheckbox!
                ),
                makeControlRow(
                    title: "Ollama URL",
                    detail: "Connect to the local Ollama API endpoint.",
                    control: urlControls
                ),
                makeControlRow(
                    title: "Model",
                    detail: "Only chat-capable local models are shown.",
                    control: ollamaModelPopup!
                ),
                aiStatusLabel!
            ]
        )

        updateAIControls()
        return panel
    }

    private func makeSection(title: String, subtitle: String, rows: [NSView]) -> NSView {
        let titleLabel = makeLabel(title, font: NSFont.boldSystemFont(ofSize: 14))
        let subtitleLabel = makeLabel(subtitle, font: NSFont.systemFont(ofSize: 12), color: .secondaryLabelColor)

        let headerStack = NSStackView(views: [titleLabel, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 2

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let headerRow = NSStackView(views: [headerStack, spacer])
        headerRow.orientation = .horizontal
        headerRow.alignment = .top
        headerRow.spacing = 8

        return makePanel([headerRow] + rows)
    }

    private func makePanel(_ rows: [NSView]) -> NSView {
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        panel.layer?.cornerRadius = 8
        panel.layer?.borderWidth = 1
        panel.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14)
        ])

        return panel
    }

    private func makeControlRow(title: String, detail: String, control: NSView) -> NSView {
        let titleLabel = makeLabel(title, font: NSFont.systemFont(ofSize: 13, weight: .semibold))
        let detailLabel = makeLabel(detail, font: NSFont.systemFont(ofSize: 12), color: .secondaryLabelColor)
        detailLabel.maximumNumberOfLines = 2

        let textStack = NSStackView(views: [titleLabel, detailLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)

        let row = NSStackView(views: [textStack, spacer, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func makeLabel(_ text: String, font: NSFont, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private func makeStatusPill() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.alignment = .center
        label.font = NSFont.boldSystemFont(ofSize: 12)
        label.wantsLayer = true
        label.layer?.cornerRadius = 10
        label.layer?.masksToBounds = true
        label.widthAnchor.constraint(equalToConstant: 64).isActive = true
        label.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return label
    }

    private func configureButton(_ button: NSButton, emphasized: Bool = false) {
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = NSFont.systemFont(ofSize: 13, weight: emphasized ? .semibold : .regular)
        if emphasized {
            button.bezelColor = .systemOrange
        }
    }

    private func lockedCheckbox() -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        checkbox.state = .on
        checkbox.isEnabled = false
        return checkbox
    }

    private func buildImageSetGrid() -> NSStackView {
        imageSetCheckboxes.removeAll()
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 10

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
            checkbox.setContentHuggingPriority(.defaultLow, for: .horizontal)

            let swatch = NSView()
            swatch.wantsLayer = true
            swatch.layer?.backgroundColor = colorForImageSet(name).cgColor
            swatch.layer?.cornerRadius = 5
            swatch.widthAnchor.constraint(equalToConstant: 10).isActive = true
            swatch.heightAnchor.constraint(equalToConstant: 10).isActive = true

            let item = NSStackView(views: [swatch, checkbox])
            item.orientation = .horizontal
            item.alignment = .centerY
            item.spacing = 7
            item.widthAnchor.constraint(greaterThanOrEqualToConstant: 170).isActive = true

            row?.addArrangedSubview(item)
            imageSetCheckboxes[name] = checkbox
        }

        return container
    }

    private func colorForImageSet(_ name: String) -> NSColor {
        switch name.lowercased() {
        case "blue":
            return .systemBlue
        case "green", "victim":
            return .systemGreen
        case "orange":
            return .systemOrange
        case "purple":
            return .systemPurple
        case "red", "tdl":
            return .systemRed
        case "yellow":
            return .systemYellow
        case "tco":
            return .labelColor
        default:
            return .secondaryLabelColor
        }
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

    private func storedOllamaModel() -> String? {
        let value = UserDefaults.standard.string(forKey: DefaultsKey.ollamaModel)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }

    private func populateOllamaModelPopup(with models: [String]) {
        let uniqueModels = Array(Set(models)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        ollamaModelPopup?.removeAllItems()
        ollamaModelPopup?.addItems(withTitles: uniqueModels)

        let storedModel = storedOllamaModel()
        let preferredModel = storedModel.flatMap { uniqueModels.contains($0) ? $0 : nil }
            ?? uniqueModels.first { $0.localizedCaseInsensitiveContains("granite") }
            ?? uniqueModels.first

        if let preferredModel {
            ollamaModelPopup?.selectItem(withTitle: preferredModel)
            UserDefaults.standard.set(preferredModel, forKey: DefaultsKey.ollamaModel)
        } else {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.ollamaModel)
        }

        updateAIControls()
    }

    private func saveOllamaURLFromField() -> String {
        let rawValue = ollamaURLField?.stringValue ?? LocalAIPlanner.defaultBaseURL
        let normalized = aiPlanner.normalizedBaseURLString(from: rawValue)
        ollamaURLField?.stringValue = normalized
        UserDefaults.standard.set(normalized, forKey: DefaultsKey.ollamaBaseURL)
        return normalized
    }

    private func updateAIControls() {
        let defaults = UserDefaults.standard
        let aiEnabled = defaults.bool(forKey: DefaultsKey.aiEnabled)
        aiEnabledCheckbox?.state = aiEnabled ? .on : .off
        ollamaURLField?.stringValue = defaults.string(forKey: DefaultsKey.ollamaBaseURL) ?? LocalAIPlanner.defaultBaseURL

        let hasModel = (ollamaModelPopup?.numberOfItems ?? 0) > 0 && storedOllamaModel() != nil
        ollamaModelPopup?.isEnabled = aiEnabled && hasModel
        loadOllamaModelsButton?.isEnabled = true

        if let aiStatusLabel, aiStatusLabel.stringValue.isEmpty {
            aiStatusLabel.stringValue = aiEnabled
                ? (hasModel ? "Local AI is ready." : "Load models to choose a chat model.")
                : "Local AI is off."
        }
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

    @objc private func aiEnabledChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: DefaultsKey.aiEnabled)
        appendLogLine(sender.state == .on ? "Local AI behavior enabled." : "Local AI behavior disabled.")
        if sender.state == .on && (ollamaModelPopup?.numberOfItems ?? 0) == 0 {
            loadOllamaModels()
        } else {
            aiStatusLabel?.stringValue = sender.state == .on ? "Local AI is ready." : "Local AI is off."
            updateAIControls()
        }
    }

    @objc private func ollamaURLChanged(_ sender: NSTextField) {
        let normalized = saveOllamaURLFromField()
        aiStatusLabel?.stringValue = "Ollama URL set to \(normalized)."
    }

    @objc private func ollamaModelChanged(_ sender: NSPopUpButton) {
        guard let selectedModel = sender.selectedItem?.title, !selectedModel.isEmpty else {
            return
        }

        UserDefaults.standard.set(selectedModel, forKey: DefaultsKey.ollamaModel)
        aiStatusLabel?.stringValue = "Using \(selectedModel)."
        appendLogLine("Local AI model selected: \(selectedModel).")
        updateAIControls()
    }

    @objc private func loadOllamaModels() {
        let baseURL = saveOllamaURLFromField()
        loadOllamaModelsButton?.isEnabled = false
        aiStatusLabel?.stringValue = "Loading Ollama models..."

        aiPlanner.fetchModels(baseURLString: baseURL) { [weak self] result in
            guard let self else {
                return
            }

            self.loadOllamaModelsButton?.isEnabled = true
            switch result {
            case .success(let models):
                self.populateOllamaModelPopup(with: models)
                if models.isEmpty {
                    self.aiStatusLabel?.stringValue = "No chat-capable Ollama models found."
                    self.appendLogLine("Ollama model load found no chat-capable models at \(baseURL).")
                } else {
                    let selectedModel = self.storedOllamaModel() ?? models[0]
                    self.aiStatusLabel?.stringValue = "Loaded \(models.count) local model\(models.count == 1 ? "" : "s"). Using \(selectedModel)."
                    self.appendLogLine("Loaded Ollama models from \(baseURL): \(models.joined(separator: ", ")).")
                }
            case .failure(let error):
                self.populateOllamaModelPopup(with: self.storedOllamaModel().map { [$0] } ?? [])
                self.aiStatusLabel?.stringValue = "Could not load Ollama models: \(error.localizedDescription)"
                self.appendLogLine("Failed to load Ollama models from \(baseURL): \(error.localizedDescription).")
            }
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              textField === ollamaURLField else {
            return
        }

        _ = saveOllamaURLFromField()
    }

    private func updateStatus() {
        statusValueLabel?.stringValue = controller.isRunning ? "On" : "Off"
        statusValueLabel?.textColor = .white
        statusValueLabel?.layer?.backgroundColor = (controller.isRunning ? NSColor.systemGreen : NSColor.systemRed).cgColor
        resourcePathLabel?.stringValue = "Assets loaded from \(resourcesURL.path)"
        startStopButton?.title = controller.isRunning ? "Turn Off" : "Turn On"
        restartButton?.isEnabled = controller.isRunning
        autoStartCheckbox?.state = UserDefaults.standard.bool(forKey: DefaultsKey.autoStart) ? .on : .off
        keepAliveCheckbox?.state = UserDefaults.standard.bool(forKey: DefaultsKey.keepAlive) ? .on : .off
        let selectedNames = Set(selectedImageSetNames())
        for (name, checkbox) in imageSetCheckboxes {
            checkbox.state = selectedNames.contains(name) ? .on : .off
        }
        updateAIControls()
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

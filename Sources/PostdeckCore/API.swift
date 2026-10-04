import Foundation

/// What the server needs from the app.
public struct Inbox: Sendable {
  /// The name of the deck new posts go to, or nil when there are no decks yet.
  public var currentDeckName: @Sendable () async -> String?
  public var receive: @Sendable (PostPayload) async throws -> AddResult
  /// The whole library, for `postdeck list` and `postdeck show`.
  public var library: @Sendable () async -> Library
  /// Runs a command from the `postdeck` tool.
  public var run: @Sendable (Command) async throws -> CommandReply

  public init(
    currentDeckName: @escaping @Sendable () async -> String?,
    receive: @escaping @Sendable (PostPayload) async throws -> AddResult,
    library: @escaping @Sendable () async -> Library,
    run: @escaping @Sendable (Command) async throws -> CommandReply
  ) {
    self.currentDeckName = currentDeckName
    self.receive = receive
    self.library = library
    self.run = run
  }
}

public struct StatusReply: Codable, Equatable, Sendable {
  public var app: String
  public var version: String
  public var deck: String?
}

public struct CardReply: Codable, Equatable, Sendable {
  /// `added`, `updated` when the post's text got longer, or `exists`.
  public var status: String
  public var deck: String
  public var count: Int

  init(_ result: AddResult) {
    switch result {
    case .added(let deck, let count):
      (status, self.deck, self.count) = ("added", deck, count)
    case .updated(let deck, let count):
      (status, self.deck, self.count) = ("updated", deck, count)
    case .alreadyThere(let deck, let count):
      (status, self.deck, self.count) = ("exists", deck, count)
    }
  }
}

public struct ErrorReply: Codable, Equatable, Sendable {
  public var error: String
}

/// The routes: `GET /status` and `POST /cards` for the extension, `GET /library` and `POST /commands` for the `postdeck` tool.
public enum API {
  public static func respond(to request: HTTPRequest, inbox: Inbox) async -> HTTPResponse {
    // A web page can reach 127.0.0.1 through a domain it controls (DNS rebinding). Its requests then name that domain.
    if let host = request.headers["host"], !isLoopback(host) {
      return .json(403, ErrorReply(error: "Postdeck only answers requests for 127.0.0.1."))
    }
    // Web pages send their Origin and can't set a JSON content type without a CORS preflight, which this server never allows.
    if let origin = request.headers["origin"], !origin.hasPrefix("chrome-extension://") {
      return .json(403, ErrorReply(error: "Postdeck only takes posts from its Chrome extension."))
    }

    switch (request.method, request.path) {
    case ("GET", "/status"):
      let deck = await inbox.currentDeckName()
      return .json(200, StatusReply(app: "Postdeck", version: Postdeck.version, deck: deck))

    case ("POST", "/cards"):
      guard isJSON(request) else { return .json(415, ErrorReply(error: "Send the post as JSON.")) }
      do {
        let payload = try PostPayload.decode(request.body)
        let result = try await inbox.receive(payload)
        return .json(200, CardReply(result))
      } catch {
        return .json(400, ErrorReply(error: error.localizedDescription))
      }

    case ("GET", "/library"):
      return .json(200, await inbox.library())

    case ("POST", "/commands"):
      guard isJSON(request) else { return .json(415, ErrorReply(error: "Send the command as JSON.")) }
      guard let command = try? JSONDecoder().decode(Command.self, from: request.body) else {
        return .json(400, ErrorReply(error: "The command isn't valid JSON for Postdeck \(Postdeck.version)."))
      }
      do {
        return .json(200, try await inbox.run(command))
      } catch {
        return .json(400, ErrorReply(error: error.localizedDescription))
      }

    case (_, "/status"), (_, "/cards"), (_, "/library"), (_, "/commands"):
      return .json(405, ErrorReply(error: "\(request.method) isn't supported on \(request.path)."))

    default:
      return .json(404, ErrorReply(error: "There's nothing at \(request.path)."))
    }
  }

  static func isJSON(_ request: HTTPRequest) -> Bool {
    request.headers["content-type"]?.lowercased().hasPrefix("application/json") == true
  }

  static func isLoopback(_ host: String) -> Bool {
    let name = host.split(separator: ":", maxSplits: 1).first.map { $0.lowercased() } ?? ""
    return name == "127.0.0.1" || name == "localhost"
  }
}

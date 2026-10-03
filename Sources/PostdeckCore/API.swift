import Foundation

/// What the server needs from the app.
public struct Inbox: Sendable {
  /// The name of the deck new posts go to, or nil when there are no decks yet.
  public var currentDeckName: @Sendable () async -> String?
  public var receive: @Sendable (PostPayload) async throws -> AddResult

  public init(
    currentDeckName: @escaping @Sendable () async -> String?,
    receive: @escaping @Sendable (PostPayload) async throws -> AddResult
  ) {
    self.currentDeckName = currentDeckName
    self.receive = receive
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

/// The routes the extension calls: `GET /status` and `POST /cards`.
public enum API {
  public static func respond(to request: HTTPRequest, inbox: Inbox) async -> HTTPResponse {
    // Web pages send their Origin and can't set a JSON content type without a CORS preflight, which this server never allows.
    if let origin = request.headers["origin"], !origin.hasPrefix("chrome-extension://") {
      return .json(403, ErrorReply(error: "Postdeck only takes posts from its Chrome extension."))
    }

    switch (request.method, request.path) {
    case ("GET", "/status"):
      let deck = await inbox.currentDeckName()
      return .json(200, StatusReply(app: "Postdeck", version: Postdeck.version, deck: deck))

    case ("POST", "/cards"):
      guard request.headers["content-type"]?.lowercased().hasPrefix("application/json") == true else {
        return .json(415, ErrorReply(error: "Send the post as JSON."))
      }
      do {
        let payload = try PostPayload.decode(request.body)
        let result = try await inbox.receive(payload)
        return .json(200, CardReply(result))
      } catch {
        return .json(400, ErrorReply(error: error.localizedDescription))
      }

    case (_, "/status"), (_, "/cards"):
      return .json(405, ErrorReply(error: "\(request.method) isn't supported on \(request.path)."))

    default:
      return .json(404, ErrorReply(error: "There's nothing at \(request.path)."))
    }
  }
}

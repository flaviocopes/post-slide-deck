import Foundation

/// Talks to the app's local server, for the `postdeck` command.
public struct AppClient: Sendable {
  public var baseURL: URL
  public var session: URLSession

  public init(port: UInt16 = Postdeck.port, session: URLSession = .shared) {
    baseURL = URL(string: "http://127.0.0.1:\(port)")!
    self.session = session
  }

  public func status() async throws -> StatusReply {
    try await send(URLRequest(url: baseURL.appending(path: "status")))
  }

  public func library() async throws -> Library {
    try await send(URLRequest(url: baseURL.appending(path: "library")))
  }

  public func run(_ command: Command) async throws -> CommandReply {
    var request = URLRequest(url: baseURL.appending(path: "commands"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(command)
    return try await send(request)
  }

  private func send<Reply: Decodable>(_ request: URLRequest) async throws -> Reply {
    let (data, response) = try await session.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard status == 200 else {
      let message = (try? JSONDecoder().decode(ErrorReply.self, from: data))?.error
      throw CommandError(message ?? "Postdeck answered with HTTP \(status).")
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Reply.self, from: data)
  }
}

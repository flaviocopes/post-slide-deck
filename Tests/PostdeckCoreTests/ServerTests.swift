import Foundation
import Testing

@testable import PostdeckCore

struct ServerTests {
  let post = #"{"id":"2106174390564159515","author":{"name":"flavio","handle":"flaviocopes"},"text":"Releases"}"#

  @Test func parsesARequestThatArrivesInPieces() {
    let raw = "POST /cards?source=test HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\nContent-Length: \(post.utf8.count)\r\n\r\n\(post)"
    let data = Data(raw.utf8)
    #expect(HTTPRequest.parse(data.prefix(20)) == .incomplete)
    #expect(HTTPRequest.parse(data.dropLast(5)) == .incomplete)
    guard case .complete(let request) = HTTPRequest.parse(data) else {
      Issue.record("the request should be complete")
      return
    }
    #expect(request.method == "POST")
    #expect(request.path == "/cards")
    #expect(request.headers["content-type"] == "application/json")
    #expect(String(decoding: request.body, as: UTF8.self) == post)
  }

  @Test func rejectsGarbage() {
    #expect(HTTPRequest.parse(Data("hello\r\n\r\n".utf8)) == .invalid)
    #expect(HTTPRequest.parse(Data("GET / HTTP/1.1\r\nContent-Length: -4\r\n\r\n".utf8)) == .invalid)
  }

  func inbox(recording received: Received = Received(), library: SharedLibrary = SharedLibrary()) -> Inbox {
    Inbox(
      currentDeckName: { "Releases video" },
      receive: { payload in
        await received.append(payload)
        return .added(deck: "Releases video", count: await received.count)
      },
      library: { await library.library },
      run: { command in try await library.apply(command) }
    )
  }

  @Test func runsCommandsAndListsTheLibrary() async throws {
    let library = SharedLibrary()
    let create = HTTPRequest(
      method: "POST",
      path: "/commands",
      headers: ["content-type": "application/json", "host": "127.0.0.1:7678"],
      body: try JSONEncoder().encode(Command.create(name: "Releases video", theme: nil))
    )
    let created = await API.respond(to: create, inbox: inbox(library: library))
    #expect(created.status == 200)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    #expect(try decoder.decode(CommandReply.self, from: created.body).deck?.name == "Releases video")

    let listed = await API.respond(to: HTTPRequest(method: "GET", path: "/library"), inbox: inbox(library: library))
    #expect(try decoder.decode(Library.self, from: listed.body).decks.map(\.name) == ["Releases video"])

    var missing = create
    missing.body = try JSONEncoder().encode(Command.delete(slideshow: "Podcast"))
    let refused = await API.respond(to: missing, inbox: inbox(library: library))
    #expect(refused.status == 400)
    #expect(try JSONDecoder().decode(ErrorReply.self, from: refused.body).error.contains("Podcast"))
  }

  @Test func refusesOtherHostNames() async {
    let rebound = HTTPRequest(method: "GET", path: "/library", headers: ["host": "flaviocopes.com:7678"])
    #expect(await API.respond(to: rebound, inbox: inbox()).status == 403)
    let local = HTTPRequest(method: "GET", path: "/library", headers: ["host": "localhost:7678"])
    #expect(await API.respond(to: local, inbox: inbox()).status == 200)
  }

  @Test func addsPostsFromTheExtension() async throws {
    let received = Received()
    let request = HTTPRequest(
      method: "POST",
      path: "/cards",
      headers: ["content-type": "application/json", "origin": "chrome-extension://abcdefghijklmnop"],
      body: Data(post.utf8)
    )
    let response = await API.respond(to: request, inbox: inbox(recording: received))
    #expect(response.status == 200)
    #expect(try JSONDecoder().decode(CardReply.self, from: response.body) == CardReply(.added(deck: "Releases video", count: 1)))
    #expect(await received.payloads.map(\.id) == ["2106174390564159515"])
  }

  @Test func refusesWebPages() async {
    let request = HTTPRequest(
      method: "POST",
      path: "/cards",
      headers: ["content-type": "application/json", "origin": "https://flaviocopes.com"],
      body: Data(post.utf8)
    )
    #expect(await API.respond(to: request, inbox: inbox()).status == 403)

    let plain = HTTPRequest(method: "POST", path: "/cards", headers: ["content-type": "text/plain"], body: Data(post.utf8))
    #expect(await API.respond(to: plain, inbox: inbox()).status == 415)
  }

  @Test func answersStatusAndErrors() async throws {
    let status = await API.respond(to: HTTPRequest(method: "GET", path: "/status"), inbox: inbox())
    #expect(try JSONDecoder().decode(StatusReply.self, from: status.body).deck == "Releases video")
    #expect(await API.respond(to: HTTPRequest(method: "GET", path: "/cards"), inbox: inbox()).status == 405)
    #expect(await API.respond(to: HTTPRequest(method: "GET", path: "/"), inbox: inbox()).status == 404)

    let bad = HTTPRequest(method: "POST", path: "/cards", headers: ["content-type": "application/json"], body: Data("{}".utf8))
    let response = await API.respond(to: bad, inbox: inbox())
    #expect(response.status == 400)
    #expect(try JSONDecoder().decode(ErrorReply.self, from: response.body).error.contains("valid JSON"))
  }

  @Test func servesOverTheLoopback() async throws {
    let library = SharedLibrary()
    let server = try LocalServer(port: 0) { request in
      await API.respond(to: request, inbox: inbox(library: library))
    }
    let port = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UInt16, Error>) in
      let once = Once()
      server.start { state in
        guard once.claim() else { return }
        switch state {
        case .listening(let port): continuation.resume(returning: port)
        case .failed(let message): continuation.resume(throwing: PayloadError(message))
        }
      }
    }
    defer { server.stop() }

    var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/cards")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data(post.utf8)
    let (data, response) = try await URLSession.shared.data(for: request)
    #expect((response as? HTTPURLResponse)?.statusCode == 200)
    #expect(try JSONDecoder().decode(CardReply.self, from: data).status == "added")

    let client = AppClient(port: port)
    #expect(try await client.status().version == Postdeck.version)
    _ = try await client.run(.create(name: "Releases video", theme: "mint"))
    let added = try await client.run(.addText(slideshow: "Releases video", title: "Releases", subtitle: "", at: nil))
    #expect(added.deck?.slides.count == 1)
    #expect(try await client.library().decks.first?.theme == "mint")
    await #expect(throws: CommandError("There's no slideshow named “Podcast”. Run `postdeck list` to see them.")) {
      try await client.run(.delete(slideshow: "Podcast"))
    }
  }
}

actor SharedLibrary {
  var library = Library()

  func apply(_ command: Command) throws -> CommandReply {
    try library.apply(command)
  }
}

actor Received {
  var payloads: [PostPayload] = []
  var count: Int { payloads.count }

  func append(_ payload: PostPayload) {
    payloads.append(payload)
  }
}

final class Once: @unchecked Sendable {
  private let lock = NSLock()
  private var claimed = false

  func claim() -> Bool {
    lock.withLock {
      defer { claimed = true }
      return !claimed
    }
  }
}

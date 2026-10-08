import Foundation
import Network

/// An HTTP server on 127.0.0.1, so only apps on this Mac can reach it.
public final class LocalServer: @unchecked Sendable {
  public typealias Handler = @Sendable (HTTPRequest) async -> HTTPResponse

  public enum State: Equatable, Sendable {
    case listening(port: UInt16)
    case failed(String)
  }

  static let maxRequestSize = 2_000_000

  private let listener: NWListener
  private let handler: Handler
  private let queue = DispatchQueue(label: "com.flaviocopes.postdeck.server")

  /// Port 0 picks a free port, which `State.listening` reports.
  public init(port: UInt16, handler: @escaping Handler) throws {
    let parameters = NWParameters.tcp
    parameters.allowLocalEndpointReuse = true
    parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port) ?? .any)
    listener = try NWListener(using: parameters)
    self.handler = handler
  }

  public func start(onState: @escaping @Sendable (State) -> Void) {
    listener.stateUpdateHandler = { [listener] state in
      switch state {
      case .ready:
        onState(.listening(port: listener.port?.rawValue ?? 0))
      case .failed(let error), .waiting(let error):
        onState(.failed(Self.describe(error)))
      default:
        break
      }
    }
    listener.newConnectionHandler = { [weak self] connection in
      self?.accept(connection)
    }
    listener.start(queue: queue)
  }

  public func stop() {
    listener.cancel()
  }

  private static func describe(_ error: NWError) -> String {
    if case .posix(.EADDRINUSE) = error {
      return "Another app is using port \(Postdeck.port)."
    }
    return error.localizedDescription
  }

  private func accept(_ connection: NWConnection) {
    connection.start(queue: queue)
    read(connection, buffer: Data())
  }

  private func read(_ connection: NWConnection, buffer: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [self] data, _, isComplete, error in
      var buffer = buffer
      if let data {
        buffer.append(data)
      }
      switch HTTPRequest.parse(buffer) {
      case .complete(let request):
        let handler = handler
        Task {
          let response = await handler(request)
          self.send(response, on: connection)
        }
      case .incomplete where !isComplete && error == nil && buffer.count <= Self.maxRequestSize:
        read(connection, buffer: buffer)
      default:
        send(.json(400, ErrorReply(error: "Post Slide Deck couldn't read the request.")), on: connection)
      }
    }
  }

  private func send(_ response: HTTPResponse, on connection: NWConnection) {
    connection.send(content: response.serialized(), completion: .contentProcessed { _ in connection.cancel() })
  }
}

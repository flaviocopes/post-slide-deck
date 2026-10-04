import Foundation

/// Just enough HTTP/1.1 for the extension and the `postdeck` tool: one request per connection, with a `Content-Length` body.
public struct HTTPRequest: Sendable, Equatable {
  public var method: String
  public var path: String
  /// Header names are lowercased.
  public var headers: [String: String]
  public var body: Data

  public init(method: String, path: String, headers: [String: String] = [:], body: Data = Data()) {
    self.method = method
    self.path = path
    self.headers = headers
    self.body = body
  }

  public enum ParseResult: Equatable, Sendable {
    case complete(HTTPRequest)
    case incomplete
    case invalid
  }

  static let maxHeadSize = 16_384

  public static func parse(_ data: Data) -> ParseResult {
    guard let end = data.range(of: Data("\r\n\r\n".utf8)) else {
      return data.count > maxHeadSize ? .invalid : .incomplete
    }
    guard let head = String(data: data[data.startIndex..<end.lowerBound], encoding: .utf8) else { return .invalid }
    var lines = head.components(separatedBy: "\r\n")
    let requestLine = lines.removeFirst().split(separator: " ")
    guard requestLine.count == 3 else { return .invalid }

    var headers = [String: String]()
    for line in lines {
      guard let colon = line.firstIndex(of: ":") else { return .invalid }
      let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
      headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
    }

    guard let length = Int(headers["content-length"] ?? "0"), length >= 0 else { return .invalid }
    let body = data[end.upperBound...]
    guard body.count >= length else { return .incomplete }

    let target = requestLine[1]
    let path = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first ?? target
    return .complete(
      HTTPRequest(method: String(requestLine[0]), path: String(path), headers: headers, body: Data(body.prefix(length)))
    )
  }
}

public struct HTTPResponse: Sendable, Equatable {
  public var status: Int
  public var body: Data

  public init(status: Int, body: Data) {
    self.status = status
    self.body = body
  }

  public static func json(_ status: Int, _ value: some Encodable) -> HTTPResponse {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return HTTPResponse(status: status, body: (try? encoder.encode(value)) ?? Data("{}".utf8))
  }

  var reason: String {
    switch status {
    case 200: "OK"
    case 400: "Bad Request"
    case 403: "Forbidden"
    case 404: "Not Found"
    case 405: "Method Not Allowed"
    case 415: "Unsupported Media Type"
    default: "Internal Server Error"
    }
  }

  public func serialized() -> Data {
    let head =
      "HTTP/1.1 \(status) \(reason)\r\n"
      + "Content-Type: application/json; charset=utf-8\r\n"
      + "Content-Length: \(body.count)\r\n"
      + "Connection: close\r\n\r\n"
    return Data(head.utf8) + body
  }
}

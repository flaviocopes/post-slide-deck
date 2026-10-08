import Foundation

/// The JSON the Chrome extension posts to `/cards`.
public struct PostPayload: Codable, Sendable, Equatable {
  public struct Author: Codable, Sendable, Equatable {
    public var name: String
    public var handle: String
    public var avatarURL: URL?
    public var verified: Bool?

    public init(name: String, handle: String, avatarURL: URL? = nil, verified: Bool? = nil) {
      self.name = name
      self.handle = handle
      self.avatarURL = avatarURL
      self.verified = verified
    }
  }

  public struct Attachment: Codable, Sendable, Equatable {
    public var kind: Media.Kind
    public var url: URL

    public init(kind: Media.Kind, url: URL) {
      self.kind = kind
      self.url = url
    }
  }

  public var id: String
  public var author: Author
  public var text: String
  public var links: [String]?
  /// Milliseconds since 1970, what JavaScript's `Date` uses.
  public var postedAt: Double?
  public var replyingTo: [String]?
  public var media: [Attachment]?

  public init(
    id: String,
    author: Author,
    text: String,
    links: [String]? = nil,
    postedAt: Double? = nil,
    replyingTo: [String]? = nil,
    media: [Attachment]? = nil
  ) {
    self.id = id
    self.author = author
    self.text = text
    self.links = links
    self.postedAt = postedAt
    self.replyingTo = replyingTo
    self.media = media
  }

  public static func decode(_ data: Data) throws -> PostPayload {
    do {
      return try JSONDecoder().decode(PostPayload.self, from: data)
    } catch {
      throw PayloadError("The post data isn't valid JSON for Post Slide Deck.")
    }
  }

  static let maxTextLength = 25_000
  static let maxMedia = 4

  /// Checks the payload and turns it into a card. Media and avatar point to X's servers until downloaded.
  public func card(savedAt: Date = Date()) throws -> Card {
    guard !id.isEmpty, id.count <= 30, id.allSatisfy(\.isASCII), id.allSatisfy(\.isNumber) else {
      throw PayloadError("The post ID should be a number.")
    }
    guard Self.isHandle(author.handle) else {
      throw PayloadError("@\(author.handle) isn't a valid X handle.")
    }
    let text = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxTextLength))
    let media = (media ?? []).compactMap { attachment in
      TwitterImage.large(attachment.url).map { Media(kind: attachment.kind, remoteURL: $0) }
    }
    guard !text.isEmpty || !media.isEmpty else {
      throw PayloadError("The post has no text or media to show.")
    }
    let name = author.name.trimmingCharacters(in: .whitespacesAndNewlines)
    var replyingTo = [String]()
    for handle in self.replyingTo ?? [] where Self.isHandle(handle) {
      if handle.lowercased() != author.handle.lowercased(), !replyingTo.contains(handle) {
        replyingTo.append(handle)
      }
    }
    return Card(
      id: id,
      url: URL(string: "https://x.com/\(author.handle)/status/\(id)")!,
      authorName: name.isEmpty ? author.handle : String(name.prefix(100)),
      authorHandle: author.handle,
      authorVerified: author.verified ?? false,
      avatar: author.avatarURL.flatMap(TwitterImage.large).map { Media(kind: .photo, remoteURL: $0) },
      text: text,
      links: (links ?? []).filter { !$0.isEmpty && $0.count <= 300 && text.contains($0) }.prefix(50).map { $0 },
      postedAt: postedAt.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Self.date(fromID: id),
      replyingTo: replyingTo,
      media: Array(media.prefix(Self.maxMedia)),
      savedAt: savedAt
    )
  }

  /// A post ID is a snowflake: its top bits are milliseconds since X's epoch, like `post.js` reads them.
  static func date(fromID id: String) -> Date? {
    guard let snowflake = UInt64(id), snowflake > 1_000_000_000_000_000 else { return nil }
    return Date(timeIntervalSince1970: Double((snowflake >> 22) + 1_288_834_974_657) / 1000)
  }

  static func isHandle(_ handle: String) -> Bool {
    (1...50).contains(handle.count)
      && handle.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "_") }
  }
}

public struct PayloadError: LocalizedError, Equatable {
  public var message: String

  public init(_ message: String) {
    self.message = message
  }

  public var errorDescription: String? { message }
}

import Foundation

/// A post saved from X, shown as one slide.
public struct Card: Codable, Identifiable, Hashable, Sendable {
  /// The post's ID on X. A deck holds each post once.
  public var id: String
  public var url: URL
  public var authorName: String
  public var authorHandle: String
  public var authorVerified: Bool
  public var avatar: Media?
  public var text: String
  public var sourcePostID: String?
  public var part: Int?
  public var partCount: Int?
  /// The visible text of each link in `text`, like `flaviocopes.com/releases/` or `@maxfaber_Om`.
  public var links: [String]
  public var postedAt: Date?
  public var replyingTo: [String]
  public var media: [Media]
  public var savedAt: Date

  public init(
    id: String,
    url: URL,
    authorName: String,
    authorHandle: String,
    authorVerified: Bool = false,
    avatar: Media? = nil,
    text: String,
    links: [String] = [],
    postedAt: Date? = nil,
    replyingTo: [String] = [],
    media: [Media] = [],
    savedAt: Date = Date()
  ) {
    self.id = id
    self.url = url
    self.authorName = authorName
    self.authorHandle = authorHandle
    self.authorVerified = authorVerified
    self.avatar = avatar
    self.text = text
    self.links = links
    self.postedAt = postedAt
    self.replyingTo = replyingTo
    self.media = media
    self.savedAt = savedAt
  }
}

public struct Media: Codable, Hashable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case photo, video
  }

  public var kind: Kind
  public var remoteURL: URL
  /// The file name in the media folder, once downloaded.
  public var file: String?

  public init(kind: Kind, remoteURL: URL, file: String? = nil) {
    self.kind = kind
    self.remoteURL = remoteURL
    self.file = file
  }
}

/// A slide you write in the app: a title, and smaller text below it. Either one can be empty.
public struct TextSlide: Codable, Identifiable, Hashable, Sendable {
  /// A UUID, so it never matches a post's ID.
  public var id: String
  public var title: String
  public var subtitle: String

  public init(id: String = UUID().uuidString, title: String = "", subtitle: String = "") {
    self.id = id
    self.title = title
    self.subtitle = subtitle
  }
}

/// A slide with an image you added, like a screenshot, copied into the media folder.
public struct ImageSlide: Codable, Identifiable, Hashable, Sendable {
  /// A UUID, so it never matches a post's ID.
  public var id: String
  /// The file name in the media folder, `<id>.<extension>`.
  public var file: String

  public init(id: String = UUID().uuidString, file: String) {
    self.id = id
    self.file = file
  }
}

/// One slide of a deck. In `library.json` a post has the fields of a `Card`, and the other slides have a `kind`.
public enum Slide: Codable, Identifiable, Hashable, Sendable {
  case post(Card)
  case text(TextSlide)
  case image(ImageSlide)

  public var id: String {
    switch self {
    case .post(let card): card.id
    case .text(let text): text.id
    case .image(let image): image.id
    }
  }

  public var post: Card? {
    if case .post(let card) = self { card } else { nil }
  }

  private enum CodingKeys: String, CodingKey {
    case kind
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decodeIfPresent(String.self, forKey: .kind) {
    case "text": self = .text(try TextSlide(from: decoder))
    case "image": self = .image(try ImageSlide(from: decoder))
    default: self = .post(try Card(from: decoder))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .post(let card):
      try card.encode(to: encoder)
    case .text(let text):
      try text.encode(to: encoder)
      try container.encode("text", forKey: .kind)
    case .image(let image):
      try image.encode(to: encoder)
      try container.encode("image", forKey: .kind)
    }
  }
}

/// A slideshow: posts and text slides in the order they play.
public struct Deck: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var name: String
  public var createdAt: Date
  public var slides: [Slide]
  /// The ID of the slides' theme, which the app defines. Nil until you pick one.
  public var theme: String?

  /// The slides are saved as `cards`, from when every slide was a post.
  private enum CodingKeys: String, CodingKey {
    case id, name, createdAt, theme
    case slides = "cards"
  }

  public init(id: UUID = UUID(), name: String, createdAt: Date = Date(), slides: [Slide] = [], theme: String? = nil) {
    self.id = id
    self.name = name
    self.createdAt = createdAt
    self.slides = slides
    self.theme = theme
  }
}

public struct Library: Codable, Sendable, Equatable {
  public var decks: [Deck]
  /// The deck new posts go to, the one selected in the app.
  public var currentDeckID: UUID?

  public init(decks: [Deck] = [], currentDeckID: UUID? = nil) {
    self.decks = decks
    self.currentDeckID = currentDeckID
  }
}

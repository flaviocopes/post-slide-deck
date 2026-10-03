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

/// A slideshow: cards in the order they play.
public struct Deck: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var name: String
  public var createdAt: Date
  public var cards: [Card]

  public init(id: UUID = UUID(), name: String, createdAt: Date = Date(), cards: [Card] = []) {
    self.id = id
    self.name = name
    self.createdAt = createdAt
    self.cards = cards
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

import Foundation

/// A change the `postdeck` command asks the app to make. A slideshow is named by its name or ID,
/// a slide by its number, from 1, or its ID. Positions count from 1 too.
public enum Command: Codable, Sendable, Equatable {
  case create(name: String, theme: String?)
  case rename(slideshow: String, name: String)
  case setTheme(slideshow: String, theme: String)
  case delete(slideshow: String)
  case addText(slideshow: String, title: String, subtitle: String, at: Int?)
  case addPost(slideshow: String, post: PostPayload, at: Int?)
  /// Adds the image file at `path`, which the app copies into its media folder.
  case addImage(slideshow: String, path: String, at: Int?)
  /// Changes a text slide. A nil title or subtitle stays as it is.
  case edit(slideshow: String, slide: String, title: String?, subtitle: String?)
  case move(slideshow: String, slide: String, to: Int)
  case remove(slideshow: String, slide: String)
  /// Selects the slideshow in the app, and the slide, or the first one.
  case open(slideshow: String, slide: String?)
}

public struct CommandReply: Codable, Equatable, Sendable {
  /// The slideshow after the change, or nil once deleted.
  public var deck: Deck?
  /// The slide the command added, edited, moved or opened.
  public var slide: Slide.ID?

  public init(deck: Deck?, slide: Slide.ID? = nil) {
    self.deck = deck
    self.slide = slide
  }
}

public struct CommandError: LocalizedError, Equatable {
  public var message: String

  public init(_ message: String) {
    self.message = message
  }

  public var errorDescription: String? { message }
}

extension Library {
  /// Runs a command. Posts keep the image URLs on X, and the app downloads the images afterwards.
  /// `importImage` copies an image file for a new image slide's ID and returns its name in the media folder.
  public mutating func apply(
    _ command: Command,
    importImage: (URL, Slide.ID) throws -> String = { _, _ in throw CommandError("Images can't be added here.") }
  ) throws -> CommandReply {
    switch command {
    case .create(let name, let theme):
      let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { throw CommandError("A slideshow needs a name.") }
      let theme = try theme.map(Self.checkTheme)
      // A slideshow made from the command line doesn't take the place of the one open in the app.
      let selected = currentDeckID
      let id = createDeck(named: name)
      currentDeckID = selected ?? id
      if let theme {
        setTheme(theme, of: id)
      }
      return reply(id)

    case .rename(let slideshow, let name):
      let index = try deckIndex(matching: slideshow)
      guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CommandError("A slideshow needs a name.") }
      renameDeck(decks[index].id, to: name)
      return reply(decks[index].id)

    case .setTheme(let slideshow, let theme):
      let index = try deckIndex(matching: slideshow)
      setTheme(try Self.checkTheme(theme), of: decks[index].id)
      return reply(decks[index].id)

    case .delete(let slideshow):
      deleteDeck(decks[try deckIndex(matching: slideshow)].id)
      return CommandReply(deck: nil)

    case .addText(let slideshow, let title, let subtitle, let at):
      let index = try deckIndex(matching: slideshow)
      let text = TextSlide(
        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
        subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
      )
      guard !text.title.isEmpty || !text.subtitle.isEmpty else { throw CommandError("A text slide needs a title or a subtitle.") }
      let position = try insertion(at, in: index) ?? decks[index].slides.endIndex
      decks[index].slides.insert(.text(text), at: position)
      return reply(decks[index].id, slide: text.id)

    case .addPost(let slideshow, let post, let at):
      let index = try deckIndex(matching: slideshow)
      let card = try post.card()
      if case .alreadyThere = add(card, to: decks[index].id, at: try insertion(at, in: index)) {
        let number = (decks[index].slides.firstIndex { $0.id == card.id } ?? 0) + 1
        throw CommandError("“\(decks[index].name)” already has this post, at slide \(number).")
      }
      return reply(decks[index].id, slide: card.id)

    case .addImage(let slideshow, let path, let at):
      let index = try deckIndex(matching: slideshow)
      let position = try insertion(at, in: index) ?? decks[index].slides.endIndex
      let id = UUID().uuidString
      let image = ImageSlide(id: id, file: try importImage(URL(filePath: path), id))
      decks[index].slides.insert(.image(image), at: position)
      return reply(decks[index].id, slide: id)

    case .edit(let slideshow, let slide, let title, let subtitle):
      let index = try deckIndex(matching: slideshow)
      let position = try slideIndex(matching: slide, in: index)
      guard case .text(var text) = decks[index].slides[position] else {
        throw CommandError("Slide \(position + 1) isn't a text slide. Only text slides can be edited.")
      }
      guard title != nil || subtitle != nil else { throw CommandError("Give a new title, a new subtitle, or both.") }
      text.title = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? text.title
      text.subtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? text.subtitle
      guard !text.title.isEmpty || !text.subtitle.isEmpty else { throw CommandError("A text slide needs a title or a subtitle.") }
      decks[index].slides[position] = .text(text)
      return reply(decks[index].id, slide: text.id)

    case .move(let slideshow, let slide, let to):
      let index = try deckIndex(matching: slideshow)
      let from = try slideIndex(matching: slide, in: index)
      let count = decks[index].slides.count
      guard (1...count).contains(to) else { throw CommandError("Pick a position from 1 to \(count).") }
      let moving = decks[index].slides.remove(at: from)
      decks[index].slides.insert(moving, at: to - 1)
      return reply(decks[index].id, slide: moving.id)

    case .remove(let slideshow, let slide):
      let index = try deckIndex(matching: slideshow)
      decks[index].slides.remove(at: try slideIndex(matching: slide, in: index))
      return reply(decks[index].id)

    case .open(let slideshow, let slide):
      let index = try deckIndex(matching: slideshow)
      let slideID = try slide.map { decks[index].slides[try slideIndex(matching: $0, in: index)].id }
      currentDeckID = decks[index].id
      return reply(decks[index].id, slide: slideID ?? decks[index].slides.first?.id)
    }
  }

  /// The deck with this ID, or this name, in any case.
  public func deckIndex(matching reference: String) throws -> Int {
    if let id = UUID(uuidString: reference), let index = index(of: id) {
      return index
    }
    let matches = decks.indices.filter { decks[$0].name.caseInsensitiveCompare(reference) == .orderedSame }
    guard let first = matches.first else {
      throw CommandError("There's no slideshow named “\(reference)”. Run `postdeck list` to see them.")
    }
    guard matches.count == 1 else {
      let ids = matches.map { decks[$0].id.uuidString }.joined(separator: ", ")
      throw CommandError("\(matches.count) slideshows are named “\(reference)”. Use the ID of one: \(ids).")
    }
    return first
  }

  /// The slide with this number, from 1, or this ID. Post IDs are numbers too, but far bigger than any slide count.
  public func slideIndex(matching reference: String, in deckIndex: Int) throws -> Int {
    let deck = decks[deckIndex]
    if let number = Int(reference), deck.slides.indices.contains(number - 1) {
      return number - 1
    }
    if let index = deck.slides.firstIndex(where: { $0.id == reference }) {
      return index
    }
    guard !deck.slides.isEmpty else { throw CommandError("“\(deck.name)” has no slides.") }
    throw CommandError("“\(deck.name)” has no slide “\(reference)”. Its slides are numbered 1 to \(deck.slides.count).")
  }

  /// Sets the downloaded avatar and images of a post, in every deck that has it.
  public mutating func setMedia(of card: Card) {
    for deck in decks.indices {
      for slide in decks[deck].slides.indices {
        guard case .post(var post) = decks[deck].slides[slide], post.id == card.id else { continue }
        post.avatar = card.avatar
        post.media = card.media
        decks[deck].slides[slide] = .post(post)
      }
    }
  }

  private func reply(_ deckID: UUID, slide: Slide.ID? = nil) -> CommandReply {
    CommandReply(deck: decks.first { $0.id == deckID }, slide: slide)
  }

  /// Where to insert a slide at a position from 1, which can be one past the last slide.
  private func insertion(_ position: Int?, in deckIndex: Int) throws -> Int? {
    guard let position else { return nil }
    let count = decks[deckIndex].slides.count
    guard (1...count + 1).contains(position) else { throw CommandError("Pick a position from 1 to \(count + 1).") }
    return position - 1
  }

  private static func checkTheme(_ theme: String) throws -> String {
    guard let theme = SlideTheme(rawValue: theme.lowercased()) else {
      let names = SlideTheme.allCases.map(\.rawValue).joined(separator: ", ")
      throw CommandError("There's no “\(theme)” theme. Pick one of \(names).")
    }
    return theme.rawValue
  }
}

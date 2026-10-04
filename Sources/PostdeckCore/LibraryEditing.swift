import Foundation

public enum AddResult: Equatable, Sendable {
  case added(deck: String, count: Int)
  /// The deck had the post with a shorter text, cut by X in the timeline, and now has the full one.
  case updated(deck: String, count: Int)
  case alreadyThere(deck: String, count: Int)
}

extension Library {
  public static let untitledDeckName = "Untitled Slideshow"

  public var currentDeck: Deck? {
    decks.first { $0.id == currentDeckID }
  }

  public func index(of deckID: UUID) -> Int? {
    decks.firstIndex { $0.id == deckID }
  }

  public func contains(_ slideID: Slide.ID, in deckID: UUID) -> Bool {
    guard let index = index(of: deckID) else { return false }
    return decks[index].slides.contains { $0.id == slideID }
  }

  /// The deck new posts go to. Picks the newest deck when none is selected, and creates one when there are none.
  public mutating func ensureCurrentDeck() -> UUID {
    if let id = currentDeckID, index(of: id) != nil {
      return id
    }
    if let newest = decks.last {
      currentDeckID = newest.id
      return newest.id
    }
    return createDeck()
  }

  @discardableResult
  public mutating func createDeck(named name: String? = nil) -> UUID {
    let deck = Deck(name: name ?? nextUntitledName())
    decks.append(deck)
    currentDeckID = deck.id
    return deck.id
  }

  /// "Untitled Slideshow", then "Untitled Slideshow 2", and so on.
  public func nextUntitledName() -> String {
    let names = Set(decks.map(\.name))
    guard names.contains(Self.untitledDeckName) else { return Self.untitledDeckName }
    var number = 2
    while names.contains("\(Self.untitledDeckName) \(number)") {
      number += 1
    }
    return "\(Self.untitledDeckName) \(number)"
  }

  @discardableResult
  public mutating func add(_ card: Card, to deckID: UUID) -> AddResult {
    guard let index = index(of: deckID) else {
      let id = createDeck()
      return add(card, to: id)
    }
    let deck = decks[index]
    if let existing = deck.slides.firstIndex(where: { $0.id == card.id }) {
      guard case .post(var post) = deck.slides[existing], card.text.count > post.text.count else {
        return .alreadyThere(deck: deck.name, count: deck.slides.count)
      }
      post.text = card.text
      post.links = card.links
      decks[index].slides[existing] = .post(post)
      return .updated(deck: deck.name, count: deck.slides.count)
    }
    decks[index].slides.append(.post(card))
    return .added(deck: deck.name, count: decks[index].slides.count)
  }

  /// Adds a text slide after `slideID`, or at the end when that's nil or not in the deck.
  public mutating func insert(_ text: TextSlide, in deckID: UUID, after slideID: Slide.ID?) {
    guard let index = index(of: deckID) else { return }
    let slides = decks[index].slides
    let position = slideID.flatMap { id in slides.firstIndex { $0.id == id } }.map { $0 + 1 } ?? slides.endIndex
    decks[index].slides.insert(.text(text), at: position)
  }

  /// Replaces the text slide that has the same ID.
  public mutating func update(_ text: TextSlide, in deckID: UUID) {
    guard let index = index(of: deckID),
      let position = decks[index].slides.firstIndex(where: { $0.id == text.id }),
      case .text = decks[index].slides[position]
    else { return }
    decks[index].slides[position] = .text(text)
  }

  public mutating func setTheme(_ theme: String, of deckID: UUID) {
    guard let index = index(of: deckID) else { return }
    decks[index].theme = theme
  }

  public mutating func renameDeck(_ deckID: UUID, to name: String) {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, let index = index(of: deckID) else { return }
    decks[index].name = name
  }

  /// Deletes the deck. When it was the current one, the deck next to it becomes current.
  public mutating func deleteDeck(_ deckID: UUID) {
    guard let index = index(of: deckID) else { return }
    decks.remove(at: index)
    if currentDeckID == deckID {
      currentDeckID = decks.isEmpty ? nil : decks[min(index, decks.count - 1)].id
    }
  }

  public mutating func removeSlides(_ slideIDs: Set<Slide.ID>, from deckID: UUID) {
    guard let index = index(of: deckID) else { return }
    decks[index].slides.removeAll { slideIDs.contains($0.id) }
  }

  /// Reorders slides the way `List.onMove` describes it: the offsets before the move, and the destination before removing them.
  public mutating func moveSlides(in deckID: UUID, fromOffsets offsets: IndexSet, toOffset destination: Int) {
    guard let index = index(of: deckID) else { return }
    var slides = decks[index].slides
    let moving = offsets.map { slides[$0] }
    let removedBefore = offsets.count { $0 < destination }
    for offset in offsets.reversed() {
      slides.remove(at: offset)
    }
    slides.insert(contentsOf: moving, at: destination - removedBefore)
    decks[index].slides = slides
  }

  /// Moves a slide to the end of another deck. When the other deck has the post already, the slide is only removed.
  public mutating func moveSlide(_ slideID: Slide.ID, from sourceID: UUID, to targetID: UUID) {
    guard sourceID != targetID,
      let source = index(of: sourceID),
      let target = index(of: targetID),
      let slide = decks[source].slides.first(where: { $0.id == slideID })
    else { return }
    decks[source].slides.removeAll { $0.id == slideID }
    if !decks[target].slides.contains(where: { $0.id == slideID }) {
      decks[target].slides.append(slide)
    }
  }

  /// Every media file a post points to, so the rest can be deleted.
  public var mediaFiles: Set<String> {
    var files = Set<String>()
    for card in decks.flatMap(\.slides).compactMap(\.post) {
      if let file = card.avatar?.file {
        files.insert(file)
      }
      files.formUnion(card.media.compactMap(\.file))
    }
    return files
  }
}

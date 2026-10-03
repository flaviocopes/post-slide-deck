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

  public func contains(_ cardID: String, in deckID: UUID) -> Bool {
    guard let index = index(of: deckID) else { return false }
    return decks[index].cards.contains { $0.id == cardID }
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
    if let existing = decks[index].cards.firstIndex(where: { $0.id == card.id }) {
      let deck = decks[index]
      guard card.text.count > deck.cards[existing].text.count else {
        return .alreadyThere(deck: deck.name, count: deck.cards.count)
      }
      decks[index].cards[existing].text = card.text
      decks[index].cards[existing].links = card.links
      return .updated(deck: deck.name, count: deck.cards.count)
    }
    decks[index].cards.append(card)
    return .added(deck: decks[index].name, count: decks[index].cards.count)
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

  public mutating func removeCards(_ cardIDs: Set<String>, from deckID: UUID) {
    guard let index = index(of: deckID) else { return }
    decks[index].cards.removeAll { cardIDs.contains($0.id) }
  }

  /// Reorders cards the way `List.onMove` describes it: the offsets before the move, and the destination before removing them.
  public mutating func moveCards(in deckID: UUID, fromOffsets offsets: IndexSet, toOffset destination: Int) {
    guard let index = index(of: deckID) else { return }
    var cards = decks[index].cards
    let moving = offsets.map { cards[$0] }
    let removedBefore = offsets.count { $0 < destination }
    for offset in offsets.reversed() {
      cards.remove(at: offset)
    }
    cards.insert(contentsOf: moving, at: destination - removedBefore)
    decks[index].cards = cards
  }

  /// Moves a card to the end of another deck. When the other deck has the post already, the card is only removed.
  public mutating func moveCard(_ cardID: String, from sourceID: UUID, to targetID: UUID) {
    guard sourceID != targetID,
      let source = index(of: sourceID),
      let target = index(of: targetID),
      let card = decks[source].cards.first(where: { $0.id == cardID })
    else { return }
    decks[source].cards.removeAll { $0.id == cardID }
    if !decks[target].cards.contains(where: { $0.id == cardID }) {
      decks[target].cards.append(card)
    }
  }

  /// Every media file a card points to, so the rest can be deleted.
  public var mediaFiles: Set<String> {
    var files = Set<String>()
    for card in decks.flatMap(\.cards) {
      if let file = card.avatar?.file {
        files.insert(file)
      }
      files.formUnion(card.media.compactMap(\.file))
    }
    return files
  }
}

import Foundation
import Testing

@testable import PostdeckCore

func makeCard(_ id: String, text: String = "A post") -> Card {
  Card(
    id: id,
    url: URL(string: "https://x.com/flaviocopes/status/\(id)")!,
    authorName: "flavio",
    authorHandle: "flaviocopes",
    text: text
  )
}

struct LibraryTests {
  @Test func firstPostCreatesADeck() {
    var library = Library()
    let deckID = library.ensureCurrentDeck()
    let result = library.add(makeCard("1"), to: deckID)
    #expect(result == .added(deck: "Untitled Slideshow", count: 1))
    #expect(library.decks.count == 1)
    #expect(library.currentDeckID == deckID)
  }

  @Test func aDeckHoldsEachPostOnce() {
    var library = Library()
    let deckID = library.ensureCurrentDeck()
    library.add(makeCard("1"), to: deckID)
    #expect(library.add(makeCard("1"), to: deckID) == .alreadyThere(deck: "Untitled Slideshow", count: 1))
    #expect(library.contains("1", in: deckID))
  }

  @Test func theFullTextReplacesOneXCutShort() {
    var library = Library()
    let deckID = library.ensureCurrentDeck()
    library.add(makeCard("1", text: "I don't write code anymore. I don't…"), to: deckID)
    let full = makeCard("1", text: "I don't write code anymore. I don't even read it.")
    #expect(library.add(full, to: deckID) == .updated(deck: "Untitled Slideshow", count: 1))
    #expect(library.decks[0].cards[0].text == full.text)
    #expect(library.add(makeCard("1", text: "Short"), to: deckID) == .alreadyThere(deck: "Untitled Slideshow", count: 1))
  }

  @Test func newDecksGetNumberedNames() {
    var library = Library()
    library.createDeck()
    library.createDeck()
    library.createDeck(named: "Releases video")
    library.createDeck()
    #expect(library.decks.map(\.name) == ["Untitled Slideshow", "Untitled Slideshow 2", "Releases video", "Untitled Slideshow 3"])
    #expect(library.currentDeck?.name == "Untitled Slideshow 3")
  }

  @Test func picksTheNewestDeckWhenNoneIsSelected() {
    var library = Library()
    library.createDeck(named: "Old")
    let newest = library.createDeck(named: "New")
    library.currentDeckID = nil
    #expect(library.ensureCurrentDeck() == newest)
  }

  @Test func reordersCardsLikeAList() {
    var library = Library()
    let deckID = library.createDeck()
    for id in ["1", "2", "3", "4"] {
      library.add(makeCard(id), to: deckID)
    }
    library.moveCards(in: deckID, fromOffsets: [0], toOffset: 3)
    #expect(library.decks[0].cards.map(\.id) == ["2", "3", "1", "4"])
    library.moveCards(in: deckID, fromOffsets: [2, 3], toOffset: 0)
    #expect(library.decks[0].cards.map(\.id) == ["1", "4", "2", "3"])
  }

  @Test func deletingTheCurrentDeckSelectsTheNextOne() {
    var library = Library()
    let first = library.createDeck(named: "First")
    let second = library.createDeck(named: "Second")
    let third = library.createDeck(named: "Third")
    library.currentDeckID = second
    library.deleteDeck(second)
    #expect(library.currentDeckID == third)
    library.deleteDeck(third)
    #expect(library.currentDeckID == first)
    library.deleteDeck(first)
    #expect(library.currentDeckID == nil)
  }

  @Test func movesACardToAnotherDeck() {
    var library = Library()
    let source = library.createDeck(named: "Source")
    let target = library.createDeck(named: "Target")
    library.add(makeCard("1"), to: source)
    library.add(makeCard("2"), to: source)
    library.add(makeCard("2"), to: target)
    library.moveCard("1", from: source, to: target)
    library.moveCard("2", from: source, to: target)
    #expect(library.decks[0].cards.isEmpty)
    #expect(library.decks[1].cards.map(\.id) == ["2", "1"])
  }

  @Test func listsTheMediaFilesInUse() {
    var library = Library()
    let deckID = library.createDeck()
    var card = makeCard("1")
    card.avatar = Media(kind: .photo, remoteURL: URL(string: "https://pbs.twimg.com/profile_images/1/a_400x400.jpg")!, file: "1-avatar.jpg")
    card.media = [
      Media(kind: .photo, remoteURL: URL(string: "https://pbs.twimg.com/media/A")!, file: "1-1.jpg"),
      Media(kind: .photo, remoteURL: URL(string: "https://pbs.twimg.com/media/B")!)
    ]
    library.add(card, to: deckID)
    #expect(library.mediaFiles == ["1-avatar.jpg", "1-1.jpg"])
  }

  @Test func savesAndLoads() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: "postdeck-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = LibraryStore(folder: folder)
    #expect(try store.load() == Library())

    var library = Library()
    let deckID = library.createDeck(named: "Releases video")
    library.decks[0].createdAt = Date(timeIntervalSince1970: 1_759_450_000)
    var card = makeCard("1", text: "Releases: my free, open source Mac app")
    card.postedAt = Date(timeIntervalSince1970: 1_759_457_280)
    card.savedAt = Date(timeIntervalSince1970: 1_759_460_000)
    library.add(card, to: deckID)
    try store.save(library)
    #expect(try store.load() == library)

    try FileManager.default.createDirectory(at: store.mediaFolder, withIntermediateDirectories: true)
    try Data("a".utf8).write(to: store.mediaURL("1-1.jpg"))
    try Data("b".utf8).write(to: store.mediaURL("2-1.jpg"))
    store.removeUnusedMedia(keeping: ["1-1.jpg"])
    #expect(try FileManager.default.contentsOfDirectory(atPath: store.mediaFolder.path) == ["1-1.jpg"])
  }
}

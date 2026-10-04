import Foundation
import ImageIO
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
    #expect(library.decks[0].slides[0].post?.text == full.text)
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

  @Test func reordersSlidesLikeAList() {
    var library = Library()
    let deckID = library.createDeck()
    for id in ["1", "2", "3", "4"] {
      library.add(makeCard(id), to: deckID)
    }
    library.moveSlides(in: deckID, fromOffsets: [0], toOffset: 3)
    #expect(library.decks[0].slides.map(\.id) == ["2", "3", "1", "4"])
    library.moveSlides(in: deckID, fromOffsets: [2, 3], toOffset: 0)
    #expect(library.decks[0].slides.map(\.id) == ["1", "4", "2", "3"])
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

  @Test func movesASlideToAnotherDeck() {
    var library = Library()
    let source = library.createDeck(named: "Source")
    let target = library.createDeck(named: "Target")
    library.add(makeCard("1"), to: source)
    library.add(makeCard("2"), to: source)
    library.add(makeCard("2"), to: target)
    library.moveSlide("1", from: source, to: target)
    library.moveSlide("2", from: source, to: target)
    #expect(library.decks[0].slides.isEmpty)
    #expect(library.decks[1].slides.map(\.id) == ["2", "1"])
  }

  @Test func insertsSlidesAtAPosition() {
    var library = Library()
    let deckID = library.createDeck()
    for id in ["1", "2"] {
      library.add(makeCard(id), to: deckID)
    }
    let intro = TextSlide(title: "This week's apps")
    library.insert(.text(intro), in: deckID)
    library.insert(.text(TextSlide(id: "first")), in: deckID, at: 1)
    library.insert(.image(ImageSlide(id: "screenshot", file: "screenshot.png")), in: deckID, at: 99)
    #expect(library.decks[0].slides.map(\.id) == ["1", "first", "2", intro.id, "screenshot"])
    #expect(library.add(makeCard("3"), to: deckID) == .added(deck: "Untitled Slideshow", count: 6))
  }

  @Test func editsATextSlide() {
    var library = Library()
    let deckID = library.createDeck()
    var text = TextSlide(title: "Releases")
    library.insert(.text(text), in: deckID)
    text.subtitle = "The app that tracks every app I ship"
    library.update(text, in: deckID)
    #expect(library.decks[0].slides == [.text(text)])
  }

  @Test func readsALibraryFromBeforeTextSlides() throws {
    let json = """
      {"currentDeckID": "9889544B-7E9B-54D2-8BD8-EC15DC315D2C", "decks": [{
        "id": "9889544B-7E9B-54D2-8BD8-EC15DC315D2C", "name": "This week's apps", "createdAt": "2026-10-03T08:00:00Z",
        "cards": [{
          "id": "2106174390564159515", "url": "https://x.com/flaviocopes/status/2106174390564159515",
          "authorName": "flavio", "authorHandle": "flaviocopes", "authorVerified": true,
          "text": "Releases: my free, open source Mac app", "links": [], "replyingTo": [], "media": [],
          "savedAt": "2026-10-03T09:00:00Z"
        }]
      }]}
      """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let library = try decoder.decode(Library.self, from: Data(json.utf8))
    #expect(library.decks[0].slides.map(\.post?.authorHandle) == ["flaviocopes"])
    #expect(library.decks[0].theme == nil)
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
    library.insert(.text(TextSlide(title: "Releases")), in: deckID)
    library.insert(.image(ImageSlide(id: "screenshot", file: "screenshot.png")), in: deckID)
    #expect(library.mediaFiles == ["1-avatar.jpg", "1-1.jpg", "screenshot.png"])
  }

  @Test func importsImagesIntoTheMediaFolder() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: "postdeck-tests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = LibraryStore(folder: folder)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    // A 2×2 PNG, saved without an extension so the name comes from the image itself.
    let png = folder.appending(path: "screenshot")
    let context = CGContext(
      data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let destination = CGImageDestinationCreateWithURL(png as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    #expect(CGImageDestinationFinalize(destination))

    #expect(try store.importImage(from: png, as: "slide") == "slide.png")
    #expect(FileManager.default.fileExists(atPath: store.mediaURL("slide.png").path))

    let notes = folder.appending(path: "notes.txt")
    try Data("Not an image".utf8).write(to: notes)
    #expect(throws: CommandError.self) { try store.importImage(from: notes, as: "notes") }
    #expect(throws: CommandError.self) { try store.importImage(from: folder.appending(path: "missing.png"), as: "missing") }
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
    library.insert(.text(TextSlide(title: "Releases", subtitle: "The app that tracks every app I ship")), in: deckID)
    library.insert(.image(ImageSlide(file: "screenshot.png")), in: deckID)
    library.setTheme("ocean", of: deckID)
    #expect(library.decks[0].theme == "ocean")
    try store.save(library)
    #expect(try store.load() == library)
    let json = try String(contentsOf: store.libraryURL, encoding: .utf8)
    #expect(json.contains(#""kind" : "text""#) && json.contains(#""kind" : "image""#))

    try FileManager.default.createDirectory(at: store.mediaFolder, withIntermediateDirectories: true)
    try Data("a".utf8).write(to: store.mediaURL("1-1.jpg"))
    try Data("b".utf8).write(to: store.mediaURL("2-1.jpg"))
    store.removeUnusedMedia(keeping: ["1-1.jpg"])
    #expect(try FileManager.default.contentsOfDirectory(atPath: store.mediaFolder.path) == ["1-1.jpg"])
  }
}

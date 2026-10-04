import Foundation
import Testing

@testable import PostdeckCore

struct CommandTests {
  /// "Releases video" with posts 1 and 2, open in the app, and an empty "Coding with agents".
  func library() -> Library {
    var library = Library()
    let releases = library.createDeck(named: "Releases video")
    library.add(makeCard("1"), to: releases)
    library.add(makeCard("2"), to: releases)
    library.createDeck(named: "Coding with agents")
    library.currentDeckID = releases
    return library
  }

  @Test func createsASlideshowWithoutChangingTheOpenOne() throws {
    var library = library()
    let open = library.currentDeckID
    let reply = try library.apply(.create(name: "  Mac apps  ", theme: "Ocean"))
    #expect(reply.deck?.name == "Mac apps")
    #expect(reply.deck?.theme == "ocean")
    #expect(library.currentDeckID == open)
    #expect(throws: CommandError.self) { try library.apply(.create(name: "Mac apps", theme: "neon")) }
    #expect(throws: CommandError.self) { try library.apply(.create(name: " ", theme: nil)) }
  }

  @Test func findsSlideshowsByNameOrID() throws {
    var library = library()
    #expect(try library.deckIndex(matching: "releases VIDEO") == 0)
    #expect(try library.deckIndex(matching: library.decks[1].id.uuidString) == 1)
    #expect(throws: CommandError.self) { try library.deckIndex(matching: "Podcast") }
    library.createDeck(named: "Releases video")
    #expect(throws: CommandError.self) { try library.deckIndex(matching: "Releases video") }
  }

  @Test func findsSlidesByNumberOrID() throws {
    let library = library()
    #expect(try library.slideIndex(matching: "2", in: 0) == 1)
    #expect(try library.slideIndex(matching: "1", in: 0) == 0)
    #expect(throws: CommandError.self) { try library.slideIndex(matching: "3", in: 0) }
    #expect(throws: CommandError.self) { try library.slideIndex(matching: "1", in: 1) }
  }

  @Test func addsEditsMovesAndRemovesTextSlides() throws {
    var library = library()
    let added = try library.apply(.addText(slideshow: "Releases video", title: "This week's apps", subtitle: "", at: 1))
    let id = try #require(added.slide)
    #expect(added.deck?.slides.map(\.id) == [id, "1", "2"])

    let edited = try library.apply(.edit(slideshow: "Releases video", slide: id, title: nil, subtitle: "Two posts"))
    #expect(edited.deck?.slides.first == .text(TextSlide(id: id, title: "This week's apps", subtitle: "Two posts")))

    let moved = try library.apply(.move(slideshow: "Releases video", slide: "1", to: 3))
    #expect(moved.deck?.slides.map(\.id) == ["1", "2", id])

    let removed = try library.apply(.remove(slideshow: "Releases video", slide: id))
    #expect(removed.deck?.slides.map(\.id) == ["1", "2"])
  }

  @Test func refusesWhatDoesntFit() {
    var library = library()
    #expect(throws: CommandError.self) { try library.apply(.addText(slideshow: "Releases video", title: " ", subtitle: "", at: nil)) }
    #expect(throws: CommandError.self) { try library.apply(.addText(slideshow: "Releases video", title: "Intro", subtitle: "", at: 4)) }
    #expect(throws: CommandError.self) { try library.apply(.edit(slideshow: "Releases video", slide: "1", title: "A post", subtitle: nil)) }
    #expect(throws: CommandError.self) { try library.apply(.move(slideshow: "Releases video", slide: "1", to: 3)) }
  }

  @Test func addsAPostAtAPosition() throws {
    var library = library()
    let post = PostPayload(id: "2106174390564159515", author: .init(name: "flavio", handle: "flaviocopes"), text: "Releases")
    let reply = try library.apply(.addPost(slideshow: "Releases video", post: post, at: 2))
    #expect(reply.deck?.slides.map(\.id) == ["1", "2106174390564159515", "2"])
    #expect(reply.slide == "2106174390564159515")
    #expect(throws: CommandError("“Releases video” already has this post, at slide 2.")) {
      try library.apply(.addPost(slideshow: "Releases video", post: post, at: nil))
    }
  }

  @Test func opensASlideshowAtASlide() throws {
    var library = library()
    let reply = try library.apply(.open(slideshow: "Coding with agents", slide: nil))
    #expect(library.currentDeckID == library.decks[1].id)
    #expect(reply.slide == nil)
    #expect(try library.apply(.open(slideshow: "Releases video", slide: "2")).slide == "2")
  }

  @Test func renamesThemesAndDeletes() throws {
    var library = library()
    #expect(try library.apply(.rename(slideshow: "Coding with agents", name: "Agents")).deck?.name == "Agents")
    #expect(try library.apply(.setTheme(slideshow: "Agents", theme: "graphite")).deck?.theme == "graphite")
    #expect(try library.apply(.delete(slideshow: "Agents")) == CommandReply(deck: nil))
    #expect(library.decks.map(\.name) == ["Releases video"])
  }

  @Test func setsDownloadedMediaInEveryDeck() {
    var library = library()
    library.add(makeCard("1"), to: library.decks[1].id)
    var downloaded = makeCard("1")
    downloaded.avatar = Media(kind: .photo, remoteURL: URL(string: "https://pbs.twimg.com/profile_images/1/a_400x400.jpg")!, file: "1-avatar.jpg")
    library.setMedia(of: downloaded)
    #expect(library.mediaFiles == ["1-avatar.jpg"])
    #expect(library.decks.allSatisfy { $0.slides.first?.post?.avatar?.file == "1-avatar.jpg" })
  }

  @Test func commandsSurviveJSON() throws {
    let command = Command.addText(slideshow: "Releases video", title: "Intro", subtitle: "", at: 1)
    #expect(try JSONDecoder().decode(Command.self, from: JSONEncoder().encode(command)) == command)
  }
}

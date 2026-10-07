import Foundation
import Testing
@testable import PostdeckCore

@Test func longPostsBecomeLinkedPagesWithoutLosingText() throws {
  let text = String(repeating: "A paragraph about building apps. 👨‍👩‍👧‍👦 Read https://flaviocopes.com for more.\n\n", count: 40)
  let card = Card(id: "123", url: URL(string: "https://x.com/flaviocopes/status/123")!, authorName: "Flavio", authorHandle: "flaviocopes", text: text)
  let pages = card.pages
  #expect(pages.count > 1)
  #expect(pages.map(\.text).joined() == text)
  #expect(Set(pages.map(\.id)).count == pages.count)
  #expect(pages.first?.id == card.id)
  #expect(pages.allSatisfy { $0.sourcePostID == card.id && $0.partCount == pages.count && $0.url == card.url })
  #expect(pages.map(\.part) == Array(1...pages.count).map(Optional.some))
  let deck = Deck(name: "Test", slides: [.post(card), .text(TextSlide(title: "Done"))])
  #expect(deck.playbackSlides.count == pages.count + 1)
  #expect(deck.sourceIndex(for: pages.last!.id) == 0)
  #expect(deck.slides.first?.post?.text == text)
  let restored = try JSONDecoder().decode(Deck.self, from: JSONEncoder().encode(deck))
  #expect(restored.playbackSlides == deck.playbackSlides)
}

@Test func shortPostsStayWholeAndLongPostMediaAppearsOnce() {
  var card = Card(id: "123", url: URL(string: "https://x.com/flaviocopes/status/123")!, authorName: "Flavio", authorHandle: "flaviocopes", text: "Hello")
  #expect(card.pages == [card])
  card.text = String(repeating: "Long post with a lot to say.\n", count: 80)
  card.media = [Media(kind: .photo, remoteURL: URL(string: "https://pbs.twimg.com/media/test.jpg")!)]
  #expect(card.pages.dropLast().allSatisfy { $0.media.isEmpty })
  #expect(card.pages.last?.media == card.media)
  #expect(card.pages.map(\.text).joined() == card.text)
  card.text = String(repeating: "👨‍👩‍👧‍👦", count: 800)
  #expect(card.pages.map(\.text).joined() == card.text)
}

@Test func commandsUsePageNumbersAndKeepPostsTogether() throws {
  let card = Card(id: "123456789", url: URL(string: "https://x.com/flaviocopes/status/123456789")!, authorName: "Flavio", authorHandle: "flaviocopes", text: String(repeating: "A line of text that needs more room.\n", count: 50))
  let end = TextSlide(title: "End")
  let deck = Deck(name: "Test", slides: [.post(card), .text(end)])
  var library = Library(decks: [deck], currentDeckID: deck.id)
  let count = card.pages.count
  let opened = try library.apply(.open(slideshow: "Test", slide: "2"))
  #expect(opened.slide == card.pages[1].id)
  let moved = try library.apply(.move(slideshow: "Test", slide: "2", to: count + 1))
  #expect(moved.deck?.slides.map(\.id) == [end.id, card.id])
  _ = try library.apply(.addText(slideshow: "Test", title: "Before", subtitle: "", at: 3))
  if case .text(let text) = library.decks[0].slides[1] {
    #expect(text.title == "Before")
  } else { Issue.record("Expected a text slide before the linked post") }
  #expect(library.decks[0].slides.last?.id == card.id)
  _ = try library.apply(.remove(slideshow: "Test", slide: card.pages[1].id))
  #expect(library.decks[0].slides.count == 2)
  #expect(library.decks[0].slides.allSatisfy { $0.post == nil })
}

import AppKit
import Observation
import PostdeckCore

@MainActor
@Observable
final class AppModel {
  private(set) var library: Library
  /// The selected post, which is also the slide the slideshow shows.
  var selectedCardID: Card.ID?
  private(set) var serverState: LocalServer.State?
  var errorMessage: String?
  /// True while the slideshow plays in the main window, so new posts don't change the slide on screen.
  private(set) var isPresenting = false
  /// The slideshow whose name is being edited in the sidebar.
  var renamingDeckID: Deck.ID?

  let store: LibraryStore
  @ObservationIgnored private var server: LocalServer?

  init(store: LibraryStore = LibraryStore()) {
    self.store = store
    do {
      library = try store.load()
    } catch {
      library = Library()
      let backup = store.folder.appending(path: "library-unreadable-\(Int(Date().timeIntervalSince1970)).json")
      try? FileManager.default.moveItem(at: store.libraryURL, to: backup)
      errorMessage = "Postdeck couldn't read its library, so it started a new one. The old file is \(backup.lastPathComponent) in \(store.folder.path)."
    }
    selectedCardID = library.currentDeck?.cards.first?.id
    startServer()
  }

  // MARK: Decks

  var currentDeck: Deck? {
    library.currentDeck
  }

  var currentDeckID: Deck.ID? {
    get { library.currentDeckID }
    set {
      guard newValue != library.currentDeckID else { return }
      library.currentDeckID = newValue
      selectedCardID = library.currentDeck?.cards.first?.id
      save()
    }
  }

  var cards: [Card] {
    currentDeck?.cards ?? []
  }

  func createDeck() {
    renamingDeckID = library.createDeck()
    selectedCardID = nil
    save()
  }

  func renameDeck(_ deckID: Deck.ID, to name: String) {
    library.renameDeck(deckID, to: name)
    save()
  }

  func deleteDeck(_ deckID: Deck.ID) {
    library.deleteDeck(deckID)
    selectedCardID = currentDeck?.cards.first?.id
    save()
    store.removeUnusedMedia(keeping: library.mediaFiles)
  }

  // MARK: Cards

  var selectedIndex: Int? {
    cards.firstIndex { $0.id == selectedCardID }
  }

  var selectedCard: Card? {
    selectedIndex.map { cards[$0] }
  }

  func deleteCard(_ cardID: Card.ID) {
    guard let deckID = library.currentDeckID, let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
    library.removeCards([cardID], from: deckID)
    if selectedCardID == cardID {
      selectedCardID = cards.isEmpty ? nil : cards[min(index, cards.count - 1)].id
    }
    save()
    store.removeUnusedMedia(keeping: library.mediaFiles)
  }

  /// Moves a card in front of another one, or to the end when `targetID` is nil.
  func moveCard(_ cardID: Card.ID, before targetID: Card.ID?) {
    guard let deckID = library.currentDeckID, cardID != targetID,
      let source = cards.firstIndex(where: { $0.id == cardID })
    else { return }
    let destination = targetID.flatMap { id in cards.firstIndex { $0.id == id } } ?? cards.count
    library.moveCards(in: deckID, fromOffsets: [source], toOffset: destination)
    save()
  }

  /// Moves a card of the current slideshow to another one. When it was selected, the card that takes its place is.
  func moveCard(_ cardID: Card.ID, to targetID: Deck.ID) {
    guard let deckID = library.currentDeckID, let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
    library.moveCard(cardID, from: deckID, to: targetID)
    if selectedCardID == cardID {
      selectedCardID = cards.isEmpty ? nil : cards[min(index, cards.count - 1)].id
    }
    save()
  }

  // MARK: Slideshow

  func showNext() { show(offset: 1) }
  func showPrevious() { show(offset: -1) }
  func showFirst() { selectedCardID = cards.first?.id }
  func showLast() { selectedCardID = cards.last?.id }

  private func show(offset: Int) {
    guard !cards.isEmpty else { return }
    let index = selectedIndex.map { $0 + offset } ?? 0
    selectedCardID = cards[min(max(index, 0), cards.count - 1)].id
  }

  func startPresenting() {
    guard !cards.isEmpty else { return }
    if selectedCard == nil {
      showFirst()
    }
    isPresenting = true
  }

  func stopPresenting() {
    isPresenting = false
  }

  // MARK: Posts from the extension

  func startServer() {
    server?.stop()
    let port = ProcessInfo.processInfo.environment["POSTDECK_PORT"].flatMap(UInt16.init) ?? Postdeck.port
    let inbox = Inbox(
      currentDeckName: { [weak self] in await self?.currentDeck?.name },
      receive: { [weak self] payload in
        guard let self else { throw PayloadError("Postdeck is quitting.") }
        return try await self.receive(payload)
      }
    )
    do {
      let server = try LocalServer(port: port) { request in
        await API.respond(to: request, inbox: inbox)
      }
      server.start { [weak self] state in
        Task { @MainActor in self?.serverDidChange(state) }
      }
      self.server = server
    } catch {
      serverDidChange(.failed(error.localizedDescription))
    }
  }

  /// A busy port is often a copy of Postdeck that's still quitting, so keep trying every 2 seconds.
  private func serverDidChange(_ state: LocalServer.State) {
    serverState = state
    guard case .failed = state else { return }
    Task {
      try? await Task.sleep(for: .seconds(2))
      if case .failed = serverState {
        startServer()
      }
    }
  }

  func receive(_ payload: PostPayload) async throws -> AddResult {
    let card = try payload.card()
    let deckID = library.ensureCurrentDeck()
    if library.contains(card.id, in: deckID) {
      let result = library.add(card, to: deckID)
      save()
      return result
    }
    save()

    let downloaded = await MediaDownloader(folder: store.mediaFolder).download(card)
    let result = library.add(downloaded, to: deckID)
    save()
    if case .added = result, library.currentDeckID == deckID, !isPresenting {
      selectedCardID = downloaded.id
    }
    return result
  }

  private func save() {
    do {
      try store.save(library)
    } catch {
      errorMessage = "Postdeck couldn't save the library: \(error.localizedDescription)"
    }
  }
}

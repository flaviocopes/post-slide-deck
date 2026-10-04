import AppKit
import Observation
import PostdeckCore

@MainActor
@Observable
final class AppModel {
  private(set) var library: Library
  /// The selected slide, which is also the one the slideshow shows.
  var selectedSlideID: Slide.ID? {
    didSet {
      if selectedSlideID != newTextSlideID {
        newTextSlideID = nil
      }
    }
  }
  private(set) var serverState: LocalServer.State?
  var errorMessage: String?
  /// True while the slideshow plays in the main window, so new posts don't change the slide on screen.
  private(set) var isPresenting = false
  /// The slideshow whose name is being edited in the sidebar.
  var renamingDeckID: Deck.ID?
  /// The text slide just added, so the stage puts the cursor in its title.
  private(set) var newTextSlideID: Slide.ID?

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
    selectedSlideID = library.currentDeck?.slides.first?.id
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
      selectedSlideID = library.currentDeck?.slides.first?.id
      save()
    }
  }

  var slides: [Slide] {
    currentDeck?.slides ?? []
  }

  var theme: SlideTheme {
    SlideTheme(currentDeck?.theme)
  }

  func setTheme(_ theme: SlideTheme) {
    guard let deckID = library.currentDeckID else { return }
    library.setTheme(theme.rawValue, of: deckID)
    save()
  }

  func createDeck() {
    renamingDeckID = library.createDeck()
    selectedSlideID = nil
    save()
  }

  func renameDeck(_ deckID: Deck.ID, to name: String) {
    library.renameDeck(deckID, to: name)
    save()
  }

  func deleteDeck(_ deckID: Deck.ID) {
    library.deleteDeck(deckID)
    selectedSlideID = currentDeck?.slides.first?.id
    save()
    store.removeUnusedMedia(keeping: library.mediaFiles)
  }

  // MARK: Slides

  var selectedIndex: Int? {
    slides.firstIndex { $0.id == selectedSlideID }
  }

  var selectedSlide: Slide? {
    selectedIndex.map { slides[$0] }
  }

  /// The slide after the selected one, or nil on the last slide.
  var nextSlide: Slide? {
    guard let index = selectedIndex, index + 1 < slides.count else { return nil }
    return slides[index + 1]
  }

  /// Adds an empty text slide after the selected one and selects it, so the stage shows it ready to type in.
  func addTextSlide() {
    let deckID = library.ensureCurrentDeck()
    let slide = TextSlide()
    library.insert(slide, in: deckID, after: selectedSlideID)
    selectedSlideID = slide.id
    newTextSlideID = slide.id
    save()
  }

  func updateTextSlide(_ slide: TextSlide) {
    guard let deckID = library.currentDeckID, !slides.contains(.text(slide)) else { return }
    library.update(slide, in: deckID)
    save()
  }

  func deleteSlide(_ slideID: Slide.ID) {
    guard let deckID = library.currentDeckID, let index = slides.firstIndex(where: { $0.id == slideID }) else { return }
    library.removeSlides([slideID], from: deckID)
    if selectedSlideID == slideID {
      selectedSlideID = slides.isEmpty ? nil : slides[min(index, slides.count - 1)].id
    }
    save()
    store.removeUnusedMedia(keeping: library.mediaFiles)
  }

  /// Moves a slide in front of another one, or to the end when `targetID` is nil.
  func moveSlide(_ slideID: Slide.ID, before targetID: Slide.ID?) {
    guard let deckID = library.currentDeckID, slideID != targetID,
      let source = slides.firstIndex(where: { $0.id == slideID })
    else { return }
    let destination = targetID.flatMap { id in slides.firstIndex { $0.id == id } } ?? slides.count
    library.moveSlides(in: deckID, fromOffsets: [source], toOffset: destination)
    save()
  }

  /// Moves a slide of the current slideshow to another one. When it was selected, the slide that takes its place is.
  func moveSlide(_ slideID: Slide.ID, to targetID: Deck.ID) {
    guard let deckID = library.currentDeckID, let index = slides.firstIndex(where: { $0.id == slideID }) else { return }
    library.moveSlide(slideID, from: deckID, to: targetID)
    if selectedSlideID == slideID {
      selectedSlideID = slides.isEmpty ? nil : slides[min(index, slides.count - 1)].id
    }
    save()
  }

  // MARK: Slideshow

  func showNext() { show(offset: 1) }
  func showPrevious() { show(offset: -1) }
  func showFirst() { selectedSlideID = slides.first?.id }
  func showLast() { selectedSlideID = slides.last?.id }

  private func show(offset: Int) {
    guard !slides.isEmpty else { return }
    let index = selectedIndex.map { $0 + offset } ?? 0
    selectedSlideID = slides[min(max(index, 0), slides.count - 1)].id
  }

  func startPresenting() {
    guard !slides.isEmpty else { return }
    if selectedSlide == nil {
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
      selectedSlideID = downloaded.id
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

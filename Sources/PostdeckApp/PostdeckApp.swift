import PostdeckCore
import SwiftUI

@main
struct PostdeckApp: App {
  @State private var model = AppModel()

  init() {
    AppUpdater.shared.start(repository: "flaviocopes/postdeck")
  }

  var body: some Scene {
    Window("Postdeck", id: "main") {
      ContentView()
        .environment(model)
        .frame(minWidth: 1000, minHeight: 620)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1280, height: 800)
    .commands {
      PostdeckCommands(model: model)
    }
  }
}

struct PostdeckCommands: Commands {
  let model: AppModel

  var body: some Commands {
    CommandGroup(after: .appInfo) {
      Button("Check for Updates…") {
        AppUpdater.shared.checkForUpdates()
      }
    }
    CommandGroup(replacing: .newItem) {
      Button("New Slideshow") {
        model.createDeck()
      }
      .keyboardShortcut("n")
      .disabled(model.isPresenting)
      Button("New Text Slide") {
        model.addTextSlide()
      }
      .keyboardShortcut("t")
      .disabled(model.isPresenting)
    }
    CommandMenu("Slideshow") {
      if model.isPresenting {
        Button("Stop") { model.stopPresenting() }
          .keyboardShortcut(.return, modifiers: .command)
      } else {
        Button("Play") { model.startPresenting() }
          .keyboardShortcut(.return, modifiers: .command)
          .disabled(model.slides.isEmpty)
      }
      Divider()
      Button("Next Slide") { model.showNext() }
      Button("Previous Slide") { model.showPrevious() }
      Button("First Slide") { model.showFirst() }
      Button("Last Slide") { model.showLast() }
    }
  }
}

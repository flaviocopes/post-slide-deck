import AppKit
import PostdeckCore
import SwiftUI

/// A small floating window with the next slide, open while the slideshow plays.
/// It's a window of its own, so a recording of the main window doesn't show it, and it never
/// takes the keyboard, so → ← and clickers keep changing the slide.
@MainActor
enum NextSlidePanel {
  private static var panel: NSPanel?
  private static let frameName = "NextSlidePanel"

  static func show(_ model: AppModel) {
    let panel = panel ?? makePanel(model)
    self.panel = panel
    panel.orderFront(nil)
  }

  static func hide() {
    panel?.orderOut(nil)
  }

  private static func makePanel(_ model: AppModel) -> NSPanel {
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 400, height: 248),
      styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.title = "Next Slide"
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = true
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.becomesKeyOnlyIfNeeded = true
    panel.isReleasedWhenClosed = false
    panel.collectionBehavior = [.fullScreenAuxiliary]
    panel.contentMinSize = NSSize(width: 240, height: 170)
    panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
    panel.standardWindowButton(.zoomButton)?.isHidden = true
    let host = NSHostingView(rootView: NextSlideView().environment(model))
    host.sizingOptions = []
    panel.contentView = host
    if !panel.setFrameUsingName(frameName), let screen = NSApp.mainWindow?.screen ?? NSScreen.main {
      let visible = screen.visibleFrame
      panel.setFrameTopLeftPoint(NSPoint(x: visible.maxX - panel.frame.width - 20, y: visible.maxY - 20))
    }
    panel.setFrameAutosaveName(frameName)
    return panel
  }
}

private struct NextSlideView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(spacing: 6) {
      HStack {
        SectionLabel(text: "Up next")
        Spacer()
        Text("\((model.selectedIndex ?? 0) + 1) / \(model.slides.count)")
          .font(Typography.captionStrong)
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
      .padding(.leading, 12)
      .frame(height: 18)
      GeometryReader { proxy in
        let width = min(proxy.size.width, proxy.size.height * 16 / 9)
        Group {
          if let slide = model.nextSlide {
            SlideView(slide: slide, theme: model.theme, store: model.store, width: width)
          } else {
            Surface.hover
              .overlay {
                Text("End of the slideshow")
                  .font(Typography.bodyStrong)
                  .foregroundStyle(.secondary)
              }
              .frame(width: width, height: width * 9 / 16)
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Surface.hairline))
        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
      }
    }
    .padding([.horizontal, .bottom], 12)
    .background(Surface.stage)
    .ignoresSafeArea()
  }
}

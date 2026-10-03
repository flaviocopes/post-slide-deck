import AppKit
import PostdeckCore
import SwiftUI

/// The selected slide, large, with the controls.
struct Stage: View {
  @Environment(AppModel.self) private var model
  @AppStorage("slideTheme") private var theme = SlideTheme.light

  var body: some View {
    ZStack {
      Surface.stage
      DotGrid()
      VStack(spacing: 0) {
        topBar
        if let card = model.selectedCard {
          GeometryReader { proxy in
            let width = min(proxy.size.width, proxy.size.height * 16 / 9)
            SlideView(card: card, theme: theme, store: model.store, width: width)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
              .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Surface.hairline))
              .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
              .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
          }
          .padding(.horizontal, 40)
          .padding(.vertical, 16)
          controls
            .padding(.bottom, 10)
          Text("While playing, → ← or a clicker change the slide, and S brings you back here")
            .font(Typography.caption)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 16)
        } else {
          Spacer()
          EmptyState(
            symbol: "play.rectangle.fill",
            title: model.cards.isEmpty ? "Your slides show up here" : "Pick a slide",
            message: model.cards.isEmpty
              ? "Each post you send from X becomes a slide you can talk over."
              : "Click a slide on the left to see it here."
          )
          Spacer()
        }
      }
    }
  }

  private var topBar: some View {
    HStack(spacing: 10) {
      if let card = model.selectedCard {
        Button {
          NSWorkspace.shared.open(card.url)
        } label: {
          Label("Open on X", systemImage: "arrow.up.right")
            .font(Typography.bodyStrong)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 28)
        }
        .buttonStyle(HoverButtonStyle())
      }
      Spacer()
      ThemeToggle(theme: $theme)
      Button {
        model.startPresenting()
      } label: {
        Label("Play", systemImage: "play.fill")
      }
      .buttonStyle(PlayButtonStyle())
      .disabled(model.cards.isEmpty)
      .help("Show only the slide in this window (⌘↩)")
    }
    .padding(.horizontal, 16)
    .frame(height: Metrics.topBar)
  }

  private var controls: some View {
    HStack(spacing: 2) {
      Button {
        model.showPrevious()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 12, weight: .semibold))
          .frame(width: 32, height: 28)
      }
      .disabled(model.selectedIndex == 0)
      Text("\((model.selectedIndex ?? 0) + 1) / \(model.cards.count)")
        .font(Typography.captionStrong)
        .monospacedDigit()
        .frame(minWidth: 44)
      Button {
        model.showNext()
      } label: {
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .frame(width: 32, height: 28)
      }
      .disabled(model.selectedIndex == model.cards.count - 1)
    }
    .buttonStyle(HoverButtonStyle(cornerRadius: 14))
    .padding(4)
    .background(Surface.raised, in: Capsule())
    .overlay(Capsule().strokeBorder(Surface.hairline))
    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
  }
}

/// What you record in Borumi: the main window with only the slide in it, and no window buttons.
struct SlideshowView: View {
  @Environment(AppModel.self) private var model
  @AppStorage("slideTheme") private var theme = SlideTheme.light
  @FocusState private var focused: Bool

  var body: some View {
    GeometryReader { proxy in
      let width = min(proxy.size.width, proxy.size.height * 16 / 9)
      ZStack {
        theme.background
        if let card = model.selectedCard {
          SlideView(card: card, theme: theme, store: model.store, width: width)
            .id(card.id)
            .transition(.opacity)
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .animation(.easeInOut(duration: 0.25), value: model.selectedCardID)
    .ignoresSafeArea()
    .focusable()
    .focusEffectDisabled()
    .focused($focused)
    .onKeyPress(keys: [.rightArrow, .downArrow, .pageDown, .space, .return]) { _ in
      model.showNext()
      return .handled
    }
    .onKeyPress(keys: [.leftArrow, .upArrow, .pageUp, .delete]) { _ in
      model.showPrevious()
      return .handled
    }
    .onKeyPress(keys: [.home]) { _ in
      model.showFirst()
      return .handled
    }
    .onKeyPress(keys: [.end]) { _ in
      model.showLast()
      return .handled
    }
    .onKeyPress(keys: ["s", "S", .escape]) { _ in
      model.stopPresenting()
      return .handled
    }
    .onAppear { focused = true }
    .background(HiddenWindowButtons())
  }
}

/// Hides the traffic lights of the window it's in, and shows them again when it leaves the window.
private struct HiddenWindowButtons: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    ButtonHider()
  }

  func updateNSView(_ nsView: NSView, context: Context) {}

  final class ButtonHider: NSView {
    override func viewWillMove(toWindow newWindow: NSWindow?) {
      super.viewWillMove(toWindow: newWindow)
      setButtons(of: window, hidden: false)
      setButtons(of: newWindow, hidden: true)
    }

    private func setButtons(of window: NSWindow?, hidden: Bool) {
      for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        window?.standardWindowButton(button)?.isHidden = hidden
      }
    }
  }
}

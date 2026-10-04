// Renders the real app views from a library folder into <output>:
// screenshot-<light|dark>.png (the main window, framed with a shadow) and slide-<n>-<light|dark>.png
// (each slide, 1920×1080).
// Scripts/screenshot.sh compiles it with the app's views, in place of the @main file.

import AppKit
import PostdeckCore
import SwiftUI

let output = URL(filePath: CommandLine.arguments[1])
let width: CGFloat = 1280
let height: CGFloat = 780

@main
enum Screenshot {
  @MainActor
  static func main() {
    // The library to show, and a free port, so a running Postdeck keeps its own.
    setenv("POSTDECK_HOME", CommandLine.arguments[2], 1)
    setenv("POSTDECK_PORT", "0", 1)
    let model = AppModel()

    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let host = NSHostingView(rootView: ContentView().environment(model).frame(width: width, height: height))
    let window = ActiveWindow(
      contentRect: CGRect(x: 0, y: 0, width: width, height: height),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "Postdeck"
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.contentView = host
    window.center()
    _ = NotificationCenter.default.addObserver(forName: NSApplication.didFinishLaunchingNotification, object: nil, queue: .main) { _ in
      MainActor.assumeIsolated {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        Task { await capture(window, model: model) }
      }
    }
    app.run()
  }
}

/// Draws as the active window even when another app is frontmost, which is the case
/// when this runs from a terminal: macOS doesn't let it take focus.
final class ActiveWindow: NSWindow {
  override var isKeyWindow: Bool { true }
  override var isMainWindow: Bool { true }
  @objc(_hasActiveAppearance) func hasActiveAppearance() -> Bool { true }
  @objc(_hasActiveAppearanceIgnoringKeyFocus) func hasActiveAppearanceIgnoringKeyFocus() -> Bool { true }
  @objc(_hasKeyAppearance) func hasKeyAppearance() -> Bool { true }
  @objc(_hasMainAppearance) func hasMainAppearance() -> Bool { true }
}

@MainActor
func capture(_ window: NSWindow, model: AppModel) async {
  for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
    NSApp.appearance = NSAppearance(named: appearance)
    window.makeFirstResponder(nil)
    try? await Task.sleep(for: .seconds(1))
    write(framed(snapshot(window)), to: output.appending(path: "screenshot-\(name).png"))
  }
  for (index, slide) in model.slides.enumerated() {
    for theme in SlideTheme.allCases {
      let renderer = ImageRenderer(content: SlideView(slide: slide, theme: theme, store: model.store, width: 1920))
      renderer.scale = 1
      if let image = renderer.cgImage {
        write(image, to: output.appending(path: "slide-\(index + 1)-\(theme.rawValue).png"))
      }
    }
  }
  NSApp.terminate(nil)
}

/// The whole window, title bar included, at the screen's scale.
@MainActor
func snapshot(_ window: NSWindow) -> CGImage {
  let view = window.contentView!.superview!
  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
  view.cacheDisplay(in: view.bounds, to: rep)
  return rep.cgImage!
}

/// Rounds the corners like a window and adds a soft shadow on a transparent 48pt margin.
func framed(_ image: CGImage) -> CGImage {
  let scale: CGFloat = 2
  let margin = 48 * scale
  let radius = 10 * scale
  let size = CGSize(width: CGFloat(image.width) + 2 * margin, height: CGFloat(image.height) + 2 * margin)
  let context = CGContext(
    data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  )!
  let rect = CGRect(x: margin, y: margin, width: CGFloat(image.width), height: CGFloat(image.height))
  let window = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

  context.saveGState()
  context.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 36 * scale, color: CGColor(gray: 0, alpha: 0.32))
  context.addPath(window)
  context.setFillColor(CGColor(gray: 0.5, alpha: 1))
  context.fillPath()
  context.restoreGState()

  context.addPath(window)
  context.clip()
  context.draw(image, in: rect)
  context.resetClip()
  context.addPath(window)
  context.setStrokeColor(CGColor(gray: 0, alpha: 0.18))
  context.setLineWidth(1)
  context.strokePath()
  return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
  let rep = NSBitmapImageRep(cgImage: image)
  try! rep.representation(using: .png, properties: [:])!.write(to: url)
  print(url.path)
}

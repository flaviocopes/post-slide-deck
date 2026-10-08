#!/usr/bin/env swift
// Renders the README banner, docs/banner.png, at 2x: the icon, the name, a tagline and
// feature chips on the left, the real window on the right, on the icon's blue with a faint dot grid.
// The window is docs/screenshot-dark.png, made by Scripts/screenshot.sh.
// Usage: swift Scripts/render-banner.swift

import AppKit
import SwiftUI

let name = "Post Slide Deck"
let tagline = "Turn posts on X into slides\nyou talk over in your videos."
let chips = ["One click on X", "Drag to reorder", "Six themes"]
let size = CGSize(width: 1280, height: 560)
// Where the window's top-left corner sits, and how much it's scaled down.
let windowOrigin = CGPoint(x: 566, y: 66)
let windowScale: CGFloat = 0.53

// The icon's background, a bit deeper.
let backgroundTop = Color(hex: 0x3F5FE6)
let backgroundBottom = Color(hex: 0x1D1283)
let glow = Color(hex: 0x6E9BFF)
let muted = Color.white.opacity(0.74)

let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconSource = root.appending(path: "Assets/AppIcon.png")
let screenshot = root.appending(path: "docs/screenshot-dark.png")
let output = root.appending(path: "docs/banner.png")
// Scripts/screenshot.sh leaves a 48pt margin around the window for its shadow.
let shadowMargin: CGFloat = 48

extension Color {
  init(hex: UInt32) {
    self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
  }
}

struct Dots: View {
  var body: some View {
    Canvas { context, canvasSize in
      let spacing: CGFloat = 22
      var path = Path()
      for x in stride(from: spacing / 2, to: canvasSize.width, by: spacing) {
        for y in stride(from: spacing / 2, to: canvasSize.height, by: spacing) {
          path.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
        }
      }
      context.fill(path, with: .color(.white.opacity(0.07)))
    }
  }
}

struct Banner: View {
  let icon: NSImage
  let window: NSImage

  var body: some View {
    ZStack(alignment: .topLeading) {
      LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
      Dots()
      RadialGradient(colors: [glow.opacity(0.45), glow.opacity(0)], center: UnitPoint(x: 0.16, y: 0.36), startRadius: 0, endRadius: 420)

      // The screenshot is 2x, so its size in points is half its pixels.
      Image(nsImage: window)
        .resizable()
        .interpolation(.high)
        .frame(width: CGFloat(window.representations[0].pixelsWide) / 2 * windowScale, height: CGFloat(window.representations[0].pixelsHigh) / 2 * windowScale)
        .offset(x: windowOrigin.x - shadowMargin * windowScale, y: windowOrigin.y - shadowMargin * windowScale)

      VStack(alignment: .leading, spacing: 0) {
        // The PNG has Apple's padding around the squircle, so it's drawn larger than it looks.
        Image(nsImage: icon)
          .resizable()
          .interpolation(.high)
          .frame(width: 156, height: 156)
          .padding(-12)
          .shadow(color: .black.opacity(0.3), radius: 18, y: 10)
        Text(name)
          .font(.system(size: 58, weight: .bold))
          .tracking(-1.8)
          .foregroundStyle(.white)
          .padding(.top, 26)
        Text(tagline)
          .font(.system(size: 27, weight: .regular))
          .lineSpacing(4)
          .foregroundStyle(muted)
          .padding(.top, 8)
        HStack(spacing: 10) {
          ForEach(chips, id: \.self) { chip in
            Text(chip)
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(.white.opacity(0.92))
              .padding(.horizontal, 14)
              .padding(.vertical, 7)
              .background(.white.opacity(0.12), in: .capsule)
              .overlay(Capsule().strokeBorder(.white.opacity(0.2)))
          }
        }
        .padding(.top, 26)
      }
      .offset(x: 84, y: 66)
    }
    .frame(width: size.width, height: size.height)
    .clipShape(.rect(cornerRadius: 28))
  }
}

MainActor.assumeIsolated {
  let renderer = ImageRenderer(content: Banner(icon: NSImage(contentsOf: iconSource)!, window: NSImage(contentsOf: screenshot)!))
  renderer.scale = 2
  // ImageRenderer produces 16 bits per channel. Redraw at 8 bits for a small PNG.
  let image = renderer.cgImage!
  let context = CGContext(
    data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  )!
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
  let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
  try! rep.representation(using: .png, properties: [:])!.write(to: output)
  print("Wrote \(output.path)")
}

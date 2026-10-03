#!/usr/bin/env swift
// Renders the Postdeck icon: a deck of cards with a post on the front one and an amber play button,
// baked into a squircle on Apple's macOS icon grid. Writes Assets/AppIcon.png, which Scripts/build-app.sh
// turns into AppIcon.icns, and the Chrome extension's icons in extension/icons.
// Usage: swift Scripts/render-icon.swift

import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

let canvas: CGFloat = 1024
// Apple's macOS icon grid: an 824pt continuous-corner body centered on a 1024pt canvas.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyRadius: CGFloat = 185.4

// The front card, with two cards peeking out above it.
let frontCard = CGRect(x: 206, y: 342, width: 612, height: 432)
let cardRadius: CGFloat = 58
let cardPeek: CGFloat = 46
let cardShrink: CGFloat = 62
let backCardOpacities: [CGFloat] = [0.62, 0.32]

// The post on the front card: an avatar, a name, and three lines of text.
let avatar = CGRect(x: 262, y: 398, width: 96, height: 96)
let nameBar = CGRect(x: 384, y: 418, width: 214, height: 30)
let handleBar = CGRect(x: 384, y: 458, width: 132, height: 22)
let textBars: [CGRect] = [
  CGRect(x: 262, y: 540, width: 500, height: 32),
  CGRect(x: 262, y: 600, width: 500, height: 32),
  CGRect(x: 262, y: 660, width: 300, height: 32)
]

let playCenter = CGPoint(x: 752, y: 742)
let playRadius: CGFloat = 116
let playTriangle: CGFloat = 92

let backgroundTop: UInt32 = 0x5B8CFF
let backgroundBottom: UInt32 = 0x3121C4
let cardColor: UInt32 = 0xFFFFFF
let avatarColor: UInt32 = 0x5B7BFF
let nameColor: UInt32 = 0x2B2F45
let lineColor: UInt32 = 0xC9D1F3
let accentColor: UInt32 = 0xFFC53D
let accentInk: UInt32 = 0x3121C4

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
  CGColor(
    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
    green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255,
    alpha: alpha
  )
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]? = nil) -> CGGradient {
  CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
}

func squircle(_ rect: CGRect, radius: CGFloat) -> CGPath {
  RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect).cgPath
}

func pill(_ rect: CGRect) -> CGPath {
  CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil)
}

func drawCards(_ context: CGContext) {
  for (index, opacity) in backCardOpacities.enumerated().reversed() {
    let step = CGFloat(index + 1)
    let card = frontCard.insetBy(dx: cardShrink * step / 2, dy: 0).offsetBy(dx: 0, dy: -cardPeek * step)
    context.addPath(squircle(card, radius: cardRadius))
    context.setFillColor(rgb(cardColor, opacity))
    context.fillPath()
  }
  context.addPath(squircle(frontCard, radius: cardRadius))
  context.setFillColor(rgb(cardColor))
  context.fillPath()

  context.setFillColor(rgb(avatarColor))
  context.fillEllipse(in: avatar)
  context.addPath(pill(nameBar))
  context.setFillColor(rgb(nameColor))
  context.fillPath()
  context.addPath(pill(handleBar))
  context.setFillColor(rgb(lineColor))
  context.fillPath()
  for bar in textBars {
    context.addPath(pill(bar))
  }
  context.setFillColor(rgb(lineColor))
  context.fillPath()
}

func drawPlayButton(_ context: CGContext) {
  context.setFillColor(rgb(accentColor))
  context.fillEllipse(
    in: CGRect(x: playCenter.x - playRadius, y: playCenter.y - playRadius, width: 2 * playRadius, height: 2 * playRadius)
  )
  // An equilateral triangle, nudged right so it looks centered.
  let height = playTriangle * sqrt(3) / 2
  let left = playCenter.x - height / 3 + 8
  context.move(to: CGPoint(x: left, y: playCenter.y - playTriangle / 2))
  context.addLine(to: CGPoint(x: left + height, y: playCenter.y))
  context.addLine(to: CGPoint(x: left, y: playCenter.y + playTriangle / 2))
  context.closePath()
  context.setFillColor(rgb(accentInk))
  context.setLineJoin(.round)
  context.setLineWidth(18)
  context.setStrokeColor(rgb(accentInk))
  context.drawPath(using: .fillStroke)
}

// The artwork, in 1024pt canvas coordinates with a top-left origin.
func drawArtwork(_ context: CGContext, scale: CGFloat) {
  // Shadows ignore the transform: the offset is in unflipped pixels, so scale it by hand.
  context.saveGState()
  context.setShadow(offset: CGSize(width: 0, height: -16 * scale), blur: 34 * scale, color: rgb(0x14095E, 0.4))
  context.beginTransparencyLayer(auxiliaryInfo: nil)
  drawCards(context)
  context.endTransparencyLayer()
  context.restoreGState()

  context.saveGState()
  context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 24 * scale, color: rgb(0x14095E, 0.45))
  context.beginTransparencyLayer(auxiliaryInfo: nil)
  drawPlayButton(context)
  context.endTransparencyLayer()
  context.restoreGState()
}

func drawIcon(_ context: CGContext, scale: CGFloat) {
  let bodyPath = squircle(body, radius: bodyRadius)

  // Drop shadow under the body, as in Apple's icon template.
  context.saveGState()
  context.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 22 * scale, color: rgb(0x000000, 0.32))
  context.addPath(bodyPath)
  context.setFillColor(rgb(backgroundBottom))
  context.fillPath()
  context.restoreGState()

  context.saveGState()
  context.addPath(bodyPath)
  context.clip()
  context.drawLinearGradient(
    gradient([rgb(backgroundTop), rgb(backgroundBottom)]),
    start: CGPoint(x: 0, y: body.minY),
    end: CGPoint(x: 0, y: body.maxY),
    options: []
  )
  drawArtwork(context, scale: scale)
  context.restoreGState()

  // Hairline highlight along the top edge of the body.
  context.saveGState()
  context.addPath(bodyPath)
  context.setLineWidth(3)
  context.replacePathWithStrokedPath()
  context.clip()
  context.drawLinearGradient(
    gradient([rgb(0xFFFFFF, 0.45), rgb(0xFFFFFF, 0)]),
    start: CGPoint(x: 0, y: body.minY),
    end: CGPoint(x: 0, y: body.midY),
    options: []
  )
  context.restoreGState()
}

func render(pixels: Int) -> CGImage {
  let context = CGContext(
    data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  )!
  let scale = CGFloat(pixels) / canvas
  context.translateBy(x: 0, y: CGFloat(pixels))
  context.scaleBy(x: scale, y: -scale)
  drawIcon(context, scale: scale)
  return context.makeImage()!
}

func write(_ image: CGImage, to path: String) {
  let url = URL(filePath: path)
  try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(path)") }
  print("Wrote \(path)")
}

write(render(pixels: 1024), to: "Assets/AppIcon.png")
for size in [16, 32, 48, 128] {
  write(render(pixels: size), to: "extension/icons/icon\(size).png")
}

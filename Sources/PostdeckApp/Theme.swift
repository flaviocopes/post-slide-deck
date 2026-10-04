import AppKit
import PostdeckCore
import SwiftUI

/// The app's colors, sizes and shared pieces. The brand colors come from the app icon.
enum Brand {
  static let blue = Color(hex: 0x5B8CFF)
  static let indigo = Color(hex: 0x3121C4)
  static let gradient = LinearGradient(colors: [blue, indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
}

enum Surface {
  static let stage = Color(light: 0xF4F5F9, dark: 0x0F1015)
  static let sidebar = Color(light: 0xECEEF5, dark: 0x16171D)
  static let panel = Color(light: 0xFAFAFC, dark: 0x1A1B22)
  static let raised = Color(light: 0xFFFFFF, dark: 0x262731)
  static let hairline = Color.primary.opacity(0.08)
  static let hover = Color.primary.opacity(0.05)
}

enum Typography {
  static let section = Font.system(size: 10, weight: .semibold)
  static let caption = Font.system(size: 11)
  static let captionStrong = Font.system(size: 11, weight: .semibold, design: .rounded)
  static let body = Font.system(size: 13)
  static let bodyStrong = Font.system(size: 13, weight: .medium)
  static let title = Font.system(size: 15, weight: .semibold, design: .rounded)
  static let display = Font.system(size: 17, weight: .semibold, design: .rounded)
}

enum Metrics {
  /// The row the traffic lights sit in, shared by the three columns so their headers line up.
  static let topBar: CGFloat = 52
  static let sidebarWidth: CGFloat = 248
  static let navigatorWidth: CGFloat = 300
}

extension Color {
  init(light: UInt32, dark: UInt32) {
    self.init(
      nsColor: NSColor(name: nil) { appearance in
        let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        return NSColor(
          srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
          green: CGFloat((hex >> 8) & 0xFF) / 255,
          blue: CGFloat(hex & 0xFF) / 255,
          alpha: 1
        )
      }
    )
  }
}

/// An uppercase label above a group, like "SLIDESHOWS".
struct SectionLabel: View {
  let text: String

  var body: some View {
    Text(text.uppercased())
      .font(Typography.section)
      .tracking(0.8)
      .foregroundStyle(.secondary)
  }
}

struct EmptyState: View {
  let symbol: String
  let title: String
  let message: String

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: symbol)
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(.white)
        .frame(width: 52, height: 52)
        .background(Brand.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Brand.indigo.opacity(0.3), radius: 10, y: 4)
      Text(title)
        .font(Typography.display)
      Text(message)
        .font(Typography.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 260)
    }
    .padding(24)
  }
}

/// A faint grid of dots behind the slide preview.
struct DotGrid: View {
  var body: some View {
    Canvas { context, size in
      let spacing: CGFloat = 18
      var path = Path()
      for x in stride(from: spacing / 2, to: size.width, by: spacing) {
        for y in stride(from: spacing / 2, to: size.height, by: spacing) {
          path.addEllipse(in: CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5))
        }
      }
      context.fill(path, with: .color(.primary.opacity(0.08)))
    }
  }
}

/// A plain button that shows a soft background on hover.
struct HoverButtonStyle: ButtonStyle {
  var cornerRadius: CGFloat = 8

  func makeBody(configuration: Configuration) -> some View {
    HoverBody(configuration: configuration, cornerRadius: cornerRadius)
  }

  private struct HoverBody: View {
    let configuration: Configuration
    let cornerRadius: CGFloat
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
      configuration.label
        .background(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(configuration.isPressed ? Surface.hover.opacity(2) : hovering ? Surface.hover : .clear)
        )
        .opacity(isEnabled ? 1 : 0.35)
        .contentShape(Rectangle())
        .onHover { hovering = $0 && isEnabled }
    }
  }
}

/// The gradient Play button.
struct PlayButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    PlayBody(configuration: configuration)
  }

  private struct PlayBody: View {
    let configuration: Configuration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
      configuration.label
        .font(Typography.bodyStrong)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(Brand.gradient, in: Capsule())
        .shadow(color: Brand.indigo.opacity(configuration.isPressed || !isEnabled ? 0.1 : 0.35), radius: 8, y: 3)
        .opacity(isEnabled ? 1 : 0.4)
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
  }
}

/// The slideshow's theme, as a swatch of each background in a capsule: the light ones, then the dark ones.
struct ThemePicker: View {
  let selection: SlideTheme
  let select: @MainActor (SlideTheme) -> Void

  var body: some View {
    HStack(spacing: 2) {
      swatches(SlideTheme.allCases.filter { !$0.isDark })
      Rectangle()
        .fill(Surface.hairline)
        .frame(width: 1, height: 14)
        .padding(.horizontal, 3)
      swatches(SlideTheme.allCases.filter(\.isDark))
    }
    .padding(3)
    .background(Surface.hover, in: Capsule())
  }

  private func swatches(_ themes: [SlideTheme]) -> some View {
    ForEach(themes) { theme in
      Button {
        withAnimation(.easeOut(duration: 0.15)) { select(theme) }
      } label: {
        Circle()
          .fill(theme.background)
          .overlay(Circle().strokeBorder(Color.primary.opacity(theme.isDark ? 0.3 : 0.15), lineWidth: 1))
          .frame(width: 16, height: 16)
          .padding(3)
          .overlay(Circle().strokeBorder(Brand.blue, lineWidth: 2).opacity(theme == selection ? 1 : 0))
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .help("\(theme.title) theme")
      .accessibilityLabel("\(theme.title) theme")
    }
  }
}

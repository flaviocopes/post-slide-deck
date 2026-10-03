import PostdeckCore
import SwiftUI

enum SlideTheme: String, CaseIterable, Identifiable {
  case light, dark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  var background: LinearGradient {
    switch self {
    case .light:
      LinearGradient(colors: [Color(hex: 0xD9E6FB), Color(hex: 0xF2DCEF)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .dark:
      LinearGradient(colors: [Color(hex: 0x0E1A33), Color(hex: 0x2A0F2E)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
  }

  var card: Color {
    switch self {
    case .light: .white
    case .dark: Color(hex: 0x16181C)
    }
  }

  var text: Color {
    switch self {
    case .light: Color(hex: 0x0F1419)
    case .dark: Color(hex: 0xE7E9EA)
    }
  }

  var secondary: Color {
    switch self {
    case .light: Color(hex: 0x536471)
    case .dark: Color(hex: 0x71767B)
    }
  }

  static let blue = Color(hex: 0x1D9BF0)
}

/// One post as a slide. Laid out on a 1920×1080 canvas, then every size is multiplied by `width / 1920`.
struct SlideView: View {
  static let canvas = CGSize(width: 1920, height: 1080)

  let card: Card
  let theme: SlideTheme
  let store: LibraryStore
  let width: CGFloat

  private var unit: CGFloat { width / Self.canvas.width }
  private func scaled(_ value: CGFloat) -> CGFloat { value * unit }

  var body: some View {
    ZStack {
      theme.background
      VStack(alignment: .leading, spacing: scaled(36)) {
        header
        if !card.replyingTo.isEmpty {
          replyLine
        }
        if !card.text.isEmpty {
          Text(attributedText)
            .font(.system(size: scaled(fontSize)))
            .lineSpacing(scaled(fontSize * 0.22))
            .foregroundStyle(theme.text)
            .minimumScaleFactor(0.4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        if !card.media.isEmpty {
          mediaGrid
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        if let postedAt = card.postedAt {
          Text(Self.dateText(postedAt))
            .font(.system(size: scaled(30)))
            .foregroundStyle(theme.secondary)
        }
      }
      .padding(scaled(72))
      .frame(width: scaled(1400))
      .background(theme.card, in: RoundedRectangle(cornerRadius: scaled(44), style: .continuous))
      .shadow(color: .black.opacity(theme == .light ? 0.12 : 0.4), radius: scaled(40), y: scaled(20))
      .frame(maxHeight: scaled(940))
    }
    .frame(width: width, height: width * Self.canvas.height / Self.canvas.width)
    .clipped()
  }

  private var header: some View {
    HStack(spacing: scaled(28)) {
      AvatarImage(media: card.avatar, store: store)
        .frame(width: scaled(112), height: scaled(112))
      VStack(alignment: .leading, spacing: scaled(4)) {
        HStack(spacing: scaled(12)) {
          Text(card.authorName)
            .font(.system(size: scaled(46), weight: .bold))
            .foregroundStyle(theme.text)
          if card.authorVerified {
            Image(systemName: "checkmark.seal.fill")
              .font(.system(size: scaled(38)))
              .foregroundStyle(SlideTheme.blue)
          }
        }
        Text("@\(card.authorHandle)")
          .font(.system(size: scaled(36)))
          .foregroundStyle(theme.secondary)
      }
      .lineLimit(1)
    }
  }

  private var replyLine: some View {
    let handles = card.replyingTo.map { "@\($0)" }.joined(separator: " ")
    return (Text("Replying to ").foregroundStyle(theme.secondary) + Text(handles).foregroundStyle(SlideTheme.blue))
      .font(.system(size: scaled(32)))
      .lineLimit(1)
  }

  @ViewBuilder private var mediaGrid: some View {
    let spacing = scaled(12)
    let tiles = Array(card.media.prefix(4))
    let shape = RoundedRectangle(cornerRadius: scaled(24), style: .continuous)
    if tiles.count == 1 {
      tile(tiles[0], contentMode: .fit)
        .clipShape(shape)
    } else {
      let rows = tiles.count == 2 ? [Array(tiles)] : [Array(tiles.prefix(2)), Array(tiles.dropFirst(2))]
      VStack(spacing: spacing) {
        ForEach(rows.indices, id: \.self) { row in
          HStack(spacing: spacing) {
            ForEach(rows[row], id: \.remoteURL) { media in
              tile(media, contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
            }
          }
        }
      }
      .clipShape(shape)
    }
  }

  private func tile(_ media: Media, contentMode: ContentMode) -> some View {
    CardImage(media: media, store: store, contentMode: contentMode)
      .overlay {
        if media.kind == .video {
          Image(systemName: "play.fill")
            .font(.system(size: scaled(44)))
            .foregroundStyle(.white)
            .frame(width: scaled(110), height: scaled(110))
            .background(SlideTheme.blue, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: scaled(5)))
        }
      }
  }

  /// Shorter posts get bigger text. Posts with images get smaller text, to leave room for them.
  private var fontSize: CGFloat {
    let length = card.text.count + card.text.filter { $0 == "\n" }.count * 30
    let steps: [(Int, CGFloat)] =
      card.media.isEmpty
      ? [(60, 76), (140, 64), (280, 54), (500, 46), (900, 38)]
      : [(80, 50), (160, 44), (280, 38), (600, 32)]
    return steps.first { length <= $0.0 }?.1 ?? (card.media.isEmpty ? 32 : 28)
  }

  private var attributedText: AttributedString {
    var text = AttributedString(card.text)
    for link in card.links {
      var searchStart = text.startIndex
      while let range = text[searchStart...].range(of: link) {
        text[range].foregroundColor = SlideTheme.blue
        searchStart = range.upperBound
      }
    }
    return text
  }

  /// Like X shows it: "7:37 AM · Oct 3, 2026".
  static func dateText(_ date: Date) -> String {
    let time = date.formatted(date: .omitted, time: .shortened)
    let day = date.formatted(.dateTime.month(.abbreviated).day().year())
    return "\(time) · \(day)"
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }
}

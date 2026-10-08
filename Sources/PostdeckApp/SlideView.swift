import PostdeckCore
import SwiftUI

/// The background and colors of each theme.
extension SlideTheme {
  /// A slideshow's theme. Slideshows without one use the Light or Dark switch of Post Slide Deck 1.0.
  init(_ id: String?) {
    self = id.flatMap(Self.init(rawValue:)) ?? (UserDefaults.standard.string(forKey: "slideTheme") == "dark" ? .midnight : .dawn)
  }

  /// The colors in the top leading and bottom trailing corners.
  private var corners: (UInt32, UInt32) {
    switch self {
    case .dawn: (0xD9E6FB, 0xF2DCEF)
    case .mint: (0xD3F0E0, 0xDDEEF8)
    case .peach: (0xFCEBD5, 0xF8D5CB)
    case .midnight: (0x0E1A33, 0x2A0F2E)
    case .ocean: (0x03263A, 0x064047)
    case .graphite: (0x3A3C43, 0x1A1B1F)
    }
  }

  var background: LinearGradient {
    LinearGradient(colors: [Color(hex: corners.0), Color(hex: corners.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
  }

  var card: Color {
    isDark ? Color(hex: 0x16181C) : .white
  }

  var text: Color {
    isDark ? Color(hex: 0xE7E9EA) : Color(hex: 0x0F1419)
  }

  var secondary: Color {
    isDark ? Color(hex: 0x8B98A5) : Color(hex: 0x536471)
  }

  /// So the text fields of a text slide get a cursor and placeholders that show on its background.
  var colorScheme: ColorScheme {
    isDark ? .dark : .light
  }

  static let blue = Color(hex: 0x1D9BF0)
}

/// One slide. Laid out on a 1920×1080 canvas, then every size is multiplied by `width / 1920`.
struct SlideView: View {
  static let canvas = CGSize(width: 1920, height: 1080)

  let slide: Slide
  let theme: SlideTheme
  let store: LibraryStore
  let width: CGFloat
  /// Set in the stage, where you type on a text slide.
  var editText: (@MainActor (TextSlide) -> Void)?
  /// Puts the cursor in the title of a text slide, when it's new.
  var focusesTitle = false

  var body: some View {
    let unit = width / Self.canvas.width
    ZStack {
      theme.background
      switch slide {
      case .post(let card):
        PostSlide(card: card, theme: theme, store: store, unit: unit)
      case .text(let text):
        TextSlideContent(slide: text, theme: theme, unit: unit, edit: editText, focusesTitle: focusesTitle)
      case .image(let image):
        ImageSlideContent(slide: image, theme: theme, store: store, unit: unit)
      }
    }
    .frame(width: width, height: width * Self.canvas.height / Self.canvas.width)
    .clipped()
  }
}

/// A text slide: the title, and the smaller text below it, in the middle of the slide.
/// With `edit` set, the two lines are text fields.
private struct TextSlideContent: View {
  let slide: TextSlide
  let theme: SlideTheme
  let unit: CGFloat
  let edit: (@MainActor (TextSlide) -> Void)?
  let focusesTitle: Bool
  @FocusState private var focus: Field?

  private enum Field {
    case title, subtitle
  }

  var body: some View {
    ZStack {
      if edit != nil {
        // A click on the slide, outside the text, ends editing.
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture { focus = nil }
      }
      fields
    }
    .task {
      if focusesTitle {
        focus = .title
      }
    }
  }

  private var fields: some View {
    VStack(spacing: 40 * unit) {
      if let edit {
        TextField("Title", text: Binding(get: { slide.title }, set: { edit(with(title: $0)) }), axis: .vertical)
          .modifier(TitleStyle(size: titleSize * unit, theme: theme))
          .focused($focus, equals: .title)
          .onSubmit { focus = .subtitle }
        TextField("Smaller text below", text: Binding(get: { slide.subtitle }, set: { edit(with(subtitle: $0)) }), axis: .vertical)
          .modifier(SubtitleStyle(size: subtitleSize * unit, theme: theme))
          .focused($focus, equals: .subtitle)
      } else {
        if !slide.title.isEmpty {
          Text(slide.title)
            .modifier(TitleStyle(size: titleSize * unit, theme: theme))
        }
        if !slide.subtitle.isEmpty {
          Text(slide.subtitle)
            .modifier(SubtitleStyle(size: subtitleSize * unit, theme: theme))
        }
      }
    }
    .textFieldStyle(.plain)
    .multilineTextAlignment(.center)
    .minimumScaleFactor(0.4)
    .frame(maxWidth: 1560 * unit)
    .padding(.vertical, 100 * unit)
    .environment(\.colorScheme, theme.colorScheme)
  }

  private func with(title: String? = nil, subtitle: String? = nil) -> TextSlide {
    var slide = slide
    slide.title = title ?? slide.title
    slide.subtitle = subtitle ?? slide.subtitle
    return slide
  }

  /// Shorter text gets bigger, like posts.
  private var titleSize: CGFloat {
    let length = slide.title.count + slide.title.filter { $0 == "\n" }.count * 20
    let steps: [(Int, CGFloat)] = [(14, 150), (28, 128), (56, 108), (110, 90), (220, 76)]
    return steps.first { length <= $0.0 }?.1 ?? 64
  }

  private var subtitleSize: CGFloat {
    let length = slide.subtitle.count + slide.subtitle.filter { $0 == "\n" }.count * 30
    let steps: [(Int, CGFloat)] = [(50, 60), (120, 54), (260, 46)]
    return steps.first { length <= $0.0 }?.1 ?? 40
  }

  private struct TitleStyle: ViewModifier {
    let size: CGFloat
    let theme: SlideTheme

    func body(content: Content) -> some View {
      content
        .font(.system(size: size, weight: .bold))
        .lineSpacing(size * 0.08)
        .foregroundStyle(theme.text)
    }
  }

  private struct SubtitleStyle: ViewModifier {
    let size: CGFloat
    let theme: SlideTheme

    func body(content: Content) -> some View {
      content
        .font(.system(size: size))
        .lineSpacing(size * 0.2)
        .foregroundStyle(theme.secondary)
    }
  }
}

/// An image slide: the image as large as it fits, with rounded corners and a shadow like a post's card.
private struct ImageSlideContent: View {
  let slide: ImageSlide
  let theme: SlideTheme
  let store: LibraryStore
  let unit: CGFloat

  var body: some View {
    Group {
      if let image = ImageCache.image(at: store.mediaURL(slide.file)) {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .aspectRatio(contentMode: .fit)
          .clipShape(RoundedRectangle(cornerRadius: 28 * unit, style: .continuous))
          .shadow(color: .black.opacity(theme.isDark ? 0.4 : 0.12), radius: 40 * unit, y: 20 * unit)
      } else {
        Label("The image is missing", systemImage: "photo")
          .font(.system(size: 40 * unit))
          .foregroundStyle(theme.secondary)
      }
    }
    .padding(.horizontal, 120 * unit)
    .padding(.vertical, 90 * unit)
  }
}

/// A post, on a card like X shows it.
private struct PostSlide: View {
  let card: Card
  let theme: SlideTheme
  let store: LibraryStore
  let unit: CGFloat

  private func scaled(_ value: CGFloat) -> CGFloat { value * unit }

  var body: some View {
    VStack(alignment: .leading, spacing: scaled(36)) {
      HStack(alignment: .top, spacing: scaled(28)) {
        if (card.part ?? 1) == 1 { header }
        if let part = card.part, let count = card.partCount {
          Spacer(minLength: 0)
          Text("\(part)/\(count)")
            .font(.system(size: scaled(44), weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, scaled(24))
            .padding(.vertical, scaled(12))
            .background(SlideTheme.blue, in: RoundedRectangle(cornerRadius: scaled(20)))
            .accessibilityLabel("Part \(part) of \(count)")
        }
      }
      if (card.part ?? 1) == 1, !card.replyingTo.isEmpty {
        replyLine
      }
      if (card.part ?? 1) > 1 { continuationMark }
      if !card.text.isEmpty {
        Text(attributedText)
          .font(.system(size: scaled(fontSize)))
          .lineSpacing(scaled(fontSize * 0.22))
          .foregroundStyle(theme.text)
          .minimumScaleFactor(0.4)
          .frame(maxWidth: .infinity, alignment: .leading)
          .layoutPriority(1)
      }
      if let part = card.part, let count = card.partCount, part < count {
        continuationMark
      }
      if !card.media.isEmpty {
        mediaGrid
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      }
      if (card.part ?? 1) == 1, let postedAt = card.postedAt {
        Text(Self.dateText(postedAt))
          .font(.system(size: scaled(30)))
          .foregroundStyle(theme.secondary)
      }
    }
    .padding(scaled(72))
    .frame(width: scaled(1400))
    .background(theme.card, in: RoundedRectangle(cornerRadius: scaled(44), style: .continuous))
    .shadow(color: .black.opacity(theme.isDark ? 0.4 : 0.12), radius: scaled(40), y: scaled(20))
    .frame(maxHeight: scaled(940))
  }

  private var continuationMark: some View {
    Text("…")
      .font(.system(size: scaled(46), weight: .bold))
      .foregroundStyle(theme.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
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
    if card.part != nil { return 38 }
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

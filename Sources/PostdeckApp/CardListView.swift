import PostdeckCore
import SwiftUI

/// The slides of the selected slideshow, as small slides you can drag to reorder.
struct Navigator: View {
  @Environment(AppModel.self) private var model
  @AppStorage("slideTheme") private var theme = SlideTheme.light
  @State private var dropTarget: String?
  @FocusState private var focused: Bool

  private static let endOfList = "end"

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        VStack(alignment: .leading, spacing: 1) {
          Text(model.currentDeck?.name ?? "Postdeck")
            .font(Typography.title)
            .lineLimit(1)
          Text(subtitle)
            .font(Typography.caption)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
        Button {
          model.addTextSlide()
        } label: {
          Image(systemName: "text.badge.plus")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
        }
        .buttonStyle(HoverButtonStyle())
        .help("New Text Slide (⌘T)")
      }
      .padding(.leading, 16)
      .padding(.trailing, 12)
      .frame(maxWidth: .infinity, minHeight: Metrics.topBar, alignment: .leading)

      if let deck = model.currentDeck {
        if deck.slides.isEmpty {
          EmptyState(
            symbol: "plus.rectangle.on.rectangle",
            title: "No slides yet",
            message: "Click the slide icon under any post on X, and it lands here, in “\(deck.name)”. Press ⌘T for a slide with your own text."
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          slides(deck.slides)
        }
      } else {
        EmptyState(
          symbol: "play.rectangle",
          title: "No slideshow",
          message: "Create one with the + button, or send a post from X and Postdeck starts one for you."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  private var subtitle: String {
    let count = model.slides.count
    return count == 1 ? "1 slide" : "\(count) slides"
  }

  private func slides(_ slides: [Slide]) -> some View {
    ScrollView {
      VStack(spacing: 4) {
        ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
          ThumbnailRow(slide: slide, number: index + 1, isSelected: slide.id == model.selectedSlideID, theme: theme)
            .overlay(alignment: .top) { dropIndicator(dropTarget == slide.id) }
            .onTapGesture {
              model.selectedSlideID = slide.id
              focused = true
            }
            .draggable(slide.id) {
              SlideView(slide: slide, theme: theme, store: model.store, width: 160)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .dropDestination(for: String.self) { ids, _ in
              guard let id = ids.first else { return false }
              model.moveSlide(id, before: slide.id)
              return true
            } isTargeted: { dropTarget = $0 ? slide.id : (dropTarget == slide.id ? nil : dropTarget) }
            .contextMenu { menu(for: slide) }
        }
        Color.clear
          .frame(height: 40)
          .overlay(alignment: .top) { dropIndicator(dropTarget == Self.endOfList) }
          .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            model.moveSlide(id, before: nil)
            return true
          } isTargeted: { dropTarget = $0 ? Self.endOfList : (dropTarget == Self.endOfList ? nil : dropTarget) }
      }
      .padding(.horizontal, 12)
      .padding(.top, 4)
    }
    .focusable()
    .focusEffectDisabled()
    .focused($focused)
    .onKeyPress(.upArrow) {
      model.showPrevious()
      return .handled
    }
    .onKeyPress(.downArrow) {
      model.showNext()
      return .handled
    }
    .onDeleteCommand {
      if let id = model.selectedSlideID {
        model.deleteSlide(id)
      }
    }
  }

  private func dropIndicator(_ visible: Bool) -> some View {
    Capsule()
      .fill(Brand.blue)
      .frame(height: 3)
      .padding(.leading, 28)
      .offset(y: -3)
      .opacity(visible ? 1 : 0)
  }

  @ViewBuilder private func menu(for slide: Slide) -> some View {
    if let card = slide.post {
      Button("Open on X") {
        NSWorkspace.shared.open(card.url)
      }
    }
    let otherDecks = model.library.decks.filter { $0.id != model.currentDeckID }
    if !otherDecks.isEmpty {
      Menu("Move To") {
        ForEach(otherDecks) { deck in
          Button(deck.name) {
            model.moveSlide(slide.id, to: deck.id)
          }
        }
      }
    }
    Divider()
    Button("Delete", role: .destructive) {
      model.deleteSlide(slide.id)
    }
  }
}

struct ThumbnailRow: View {
  @Environment(AppModel.self) private var model
  let slide: Slide
  let number: Int
  let isSelected: Bool
  let theme: SlideTheme
  @State private var hovering = false

  /// The navigator's width, minus its padding, the number and the selection ring.
  static let slideWidth: CGFloat = 240

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Text("\(number)")
        .font(Typography.captionStrong)
        .monospacedDigit()
        .foregroundStyle(isSelected ? Brand.blue : .secondary)
        .frame(width: 20, alignment: .trailing)
        .padding(.top, 6)
      VStack(alignment: .leading, spacing: 6) {
        SlideView(slide: slide, theme: theme, store: model.store, width: Self.slideWidth)
          .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
          .padding(3)
          .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .strokeBorder(ringColor, lineWidth: isSelected ? 2.5 : 1)
          }
        HStack(spacing: 4) {
          switch slide {
          case .post(let card):
            Text(card.authorName)
              .font(Typography.captionStrong)
            Text("@\(card.authorHandle)")
              .font(Typography.caption)
              .foregroundStyle(.secondary)
            if !card.replyingTo.isEmpty {
              Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .help("A reply to @\(card.replyingTo.joined(separator: ", @"))")
            }
          case .text:
            Text("Text slide")
              .font(Typography.captionStrong)
          }
        }
        .lineLimit(1)
        .padding(.leading, 4)
      }
    }
    .padding(.vertical, 6)
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
  }

  private var ringColor: Color {
    if isSelected { return Brand.blue }
    return hovering ? Color.primary.opacity(0.18) : Surface.hairline
  }
}

/// An avatar or a photo, from the downloaded file when there is one, or from X otherwise.
struct CardImage: View {
  let media: Media?
  let store: LibraryStore
  let contentMode: ContentMode

  var body: some View {
    if let file = media?.file, let image = ImageCache.image(at: store.mediaURL(file)) {
      Image(nsImage: image)
        .resizable()
        .aspectRatio(contentMode: contentMode)
    } else if let url = media?.remoteURL {
      AsyncImage(url: url) { image in
        image
          .resizable()
          .aspectRatio(contentMode: contentMode)
      } placeholder: {
        Color.gray.opacity(0.2)
      }
    } else {
      Color.gray.opacity(0.2)
    }
  }
}

/// A round avatar. The downloaded file is drawn into a circle once, because `clipShape(Circle())` on an
/// image at a fractional size, like a slide scaled to its window, lets a line of the image's top edge show.
struct AvatarImage: View {
  let media: Media?
  let store: LibraryStore

  var body: some View {
    if let file = media?.file, let image = ImageCache.circle(at: store.mediaURL(file)) {
      Image(nsImage: image)
        .resizable()
        .interpolation(.high)
    } else {
      CardImage(media: media, store: store, contentMode: .fill)
        .clipShape(Circle())
    }
  }
}

@MainActor
enum ImageCache {
  private static let cache = NSCache<NSURL, NSImage>()
  private static let circles = NSCache<NSURL, NSImage>()

  static func image(at url: URL) -> NSImage? {
    if let image = cache.object(forKey: url as NSURL) {
      return image
    }
    guard let image = NSImage(contentsOf: url) else { return nil }
    cache.setObject(image, forKey: url as NSURL)
    return image
  }

  /// The image cropped to a centered square, inside a circle, with transparent corners.
  static func circle(at url: URL) -> NSImage? {
    if let image = circles.object(forKey: url as NSURL) {
      return image
    }
    guard let source = image(at: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    let side = min(source.width, source.height)
    guard
      let square = source.cropping(to: CGRect(x: (source.width - side) / 2, y: (source.height - side) / 2, width: side, height: side)),
      let context = CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else { return nil }
    let rect = CGRect(x: 0, y: 0, width: side, height: side)
    context.addEllipse(in: rect)
    context.clip()
    context.interpolationQuality = .high
    context.draw(square, in: rect)
    guard let round = context.makeImage() else { return nil }
    let image = NSImage(cgImage: round, size: NSSize(width: side, height: side))
    circles.setObject(image, forKey: url as NSURL)
    return image
  }
}

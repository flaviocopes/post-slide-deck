import AppKit

extension Card {
  /// Pages are derived from the saved post, so receiving its full text updates every part.
  public var pages: [Card] {
    guard part == nil else { return [self] }
    let font = NSFont.systemFont(ofSize: 38)
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 38 * 0.22
    let textHeight: CGFloat = replyingTo.isEmpty ? 470 : 400
    func fits(_ text: String, height: CGFloat? = nil) -> Bool {
      let bounds = (text as NSString).boundingRect(
        with: NSSize(width: 1256, height: CGFloat.greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: font, .paragraphStyle: paragraph]
      )
      return bounds.height <= (height ?? textHeight)
    }
    guard !fits(text, height: media.isEmpty ? textHeight : 250) else { return [self] }
    var remaining = text[...]
    var chunks: [String] = []
    while !remaining.isEmpty {
      var lower = 1
      var upper = remaining.count
      while lower < upper {
        let middle = (lower + upper + 1) / 2
        if fits(String(remaining.prefix(middle))) { lower = middle } else { upper = middle - 1 }
      }
      var end = remaining.index(remaining.startIndex, offsetBy: lower)
      if end < remaining.endIndex {
        let candidate = remaining[..<end]
        // Prefer a paragraph or line break, then a word boundary, without leaving a nearly empty page.
        let halfway = candidate.index(candidate.startIndex, offsetBy: candidate.count / 2)
        if let boundary = candidate[halfway...].lastIndex(of: "\n") {
          end = remaining.index(after: boundary)
        } else if let boundary = candidate[halfway...].lastIndex(where: { $0.isWhitespace }) {
          end = remaining.index(after: boundary)
        }
      }
      chunks.append(String(remaining[..<end]))
      remaining = remaining[end...]
    }
    if !media.isEmpty { chunks.append("") }
    return chunks.enumerated().map { index, text in
      var page = self
      page.id = index == 0 ? id : "\(id)-part-\(index + 1)"
      page.sourcePostID = id
      page.part = index + 1
      page.partCount = chunks.count
      page.text = text
      page.media = index == chunks.count - 1 ? media : []
      return page
    }
  }
}

extension Slide {
  public var sourceID: String { post?.sourcePostID ?? id }
}

extension Deck {
  public var playbackSlides: [Slide] {
    slides.flatMap { slide in
      if let card = slide.post { card.pages.map(Slide.post) } else { [slide] }
    }
  }

  public func sourceIndex(for playbackID: String) -> Int? {
    guard let sourceID = playbackSlides.first(where: { $0.id == playbackID })?.sourceID else { return nil }
    return slides.firstIndex { $0.id == sourceID }
  }
}

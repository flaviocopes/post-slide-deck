import Foundation

/// Downloads a card's avatar and images, so slides don't depend on X's servers while you record.
public struct MediaDownloader: Sendable {
  public var folder: URL
  public var session: URLSession

  public init(folder: URL, session: URLSession = .shared) {
    self.folder = folder
    self.session = session
  }

  /// Returns the card with the downloaded file names set.
  /// An image that fails to download keeps only its remote URL, and the app loads it from there.
  public func download(_ card: Card) async -> Card {
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let id = card.id
    let avatarURL = card.avatar?.remoteURL
    let mediaURLs = card.media.map(\.remoteURL)

    let files = await withTaskGroup(of: (Int, String?).self, returning: [Int: String].self) { group in
      if let avatarURL {
        group.addTask { (-1, await save(avatarURL, as: "\(id)-avatar")) }
      }
      for (index, url) in mediaURLs.enumerated() {
        group.addTask { (index, await save(url, as: "\(id)-\(index + 1)")) }
      }
      var files = [Int: String]()
      for await (index, file) in group {
        files[index] = file
      }
      return files
    }

    var card = card
    card.avatar?.file = files[-1]
    for index in card.media.indices {
      card.media[index].file = files[index]
    }
    return card
  }

  private func save(_ url: URL, as name: String) async -> String? {
    do {
      let (data, response) = try await session.data(for: URLRequest(url: url, timeoutInterval: 20))
      guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else { return nil }
      let ext =
        switch response.mimeType {
        case "image/png": "png"
        case "image/webp": "webp"
        case "image/gif": "gif"
        default: "jpg"
        }
      let file = "\(name).\(ext)"
      try data.write(to: folder.appending(path: file), options: .atomic)
      return file
    } catch {
      return nil
    }
  }
}

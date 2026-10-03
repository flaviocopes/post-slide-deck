import Foundation

/// Reads and writes `library.json` and the downloaded images, in `~/Library/Application Support/Postdeck`.
/// Set `POSTDECK_HOME` to use another folder.
public struct LibraryStore: Sendable {
  public let folder: URL

  public init(folder: URL = LibraryStore.defaultFolder) {
    self.folder = folder
  }

  public static var defaultFolder: URL {
    if let custom = ProcessInfo.processInfo.environment["POSTDECK_HOME"], !custom.isEmpty {
      return URL(filePath: custom, directoryHint: .isDirectory)
    }
    return URL.applicationSupportDirectory.appending(path: "Postdeck", directoryHint: .isDirectory)
  }

  public var libraryURL: URL {
    folder.appending(path: "library.json")
  }

  public var mediaFolder: URL {
    folder.appending(path: "media", directoryHint: .isDirectory)
  }

  public func mediaURL(_ file: String) -> URL {
    mediaFolder.appending(path: file)
  }

  public func load() throws -> Library {
    guard FileManager.default.fileExists(atPath: libraryURL.path) else { return Library() }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Library.self, from: Data(contentsOf: libraryURL))
  }

  public func save(_ library: Library) throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(library).write(to: libraryURL, options: .atomic)
  }

  /// Deletes the downloaded images no card points to anymore.
  public func removeUnusedMedia(keeping files: Set<String>) {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: mediaFolder.path)) ?? []
    for name in names where !files.contains(name) {
      try? FileManager.default.removeItem(at: mediaURL(name))
    }
  }
}

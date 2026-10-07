import Foundation
import PostdeckCore

extension Commands {
  /// What `postdeck capabilities` prints. Add a changelog entry for every release, newest first.
  static let manifest = Manifest(
    name: "postdeck",
    version: Postdeck.version,
    summary: "Builds slideshows in the Postdeck app from posts on X, text slides and images.",
    capabilities: [
      Manifest.Capability(
        description: "List the slideshows in your library",
        command: "postdeck list --json"
      ),
      Manifest.Capability(
        description: "Create a slideshow and pick a slide theme",
        command: "postdeck create \"This week's apps\" --theme midnight"
      ),
      Manifest.Capability(
        description: "Add a post from X as a slide",
        command: "postdeck add-post \"This week's apps\" post.json"
      ),
      Manifest.Capability(
        description: "Add a title slide with smaller text below it",
        command: "postdeck add-text \"This week's apps\" \"This week's apps\" --subtitle \"Four Mac apps I shipped\""
      ),
      Manifest.Capability(
        description: "Add an image file as a slide",
        command: "postdeck add-image \"This week's apps\" ~/Desktop/screenshot.png"
      ),
      Manifest.Capability(
        description: "Show every slide in a slideshow, numbered",
        command: "postdeck show \"This week's apps\" --json"
      ),
      Manifest.Capability(
        description: "Reorder a slide to another position",
        command: "postdeck move \"This week's apps\" 4 1"
      ),
      Manifest.Capability(
        description: "Open a slideshow in Postdeck at a slide",
        command: "postdeck open \"This week's apps\" 1"
      ),
      Manifest.Capability(
        description: "Change the theme of a slideshow's slides",
        command: "postdeck theme \"This week's apps\" dawn"
      ),
    ],
    changelog: [
      Manifest.Release(
        version: "1.1.0",
        date: "2026-10-07",
        changes: [
          "New postdeck command builds slideshows from posts, text and images, with six themes.",
          "New capabilities command lists tasks, example commands and release history.",
          "Long posts split into linked slides; moving or deleting a part acts on the whole post.",
          "Text and image slides, an Up Next window, and restored Delete and arrow key navigation.",
        ]
      ),
      Manifest.Release(
        version: "1.0.0",
        date: "2026-10-03",
        changes: [
          "First release: Postdeck app and Chrome extension turn X posts into slideshow slides.",
          "Play a slideshow in the app window for screen recording, with keyboard and clicker controls.",
          "The app downloads avatars and images so slides work offline while you record.",
        ]
      ),
    ]
  )

  struct Manifest: Encodable {
    struct Capability: Encodable {
      let description: String
      var command: String? = nil
    }

    struct Release: Encodable {
      let version: String
      let date: String
      let changes: [String]
    }

    let name: String
    let version: String
    let summary: String
    let capabilities: [Capability]
    let changelog: [Release]

    func print(json: Bool) throws {
      if json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        Swift.print(String(decoding: try encoder.encode(self), as: UTF8.self))
        return
      }

      Swift.print("\(name) \(version)\n\(summary)\n\nWhat it can do:")
      for capability in capabilities {
        Swift.print("  \(capability.description)")
        if let command = capability.command { Swift.print("    $ \(command)") }
      }
      Swift.print("\nChanges:")
      for release in changelog {
        Swift.print("  \(release.version) (\(release.date))")
        release.changes.forEach { Swift.print("    - \($0)") }
      }
    }
  }
}

import Foundation
import PostdeckCore

enum Commands {
  static let themes = SlideTheme.allCases.map { "\($0.rawValue) (\($0.isDark ? "dark" : "light"))" }.joined(separator: ", ")

  static let all: [Spec] = [
    Spec(name: "list", usage: "list [--json]", summary: "List the slideshows") { arguments in
      let library = try await App.connect().library()
      if arguments.json {
        try Output.json(library.decks.map { DeckSummary($0, selected: $0.id == library.currentDeckID) })
      } else {
        Output.decks(library)
      }
    },

    Spec(name: "show", usage: "show <slideshow> [--json]", summary: "List the slides of a slideshow, numbered") { arguments in
      let reference = try arguments.require(0, "the slideshow", spec("show"))
      let library = try await App.connect().library()
      let deck = library.decks[try library.deckIndex(matching: reference)]
      if arguments.json {
        var displayed = deck
        displayed.slides = deck.playbackSlides
        try Output.json(displayed)
      } else {
        Output.deck(deck)
      }
    },

    Spec(
      name: "create", usage: "create <name> [--theme <theme>] [--json]", summary: "Create a slideshow", options: ["--theme"],
      details: "It doesn't replace the slideshow open in the app. Themes: \(themes)."
    ) { arguments in
      let name = try arguments.require(0, "the name", spec("create"))
      let reply = try await run(.create(name: name, theme: arguments.value("--theme")), arguments)
      Output.done("Created “\(reply.deck?.name ?? name)”, \(reply.deck?.id.uuidString ?? "").", arguments)
    },

    Spec(name: "rename", usage: "rename <slideshow> <name> [--json]", summary: "Rename a slideshow") { arguments in
      let reference = try arguments.require(0, "the slideshow", spec("rename"))
      let name = try arguments.require(1, "the new name", spec("rename"))
      let reply = try await run(.rename(slideshow: reference, name: name), arguments)
      Output.done("Renamed it “\(reply.deck?.name ?? name)”.", arguments)
    },

    Spec(
      name: "theme", usage: "theme <slideshow> <theme> [--json]", summary: "Set the theme of a slideshow's slides",
      details: "Themes: \(themes)."
    ) { arguments in
      let reference = try arguments.require(0, "the slideshow", spec("theme"))
      let theme = try arguments.require(1, "the theme", spec("theme"))
      let reply = try await run(.setTheme(slideshow: reference, theme: theme), arguments)
      Output.done("“\(reply.deck?.name ?? reference)” uses the \(theme.capitalized) theme.", arguments)
    },

    Spec(name: "delete", usage: "delete <slideshow> [--json]", summary: "Delete a slideshow and its slides") { arguments in
      let reference = try arguments.require(0, "the slideshow", spec("delete"))
      _ = try await run(.delete(slideshow: reference), arguments)
      Output.done("Deleted “\(reference)”.", arguments)
    },

    Spec(
      name: "add-text", usage: "add-text <slideshow> <title> [--subtitle <text>] [--at <position>] [--json]",
      summary: "Add a text slide: a title, and smaller text below it", options: ["--subtitle", "--at"],
      details: "It goes at the end, or at --at, counted from 1. The title can be \"\" when there's a subtitle."
    ) { arguments in
      let reference = try arguments.require(0, "the slideshow", spec("add-text"))
      let title = try arguments.require(1, "the title", spec("add-text"))
      let command = Command.addText(slideshow: reference, title: title, subtitle: arguments.value("--subtitle") ?? "", at: try arguments.number("--at"))
      let reply = try await run(command, arguments)
      Output.done(Output.slideMessage("Added", reply), arguments)
    },

    Spec(
      name: "add-post", usage: "add-post <slideshow> [<file>] [--at <position>] [--json]",
      summary: "Add a post from X, as JSON from a file or stdin", options: ["--at"], details: postFormat
    ) { arguments in
      let reference = try arguments.require(0, "the slideshow", spec("add-post"))
      let data: Data
      if let file = arguments.positional(1) {
        data = try Data(contentsOf: URL(filePath: file))
      } else {
        guard isatty(STDIN_FILENO) == 0 else { throw CLIError("Pass the post as a JSON file, or pipe it in. Run 'postdeck help add-post' for the format.") }
        data = FileHandle.standardInput.readDataToEndOfFile()
      }
      let command = Command.addPost(slideshow: reference, post: try PostPayload.decode(data), at: try arguments.number("--at"))
      let reply = try await run(command, arguments)
      Output.done(Output.slideMessage("Added", reply), arguments)
    },

    Spec(
      name: "add-image", usage: "add-image <slideshow> <file> [--at <position>] [--json]",
      summary: "Add an image as a slide, like a screenshot", options: ["--at"],
      details: "It goes at the end, or at --at, counted from 1. Post Slide Deck copies the file, shows it as large as it fits on the theme's background, and keeps it when the original goes away. PNG, JPEG, HEIC, GIF and WebP work."
    ) { arguments in
      let reference = try arguments.require(0, "the slideshow", spec("add-image"))
      let file = try arguments.require(1, "the image file", spec("add-image"))
      let command = Command.addImage(slideshow: reference, path: URL(filePath: file).standardizedFileURL.path, at: try arguments.number("--at"))
      let reply = try await run(command, arguments)
      Output.done(Output.slideMessage("Added", reply), arguments)
    },

    Spec(
      name: "edit", usage: "edit <slideshow> <slide> [--title <text>] [--subtitle <text>] [--json]",
      summary: "Change the text of a text slide", options: ["--title", "--subtitle"],
      details: "Posts and images can't be edited. Pass --subtitle \"\" to remove the smaller text."
    ) { arguments in
      let reference = try arguments.require(0, "the slideshow", spec("edit"))
      let slide = try arguments.require(1, "the slide", spec("edit"))
      let command = Command.edit(slideshow: reference, slide: slide, title: arguments.value("--title"), subtitle: arguments.value("--subtitle"))
      let reply = try await run(command, arguments)
      Output.done(Output.slideMessage("Edited", reply), arguments)
    },

    Spec(name: "move", usage: "move <slideshow> <slide> <position> [--json]", summary: "Move a slide to another position", details: "Linked parts of a long post move together.") { arguments in
      let reference = try arguments.require(0, "the slideshow", spec("move"))
      let slide = try arguments.require(1, "the slide", spec("move"))
      let text = try arguments.require(2, "the position", spec("move"))
      guard let position = Int(text) else { throw CLIError("The position is a number, not “\(text)”.") }
      let reply = try await run(.move(slideshow: reference, slide: slide, to: position), arguments)
      Output.done(Output.slideMessage("Moved", reply), arguments)
    },

    Spec(name: "remove", usage: "remove <slideshow> <slide> [--json]", summary: "Remove a slide", details: "Removing any linked part removes the whole post.") { arguments in
      let reference = try arguments.require(0, "the slideshow", spec("remove"))
      let slide = try arguments.require(1, "the slide", spec("remove"))
      let reply = try await run(.remove(slideshow: reference, slide: slide), arguments)
      let count = reply.deck?.playbackSlides.count ?? 0
      Output.done("Removed it. “\(reply.deck?.name ?? reference)” has \(count == 1 ? "1 slide" : "\(count) slides").", arguments)
    },

    Spec(
      name: "open", usage: "open <slideshow> [<slide>] [--json]", summary: "Show a slideshow in Post Slide Deck, at a slide",
      details: "Selects the slideshow, so posts sent from X go there too, and brings Post Slide Deck to the front."
    ) { arguments in
      let reference = try arguments.require(0, "the slideshow", spec("open"))
      let reply = try await run(.open(slideshow: reference, slide: arguments.positional(1)), arguments)
      App.open(["-b", App.bundleID])
      Output.done(Output.slideMessage("Opened", reply), arguments)
    },
  ]

  static func spec(_ name: String) -> Spec {
    all.first { $0.name == name }!
  }

  /// Runs a command in the app, and prints its reply as JSON with --json.
  static func run(_ command: Command, _ arguments: Arguments) async throws -> CommandReply {
    let reply = try await App.connect().run(command)
    if arguments.json {
      var displayed = reply
      displayed.deck?.slides = reply.deck?.playbackSlides ?? []
      try Output.json(displayed)
    }
    return reply
  }

  static let postFormat = """
    It goes at the end, or at --at, counted from 1. The post is the JSON the Chrome extension sends:

      {
        "id": "2106174390564159515",
        "author": {
          "name": "flavio",
          "handle": "flaviocopes",
          "verified": true,
          "avatarURL": "https://pbs.twimg.com/profile_images/1084880084090146819/uFLTp7C1_400x400.jpg"
        },
        "text": "Releases: my free, open source Mac app that tracks every app I ship flaviocopes.com/releases/",
        "links": ["flaviocopes.com/releases/"],
        "replyingTo": [],
        "media": [{ "kind": "photo", "url": "https://pbs.twimg.com/media/G2GOz3tXEAAnmDl.jpg" }]
      }

    id, author.name, author.handle, and text or media are needed. links are the parts of the text
    shown in blue, like X shows links and mentions. media has up to 4 images on pbs.twimg.com, with
    "kind": "photo" or "video" for a video's thumbnail. Post Slide Deck downloads them and the avatar.
    postedAt is milliseconds since 1970; without it, the date comes from the post ID.
    A slideshow has each post once: adding it again only replaces a shorter text.
    Long posts split into linked pages marked 1/3, 2/3 and so on. Slide numbers match the app.
    Moving or removing any part acts on the whole post. Inserting at a part goes before the post.
    """
}

/// A slideshow as `list --json` prints it.
struct DeckSummary: Encodable {
  var id: UUID
  var name: String
  var theme: String?
  var slides: Int
  /// The slideshow open in the app, where posts sent from X go.
  var selected: Bool

  init(_ deck: Deck, selected: Bool) {
    id = deck.id
    name = deck.name
    theme = deck.theme
    slides = deck.playbackSlides.count
    self.selected = selected
  }
}

enum Output {
  static func json(_ value: some Encodable) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    print(String(decoding: try encoder.encode(value), as: UTF8.self))
  }

  /// Prints what a command did, unless it printed JSON.
  static func done(_ message: String, _ arguments: Arguments) {
    if !arguments.json {
      print(message)
    }
  }

  static func decks(_ library: Library) {
    guard !library.decks.isEmpty else {
      print("No slideshows yet. Create one with: postdeck create <name>")
      return
    }
    let width = library.decks.map(\.name.count).max() ?? 0
    for deck in library.decks {
      let marker = deck.id == library.currentDeckID ? "*" : " "
      let count = deck.playbackSlides.count == 1 ? "1 slide " : "\(deck.playbackSlides.count) slides"
      let name = deck.name.padding(toLength: width, withPad: " ", startingAt: 0)
      let theme = (deck.theme ?? "default").padding(toLength: 8, withPad: " ", startingAt: 0)
      print("\(marker) \(name)  \(count.leftPadded(9))  \(theme)  \(deck.id.uuidString)")
    }
    print()
    print("* is the slideshow open in Post Slide Deck, where posts sent from X go.")
  }

  static func deck(_ deck: Deck) {
    let count = deck.playbackSlides.count == 1 ? "1 slide" : "\(deck.playbackSlides.count) slides"
    print("\(deck.name), \(count), \(deck.theme ?? "default") theme, \(deck.id.uuidString)")
    for (index, slide) in deck.playbackSlides.enumerated() {
      print(line(slide, number: index + 1, width: String(deck.playbackSlides.count).count))
    }
  }

  /// "  3  text  This week's apps · Four Mac apps I shipped  6F0E2C7A-…"
  static func line(_ slide: Slide, number: Int, width: Int) -> String {
    let summary: String
    let kind: String
    switch slide {
    case .post(let card):
      kind = "post"
      summary = "@\(card.authorHandle): \(card.text.isEmpty ? "(\(card.media.count) images)" : card.text)"
    case .text(let text):
      kind = "text"
      summary = [text.title, text.subtitle].filter { !$0.isEmpty }.joined(separator: " · ")
    case .image(let image):
      kind = "image"
      summary = image.file
    }
    let oneLine = summary.split(whereSeparator: \.isNewline).joined(separator: " ")
    let short = oneLine.count > 70 ? oneLine.prefix(69) + "…" : oneLine
    return "  \(String(number).leftPadded(width))  \(kind)  \(short)  \(slide.id)"
  }

  /// "Added slide 3 to “Releases video”:", then the slide.
  static func slideMessage(_ verb: String, _ reply: CommandReply) -> String {
    guard let deck = reply.deck, let index = deck.playbackSlides.firstIndex(where: { $0.id == reply.slide }) else {
      return "\(verb) it."
    }
    let what =
      switch verb {
      case "Added": "slide \(index + 1) to"
      case "Moved": "it to slide \(index + 1) of"
      default: "slide \(index + 1) of"
      }
    return "\(verb) \(what) “\(deck.name)”:\n" + line(deck.playbackSlides[index], number: index + 1, width: 1)
  }
}

extension String {
  func leftPadded(_ width: Int) -> String {
    count >= width ? self : String(repeating: " ", count: width - count) + self
  }
}

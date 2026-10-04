import Foundation
import PostdeckCore

@main
enum PostdeckCommand {
  static func main() async {
    var arguments = Array(CommandLine.arguments.dropFirst())
    guard let name = arguments.first else {
      printHelp()
      return
    }
    arguments.removeFirst()

    switch name {
    case "help", "--help", "-h":
      if let command = arguments.first {
        guard let spec = Commands.all.first(where: { $0.name == command }) else {
          fail("There's no '\(command)' command. Run 'postdeck help' to see them.")
        }
        printHelp(spec)
      } else {
        printHelp()
      }
    case "version", "--version":
      print(Postdeck.version)
    default:
      guard let spec = Commands.all.first(where: { $0.name == name }) else {
        fail("There's no '\(name)' command. Run 'postdeck help' to see them.")
      }
      if arguments.contains("--help") {
        printHelp(spec)
        return
      }
      do {
        try await spec.run(Arguments.parse(arguments, for: spec))
      } catch {
        fail(error.localizedDescription)
      }
    }
  }

  static func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("postdeck: \(message)\n".utf8))
    exit(1)
  }

  static func printHelp() {
    print("postdeck \(Postdeck.version): builds slideshows in the Postdeck app, with posts from X and text slides.")
    print()
    print("Usage: postdeck <command> [options]")
    print()
    let width = Commands.all.map(\.name.count).max() ?? 0
    for spec in Commands.all {
      print("  \(spec.name.padding(toLength: width, withPad: " ", startingAt: 0))  \(spec.summary)")
    }
    print()
    print("""
      A slideshow is named by its name or ID, a slide by its number, from 1, or its ID. Numbers change
      when slides move, IDs don't. Postdeck needs to be running, and the command opens it when it isn't.
      Run 'postdeck help <command>' for its options.
      """)
  }

  static func printHelp(_ spec: Spec) {
    print(spec.summary + ".")
    print()
    print("Usage: postdeck \(spec.usage)")
    if let details = spec.details {
      print()
      print(details)
    }
  }
}

struct CLIError: LocalizedError {
  var message: String

  init(_ message: String) {
    self.message = message
  }

  var errorDescription: String? { message }
}

/// A command: its name, how to call it, and the options that take a value.
struct Spec: Sendable {
  var name: String
  var usage: String
  var summary: String
  var options: [String] = []
  var details: String? = nil
  var run: @Sendable (Arguments) async throws -> Void
}

struct Arguments: Sendable {
  var positionals: [String] = []
  var values: [String: String] = [:]
  var json = false

  func value(_ name: String) -> String? { values[name] }

  func positional(_ index: Int) -> String? {
    positionals.indices.contains(index) ? positionals[index] : nil
  }

  func require(_ index: Int, _ name: String, _ spec: Spec) throws -> String {
    guard let value = positional(index) else { throw CLIError("Missing \(name). Usage: postdeck \(spec.usage)") }
    return value
  }

  func number(_ name: String) throws -> Int? {
    guard let text = values[name] else { return nil }
    guard let number = Int(text) else { throw CLIError("\(name) takes a number, not “\(text)”.") }
    return number
  }

  static func parse(_ arguments: [String], for spec: Spec) throws -> Arguments {
    var parsed = Arguments()
    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      index += 1
      guard argument.hasPrefix("--"), argument.count > 2 else {
        parsed.positionals.append(argument)
        continue
      }
      var name = argument
      var value: String?
      if let equals = argument.firstIndex(of: "=") {
        name = String(argument[..<equals])
        value = String(argument[argument.index(after: equals)...])
      }
      if name == "--json" {
        parsed.json = true
        continue
      }
      guard spec.options.contains(name) else {
        throw CLIError("'\(spec.name)' has no \(name) option. Usage: postdeck \(spec.usage)")
      }
      if value == nil {
        guard index < arguments.count else { throw CLIError("\(name) needs a value.") }
        value = arguments[index]
        index += 1
      }
      parsed.values[name] = value
    }
    return parsed
  }
}

/// The running app. When it isn't running, opens it in the background and waits for its server.
enum App {
  static let bundleID = "com.flaviocopes.postdeck"

  static var port: UInt16 {
    ProcessInfo.processInfo.environment["POSTDECK_PORT"].flatMap(UInt16.init).flatMap { $0 == 0 ? nil : $0 } ?? Postdeck.port
  }

  static func connect() async throws -> AppClient {
    let client = AppClient(port: port)
    if (try? await client.status()) != nil {
      return client
    }
    guard open(["-g", "-b", bundleID]) else {
      throw CLIError("Postdeck isn't running, and macOS couldn't open it. Is it installed?")
    }
    for _ in 0..<60 {
      try await Task.sleep(for: .milliseconds(250))
      if (try? await client.status()) != nil {
        return client
      }
    }
    throw CLIError("Postdeck isn't answering on port \(port). Open it and check the status at the bottom of its sidebar.")
  }

  @discardableResult
  static func open(_ arguments: [String]) -> Bool {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/open")
    process.arguments = arguments
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return false }
    process.waitUntilExit()
    return process.terminationStatus == 0
  }
}

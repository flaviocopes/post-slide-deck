public enum Postdeck {
  public static let version = "1.1.0"

  /// The extension posts to this port, so changing it means changing `extension/background.js` too.
  public static let port: UInt16 = 7678
}

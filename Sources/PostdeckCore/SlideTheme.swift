/// The themes a slideshow can have: three light ones, then three dark ones. The app draws them.
public enum SlideTheme: String, CaseIterable, Identifiable, Sendable {
  case dawn, mint, peach, midnight, ocean, graphite

  public var id: String { rawValue }

  public var title: String { rawValue.capitalized }

  public var isDark: Bool {
    switch self {
    case .dawn, .mint, .peach: false
    case .midnight, .ocean, .graphite: true
    }
  }
}

import Foundation

/// Image URLs on X's CDN, in the largest size that looks good on a slide.
public enum TwitterImage {
  /// The large version of an image on `pbs.twimg.com`, or nil for any other host.
  /// Avatars become 400×400, photos and video thumbnails become `format=jpg&name=large`.
  public static func large(_ url: URL) -> URL? {
    guard url.scheme == "https", url.host() == "pbs.twimg.com",
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return nil }
    if components.path.hasPrefix("/profile_images/") {
      components.path = components.path.replacing(
        #/_(normal|bigger|mini|x96|reasonably_small|200x200)(?=\.\w+$|$)/#,
        with: "_400x400"
      )
      components.query = nil
    } else {
      components.queryItems = [
        URLQueryItem(name: "format", value: "jpg"),
        URLQueryItem(name: "name", value: "large")
      ]
    }
    return components.url
  }
}

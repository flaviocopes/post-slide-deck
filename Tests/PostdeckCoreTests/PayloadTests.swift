import Foundation
import Testing

@testable import PostdeckCore

struct PayloadTests {
  let json = """
    {
      "id": "2106174390564159515",
      "author": {
        "name": "flavio",
        "handle": "flaviocopes",
        "avatarURL": "https://pbs.twimg.com/profile_images/1084880084090146819/uFLTp7C1_normal.jpg",
        "verified": true
      },
      "text": "Releases: my free, open source Mac app that tracks every app I ship flaviocopes.com/releases/",
      "links": ["flaviocopes.com/releases/"],
      "postedAt": 1759457280000,
      "replyingTo": [],
      "media": [
        {
          "kind": "video",
          "url": "https://pbs.twimg.com/amplify_video_thumb/2105992733001211905/img/Jkshc7k5o5kefoI4?format=webp&name=medium"
        }
      ]
    }
    """

  @Test func decodesWhatTheExtensionSends() throws {
    let card = try PostPayload.decode(Data(json.utf8)).card()
    #expect(card.id == "2106174390564159515")
    #expect(card.url.absoluteString == "https://x.com/flaviocopes/status/2106174390564159515")
    #expect(card.authorName == "flavio")
    #expect(card.authorVerified)
    #expect(card.links == ["flaviocopes.com/releases/"])
    #expect(card.postedAt == Date(timeIntervalSince1970: 1_759_457_280))

    var withoutDate = try PostPayload.decode(Data(json.utf8))
    withoutDate.postedAt = nil
    #expect(try withoutDate.card().postedAt == Date(timeIntervalSince1970: 1_790_986_080.195))
    #expect(
      card.avatar?.remoteURL.absoluteString
        == "https://pbs.twimg.com/profile_images/1084880084090146819/uFLTp7C1_400x400.jpg"
    )
    #expect(card.media.count == 1)
    #expect(card.media[0].kind == .video)
    #expect(
      card.media[0].remoteURL.absoluteString
        == "https://pbs.twimg.com/amplify_video_thumb/2105992733001211905/img/Jkshc7k5o5kefoI4?format=jpg&name=large"
    )
  }

  @Test func rejectsInvalidPosts() {
    let author = PostPayload.Author(name: "flavio", handle: "flaviocopes")
    #expect(throws: PayloadError.self) {
      try PostPayload(id: "abc", author: author, text: "Hello").card()
    }
    #expect(throws: PayloadError.self) {
      try PostPayload(id: "123", author: .init(name: "x", handle: "../etc"), text: "Hello").card()
    }
    #expect(throws: PayloadError.self) {
      try PostPayload(id: "123", author: author, text: "   ").card()
    }
    #expect(throws: PayloadError.self) {
      try PostPayload.decode(Data("not json".utf8))
    }
  }

  @Test func keepsOnlyImagesFromX() throws {
    let payload = PostPayload(
      id: "123",
      author: .init(name: "flavio", handle: "flaviocopes", avatarURL: URL(string: "https://flaviocopes.com/me.jpg")),
      text: "Two photos",
      media: [
        .init(kind: .photo, url: URL(string: "https://pbs.twimg.com/media/GxYz123?format=webp&name=small")!),
        .init(kind: .photo, url: URL(string: "https://flaviocopes.com/photo.jpg")!),
        .init(kind: .photo, url: URL(string: "http://pbs.twimg.com/media/GxYz456?format=jpg")!)
      ]
    )
    let card = try payload.card()
    #expect(card.avatar == nil)
    #expect(card.media.map(\.remoteURL.absoluteString) == ["https://pbs.twimg.com/media/GxYz123?format=jpg&name=large"])
  }

  @Test func cleansUpRepliesAndLinks() throws {
    let payload = PostPayload(
      id: "2106200000000000000",
      author: .init(name: "  ", handle: "maxfaber_Om"),
      text: "How on earth do you release new app every single day?",
      links: ["flaviocopes.com", ""],
      replyingTo: ["flaviocopes", "flaviocopes", "maxfaber_Om", "not a handle"]
    )
    let card = try payload.card()
    #expect(card.authorName == "maxfaber_Om")
    #expect(card.replyingTo == ["flaviocopes"])
    #expect(card.links.isEmpty)
  }

  @Test func upscalesAvatars() {
    let sizes = ["normal", "bigger", "mini", "x96", "reasonably_small", "200x200", "400x400"]
    for size in sizes {
      let url = URL(string: "https://pbs.twimg.com/profile_images/1084880084090146819/uFLTp7C1_\(size).jpg")!
      #expect(
        TwitterImage.large(url)?.absoluteString
          == "https://pbs.twimg.com/profile_images/1084880084090146819/uFLTp7C1_400x400.jpg"
      )
    }
  }
}

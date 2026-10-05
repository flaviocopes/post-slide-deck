import Foundation
import PostdeckCore
import Testing
@testable import PostdeckCLI

struct CapabilitiesTests {
  @Test
  func manifestEncodesExpectedKeys() throws {
    let data = try JSONEncoder().encode(Commands.manifest)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["name"] as? String == "postdeck")
    #expect(object["version"] as? String == Postdeck.version)
    #expect(object["summary"] as? String != nil)
    #expect((object["capabilities"] as? [[String: Any]])?.isEmpty == false)
    #expect((object["changelog"] as? [[String: Any]])?.isEmpty == false)
  }
}

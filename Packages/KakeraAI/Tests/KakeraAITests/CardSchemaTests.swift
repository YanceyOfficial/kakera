import Foundation
import Testing
@testable import KakeraAI

@Test("Card schema encodes as a JSON-Schema object with a cards array and no additional properties")
func cardSchemaShape() throws {
    let data = try JSONEncoder().encode(CardSchema.cardBatch)
    let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(obj["type"] as? String == "object")
    #expect(obj["additionalProperties"] as? Bool == false)
    let props = obj["properties"] as! [String: Any]
    let cards = props["cards"] as! [String: Any]
    #expect(cards["type"] as? String == "array")
    let required = obj["required"] as! [String]
    #expect(required.contains("cards"))
}

@Test("Card schema asks for an unrecognized list beside the cards: input, reason and suggestions")
func cardSchemaUnrecognized() throws {
    let data = try JSONEncoder().encode(CardSchema.cardBatch)
    let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let required = obj["required"] as! [String]
    #expect(required.contains("unrecognized"))
    let props = obj["properties"] as! [String: Any]
    let unrecognized = props["unrecognized"] as! [String: Any]
    #expect(unrecognized["type"] as? String == "array")
    let item = unrecognized["items"] as! [String: Any]
    let itemProps = item["properties"] as! [String: Any]
    #expect((itemProps["input"] as? [String: Any])?["type"] as? String == "string")
    #expect((itemProps["reason"] as? [String: Any])?["type"] as? String == "string")
    #expect((itemProps["suggestions"] as? [String: Any])?["type"] as? String == "array")
    #expect((item["required"] as? [String]) == ["input", "reason", "suggestions"])
}

import XCTest
import Foundation

extension JSONEncoder {
    /// Inefficiently regain the ability to obtain the intermediate dictionary
    /// representation of an encodable object from `JSONEncoder` by doing a
    /// full encode and then deserializing the result again. Very slow.
    func serialize<T: Encodable>(_ input: T, options: JSONSerialization.ReadingOptions = []) throws -> [String: Any] {
        let encodedData = try self.encode(input)
        let rawResult = try JSONSerialization.jsonObject(with: encodedData, options: options)
        
        guard let result = rawResult as? [String: Any] else {
            throw DecodingError.typeMismatch([String: Any].self, .init(
                codingPath: [],
                debugDescription: "JSON deserialization from an encoded value produced \(type(of: rawResult)) instead of [String: Any]."
            ))
        }
        return result
    }
}

extension JSONDecoder {
    /// Inefficiently regain the ability to load the intermediate dictionary
    /// representation of a decodable object with `JSONDecoder` by doing a
    /// full serialization and then decoding the result. Very slow.
    func deserialize<T: Decodable>(_ type: T.Type = T.self, from input: [String: Any], options: JSONSerialization.WritingOptions = []) throws -> T {
        return try self.decode(T.self, from: JSONSerialization.data(withJSONObject: input, options: options))
    }
}

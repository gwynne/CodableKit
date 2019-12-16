import XCTest
import Foundation
@testable import CodableKit

struct WeirdTestData: Codable, Equatable {
    enum WeirdType<A: Codable & Equatable>: Codable, Equatable {
        case inner
        case belter(A)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self = .belter(try container.decode(A.self))
        }
        
        func encode(to encoder: Encoder) throws {
            guard case let .belter(value) = self else { return }
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
        
        static func == (lhs: WeirdType, rhs: WeirdType) -> Bool {
            switch (lhs, rhs) {
                case (.inner, .inner): return true
                case (.belter(let lhsValue), .belter(let rhsValue)) where lhsValue == rhsValue: return true
                default: return false
            }
        }
    }
    
    private enum CodingKeys: CodingKey { case id, weirdness }
    
    let id: UUID
    let weirdness: WeirdType<Date?>
    
    init(id: UUID = .init(), weirdness: WeirdType<Date?>) {
        self.id = id
        self.weirdness = weirdness
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(UUID.self, forKey: .id)
        if container.contains(.weirdness) {
            self.weirdness = try container.decodeIfPresent(WeirdType<Date?>.self, forKey: .weirdness) ?? .belter(nil)
        } else {
            self.weirdness = .inner
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.id, forKey: .id)
        if case .belter(let value) = self.weirdness {
            try container.encode(value, forKey: .weirdness)
        }
    }
}

/// https://bugs.swift.org/browse/SR-6025
/// https://forums.swift.org/t/casting-from-any-to-optional/21883
func XCTOptionalDowncast<T, U>(
    _ expression: @autoclosure () throws -> T,
    as type: U.Type = U.self,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file,
    line: UInt = #line
) throws -> U {
    return try XCTUnwrap(expression() as? U, message(), file: file, line: line)
}

final class EncodingTests: XCTestCase {

    func testEncodingURLToSimpleString() throws {
        struct TestData: Codable {
            let url: URL
            let urls: [URL]
        }
        let input = TestData(url: URL(string: "http://localhost:8080")!, urls: [
            URL(string: "http://localhost:8081")!, URL(string: "http://localhost:8082")!
        ])
        let result = try XCTUnwrap(KVHashEncoder.encode(input))
        
        XCTAssertEqual(result["url"] as? String, "http://localhost:8080")
        XCTAssertEqual((result["urls"] as? [String])?.count, 2)
        XCTAssertEqual((result["urls"] as? [String])?.first, "http://localhost:8081")
        XCTAssertEqual((result["urls"] as? [String])?.dropFirst().first, "http://localhost:8082")
    }
    
    func testEncodingWrappedNilValue() throws {
        
        let test1 = WeirdTestData(weirdness: .inner)
        let test2 = WeirdTestData(weirdness: .belter(Date()))
        let test3 = WeirdTestData(weirdness: .belter(nil))

        let test1JsonEncoded = try XCTUnwrap(JSONEncoder().serialize(test1))
        let test2JsonEncoded = try XCTUnwrap(JSONEncoder().serialize(test2))
        let test3JsonEncoded = try XCTUnwrap(JSONEncoder().serialize(test3))

        let test1Encoded = try XCTUnwrap(KVHashEncoder.encode(test1))
        let test2Encoded = try XCTUnwrap(KVHashEncoder.encode(test2))
        let test3Encoded = try XCTUnwrap(KVHashEncoder.encode(test3))
        
        print(test1Encoded)
        print(test1JsonEncoded)
        print(test2Encoded)
        print(test2JsonEncoded)
        print(test3Encoded)
        print(test3JsonEncoded)

        XCTAssertEqual(test1Encoded["id"] as? String, test1.id.uuidString)
        XCTAssertEqual(test2Encoded["id"] as? String, test2.id.uuidString)
        XCTAssertEqual(test3Encoded["id"] as? String, test3.id.uuidString)
        
        XCTAssertNil(test1Encoded["weirdness"])
        
        let test2Weirdness: Any = try XCTUnwrap(test2Encoded["weirdness"])
        let test2WeirdnessTyped: Double? = try XCTOptionalDowncast(test2Weirdness, "Original is \(String(describing: test2Weirdness))")
        let test2WeirdnessUnwrapped: Double = try XCTUnwrap(test2WeirdnessTyped)
        XCTAssertEqual(.belter(.init(timeIntervalSinceReferenceDate: test2WeirdnessUnwrapped)), test2.weirdness)
        
        let test3Weirdness: Any = try XCTUnwrap(test3Encoded["weirdness"])
        let test3WeirdnessTyped: NSNull = try XCTOptionalDowncast(test3Weirdness, "Original is \(String(describing: test3Weirdness))")
        XCTAssertEqual(test3WeirdnessTyped, NSNull()) // yes, the assertion is redundant
        
        let test1Decoded = try XCTUnwrap(KVHashDecoder.decode(WeirdTestData.self, from: test1Encoded))
        let test2Decoded = try XCTUnwrap(KVHashDecoder.decode(WeirdTestData.self, from: test2Encoded))
        let test3Decoded = try XCTUnwrap(KVHashDecoder.decode(WeirdTestData.self, from: test3Encoded))
        
        let test1JsonDecoded = try XCTUnwrap(JSONDecoder().deserialize(WeirdTestData.self, from: test1JsonEncoded))
        let test2JsonDecoded = try XCTUnwrap(JSONDecoder().deserialize(WeirdTestData.self, from: test2JsonEncoded))
        let test3JsonDecoded = try XCTUnwrap(JSONDecoder().deserialize(WeirdTestData.self, from: test3JsonEncoded))

        XCTAssertEqual(test1, test1Decoded)
        XCTAssertEqual(test2, test2Decoded)
        XCTAssertEqual(test3, test3Decoded)
        
        XCTAssertEqual(test1Decoded, test1JsonDecoded)
        XCTAssertEqual(test2Decoded, test2JsonDecoded)
        XCTAssertEqual(test3Decoded, test3JsonDecoded)
    }

}

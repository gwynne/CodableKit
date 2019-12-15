import XCTest
import Foundation
@testable import CodableKit

final class DecodingTests: XCTestCase {

    func testDecodingArbitrayValueTypesKeyed() throws {
        struct TestData: Codable {
            let date: Date?
        }
        let input = ["date": Date().timeIntervalSinceReferenceDate]
        let result = try XCTUnwrap(KVHashDecoder.decode(TestData.self, from: input))
        
        XCTAssertEqual(result.date?.timeIntervalSinceReferenceDate, input["date"])
    }

    func testDecodingArbitrayValueTypesUnkeyed() throws {
        struct TestData: Codable {
            let dates: [Date?]
        }
        let input = ["dates": [Date().timeIntervalSinceReferenceDate]]
        let result = try XCTUnwrap(KVHashDecoder.decode(TestData.self, from: input))
        
        XCTAssertEqual(result.dates.first.flatMap { $0?.timeIntervalSinceReferenceDate }, input["dates"]?[0])
    }
    
    func testDecodingURLFromSimpleString() throws {
        struct TestData: Codable {
            let url: URL
            let urls: [URL]
        }
        let input: [String: Any] = ["url": "http://localhost:8080", "urls": ["http://localhost:8081", "http://localhost:8082"]]
        let result = try XCTUnwrap(KVHashDecoder.decode(TestData.self, from: input))
        
        XCTAssertEqual(result.url, URL(string: "http://localhost:8080"))
        XCTAssertEqual(result.urls.count, 2)
        XCTAssertEqual(result.urls.first, URL(string: "http://localhost:8081"))
        XCTAssertEqual(result.urls.dropFirst().first, URL(string: "http://localhost:8082"))
    }
}

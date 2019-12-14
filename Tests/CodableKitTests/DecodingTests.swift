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
}

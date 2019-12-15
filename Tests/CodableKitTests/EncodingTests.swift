import XCTest
import Foundation
@testable import CodableKit

final class encodingTests: XCTestCase {

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

}

import XCTest
import Foundation
@testable import CodableKit

final class DecodingNilTests: XCTestCase {
    
    func testDecodingNulls() throws {
    
        struct NSNullTest: Codable {
            let optionalField: Int8?
        }
    
        let inputMissing: [String: Any] = [:]
        let inputNilOptional: [String: Any] = ["optionalField": Optional<Int8>.none as Any]
        let inputNSNull: [String: Any] = ["optionalField": NSNull()]
        let inputNotNil: [String: Any] = ["optionalField": Int8(5)]
        
        do {
            let outputFromMissing = try KVHashDecoder.decode(NSNullTest.self, from: inputMissing)
            XCTAssertNil(outputFromMissing.optionalField)
            
            let outputFromNil = try KVHashDecoder.decode(NSNullTest.self, from: inputNilOptional)
            XCTAssertNil(outputFromNil.optionalField)

            let outputFromNSNull = try KVHashDecoder.decode(NSNullTest.self, from: inputNSNull)
            XCTAssertNil(outputFromNSNull.optionalField)
            
            let outputFromNotNil = try KVHashDecoder.decode(NSNullTest.self, from: inputNotNil)
            XCTAssertEqual(outputFromNotNil.optionalField, Int8(5))
        } catch {
            XCTFail("\(error)")
        }
    }

}

import Foundation

/// A simple generic `CodingKey`. Used mostly by unkeyed containers to keep
/// track of indexes in a coding path. A shame none of the several copies of
/// exactly this in the standard library are public.
public struct GenericCodingKey: CodingKey {
    public let stringValue: String
    public let intValue: Int?

    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
    
    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
}

/// Various conveniences for creating more useful `DecodingError`s.
extension DecodingError {
    
    /// Generate a human-readable string for a coding path. Works best when all
    /// keys in the path provide a reasonable `stringValue` even for integer
    /// path components. If a path component has no string value, the integer
    /// value, if any, is used. If that also doesn't exist, falls back on the
    /// dynamic type of the key as a last-ditch effort.
    private static func describe(_ codingPath: [CodingKey]) -> String {
        return codingPath.map {
            (!$0.stringValue.isEmpty ? $0.stringValue : nil) ??
            $0.intValue.map { "\($0)" } ??
            "\(type(of: $0))"
        }.joined(separator: ".")
    }
    
    /// Generate a prettier string for an unkeyed container's count than "Optional(8)"
    private static func describe(sizeOf container: UnkeyedDecodingContainer) -> String {
        return container.count?.description ?? "<unknown>"
    }
    
    /// Create a `typeMismatch` error based on the desired type and actual type.
    /// Makes a nicer debug description than the default.
    public static func typeMismatchError(
        _ expectedType: Any.Type,
        found value: Any,
        at codingPath: [CodingKey],
        debugDescription: String? = nil,
        underlyingError: Error? = nil
    ) -> DecodingError {
        return .typeMismatch(expectedType, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: debugDescription ??
                "Expected value of type \(expectedType) at \(describe(codingPath)), but found \(type(of: value))",
            underlyingError: underlyingError
        ))
    }
    
    /// Create a `keyNotFound` error from the key.
    /// Makes a nicer debug description than the default.
    public static func keyNotFoundError(
        _ key: CodingKey,
        at codingPath: [CodingKey],
        debugDescription: String? = nil,
        underlyingError: Error? = nil
    ) -> DecodingError {
        return .keyNotFound(key, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: debugDescription ??
                "Failed to find key \(key.stringValue) expected at path \(describe(codingPath))",
            underlyingError: underlyingError
        ))
    }
    
    /// Create a `dataCorrupted` error to stand in for the lack of an error to
    /// describe the scenario of a `Decoder` which does not not support the use
    /// of `superDecoder()` and/or `superDecoder(forKey:)`.
    public static func superUnsupportedError(
        at codingPath: [CodingKey],
        debugDescription: String? = nil,
        underlyingError: Error? = nil
    ) -> DecodingError {
        return .dataCorrupted(DecodingError.Context(
            codingPath: codingPath,
            debugDescription: debugDescription ??
                "Requesting an inline decoder (\"super decoder\") is not supported by this implementation (at \(describe(codingPath)))",
            underlyingError: underlyingError
        ))
    }
    
    /// Create a `keyNotFound` error representing an attempt to read past the
    /// end of an unkeyed container, based on the current index.
    /// Makes a nicer debug description than the default.
    public static func outOfBoundsError(
        in container: UnkeyedDecodingContainer,
        debugDescription: String? = nil,
        underlyingError: Error? = nil
    ) -> DecodingError {
        return .keyNotFoundError(
            GenericCodingKey(intValue: container.currentIndex)!,
            at: container.codingPath,
            debugDescription: debugDescription ??
                "Index \(container.currentIndex) out of bounds (\(describe(sizeOf: container))) at \(describe(container.codingPath))",
            underlyingError: underlyingError
        )
    }
}


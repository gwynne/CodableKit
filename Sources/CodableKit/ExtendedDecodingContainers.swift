import Foundation // for NSNull

/// Provides simplified implementation requirements common to all container
/// types.
public protocol ExtendedDecodingContainer {
    
    /// Determines whether a given value should be considered `nil` by the
    /// decoder, per the semantics of the various `decodeNil()` and
    /// `decodeIfPresent()` methods. If no implementation is provded, the
    /// following are considered `nil` by default:
    ///
    /// - Any value having type `Optional<T>` and containing `nil`, for any `T`
    /// - Any instance of `Foundation.NSNull`
    /// - An entirely absent value
    ///
    /// If the result of this method must vary based on the type of the
    /// container or on a case-by-case basis, the recommended approach is to
    /// just implement the appropriate `decodeNil()` variant, as well as the
    /// `decodeIfPresent()` variants where applicable.
    ///
    /// The static type information may or may not be of particular use; it is
    /// common for `T` to just be `Any`.
    ///
    /// - Warning: It may not always be possible to distinguish between a value
    /// of `Optional<Any>.none` and an entirely absent value.
    func checkIsNil<T>(value: T?) throws -> Bool
    
    /// Provide an instance of `Decoder` suitable for decoding a value of a
    /// given type `T: Decodable`. May also be used to implement
    /// `superDecoder()` and variants to support decoding of existentials, in
    /// which case `value` will generally be `nil`.
    func subdecoder(forValue value: Any?, codingPath: [CodingKey]) throws -> Decoder

}

extension ExtendedDecodingContainer {

    public func checkIsNil<T>(value: T?) throws -> Bool {
        if let presentValue = value {
            // Value is non-absent. Is it still Optional?
            if let optionalValue = presentValue as? AnyOptionalType {
                // TODO: Does this actually work as intended?
                return !optionalValue.hasValue
            } else {
                // By default, `NSNull` is considered `nil`.
                return presentValue is NSNull
            }
        } else {
            // Absent values are `nil` by default. In particular, they are
            // treated as `nil` rather than raising `keyNotFound` or
            // `valueNotFound` errors.
            return true
        }
    }

}

/// Provides default implementations and utility methods for building keyed
/// decoding containers.
///
/// Implementations are provided for:
/// - `decodeNil(()`
/// - `decode(_:)` for `Bool`, `String`, `Double`, `Float`, and all `Int` types
/// - `superDecoder()` and `superDecoder(forKey:)`
public protocol ExtendedKeyedDecodingContainer: ExtendedDecodingContainer, KeyedDecodingContainerProtocol {
    
    /// Retrieves a value for a given key, if it exists in the container, or
    /// returns nil.
    subscript(forKey key: Key) -> Any? { get }
    
    /// Retrieves a value for a given key, ensuring that it is of the requested
    /// type. Throws error if the key is missing or the wrong type.
    func requireValue<T>(forKey key: Key, ofType type: T.Type) throws -> T
    
}

/// Provides default implementations and utility methods for building unkeyed
/// decoding containers.
///
/// Implementations are provided for:
/// - `isAtEnd`
/// - `decodeNil(()`
/// - `decode(_:)` for `Bool`, `String`, `Double`, `Float`, and all `Int` types
/// - `superDecoder()`
public protocol ExtendedUnkeyedDecodingContainer: ExtendedDecodingContainer, UnkeyedDecodingContainer {
    
    /// The value held in the container at `self.currentIndex`, whatever it may
    /// be. Calls `fatalError()` if `self.isAtEnd` is `true`. If the
    /// implementing container's contents are not immediate values, the
    /// container _MUST_ either unwrap the primitive values before returning
    /// them, or override the provided implementations for the various
    /// `decode(_:)` methods, including `decodeNil()`, accordingly.
    var currentValue: Any { get }
    
    /// A `CodingKey` representing the current location in the container.
    var currentKey: CodingKey { get }
    
    /// codingPath + currentKey
    var nextCodingPath: [CodingKey] { get }
    
    /// Returns the value at the current container index, as converted to the
    /// given type. If the current index is out of bounds, or the type
    /// conversion fails, an error is thrown.
    func requireNextValue<T>(ofType type: T.Type) throws -> T
    
    /// Advance `self.currentIndex` to the next index in the container. This
    /// exists to work around the inability to add a setter requirement for
    /// `currentIndex` itself.
    func advanceIndex()
    
    /// Advance the current index if and only if the closure doesn't throw. Used
    /// to simplify maintenance of the current index.
    func advanceIndex<R>(after closure: @autoclosure () throws -> R) rethrows -> R
    
}

/// Provides default implementations and utility methods for building
/// single-value decoding containers.
///
/// Implementations are provided for:
/// - `decodeNil(()`
/// - `decode(_:)` for `Bool`, `String`, `Double`, `Float`, and all `Int` types
public protocol ExtendedSingleValueDecodingContainer: ExtendedDecodingContainer, SingleValueDecodingContainer {
    
    /// The contents of the container as an untyped primtiive value.
    var value: Any { get }

    /// Returns the container's value, converted to the given type.
    /// Throws an error if the conversion fails.
    func requireValue<T>(ofType: T.Type) throws -> T

}

extension ExtendedKeyedDecodingContainer {

    public func requireValue<T>(forKey key: Key, ofType type: T.Type = T.self) throws -> T {
        guard let rawValue = self[forKey: key] else {
            throw DecodingError.keyNotFoundError(key, at: self.codingPath + [key])
        }
        
        guard let value = rawValue as? T else {
            throw DecodingError.typeMismatchError(T.self, found: rawValue, at: self.codingPath + [key])
        }
        
        return value
    }
    
    public func decodeNil(forKey key: Key) throws -> Bool {
        return try self.checkIsNil(value: self[forKey: key])
    }

    /// For arbitrary types, invoke a subdecoder by default.
    public func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        return try T.init(from:
            self.subdecoder(forValue: try self.requireValue(forKey: key, ofType: T.self), codingPath: self.codingPath + [key]))
    }

    /// Temporarily disabled due to https://bugs.swift.org/browse/SR-11913
    //public func superDecoder() throws -> Decoder {
    //}
    
    public func superDecoder(forKey key: Key) throws -> Decoder {
        return try self.subdecoder(forValue: self.requireValue(forKey: key, ofType: Any.self), codingPath: self.codingPath + [key])
    }

    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { return try self.requireValue(forKey: key) }
    public func decode(_ type: String.Type, forKey key: Key) throws -> String { return try self.requireValue(forKey: key) }
    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double { return try self.requireValue(forKey: key) }
    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float { return try self.requireValue(forKey: key) }
    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int { return try self.requireValue(forKey: key) }
    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { return try self.requireValue(forKey: key) }
    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { return try self.requireValue(forKey: key) }
    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { return try self.requireValue(forKey: key) }
    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { return try self.requireValue(forKey: key) }
    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { return try self.requireValue(forKey: key) }
    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { return try self.requireValue(forKey: key) }
    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { return try self.requireValue(forKey: key) }
    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { return try self.requireValue(forKey: key) }
    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { return try self.requireValue(forKey: key) }
    
}

extension ExtendedUnkeyedDecodingContainer {

    public var currentKey: CodingKey {
        return GenericCodingKey(intValue: self.currentIndex)!
    }
    
    public var nextCodingPath: [CodingKey] {
        return self.codingPath + [self.currentKey]
    }
    
    public func requireNextValue<T>(ofType type: T.Type = T.self) throws -> T {
        guard !self.isAtEnd else {
            throw DecodingError.outOfBoundsError(in: self)
        }

        guard let value = self.currentValue as? T else {
            throw DecodingError.typeMismatchError(type, found: self.currentValue, at: self.nextCodingPath)
        }

        return value
    }
    
    public func advanceIndex<R>(after closure: @autoclosure () throws -> R) rethrows -> R {
        let result = try closure()
        
        self.advanceIndex()
        return result
    }
    
    /// Convenience implementation of `isAtEnd` using `currentIndex` and `count`.
    public var isAtEnd: Bool {
        self.currentIndex >= (self.count ?? -1)
    }

    /// Delegate `nil`-ness decisions to `checkIsNil(value:)`
    public func decodeNil() throws -> Bool {
        return try self.checkIsNil(value: self.currentValue) ? self.advanceIndex(after: true) : false
    }

    /// For arbitrary types, invoke a subdecoder by default.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try self.advanceIndex(after: T.init(from:
            self.subdecoder(forValue: self.requireNextValue(ofType: T.self), codingPath: self.nextCodingPath)))
    }

    /// Convenience overload of `superDecoder()`.
    public func superDecoder() throws -> Decoder {
        return try self.subdecoder(forValue: nil, codingPath: self.nextCodingPath) // Do not advance index
    }
    
    /// Convenience implementations of decoding all fundamental types via
    /// `requireNextValue(ofType:)`.
    public func decode(_ type: Bool.Type) throws -> Bool { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: String.Type) throws -> String { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: Double.Type) throws -> Double { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: Float.Type) throws -> Float { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: Int.Type) throws -> Int { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: Int8.Type) throws -> Int8 { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: Int16.Type) throws -> Int16 { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: Int32.Type) throws -> Int32 { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: Int64.Type) throws -> Int64 { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: UInt.Type) throws -> UInt { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: UInt8.Type) throws -> UInt8 { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: UInt16.Type) throws -> UInt16 { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: UInt32.Type) throws -> UInt32 { return try self.advanceIndex(after: self.requireNextValue()) }
    public func decode(_ type: UInt64.Type) throws -> UInt64 { return try self.advanceIndex(after: self.requireNextValue()) }
    
}

extension ExtendedSingleValueDecodingContainer {
    
    /// Returns the container's value, converted to the given type.
    /// Throws an error if the conversion fails.
    public func requireValue<T>(ofType: T.Type = T.self) throws -> T {
        guard let value = self.value as? T else {
            print("Value is \(type(of: self.value)): \(String(describing: self.value))")
            throw DecodingError.typeMismatchError(T.self, found: self.value, at: self.codingPath)
        }
        return value
    }
    
    /// Convenience implementation of `decodeNil()` using `value`.
    ///
    /// - Warning: Because `decodeNil()` on `SingleValueDecodingContainer` can
    /// not throw an error, any errors that are thrown are converted to a "this
    /// value is nil" result!
    public func decodeNil() -> Bool {
        return (try? self.checkIsNil(value: self.value)) ?? true
    }
    
    /// For arbitrary types, invoke a subdecoder by default.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try T.init(from: self.subdecoder(forValue: self.value, codingPath: self.codingPath))
    }

    /// Convenience implementations of decoding all fundamental types via
    /// `requireValue(ofType:)`.
    public func decode(_ type: Bool.Type) throws -> Bool { return try self.requireValue() }
    public func decode(_ type: String.Type) throws -> String { return try self.requireValue() }
    public func decode(_ type: Double.Type) throws -> Double { return try self.requireValue() }
    public func decode(_ type: Float.Type) throws -> Float { return try self.requireValue() }
    public func decode(_ type: Int.Type) throws -> Int { return try self.requireValue() }
    public func decode(_ type: Int8.Type) throws -> Int8 { return try self.requireValue() }
    public func decode(_ type: Int16.Type) throws -> Int16 { return try self.requireValue() }
    public func decode(_ type: Int32.Type) throws -> Int32 { return try self.requireValue() }
    public func decode(_ type: Int64.Type) throws -> Int64 { return try self.requireValue() }
    public func decode(_ type: UInt.Type) throws -> UInt { return try self.requireValue() }
    public func decode(_ type: UInt8.Type) throws -> UInt8 { return try self.requireValue() }
    public func decode(_ type: UInt16.Type) throws -> UInt16 { return try self.requireValue() }
    public func decode(_ type: UInt32.Type) throws -> UInt32 { return try self.requireValue() }
    public func decode(_ type: UInt64.Type) throws -> UInt64 { return try self.requireValue() }
    
}


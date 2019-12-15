import Foundation

public protocol ExtendedEncodingContainer {
    
    /// Called when a subencoder is needed, either to encode a value of
    /// arbitrary/unknown type into a container, or when an inline/"super"
    /// encoder has been requested.
    func subencoder(codingPath: [CodingKey]) throws -> Encoder
    
    /// Consulted to determine the appropriate representation of a "null" value
    /// for the encoder. Typically this is `Optional<Void>.none` or `NSNull()`.
    /// If no implementation is provided, defaults to `Void?(nil)`.
    static var nilRepresentation: Any { get }
    
    /// Call when an `encode<T>()` method has no special handling for the given
    /// `T`. The value will be passed along to a subencoder.
    func passthrough<T: Encodable>(_ value: T, forKey key: CodingKey?) throws

    /// A redeclaration of the `codingPath` provided by all the various
    /// coding containers so it can be accessed more generically.
    var codingPath: [CodingKey] { get }
}

public protocol ExtendedKeyedEncodingContainer: ExtendedEncodingContainer, KeyedEncodingContainerProtocol {
    
    /// Called to concretely specify a value of type `T`, which may be any type,
    /// which shall be associated with the given coding key. The value may or
    /// may not be Optional. May be called more than once for a given key,
    /// though implementations are permitted to consider this an error. A value
    /// may, in particular, be a subencoder that was used to handle an unknown
    /// type; the encoder must be prepared to handle this case gracefully.
    func set<T>(value: T, forKey key: Key) throws

}

public protocol ExtendedUnkeyedEncodingContainer: ExtendedEncodingContainer, UnkeyedEncodingContainer {
    
    /// Called to add an additional value to the end of the container. The value
    /// may be of any type, and may or may not be Optional.
    func append<T>(_ value: T) throws
    
    /// Contains a `CodingKey` with an `intValue` corresponding to the value of
    /// `self.count` at the time of the call. Useful for constructing coding
    /// paths for nested containers and errors.
    var currentCodingKey: CodingKey { get }
}

public protocol ExtendedSingleValueEncodingContainer: ExtendedEncodingContainer, SingleValueEncodingContainer {
    
    /// Called to specify the complete value of the single-value container. The
    /// value may be of any type and may or may not be Optional.
    func set<T>(value: T) throws

}

extension ExtendedEncodingContainer {

    public static var nilRepresentation: Any { Optional<Void>.none as Any }

    public func passthrough<T: Encodable>(_ value: T, forKey key: CodingKey?) throws {
        fatalError("This should have been overridden.")
    }
}

extension ExtendedKeyedEncodingContainer {

    public func encodeNil(forKey key: Key) throws { try self.set(value: Self.nilRepresentation, forKey: key) }
    public func encode(_ value: Bool, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: String, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: Double, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: Float, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: Int, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: Int8, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: Int16, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: Int32, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: Int64, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: UInt, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: UInt8, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: UInt16, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: UInt32, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode(_ value: UInt64, forKey key: Key) throws { try self.set(value: value, forKey: key) }
    public func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        try self.passthrough(value, forKey: key)
    }

    /// Temporarily disabled due to https://bugs.swift.org/browse/SR-11913
    //public func superEncoder() -> Encoder {
    //    fatalError("Inline (\"super\") encoders with no key are not supported.")
    //}
    
    public func superEncoder(forKey key: Key) -> Encoder {
        let subencoder = try! self.subencoder(codingPath: self.codingPath + [key])
        try! self.set(value: subencoder, forKey: key)
        return subencoder
    }
    
    public func passthrough<T: Encodable>(_ value: T, forKey key: CodingKey?) throws {
        let subencoder = try! self.subencoder(codingPath: self.codingPath + [key].compactMap { $0 })
        try value.encode(to: subencoder)
        try! self.set(value: subencoder, forKey: key as! Key)
    }

}

extension ExtendedUnkeyedEncodingContainer {

    public func encodeNil() throws { try self.append(Self.nilRepresentation) }
    public func encode(_ value: Bool) throws { try self.append(value) }
    public func encode(_ value: String) throws { try self.append(value) }
    public func encode(_ value: Double) throws { try self.append(value) }
    public func encode(_ value: Float) throws { try self.append(value) }
    public func encode(_ value: Int) throws { try self.append(value) }
    public func encode(_ value: Int8) throws { try self.append(value) }
    public func encode(_ value: Int16) throws { try self.append(value) }
    public func encode(_ value: Int32) throws { try self.append(value) }
    public func encode(_ value: Int64) throws { try self.append(value) }
    public func encode(_ value: UInt) throws { try self.append(value) }
    public func encode(_ value: UInt8) throws { try self.append(value) }
    public func encode(_ value: UInt16) throws { try self.append(value) }
    public func encode(_ value: UInt32) throws { try self.append(value) }
    public func encode(_ value: UInt64) throws { try self.append(value) }
    public func encode<T: Encodable>(_ value: T) throws {
        try self.passthrough(value, forKey: self.currentCodingKey)
    }

    public func superEncoder() -> Encoder {
        let subencoder = try! self.subencoder(codingPath: self.codingPath + [self.currentCodingKey])
        try! self.append(subencoder)
        return subencoder
    }
    
    public func passthrough<T: Encodable>(_ value: T, forKey key: CodingKey?) throws {
        let subencoder = try! self.subencoder(codingPath: self.codingPath + [key].compactMap { $0 })
        try value.encode(to: subencoder)
        try! self.append(subencoder)
    }

    public var currentCodingKey: CodingKey { GenericCodingKey(intValue: self.count)! }

}

extension ExtendedSingleValueEncodingContainer {

    public func encodeNil() throws { try self.set(value: Self.nilRepresentation) }
    public func encode(_ value: Bool) throws { try self.set(value: value) }
    public func encode(_ value: String) throws { try self.set(value: value) }
    public func encode(_ value: Double) throws { try self.set(value: value) }
    public func encode(_ value: Float) throws { try self.set(value: value) }
    public func encode(_ value: Int) throws { try self.set(value: value) }
    public func encode(_ value: Int8) throws { try self.set(value: value) }
    public func encode(_ value: Int16) throws { try self.set(value: value) }
    public func encode(_ value: Int32) throws { try self.set(value: value) }
    public func encode(_ value: Int64) throws { try self.set(value: value) }
    public func encode(_ value: UInt) throws { try self.set(value: value) }
    public func encode(_ value: UInt8) throws { try self.set(value: value) }
    public func encode(_ value: UInt16) throws { try self.set(value: value) }
    public func encode(_ value: UInt32) throws { try self.set(value: value) }
    public func encode(_ value: UInt64) throws { try self.set(value: value) }
    public func encode<T: Encodable>(_ value: T) throws {
        try self.passthrough(value, forKey: nil)
    }
    
    public func passthrough<T>(_ value: T, forKey key: CodingKey?) throws where T : Encodable {
        assert(key == nil)
        let subencoder = try self.subencoder(codingPath: self.codingPath)
        try value.encode(to: subencoder)
        try self.set(value: subencoder)
    }

}

import Foundation

public struct KVHashDecoder {
    
    /// Decode an arbitrary key-value hash to a given type. If the type's
    /// structure does not match that of the input, errors and hilarity are
    /// liable to result.
    public static func decode<T: Decodable>(_ type: T.Type = T.self, from input: [String: Any]) throws -> T {
        return try T.init(from: _KVHashDecoder(storage: input))
    }

}

/// The actual implementation of `Decoder` conformance.
fileprivate struct _KVHashDecoder: Decoder {
    
    /// The raw data on which this decoder is focused.
    private let storage: Any
    
    /// See `Decoder.codingPath`
    public let codingPath: [CodingKey]
    
    /// See `Decoder.userInfo`
    public var userInfo: [CodingUserInfoKey: Any]
    
    /// Create from a coding path, a data value, and any provided user info.
    fileprivate init(codingPath: [CodingKey] = [], storage: Any, userInfo: [CodingUserInfoKey: Any] = [:]) {
        self.storage = storage
        self.codingPath = codingPath
        self.userInfo = userInfo
    }
    
    /// See `Decoder.container(keyedBy:)`
    public func container<Key>(keyedBy: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        guard let value = storage as? _KVHashKeyedDecodingContainer<Key>.Storage else {
            throw DecodingError.typeMismatchError(_KVHashKeyedDecodingContainer<Key>.Storage.self, found: self.storage, at: self.codingPath)
        }
        return .init(_KVHashKeyedDecodingContainer(decoder: self, codingPath: self.codingPath, value: value))
    }
    
    /// See `Decoder.unkeyedContainer()`
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard let value = storage as? _KVHashUnkeyedDecodingContainer.Storage else {
            throw DecodingError.typeMismatchError(_KVHashUnkeyedDecodingContainer.Storage.self, found: self.storage, at: self.codingPath)
        }
        return _KVHashUnkeyedDecodingContainer(decoder: self, codingPath: self.codingPath, value: value)
    }
    
    /// See `Decoder.singleValueContainer()`
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return _KVHashSingleValueDecodingContainer(decoder: self, codingPath: codingPath, value: self.storage)
    }

}

/// This base class centralizes knowledge of how to create subencoders and
/// represents the data, such as coding path, value storage, and decoder
/// reference, common to all the container types.
fileprivate class _KVHashDecodingContainerBase<StorageType>: ExtendedDecodingContainer {
    
    /// The concrete storage type, provided so we can refer to the types
    /// declared by the containers instead of hardcoding that knowledge.
    typealias Storage = StorageType
    
    /// The decoder which created this container (or its parent)
    let decoder: _KVHashDecoder
    
    /// The base value represented in this container.
    let value: Storage
    
    /// The coding path of this container's value. May differ from the decoder's.
    let codingPath: [CodingKey]

    /// See `ExtendedDecodingContainer.subdecoder(forValue:codingPath:)`
    func subdecoder(forValue value: Any, codingPath: [CodingKey]) throws -> Decoder {
        return _KVHashDecoder(codingPath: codingPath, storage: value as Any, userInfo: self.decoder.userInfo)
    }
    
    /// Common initializer
    init(decoder: _KVHashDecoder, codingPath: [CodingKey], value: Storage) {
        self.decoder = decoder
        self.value = value
        self.codingPath = codingPath
    }

}

/// The keyed decoding container for `_KVHashDecoder`
fileprivate final class _KVHashKeyedDecodingContainer<Key: CodingKey>:
    _KVHashDecodingContainerBase<[String: Any]>, ExtendedKeyedDecodingContainer
{
    /// See `KeyedDecodingContainerProtocol.allKeys`
    public var allKeys: [Key] {
        value.keys.compactMap { Key(stringValue: $0) }
    }
    
    /// See `KeyedDecodingContainerProtocol.contains(_:)`
    public func contains(_ key: Key) -> Bool {
        value.index(forKey: key.stringValue) != nil
    }
    
    /// See `KeyedDecodingContainerProtocol.nestedContainer(keyedBy:forKey:)`
    public func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        return try self.subdecoder(forValue: self.requireValue(forKey: key), codingPath: self.codingPath + [key])
            .container(keyedBy: NestedKey.self)
    }
    
    /// See `KeyedDecodingContainerProtocol.nestedUnkeyedContainer(forKey:)`
    public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try self.subdecoder(forValue: self.requireValue(forKey: key), codingPath: self.codingPath + [key])
            .unkeyedContainer()
    }

    /// Not provided by `ExtendedKeyedDecodingContainer` due to
    /// https://bugs.swift.org/browse/SR-11913
    ///
    /// See `KeyedDecodingContainerProtocol.superDecoder()`
    public func superDecoder() throws -> Decoder {
        throw DecodingError.superUnsupportedError(at: self.codingPath)
    }

    /// See `ExtendedKeyedDecodingContainer.subscript(forKey:)`
    subscript(forKey key: Key) -> Any? {
        value[key.stringValue] as Any?
    }

    /// Explicitly override decoding for `URL` to decode from simple `String`.
    /// This matches the behavior of `JSONDecoder`.
    public func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        if T.self is URL.Type {
            let rawValue = try self.requireValue(forKey: key, ofType: String.self)
            
            guard let url = URL(string: rawValue) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Failed to create URL from string \(rawValue)")
            }
            return url as! T
        } else {
            return try self.passthrough(self.requireValue(forKey: key, ofType: Any.self), forKey: key)
        }
    }

}

/// The unkeyed decoding container for `_KVHashDecoder`
fileprivate final class _KVHashUnkeyedDecodingContainer:
    _KVHashDecodingContainerBase<[Any]>, ExtendedUnkeyedDecodingContainer
{
    /// See `UnkeyedDecodingContainer.count`
    public var count: Int? { self.value.count }
    
    /// See `UnkeyedDecodingContainer.currentIndex`
    public var currentIndex = 0
    
    /// See `UnkeyedDecodingContainer.nestedContainer(keyedBy:)`
    public func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        return try self.advanceIndex(after:
            self.subdecoder(forValue: self.requireNextValue(), codingPath: self.codingPath + [self.currentKey])
                .container(keyedBy: NestedKey.self)
        )
    }

    /// See `UnkeyedDecodingContainer.nestedUnkeyedContainer()`
    public func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try self.advanceIndex(after:
            self.subdecoder(forValue: self.requireNextValue(), codingPath: self.codingPath + [self.currentKey])
                .unkeyedContainer()
        )
    }
    
    /// See `ExtendedUnkeyedDecodingContainer.currentValue`
    var currentValue: Any {
        self.value[self.currentIndex]
    }

    /// See `ExtendedUnkeyedDecodingContainer.advanceIndex()`
    func advanceIndex() {
        self.currentIndex += 1
    }

    /// Explicitly override decoding for `URL` to decode from simple `String`.
    /// This matches the behavior of `JSONDecoder`.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if T.self is URL.Type {
            let rawValue = try self.requireNextValue(ofType: String.self)
            
            guard let url = URL(string: rawValue) else {
                throw DecodingError.dataCorruptedError(in: self, debugDescription: "Failed to create URL from string \(rawValue)")
            }
            return self.advanceIndex(after: url) as! T
        } else {
            return try self.advanceIndex(after: self.passthrough(self.requireNextValue(ofType: Any.self), forKey: self.currentKey))
        }
    }

}

/// The single=value decoding container for `_KVHashDecoder`
fileprivate final class _KVHashSingleValueDecodingContainer:
    _KVHashDecodingContainerBase<Any>, ExtendedSingleValueDecodingContainer
{
    
    /// Nothing to implement, the base class and extended container handled
    /// everything this particular decoder cares about.
    
    /// Explicitly override decoding for `URL` to decode from simple `String`.
    /// This matches the behavior of `JSONDecoder`.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if T.self is URL.Type {
            let rawValue = try self.requireValue(ofType: String.self)
            
            guard let url = URL(string: rawValue) else {
                throw DecodingError.dataCorruptedError(in: self, debugDescription: "Failed to create URL from string \(rawValue)")
            }
            return url as! T
        } else {
            return try self.passthrough(self.value, forKey: nil)
        }
    }

}

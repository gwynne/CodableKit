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
    
    /// General unboxing logic; this handles knowing which things we want to
    /// handle in an atypical manner across all container types while allowing
    /// each type to provide the correct inputs and failure modes. Calls the
    /// appropriate `self.passthrough()`.
    func unbox<T: Decodable>(
        _ valueClosure: @autoclosure () throws -> Any,
        forKey key: CodingKey?,
        typeError: (Any) -> DecodingError,
        corruptError: (String) -> DecodingError
    ) throws -> T {
        let rawValue = try valueClosure()
        
        if T.self is URL.Type {
            guard let value = rawValue as? String else { throw typeError(rawValue) }
            return try self.decodeURL(from: value, failingWith: corruptError) as! T
        //} else if T.self is Date.Type {
        //    guard let value = rawValue as? String else { throw typeError(rawValue) }
        //    return try self.decodeDate(from: value, failingWith: corruptError) as! T
        } else if T.self is Decimal.Type {
            guard let value = rawValue as? String else { throw typeError(rawValue) }
            return try self.decodeDecimal(from: value, failingWith: corruptError) as! T
        } else {
            return try self.passthrough(rawValue, forKey: key)
        }
    }
    
    /// Special handling for `URL`
    func decodeURL(from value: String, failingWith errorClosure: (String) -> DecodingError) throws -> URL {
        guard let url = URL(string: value) else {
            throw errorClosure("Failed to create URL from string \"\(value)\"")
        }
        return url
    }
    
    /// Special handling for `Date`
    func decodeDate(from value: String, failingWith errorClosure: (String) -> DecodingError) throws -> Date {
        let adjustedValue = value.replacingOccurrences(of: "Z", with: ".000000Z", options: [.anchored, .backwards])
        guard let date = isoDateFormatter.date(from: value) else {
            throw errorClosure("Failed to interpret raw string \"value\" as an ISO8601 date.")
        }
        return date
    }
    
    /// Special handling for `Decimal`
    func decodeDecimal(from value: String, failingWith errorClosure: (String) -> DecodingError) throws -> Decimal {
        guard let decimal = Decimal(string: value) else {
            throw errorClosure("Failed to interpret raw string \"value\" as a Decimal.")
        }
        return decimal
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

    /// Use our unboxing function to get various custom behaviors.
    public func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        return try self.unbox(
            self.requireValue(forKey: key),
            forKey: key,
            typeError: { .typeMismatchError(T.self, found: $0, at: self.codingPath + [key]) },
            corruptError: { .dataCorruptedError(forKey: key, in: self, debugDescription: $0) }
        )
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
            self.subdecoder(forValue: self.requireNextValue(), codingPath: self.nextCodingPath).container(keyedBy: NestedKey.self)
        )
    }

    /// See `UnkeyedDecodingContainer.nestedUnkeyedContainer()`
    public func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try self.advanceIndex(after:
            self.subdecoder(forValue: self.requireNextValue(), codingPath: self.nextCodingPath).unkeyedContainer()
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

    /// Use our unboxing function to get various custom behaviors.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try self.advanceIndex(after: self.unbox(
            self.requireNextValue(),
            forKey: self.currentKey,
            typeError: { .typeMismatchError(T.self, found: $0, at: self.nextCodingPath) },
            corruptError: { .dataCorruptedError(in: self, debugDescription: $0) }
        ))
    }

}

/// The single=value decoding container for `_KVHashDecoder`
fileprivate final class _KVHashSingleValueDecodingContainer:
    _KVHashDecodingContainerBase<Any>, ExtendedSingleValueDecodingContainer
{
    /// Use our unboxing function to get various custom behaviors.
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        return try self.unbox(
            self.value,
            forKey: nil,
            typeError: { .typeMismatchError(T.self, found: $0, at: self.codingPath) },
            corruptError: { .dataCorruptedError(in: self, debugDescription: $0) }
        )
    }

}

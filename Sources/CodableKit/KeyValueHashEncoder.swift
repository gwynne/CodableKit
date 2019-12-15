import Foundation

public struct KVHashEncoder {

    /// Transform an `Encodable` value into a key-value hash (aka a dictionary).
    public static func encode<T: Encodable>(_ input: T) throws -> [String: Any] {
        let encoder = _KVHashEncoder(codingPath: [], userInfo: [:])
        
        try input.encode(to: encoder)
        return encoder.flattenedValue as! [String: Any]
    }
}

/// Conformance to this protocol is used to replace the reference wrapper types
/// with the "real" unwrapped value types, as well as to ensure any sub-encoders
/// which were used during the encode process are properly finalized.
fileprivate protocol Flattenable {
    var flattenedValue: Any { get }
}

extension ReferenceWrappedDictionary: Flattenable {
    /// A dictionary's flattened value is the unwrapped value type with all
    /// nested values recursively flattened.
    fileprivate var flattenedValue: Any {
        self.unwrappedDictionary.mapValues { ($0 as? Flattenable)?.flattenedValue ?? $0 }
    }
}

extension ReferenceWrappedArray: Flattenable {
    /// An array's flattened value is the unwrapped value type with all nested
    /// values recursively flattened.
    fileprivate var flattenedValue: Any {
        self.unwrappedArray.map { ($0 as? Flattenable)?.flattenedValue ?? $0 }
    }
}

/// The actual implementation of `Encoder` conformance.
fileprivate class _KVHashEncoder: Encoder, Flattenable {
    
    /// Tracks the current state of this encoder. The cases correspond to the
    /// types of containers that can be requested, plus a state to represent
    /// "none as of yet".
    enum Storage: Equatable {
        case uninitialized
        case keyed(ReferenceWrappedDictionary<String, Any>)
        case unkeyed(ReferenceWrappedArray<Any>)
        case singleValue(Any)
        
        /// The compiler can't synthesize this and we don't care about the
        /// associated values in this case anyway.
        public static func ==(lhs: Storage, rhs: Storage) -> Bool {
            switch (lhs, rhs) {
                case (.uninitialized, .uninitialized), (.keyed, .keyed), (.unkeyed, .unkeyed), (.singleValue, .singleValue):
                    return true
                default:
                    return false
            }
        }
    }
    
    /// The actual data that has been stored in this encoder thus far, if any.
    fileprivate var storage: Storage = .uninitialized

    /// The flattened value of an encoder is the final form of its contents.
    fileprivate var flattenedValue: Any {
        switch self.storage {
            case .uninitialized:
                fatalError("Encoder should not be finalized unless something has been encoded into it.")
            case .keyed(let dict):
                return dict.flattenedValue
            case .unkeyed(let arr):
                return arr.flattenedValue
            case .singleValue(let value):
                return (value as? Flattenable)?.flattenedValue ?? value
        }
    }
    
    /// See `Encoder.codingPath`
    public let codingPath: [CodingKey]
    
    /// See `Encoder.userInfo`
    public let userInfo: [CodingUserInfoKey : Any]
    
    /// Initialize from a coding path and user info.
    fileprivate init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any] = [:]) {
        self.codingPath = codingPath
        self.userInfo = userInfo
    }
    
    /// See `Encoder.container(keyedBy:)`
    public func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        precondition(self.storage == .uninitialized, "It is incorrect to request more than one container from an Encoder.")
        
        let storageRef = _KVHashKeyedEncodingContainer<Key>.StorageRef()
        self.storage = .keyed(storageRef)
        return .init(_KVHashKeyedEncodingContainer(encoder: self, storageRef: storageRef, codingPath: self.codingPath))
    }
    
    /// See `Encoder.unkeyedContainer()`
    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        precondition(self.storage == .uninitialized, "It is incorrect to request more than one container from an Encoder.")
        precondition(self.codingPath.count > 0, "A key-value hash encoder can not encode an array at the top level.")
        
        let storageRef = _KVHashUnkeyedEncodingContainer.StorageRef()
        self.storage = .unkeyed(storageRef)
        return _KVHashUnkeyedEncodingContainer(encoder: self, storageRef: storageRef, codingPath: self.codingPath)
    }
    
    /// See `Encoder.singleValueContainer()`
    public func singleValueContainer() -> SingleValueEncodingContainer {
        precondition(self.storage == .uninitialized, "It is incorrect to request more than one container from an Encoder.")
        precondition(self.codingPath.count > 0, "A key-value hash encoder can not encode singular values at the top level.")
        
        // With the single-value container we just give it a closure that updates our storage directly.
        return _KVHashSingleValueEncodingContainer(encoder: self, storageRef: { self.storage = .singleValue($0) }, codingPath: self.codingPath)
    }
    
}

/// This base class centralizes knowledge of how to create subencoders and
/// represents the data, such as coding path, value storage, and encoder
/// reference, common to all the container types. It also provides the
/// `ExtendedEncodingContainer` conformance.
fileprivate class _KVHashEncodingContainerBase<StorageRefType>: ExtendedEncodingContainer {

    /// The concrete storage type, provided so we can refer to the types
    /// declared by the containers instead of hardcoding that knowledge.
    /// Encoding uses reference types to avoid writeback confusion.
    typealias StorageRef = StorageRefType
    
    /// The encoder which created this container (or its parent)
    let encoder: _KVHashEncoder
    
    /// The reference to where data encoded to this container will live.
    var storageRef: StorageRef
    
    /// The coding path of this container's value. May differ from the encoder's.
    let codingPath: [CodingKey]
    
    /// See `ExtendedEncodingContainer.subencoder(codingPath:)`
    fileprivate func subencoder(codingPath: [CodingKey]) throws -> Encoder {
        return _KVHashEncoder(codingPath: codingPath, userInfo: self.encoder.userInfo)
    }
    
    /// Common initializer
    fileprivate init(encoder: _KVHashEncoder, storageRef: StorageRef, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.storageRef = storageRef
        self.codingPath = codingPath
    }
    
    /// Create a new keyed encoding container using the given info and storage
    /// reference. Used by parent containers to correctly manage storage refs.
    fileprivate func makeContainer<Key: CodingKey>(
        keyedBy: Key.Type,
        codingPath: [CodingKey],
        storageRef: _KVHashKeyedEncodingContainer<Key>.StorageRef
    ) -> KeyedEncodingContainer<Key> {
        return .init(_KVHashKeyedEncodingContainer<Key>(encoder: self.encoder, storageRef: storageRef, codingPath: codingPath))
    }
    
    /// Create a new unkeyed encoding container using the given info and storage
    /// reference. Used by parent containers to correctly manage storage refs.
    fileprivate func makeUnkeyedContainer(
        codingPath: [CodingKey],
        storageRef: _KVHashUnkeyedEncodingContainer.StorageRef
    ) -> UnkeyedEncodingContainer {
        return _KVHashUnkeyedEncodingContainer(encoder: self.encoder, storageRef: storageRef, codingPath: codingPath)
    }

}

/// The keyed encoding container for `_KVHashEncoder`
fileprivate final class _KVHashKeyedEncodingContainer<Key: CodingKey>:
    _KVHashEncodingContainerBase<ReferenceWrappedDictionary<String, Any>>, ExtendedKeyedEncodingContainer
{
    /// See `KeyedEncodingContainerProtocol.nestedContainer(keyedBy:forKey:)`
    public func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let storageRef = ReferenceWrappedDictionary<String, Any>()
        self.storageRef[key.stringValue] = storageRef
        return self.makeContainer(keyedBy: NestedKey.self, codingPath: self.codingPath + [key], storageRef: storageRef)
    }
    
    /// See `KeyedEncodingContainerProtocol.nestedUnkeyedContainer(forKey:)`
    public func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let storageRef = ReferenceWrappedArray<Any>()
        self.storageRef[key.stringValue] = storageRef
        return self.makeUnkeyedContainer(codingPath: self.codingPath + [key], storageRef: storageRef)
    }

    /// Not provided by `ExtendedKeyedEncodingContainer` due to
    /// https://bugs.swift.org/browse/SR-11913
    ///
    /// See `KeyedEncodingContainerProtocol.superEncoder()`
    public func superEncoder() -> Encoder {
        fatalError("Inline (\"super\") encoders with no key are not supported.")
    }
    
    /// See `ExtendedKeyedEncodingContainer.set(value:forKey:)`
    func set<T>(value: T, forKey key: Key) throws {
        self.storageRef[key.stringValue] = value
    }
    
    /// Explicitly override encoding for `URL` to encode as simple `String`.
    /// This matches the behavior of `JSONEncoder`.
    public func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        if let url = value as? URL {
            try self.encode(url.absoluteString, forKey: key)
        } else {
            try self.passthrough(value, forKey: key)
        }
    }

}

/// The unkeyed encoding container for `_KVHashEncoder`
fileprivate final class _KVHashUnkeyedEncodingContainer:
    _KVHashEncodingContainerBase<ReferenceWrappedArray<Any>>, ExtendedUnkeyedEncodingContainer
{
    /// See `UnkeyedEncodingContainer.count`
    public var count: Int { self.storageRef.count }
    
    /// See `UnkeyedEncodingContainer.nestedContainer(keyedBy:)`
    public func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let newStorageRef = ReferenceWrappedDictionary<String, Any>.init()
        self.storageRef.append(newStorageRef)
        return self.makeContainer(keyedBy: keyType, codingPath: self.codingPath + [self.currentCodingKey], storageRef: newStorageRef)
    }
    
    /// See `UnkeyedEncodingContainer.nestedUnkeyedContainer()`
    public func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let newStorageRef = ReferenceWrappedArray<Any>.init()
        self.storageRef.append(newStorageRef)
        return self.makeUnkeyedContainer(codingPath: self.codingPath + [self.currentCodingKey], storageRef: newStorageRef)
    }
    
    /// See `ExtendedUnkeyedEncodingContainer.append(_:)`
    func append<T>(_ value: T) throws {
        self.storageRef.append(value)
    }

    /// Explicitly override encoding for `URL` to encode as simple `String`.
    /// This matches the behavior of `JSONEncoder`.
    public func encode<T: Encodable>(_ value: T) throws {
        if let url = value as? URL {
            try self.encode(url.absoluteString)
        } else {
            try self.passthrough(value, forKey: self.currentCodingKey)
        }
    }
}

/// The single-value encoding container for `_KVHashEncoder`
fileprivate final class _KVHashSingleValueEncodingContainer:
    _KVHashEncodingContainerBase<(Any) -> Void>, ExtendedSingleValueEncodingContainer
{
    /// See `ExtendedSingleValueEncodingContainer.set(value:)`
    func set<T>(value: T) throws {
        self.storageRef(value)
    }
    
    /// No further implementation is required.
    
    /// Explicitly override encoding for `URL` to encode as simple `String`.
    /// This matches the behavior of `JSONEncoder`.
    public func encode<T: Encodable>(_ value: T) throws {
        if let url = value as? URL {
            try self.encode(url.absoluteString)
        } else {
            try self.passthrough(value, forKey: nil)
        }
    }
}

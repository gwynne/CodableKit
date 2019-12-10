import Foundation

/// A reference wrapper for `Swift.Dictionary`. Provides most of the basic
/// `Dictionary` interfaces, but not all. It is intended for use in special
/// applications, such as `Encoder` implementations, where reference semantics
/// are useful for both speed and simplicity.
public final class ReferenceWrappedDictionary<Key: Hashable, Value>: ExpressibleByDictionaryLiteral {

    /// The equivalent `Dictionary` type.
    public typealias DictionaryType = [Key: Value]
    
    /// Internal storage
    private var _raw: DictionaryType = [:]
    
    /// Create an empty dictionary.
    public init() {}
    
    /// Wrap an existing dictionary in a reference wrapper. Obviously, further
    /// mutations to the input dictionary will not be reflected.
    public init(_ other: DictionaryType) {
        self._raw = other
    }
    
    /// Create a ref-wrapped dictionary from a sequence of elements. Matches the
    /// corresponding `Dictionary` initializer's semantics.
    public init<S: Sequence>(_ sequence: S) where S.Element == (Key, Value) {
        self._raw = .init(uniqueKeysWithValues: sequence)
    }
    
    /// See `Dictionary.keys`
    public var keys: DictionaryType.Keys { _raw.keys }
    
    /// See `Dictionary.values`
    public var values: DictionaryType.Values { _raw.values }
    
    /// See `Dictionary.count`
    public var count: Int { _raw.count }
    
    /// Read-write access to elements of the dictionary by key lookup. Shares,
    /// to the extent possible, the semantics of `Dictionary`'s own `subscript`.
    public subscript(key: Key) -> Value? {
        get {
            return _raw[key]
        }
        set {
            _raw[key] = newValue
        }
    }
    
    /// See `Dictionary.map(_:)`
    public func map<T>(_ transform: ((Key, Value)) throws -> T) rethrows -> [T] {
        return try _raw.map(transform)
    }
    
    /// See `ExpressibleByDictionaryLiteral.init(dictionaryLiteral:)`
    public convenience init(dictionaryLiteral elements: (DictionaryType.Key, DictionaryType.Value)...) {
        self.init(elements)
    }
    
    /// Return the contents as a value type. May incur the overhead of a copy.
    public var unwrappedDictionary: DictionaryType { self._raw }
    
    /// Perform an operation on the raw dictionary value while maintaining
    /// reference semantics. Useful for invoking `Dictionary` methods not
    /// exposed by the wrapper.
    public func withRawDictionary<R>(`do` closure: (inout DictionaryType) throws -> R) rethrows -> R {
        return try closure(&_raw)
    }

}

/// A reference wrapper for `Swift.Array`. Provides most of the basic `Array`
/// interfaces, but not all. It is intended for use in special applications,
/// such as `Encoder` implementations, where reference semantics are useful for
/// both speed and simplicity.
public final class ReferenceWrappedArray<Element> {
    
    /// The equivalent `Array` type.
    public typealias ArrayType = [Element]
    
    /// Internal storage
    private var _raw: [Element] = []
    
    /// Create an empty array.
    public init() {}
    
    /// Reference-wrap an existing array. Further changes to the original array
    /// are not honored by the reference wrapper.
    public init(_ other: ArrayType) {
        self._raw = other
    }
    
    /// See Array.count
    public var count: Int { _raw.count }
    
    /// Read/write index-based access to the array's elements. Matches to the
    /// maximum extent possible the rules of `Array<Element>`'s subscript. This
    /// in particular includes the bounds handling.
    public subscript(index: ArrayType.Index) -> Element {
        get {
            return self._raw[index]
        }
        set {
            self._raw[index] = newValue
        }
    }
    
    /// Append an element to the end of the array. See also `Array.append(_:)`
    public func append(_ value: Element) {
        _raw.append(value)
    }
    
    /// See `Array.map(_:)`
    public func map<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        return try _raw.map(transform)
    }

    /// Return the contents as a value type. May incur the overhead of a copy.
    public var unwrappedArray: [Element] { self._raw }
    

    /// Perform an operation on the raw array value while maintaining reference
    /// semantics. Useful for invoking `Array` methods not exposed by the
    /// wrapper.
    public func withRawArray<R>(`do` closure: (inout ArrayType) throws -> R) rethrows -> R {
        return try closure(&_raw)
    }
}

extension ReferenceWrappedArray: Equatable where Element: Equatable {

    /// `Equatable` conformance.
    static public func ==(lhs: ReferenceWrappedArray, rhs: ReferenceWrappedArray) -> Bool {
        return lhs._raw == rhs._raw
    }
    
}


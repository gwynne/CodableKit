/// A type-erased wrapper for `Optional`s whose only function is to answer the
/// question "is this value `nil`?" without needing to know the `Wrapped` type.
public protocol AnyOptionalType {
    var hasValue: Bool { get } // aka isNil
    
    static var nilValue: Any? { get }
}

/// Conform `Optional` to `AnyOptionalType` to provide the actual implementation
/// of the wrapper protocol.
extension Optional: AnyOptionalType {

    public var hasValue: Bool {
        return self.map { _ in true } ?? false
    }
    
    public static var nilValue: Any? {
        return self.none
    }
    
}

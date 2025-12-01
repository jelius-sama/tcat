typealias CString = UnsafeMutablePointer<CChar>
typealias OptionalCString = UnsafeMutablePointer<Optional<CChar>>

typealias ConstCString = UnsafePointer<CChar>
typealias OptionalConstCString = UnsafePointer<Optional<CChar>>

typealias CStringPtr = UnsafeMutablePointer<CString>
typealias OptionalCStringPtr = UnsafeMutablePointer<Optional<CString>>

typealias ConstCStringPtr = UnsafePointer<ConstCString>
typealias OptionalConstCStringPtr = UnsafePointer<Optional<ConstCString>>

typealias CPtr = UnsafeMutableRawPointer
typealias ConstCPtr = UnsafeRawPointer

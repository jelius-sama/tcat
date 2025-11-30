import Foundation

extension String {
    var toCStr: UnsafeMutablePointer<CChar> {
        strdup(self)
    }
}

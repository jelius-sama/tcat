#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

import Foundation
import Golang

let TCP_OK: CInt = 0
let TCP_ERR: CInt = 1
let PORT: String = ":6969"

@_cdecl("ConnHandler")
func ConnHandler(_ arg: Optional<CPtr>) {
    let conn = UInt64(UInt(bitPattern: arg))
    var buf = Array<UInt8>(repeating: 0, count: 1024)

    while true {
        var n: Int32 = 0
        let readOK = buf.withUnsafeMutableBytes { buffer in
            TCPRead(conn, buffer.baseAddress, Int32(buffer.count), &n) == TCP_OK
        }

        if !readOK || n <= 0 {
            TCPConnClose(conn)
            return
        }

        var written: Int32 = 0
        let writeOK = buf.withUnsafeMutableBytes { buffer in
            TCPWrite(conn, buffer.baseAddress, n, &written) == TCP_OK
        }
        if !writeOK {
            TCPConnClose(conn)
            return
        }
    }
}

@_cdecl("main")
func main(_: Int32, _: CStringPtr) -> Int32 {
    var listener: UInt64 = 0
    guard TCPListen(PORT.toCStr, &listener) == TCP_OK else {
        fputs("Failed to listen on \(PORT)\n", stderr)
        return 1
    }

    fputs("Server listening on \(PORT)\n", stdout)

    let fn = unsafeBitCast(
        ConnHandler as @convention(c) (Optional<CPtr>) -> Void,
        to: CPtr.self
    )

    while true {
        var conn: UInt64 = 0
        if TCPAccept(listener, &conn) != TCP_OK {
            continue
        }

        let arg = CPtr(bitPattern: UInt(conn))
        _ = TaskLaunchVoid(fn, arg)
    }
}

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
import Golang
import Foundation

let TCP_OK: CInt = 0
let TCP_ERR: CInt = 1

@_cdecl("main")
func main(_: Int32, _: CStringPtr) -> Int32 {
    // ---- Listen ----
    var listener: UInt64 = 0
    let addr = ":9000".cString(using: .utf8)!
    let result = TCPListen(addr, &listener)
    if result != TCP_OK {
        fputs("Failed to listen on :9000\n", stderr)
        return 1
    }
    fputs("Server listening on :9000\n", stdout)

    while true {
        // ---- Accept ----
        var conn: UInt64 = 0
        if TCPAccept(listener, &conn) != TCP_OK {
            continue
        }

        // ---- Spawn handler ----
        Thread.detachNewThread { [conn] in
            handleConn(conn)
        }
    }

    return 0;
}

func handleConn(_ conn: UInt64) {
    var buf = [UInt8](repeating: 0, count: 1024)

    while true {
        var n: Int32 = 0

        // ---- TCPRead ----
        let readCode = buf.withUnsafeMutableBytes {
            TCPRead(conn, $0.baseAddress, Int32($0.count), &n)
        }
        if readCode != TCP_OK || n <= 0 {
            TCPConnClose(conn)
            return
        }

        // ---- TCPWrite ----
        var written: Int32 = 0
        let writeCode = buf.withUnsafeMutableBytes {
            TCPWrite(conn, $0.baseAddress, n, &written)
        }
        if writeCode != TCP_OK {
            TCPConnClose(conn)
            return
        }
    }
}

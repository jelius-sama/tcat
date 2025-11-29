#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

import Golang

@_cdecl("ConnHandler")
func ConnHandler(_ arg: Optional<CPtr>) {
    let conn = UInt64(UInt(bitPattern: arg))
    var buf = Array<UInt8>(repeating: 0, count: 1024)

    while true {
        var n: Int32 = 0
        let readOK = buf.withUnsafeMutableBytes { b in
            TCPRead(conn, b.baseAddress, Int32(b.count), &n) == TCP_OK
        }
        if !readOK || n <= 0 {
            TCPConnClose(conn)
            return
        }

        var written: Int32 = 0
        let writeOK = buf.withUnsafeMutableBytes { b in
            TCPWrite(conn, b.baseAddress, n, &written) == TCP_OK
        }
        if !writeOK {
            TCPConnClose(conn)
            return
        }
    }
}

func runServer(port: String) -> Int32 {
    var listener: UInt64 = 0
    guard TCPListen((":" + port).toCStr, &listener) == TCP_OK else {
        fputs("Failed to listen on :\(port)\n", stderr)
        return 1
    }

    fputs("Server listening on :\(port)\n", stdout)

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

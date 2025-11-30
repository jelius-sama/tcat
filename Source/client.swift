import Foundation
import Golang

#if canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

// read loop for the client — runs in a Go task
@_cdecl("ClientReadLoop")
func ClientReadLoop(_ arg: CPtr?) {
    let conn = UInt64(UInt(bitPattern: arg))
    var buf = [UInt8](repeating: 0, count: 1024)

    while true {
        var n: Int32 = 0
        let ok = buf.withUnsafeMutableBytes { b in
            TCPRead(conn, b.baseAddress, Int32(b.count), &n) == TCP_OK
        }
        if !ok || n <= 0 {
            fputs("Disconnected.\n", stdout)
            TCPConnClose(conn)
            exit(0)
        }

        let msg = String(decoding: buf[0..<Int(n)], as: UTF8.self)

        if msg.hasPrefix("USER ") {
            let start = msg.index(msg.startIndex, offsetBy: 5)
            let name = String(msg[start...])
            fputs("\(name): ", stdout)
        } else {
            fputs(msg + "\n", stdout)
        }
        fflush(stdout)
    }
}

func runClient(port: String) -> Int32 {
    var conn: UInt64 = 0
    guard TCPConnect((":" + port).toCStr, &conn) == TCP_OK else {
        fputs("Client: failed to connect to :\(port)\n", stderr)
        return 1
    }
    fputs("Connected to :\(port)\n", stdout)

    let fn = unsafeBitCast(
        ClientReadLoop as @convention(c) (CPtr?) -> Void,
        to: CPtr.self
    )
    let arg = CPtr(bitPattern: UInt(conn))
    _ = TaskLaunchVoid(fn, arg)

    // write loop stays in main thread
    while true {
        if let line = readLine(strippingNewline: true) {
            let bytes = Array(line.utf8)
            var written: Int32 = 0
            bytes.withUnsafeBytes { b in
                let ptr = UnsafeMutableRawPointer(mutating: b.baseAddress)
                TCPWrite(conn, ptr, Int32(bytes.count), &written)
            }
        }
    }
}

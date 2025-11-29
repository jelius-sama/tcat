#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

import Golang

func runClient(port: String) -> Int32 {
    var conn: UInt64 = 0
    guard TCPConnect((":" + port).toCStr, &conn) == TCP_OK else {
        fputs("Client: failed to connect to :\(port)\n", stderr)
        return 1
    }
    fputs("Connected to :\(port)\n", stdout)

    var buf = Array<UInt8>(repeating: 0, count: 1024)

    while true {
        if let line = readLine(strippingNewline: true) {
            let bytes = Array(line.utf8)
            var written: Int32 = 0

            bytes.withUnsafeBytes { b in
                let ptr = UnsafeMutableRawPointer(mutating: b.baseAddress)
                TCPWrite(conn, ptr, Int32(bytes.count), &written)
            }
        }


        var n: Int32 = 0
        let readOK = buf.withUnsafeMutableBytes { b in
            TCPRead(conn, b.baseAddress, Int32(b.count), &n) == TCP_OK
        }
        if !readOK || n <= 0 {
            fputs("Disconnected.\n", stdout)
            TCPConnClose(conn)
            return 0
        }

        let received = String(decoding: buf[0..<Int(n)], as: UTF8.self)
        fputs(received + "\n", stdout)
    }
}


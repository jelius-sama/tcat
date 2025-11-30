import Foundation
import Golang

#if canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

func sendToConn(_ conn: UInt64, _ text: String) {
    let bytes = Array(text.utf8)
    var written: Int32 = 0

    bytes.withUnsafeBytes { b in
        let ptr = UnsafeMutableRawPointer(mutating: b.baseAddress)
        TCPWrite(conn, ptr, Int32(bytes.count), &written)
    }
}

func broadcast(_ text: String, except: UInt64? = nil) {
    let bytes = Array(text.utf8)
    let ex = except ?? 0

    bytes.withUnsafeBytes { b in
        let ptr = UnsafeMutableRawPointer(mutating: b.baseAddress)
        _ = TCPBroadcast(ptr, Int32(bytes.count), ex)
    }
}

// ----------------------------------------------------------
// per-connection context:
//
// [0..7]   : UInt64 conn handle
// [8.....] : username as NUL-terminated UTF-8
// ----------------------------------------------------------
@_cdecl("ConnHandler")
func ConnHandler(_ arg: CPtr?) {
    guard let raw = arg else { return }
    let ctx = UnsafeMutableRawPointer(raw)

    let conn = ctx.load(as: UInt64.self)
    let namePtr = ctx.advanced(by: 8).assumingMemoryBound(to: CChar.self)
    let username = String(cString: namePtr)

    var buf = [UInt8](repeating: 0, count: 1024)

    while true {
        var n: Int32 = 0
        let readOK = buf.withUnsafeMutableBytes { b in
            TCPRead(conn, b.baseAddress, Int32(b.count), &n) == TCP_OK
        }
        if !readOK || n <= 0 {
            TCPConnClose(conn)

            let msg = "\(username) has left the chat"
            broadcast(msg, except: conn)
            fputs("[leave] \(msg)\n", stdout)

            free(ctx)
            return
        }

        let text = String(decoding: buf[0..<Int(n)], as: UTF8.self)
        let msg = "\(username): \(text)"
        broadcast(msg, except: conn)
    }
}

// Accept loop handler - runs in its own goroutine
@_cdecl("AcceptLoopHandler")
func AcceptLoopHandler(_ arg: CPtr?) {
    guard let raw = arg else { return }
    let listener = UInt64(UInt(bitPattern: raw))

    let connHandlerFn = unsafeBitCast(
        ConnHandler as @convention(c) (CPtr?) -> Void,
        to: CPtr.self
    )

    while true {
        var conn: UInt64 = 0
        if TCPAccept(listener, &conn) != TCP_OK {
            continue
        }

        // generate simple random username
        let id = UInt32.random(in: 0..<100_000)
        let username = "user\(id)"

        // handshake: tell this client its username
        sendToConn(conn, "USER " + username)

        // announce join to everyone except the joining client
        let joinMsg = "\(username) has joined the chat"
        broadcast(joinMsg, except: conn)
        fputs("[join] \(joinMsg)\n", stdout)

        // build per-connection context blob
        let nameBytes = Array(username.utf8)
        let total = 8 + nameBytes.count + 1

        let ctx = UnsafeMutableRawPointer(malloc(total))!

        ctx.storeBytes(of: conn, as: UInt64.self)

        let namePtr = ctx.advanced(by: 8).assumingMemoryBound(to: UInt8.self)
        _ = nameBytes.withUnsafeBytes { src in
            memcpy(namePtr, src.baseAddress!, nameBytes.count)
        }
        namePtr[nameBytes.count] = 0

        let arg = CPtr(ctx)
        _ = TaskLaunchVoid(connHandlerFn, arg)
    }
}

func runServer(port: String) -> Int32 {
    var listener: UInt64 = 0
    guard TCPListen((":" + port).toCStr, &listener) == TCP_OK else {
        fputs("Failed to listen on :\(port)\n", stderr)
        return 1
    }

    fputs("Server listening on :\(port)\n", stdout)

    // Launch accept loop in a goroutine
    let acceptLoopFn = unsafeBitCast(
        AcceptLoopHandler as @convention(c) (CPtr?) -> Void,
        to: CPtr.self
    )
    let listenerArg = CPtr(bitPattern: UInt(listener))
    _ = TaskLaunchVoid(acceptLoopFn, listenerArg)

    // Keep main thread alive - server runs indefinitely
    while true {
        sleep(1)
    }
}

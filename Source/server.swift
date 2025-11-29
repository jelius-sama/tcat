#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

import Golang

// ----------------------------------------------------------
// global client registry (conn -> username)
// ----------------------------------------------------------

var clients = [UInt64: String]()
var clientsLock = pthread_mutex_t()

@inline(__always)
func lockClients() {
    pthread_mutex_lock(&clientsLock)
}

@inline(__always)
func unlockClients() {
    pthread_mutex_unlock(&clientsLock)
}

func sendToConn(_ conn: UInt64, _ text: String) {
    let bytes = Array(text.utf8)
    var written: Int32 = 0

    bytes.withUnsafeBytes { b in
        let ptr = UnsafeMutableRawPointer(mutating: b.baseAddress)
        TCPWrite(conn, ptr, Int32(bytes.count), &written)
    }
}

func broadcast(_ text: String) {
    lockClients()
    let conns = Array(clients.keys)
    unlockClients()

    for c in conns {
        sendToConn(c, text)
    }
}

func broadcastExcept(_ text: String, except: UInt64) {
    lockClients()
    let conns = Array(clients.keys)
    unlockClients()

    for c in conns where c != except {
        sendToConn(c, text)
    }
}

func usernameForConn(_ conn: UInt64) -> String? {
    lockClients()
    let name = clients[conn]
    unlockClients()
    return name
}

// ----------------------------------------------------------
// per-connection handler (runs in Go task)
// ----------------------------------------------------------
@_cdecl("ConnHandler")
func ConnHandler(_ arg: Optional<CPtr>) {
    let conn = UInt64(UInt(bitPattern: arg))
    var buf = Array<UInt8>(repeating: 0, count: 1024)

    let username = usernameForConn(conn) ?? "unknown"

    while true {
        var n: Int32 = 0
        let readOK = buf.withUnsafeMutableBytes { b in
            TCPRead(conn, b.baseAddress, Int32(b.count), &n) == TCP_OK
        }
        if !readOK || n <= 0 {
            // remove client from registry
            lockClients()
            let name = clients[conn]
            clients[conn] = nil
            unlockClients()

            TCPConnClose(conn)

            if let name = name {
                let msg = "\(name) has left the chat"
                broadcast(msg)
                fputs("[leave] \(msg)\n", stdout)
            }
            return
        }

        let text = String(decoding: buf[0..<Int(n)], as: UTF8.self)
        let msg = "\(username): \(text)"
        broadcastExcept(msg, except: conn)
    }
}

// ----------------------------------------------------------
// server bootstrap
// ----------------------------------------------------------
func runServer(port: String) -> Int32 {
    pthread_mutex_init(&clientsLock, nil)
    srandom(UInt32(time(nil)))

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

        // generate simple random username
        let id = UInt32.random(in: 0..<100000)
        let username = "user\(id)"

        // register client
        lockClients()
        clients[conn] = username
        unlockClients()

        // handshake: tell this client its username
        sendToConn(conn, "USER " + username)

        // announce join to everyone except the joining client
        let joinMsg = "\(username) has joined the chat"
        broadcastExcept(joinMsg, except: conn)

        fputs("[join] \(joinMsg)\n", stdout)

        let arg = CPtr(bitPattern: UInt(conn))
        _ = TaskLaunchVoid(fn, arg)
    }
}

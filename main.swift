import Foundation
import golang

// Signal handling using Foundation
var running = true

func setupSignalHandler() {
    signal(SIGINT) { _ in
        print("\nSIGINT received. Cleaning up...")
        running = false
    }
}

// Monitor loop callback - must match C function signature
func monitorLoop(context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    guard let context = context else { return nil }

    let config = context.assumingMemoryBound(to: MonitorConfig.self)

    while true {
        usleep(UInt32(config.pointee.intervalMs * 1000))

        let currentCount = HttpGetRequestCount()

        // Allocate on heap so it persists across channel
        let countPtr = UnsafeMutablePointer<UInt64>.allocate(capacity: 1)
        countPtr.pointee = currentCount

        ChannelSend(config.pointee.statsChannel, countPtr)
    }
}

@_cdecl("main")
func main(_: Int32, _: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
    // Need to strdup because the string must persist beyond withCString scope
    let addrCopy = strdup(":6969")

    setupSignalHandler()

    var hist: UInt64 = 0

    print("╔═════════════════════════════════════════════════════════════════╗")
    print("║           Swift-Go FFI Demo: Async Tasks & Channels             ║")
    print("╚═════════════════════════════════════════════════════════════════╝")

    // Register HTTP routes
    var msg: UnsafeMutablePointer<CChar>?

    "/".withCString { path in
        "Hello, FFI World!".withCString { response in
            msg = HttpRegisterRoute(UnsafeMutablePointer(mutating: path), UnsafeMutablePointer(mutating: response))
            if let msg = msg {
                print(String(cString: msg), terminator: "")
                free(msg)
            }
        }
    }

    "/kazu".withCString { path in
        "Hello, Kazuma!".withCString { response in
            msg = HttpRegisterRoute(UnsafeMutablePointer(mutating: path), UnsafeMutablePointer(mutating: response))
            if let msg = msg {
                print(String(cString: msg), terminator: "")
                free(msg)
            }
        }
    }

    "/coding".withCString { path in
        "ABSOLUTE CODING!!!".withCString { response in
            msg = HttpRegisterRoute(UnsafeMutablePointer(mutating: path), UnsafeMutablePointer(mutating: response))
            if let msg = msg {
                print(String(cString: msg), terminator: "")
                free(msg)
            }
        }
    }

    "/ping".withCString { path in
        "pong".withCString { response in
            msg = HttpRegisterRoute(UnsafeMutablePointer(mutating: path), UnsafeMutablePointer(mutating: response))
            if let msg = msg {
                print(String(cString: msg), terminator: "")
                free(msg)
            }
        }
    }

    // Launch HTTP server asynchronously
    let serverTask = TaskLaunch(unsafeBitCast(HttpStartServer as @convention(c) (UnsafeMutablePointer<CChar>?) -> UnsafeMutablePointer<CChar>?, to: UnsafeMutableRawPointer.self), addrCopy)

    // Create buffered channel for statistics
    let statsChannel = ChannelCreate(16)

    // Configure and launch monitor
    let monitorConfig = UnsafeMutablePointer<MonitorConfig>.allocate(capacity: 1)
    monitorConfig.pointee.statsChannel = statsChannel
    monitorConfig.pointee.intervalMs = 1000

    let monitorTask = TaskLaunch(unsafeBitCast(monitorLoop as @convention(c) (UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?, to: UnsafeMutableRawPointer.self), monitorConfig)

    print("\n📊 Real-time Statistics (Ctrl+C to quit)")
    print("────────────────────────────────────────────────────────────────")

    // Event loop using non-blocking poll pattern
    while running {
        // Check if server crashed (non-blocking)
        var errorMsg: UnsafeMutableRawPointer?
        let serverStatus = TaskPoll(serverTask, &errorMsg)

        if serverStatus == 0 {
            // Server task completed (should never happen unless error)
            if let errorMsg = errorMsg {
                print("\n❌ SERVER ERROR: \(String(cString: errorMsg.assumingMemoryBound(to: CChar.self)))")
                free(errorMsg)
            }
            break
        } else if serverStatus == -2 {
            print("\n⚠️  Server task handle invalid")
            break
        }
        // serverStatus == -1 means still running (expected)

        // Receive statistics from monitor (blocking)
        let statsPtr = ChannelRecv(statsChannel)

        if statsPtr == nil {
            print("\n📡 Stats channel closed")
            break
        }

        let stats = statsPtr!.assumingMemoryBound(to: UInt64.self).pointee

        if hist != stats {
            // Display statistics
            print("│ Total Requests: \(stats)")
        }

        hist = stats
        free(statsPtr)
    }

    free(addrCopy)
    ChannelClose(statsChannel)
    TaskCleanup(serverTask)
    TaskCleanup(monitorTask)
    monitorConfig.deallocate()

    print("\n🧹 Cleaned up.")
    print("👋 Goodbye!")
    return 0
}

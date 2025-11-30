import Foundation
import Golang

#if canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

func printHelp(_ program: String) {
    let reset = "\u{001B}[0m"
    let bold = "\u{001B}[1m"
    let dim = "\u{001B}[2m"
    let cyan = "\u{001B}[36m"
    let green = "\u{001B}[32m"
    let yellow = "\u{001B}[33m"
    let blue = "\u{001B}[34m"
    let magenta = "\u{001B}[35m"

    let msg = """
        \(cyan)\(bold)
        ╔════════════════════════════════════════════════════════════════╗
        ║                                                                ║
        ║   \(yellow)████████\(cyan) ██████  █████  ████████                           ║
        ║      \(yellow)██\(cyan)   ██      ██   ██    ██                              ║
        ║      \(yellow)██\(cyan)   ██      ███████    ██     \(dim)Terminal Chat\(reset)\(cyan)\(bold)       ║
        ║      \(yellow)██\(cyan)   ██      ██   ██    ██                              ║
        ║      \(yellow)██\(cyan)    ██████ ██   ██    ██                              ║
        ║                                                                ║
        ╚════════════════════════════════════════════════════════════════╝
        \(reset)
        \(bold)DESCRIPTION\(reset)
          A real-time terminal chat application showcasing Go-Swift FFI
          through C ABI. Leverages Go's concurrency for networking and
          Swift's expressiveness for application logic.

          \(dim)⚠️  Authentication not yet implemented - test/demo purposes only\(reset)

        \(bold)USAGE\(reset)
          \(green)\(program)\(reset) \(cyan)[MODE]\(reset) \(yellow)[OPTIONS]\(reset)

        \(bold)MODES\(reset)
          \(cyan)-s, --server\(reset)              Start server and listen for connections
          \(cyan)-c, --client\(reset)              Connect to a running server
          \(cyan)-h, --help\(reset)                Display this help message

        \(bold)OPTIONS\(reset)
          \(yellow)-p, --port\(reset) \(magenta)<port>\(reset)         Port number (default: 6969)

        \(bold)EXAMPLES\(reset)
          \(dim)# Start server on default port\(reset)
          \(green)\(program) -s\(reset)

          \(dim)# Start server on custom port\(reset)
          \(green)\(program) -s -p 9000\(reset)

          \(dim)# Connect as client\(reset)
          \(green)\(program) -c -p 9000\(reset)

          \(dim)# Connect multiple clients (in different terminals)\(reset)
          \(green)\(program) -c\(reset)

        \(bold)FEATURES\(reset)
          🎨  Twitch-style colorized usernames
          ⚡  Real-time message broadcasting
          🖥️  Beautiful terminal UI with scrolling
          💬  Blinking cursor for input feedback
          🔄  Multi-client support via Go goroutines

        \(bold)CLIENT CONTROLS\(reset)
          \(cyan)Type\(reset)          Enter your message
          \(cyan)Enter\(reset)         Send message to all users
          \(cyan)Backspace\(reset)     Delete last character
          \(cyan)Ctrl+C\(reset)        Exit client gracefully

        \(bold)ARCHITECTURE\(reset)
          \(dim)┌──────────────────┐\(reset)
          \(dim)│  Swift Layer     │\(reset)  Application logic, TUI, input handling
          \(dim)├──────────────────┤\(reset)
          \(dim)│  C ABI Bridge    │\(reset)  Zero-cost FFI abstraction
          \(dim)├──────────────────┤\(reset)
          \(dim)│  Go Runtime      │\(reset)  TCP, goroutines, channels, atomics
          \(dim)└──────────────────┘\(reset)

        \(bold)MORE INFO\(reset)
          Repository: \(blue)https://github.com/jelius-sama/tcat\(reset)
          Issues:     \(blue)https://github.com/jelius-sama/tcat/issues\(reset)

        \(dim)Built with Go and Swift\(reset)

        """
    fputs(msg, stdout)
}
func parseArgs(_ args: [String]) -> (mode: String?, port: String?) {
    var mode: String? = nil
    var port: String? = nil

    var i = 1
    while i < args.count {
        let a = args[i]

        if a == "-h" || a == "--h" || a == "-help" || a == "--help" || a == "help" {
            mode = "help"
        } else if a == "-c" || a == "--c" || a == "-client" || a == "--client" {
            mode = "client"
        } else if a == "-s" || a == "--s" || a == "-server" || a == "--server" {
            mode = "server"
        } else if a == "-p" || a == "--p" || a == "-port" || a == "--port" {
            if i + 1 < args.count {
                port = args[i + 1]
                i += 1
            }
        }
        i += 1
    }

    return (mode, port)
}

@_cdecl("main")
func main(_ argc: Int32, _ argv: CStringPtr) -> Int32 {
    let args = CommandLine.arguments
    let (mode, portOverride) = parseArgs(args)
    let port = portOverride ?? "6969"

    switch mode {
    case "help", .none:
        printHelp(args[0])
        return 0
    case "client": return runClient(port: port)
    case "server": return runServer(port: port)
    default:
        printHelp(args[0])
        return 1
    }
}

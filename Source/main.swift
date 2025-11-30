import Foundation
import Golang

#if canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

func printHelp(_ program: String) {
    let msg =
        """
        usage:
          \(program) [mode] [port]

        modes:
          -h | --h | -help | --help | help      print this help
          -s | --s | -server | --server         run server
          -c | --c | -client | --client         run client

        optional:
          -p <port>  or  --p <port> or -port <port> or --port <port>
        examples:
          \(program) -s -p 9000
          \(program) -c -p 9000\n
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

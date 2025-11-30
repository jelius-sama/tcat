import Foundation
import Golang

#if canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

// ANSI escape codes
let ANSI_CLEAR_SCREEN = "\u{001B}[2J"
let ANSI_CURSOR_HOME = "\u{001B}[H"
let ANSI_CURSOR_HIDE = "\u{001B}[?25l"
let ANSI_CURSOR_SHOW = "\u{001B}[?25h"
let ANSI_CLEAR_LINE = "\u{001B}[2K"
let ANSI_SAVE_CURSOR = "\u{001B}[s"
let ANSI_RESTORE_CURSOR = "\u{001B}[u"
let ANSI_RESET = "\u{001B}[0m"

// Color palette (Twitch-style vibrant colors)
let USER_COLORS: [String] = [
    "\u{001B}[38;5;196m",  // Red
    "\u{001B}[38;5;208m",  // Orange
    "\u{001B}[38;5;226m",  // Yellow
    "\u{001B}[38;5;46m",  // Green
    "\u{001B}[38;5;51m",  // Cyan
    "\u{001B}[38;5;21m",  // Blue
    "\u{001B}[38;5;201m",  // Magenta
    "\u{001B}[38;5;165m",  // Pink
    "\u{001B}[38;5;219m",  // Light Pink
    "\u{001B}[38;5;118m",  // Lime
    "\u{001B}[38;5;159m",  // Sky Blue
    "\u{001B}[38;5;213m",  // Hot Pink
    "\u{001B}[38;5;221m",  // Gold
    "\u{001B}[38;5;87m",  // Aqua
    "\u{001B}[38;5;171m",  // Purple
]

// Simple spinlock using Go's atomic operations
class SpinLock {
    private var flag: Int32 = 0

    func lock() {
        while AtomicCompareAndSwapInt32(&flag, 0, 1) == 0 {
            // Spin - yield to other threads
            sched_yield()
        }
    }

    func unlock() {
        AtomicStoreInt32(&flag, 0)
    }
}

// Terminal state
class TerminalState {
    var rows: Int = 24
    var cols: Int = 80
    var messages: [String] = []
    var username: String = ""
    var inputBuffer: String = ""
    var lock = SpinLock()
    var userColorMap: [String: String] = [:]
    var cursorVisible: Bool = true

    init() {
        updateTerminalSize()
        startCursorBlink()
    }

    func startCursorBlink() {
        let fn = unsafeBitCast(
            CursorBlinkLoop as @convention(c) (CPtr?) -> Void,
            to: CPtr.self
        )
        _ = TaskLaunchVoid(fn, nil)
    }

    func updateTerminalSize() {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0 {
            rows = Int(ws.ws_row)
            cols = Int(ws.ws_col)
        }
    }

    func getColorForUser(_ username: String) -> String {
        if let color = userColorMap[username] {
            return color
        }

        // Hash username to get consistent color
        var hash: UInt = 5381
        for char in username.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt(char)
        }

        let colorIndex = Int(hash % UInt(USER_COLORS.count))
        let color = USER_COLORS[colorIndex]
        userColorMap[username] = color
        return color
    }

    func colorizeMessage(_ msg: String) -> String {
        // Check if message has username format: "username: message"
        if let colonIndex = msg.firstIndex(of: ":") {
            let username = String(msg[..<colonIndex])
            let message = String(msg[msg.index(after: colonIndex)...])

            let color = getColorForUser(username)
            return "\(color)\(username)\(ANSI_RESET):\(message)"
        }

        // System messages (join/leave) - use dim gray
        if msg.contains("joined") || msg.contains("left") {
            return "\u{001B}[38;5;240m\(msg)\(ANSI_RESET)"
        }

        return msg
    }

    func addMessage(_ msg: String) {
        lock.lock()
        messages.append(msg)
        // Keep only last N messages to fit screen
        let maxMessages = max(rows - 3, 10)
        if messages.count > maxMessages * 2 {
            messages.removeFirst(messages.count - maxMessages)
        }
        lock.unlock()
    }

    func render() {
        lock.lock()

        // Move cursor to top
        write(STDOUT_FILENO, ANSI_CURSOR_HOME, ANSI_CURSOR_HOME.utf8.count)

        let chatHeight = rows - 2
        let visibleMessages = messages.suffix(chatHeight)

        // Render messages with colors
        for (idx, msg) in visibleMessages.enumerated() {
            // Position cursor at line
            let pos = "\u{001B}[\(idx + 1);1H"
            write(STDOUT_FILENO, pos, pos.utf8.count)
            write(STDOUT_FILENO, ANSI_CLEAR_LINE, ANSI_CLEAR_LINE.utf8.count)

            // Note: counting with ANSI codes is tricky, so we use a rough estimate
            let displayMsg = msg.count > cols ? String(msg.prefix(cols - 3)) + "..." : msg
            let coloredDisplay = colorizeMessage(displayMsg)
            write(STDOUT_FILENO, coloredDisplay, coloredDisplay.utf8.count)
        }

        // Clear remaining lines in chat area
        for idx in visibleMessages.count..<chatHeight {
            let pos = "\u{001B}[\(idx + 1);1H"
            write(STDOUT_FILENO, pos, pos.utf8.count)
            write(STDOUT_FILENO, ANSI_CLEAR_LINE, ANSI_CLEAR_LINE.utf8.count)
        }

        // Draw separator line with color
        let separatorLine = rows - 1
        let separator = "\u{001B}[38;5;240m" + String(repeating: "─", count: cols) + ANSI_RESET
        let pos = "\u{001B}[\(separatorLine);1H"
        write(STDOUT_FILENO, pos, pos.utf8.count)
        write(STDOUT_FILENO, separator, separator.utf8.count)

        // Draw input line with user color
        let inputLine = rows
        let userColor = getColorForUser(username)
        let prompt = "\(userColor)\(username)\(ANSI_RESET): "
        let inputPos = "\u{001B}[\(inputLine);1H"
        write(STDOUT_FILENO, inputPos, inputPos.utf8.count)
        write(STDOUT_FILENO, ANSI_CLEAR_LINE, ANSI_CLEAR_LINE.utf8.count)
        write(STDOUT_FILENO, prompt, prompt.utf8.count)

        // Display input buffer (truncate if too long)
        let maxInputLen = cols - username.count - 3 - 2  // account for prompt and cursor
        let displayInput =
            inputBuffer.count > maxInputLen ? String(inputBuffer.suffix(maxInputLen)) : inputBuffer
        write(STDOUT_FILENO, displayInput, displayInput.utf8.count)

        // Draw cursor (blinking block)
        if cursorVisible {
            let cursor = "\u{001B}[48;5;255m \u{001B}[0m"  // White block
            write(STDOUT_FILENO, cursor, cursor.utf8.count)
        } else {
            write(STDOUT_FILENO, " ", 1)
        }

        lock.unlock()
    }
}

var terminalState: TerminalState!

// Cursor blink loop
@_cdecl("CursorBlinkLoop")
func CursorBlinkLoop(_ arg: CPtr?) {
    while true {
        usleep(500_000)  // 500ms
        if terminalState != nil {
            terminalState.cursorVisible.toggle()
            terminalState.render()
        }
    }
}

// Terminal setup
func setupTerminal() {
    // Hide cursor
    write(STDOUT_FILENO, ANSI_CURSOR_HIDE, ANSI_CURSOR_HIDE.utf8.count)

    // Set terminal to raw mode
    var raw = termios()
    tcgetattr(STDIN_FILENO, &raw)

    raw.c_lflag &= ~(UInt32(ECHO | ICANON))
    raw.c_cc.16 = 0  // VMIN
    raw.c_cc.17 = 1  // VTIME

    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)

    // Clear screen
    write(STDOUT_FILENO, ANSI_CLEAR_SCREEN, ANSI_CLEAR_SCREEN.utf8.count)
    write(STDOUT_FILENO, ANSI_CURSOR_HOME, ANSI_CURSOR_HOME.utf8.count)

    // Setup signal handler for window resize
    signal(SIGWINCH) { _ in
        terminalState?.updateTerminalSize()
        terminalState?.render()
    }

    // Cleanup on exit
    atexit {
        var original = termios()
        tcgetattr(STDIN_FILENO, &original)
        original.c_lflag |= UInt32(ECHO | ICANON)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)

        write(STDOUT_FILENO, ANSI_CURSOR_SHOW, ANSI_CURSOR_SHOW.utf8.count)
        write(STDOUT_FILENO, ANSI_CLEAR_SCREEN, ANSI_CLEAR_SCREEN.utf8.count)
        write(STDOUT_FILENO, ANSI_CURSOR_HOME, ANSI_CURSOR_HOME.utf8.count)
    }
}

// Read loop for the client
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
            terminalState.addMessage(">>> Disconnected from server")
            terminalState.render()
            sleep(1)
            TCPConnClose(conn)
            exit(0)
        }

        let msg = String(decoding: buf[0..<Int(n)], as: UTF8.self)

        if msg.hasPrefix("USER ") {
            let start = msg.index(msg.startIndex, offsetBy: 5)
            let name = String(msg[start...])
            terminalState.username = name
            terminalState.addMessage(">>> Connected as \(name)")
        } else {
            terminalState.addMessage(msg)
        }

        terminalState.render()
    }
}

func runClient(port: String) -> Int32 {
    var conn: UInt64 = 0
    guard TCPConnect((":" + port).toCStr, &conn) == TCP_OK else {
        fputs("Client: failed to connect to :\(port)\n", stderr)
        return 1
    }

    terminalState = TerminalState()
    setupTerminal()

    terminalState.addMessage(">>> Connecting to :\(port)...")
    terminalState.render()

    let fn = unsafeBitCast(
        ClientReadLoop as @convention(c) (CPtr?) -> Void,
        to: CPtr.self
    )
    let arg = CPtr(bitPattern: UInt(conn))
    _ = TaskLaunchVoid(fn, arg)

    // Input handling loop
    var inputBuf = [UInt8](repeating: 0, count: 1)

    while true {
        let n = read(STDIN_FILENO, &inputBuf, 1)
        if n <= 0 { continue }

        let ch = inputBuf[0]

        // Handle special keys
        if ch == 13 || ch == 10 {  // Enter
            if !terminalState.inputBuffer.isEmpty {
                let msg = terminalState.inputBuffer
                terminalState.inputBuffer = ""

                // Send message
                let bytes = Array(msg.utf8)
                var written: Int32 = 0
                bytes.withUnsafeBytes { b in
                    let ptr = UnsafeMutableRawPointer(mutating: b.baseAddress)
                    TCPWrite(conn, ptr, Int32(bytes.count), &written)
                }
            }
            terminalState.render()
        } else if ch == 127 || ch == 8 {  // Backspace
            if !terminalState.inputBuffer.isEmpty {
                terminalState.inputBuffer.removeLast()
            }
            terminalState.render()
        } else if ch == 3 {  // Ctrl+C
            TCPConnClose(conn)
            exit(0)
        } else if ch >= 32 && ch < 127 {  // Printable ASCII
            terminalState.inputBuffer.append(Character(UnicodeScalar(ch)))
            terminalState.render()
        }
    }
}

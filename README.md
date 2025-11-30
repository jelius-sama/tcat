# 🚀 tcat - Terminal Chat Application

A blazingly fast terminal-based chat application demonstrating seamless Foreign Function Interface (FFI) between Go and Swift using C ABI compatibility.

## 🎯 Project Overview

**tcat** is a test project exploring the powerful combination of Go's concurrency primitives and Swift's expressive syntax through C ABI interoperability. This project showcases:

- **Go Backend**: Handles TCP networking, goroutines, channels, and atomic operations
- **Swift Frontend**: Implements application logic, terminal UI, and user interactions
- **C ABI Bridge**: Enables zero-cost abstractions between both languages

> ⚠️ **Note**: This is an experimental/educational project. Authentication is not yet implemented. Do not use in production environments.

## ✨ Features

- 🎨 **Twitch-Style Colorized Chat**: Each user gets a unique, consistent color
- ⚡ **Real-time Messaging**: Powered by Go's goroutines and TCP stack
- 🖥️ **Beautiful TUI**: ANSI-based terminal UI with proper scrolling and window resize handling
- 💬 **Blinking Cursor**: Visual feedback for input readiness
- 🔄 **Concurrent Architecture**: Multiple clients can connect simultaneously
- 🎭 **System Notifications**: Join/leave messages in subtle gray

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Swift Application Layer                 │
│  • Terminal UI (ANSI escape codes)                          │
│  • Input handling & message formatting                      │
│  • User interaction logic                                   │
└────────────────────┬────────────────────────────────────────┘
                     │ C ABI FFI
┌────────────────────▼────────────────────────────────────────┐
│                   Go Runtime Layer (libgolang)              │
│  • TCP networking (Listen, Connect, Accept, Read, Write)    │
│  • Goroutines (TaskLaunch, TaskLaunchVoid)                  │
│  • Channels (ChannelCreate, Send, Recv)                     │
│  • Atomic operations (CompareAndSwap, Load, Store)          │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

### Required Tools

1. **Swift Static SDK** (musl-based for Linux)
   - Download from: https://www.swift.org/install
   - Set `SWIFT_STATIC_SDK` environment variable to your SDK path

   ```bash
   export SWIFT_STATIC_SDK=~/.swiftpm/swift-sdks/swift-6.0.3-RELEASE_static-linux-0.0.1.artifactbundle/swift-6.0.3-RELEASE_static-linux-0.0.1/swift-linux-musl/musl-1.2.5.sdk/x86_64
   ```

2. **Custom Go Compiler** (musl-patched)
   - A patched Go compiler compiled against musl is required
   - Place in `bin/musl-go`
   - Note: Standard Go has a bug with `-buildmode=c-archive` when compiled with musl-gcc

3. **Standard Build Tools**
   - `make`
   - `gcc` or `musl-gcc`

## 🔧 Building

```bash
# Clone the repository
git clone https://github.com/jelius-sama/tcat.git
cd tcat

# Build everything (Go library + Swift binary)
make

# The binary will be at: bin/tcat
```

### Clean Build

```bash
make clean
make
```

## 🚀 Usage

### Starting the Server

```bash
./bin/tcat -s -p 6969
```

Or use the default port (6969):

```bash
./bin/tcat -s
```

### Connecting as Client

```bash
./bin/tcat -c -p 6969
```

Multiple clients can connect simultaneously to the same server.

### Command Line Options

```
Usage:
  tcat [mode] [options]

Modes:
  -s, --server          Start in server mode
  -c, --client          Start in client mode
  -h, --help            Show help message

Options:
  -p, --port <port>     Specify port (default: 6969)

Examples:
  tcat -s -p 9000       Start server on port 9000
  tcat -c -p 9000       Connect to server on port 9000
  tcat --help           Show this help
```

## 🎮 Controls (Client Mode)

| Key | Action |
|-----|--------|
| Type normally | Enter text |
| `Enter` | Send message |
| `Backspace` | Delete character |
| `Ctrl+C` | Exit client |

## 📁 Project Structure

```
.
├── bin/
│   ├── musl-go              # Patched Go compiler
│   └── tcat                 # Compiled binary
├── libgolang/
│   ├── golang.go            # Go runtime exports
│   ├── go.mod
│   ├── libgolang.a          # Compiled Go static library
│   ├── libgolang.h          # Generated C headers
│   └── module.modulemap     # Swift module map
├── Source/
│   ├── main.swift           # Entry point & CLI parsing
│   ├── server.swift         # Server logic
│   ├── client.swift         # Client logic & TUI
│   ├── shared.swift         # Shared constants
│   ├── ctypes.swift         # C type aliases
│   └── extension.swift      # Swift extensions
└── Makefile                 # Build configuration
```

## 🔬 Technical Deep Dive

### FFI Strategy

The project uses **C ABI as the common ground** between Go and Swift:

1. **Go Side**: Functions are exported with `//export` directive and compiled to a static archive with `-buildmode=c-archive`
2. **C Headers**: Go generates C-compatible headers automatically
3. **Swift Side**: Imports the C headers and calls functions directly with zero overhead

### Concurrency Model

- **Server**: Each client connection runs in its own goroutine via `TaskLaunchVoid`
- **Client**: Two concurrent tasks:
  - Goroutine 1: Reads messages from server
  - Goroutine 2: Blinks cursor for UI feedback
  - Main thread: Handles user input

### Synchronization

- Uses Go's `sync/atomic` primitives exported to Swift
- SpinLock implementation with `AtomicCompareAndSwapInt32`
- Thread-safe message queue with proper locking

### Networking

- Pure Go `net` package for TCP operations
- Connection handles stored in Go-side maps
- Zero-copy byte slices passed between languages using `unsafe.Pointer`

## 🎨 UI Design

The terminal UI features:

- **Chat Area**: Scrolling message history with color-coded usernames
- **Separator Line**: Visual boundary between chat and input
- **Input Line**: Shows username + current input + blinking cursor
- **Dynamic Resizing**: Adapts to terminal window size changes (SIGWINCH)

Colors are assigned deterministically based on username hash, ensuring consistency across reconnects.

## 🐛 Known Limitations

- ❌ No authentication or encryption
- ❌ No message persistence
- ❌ No private messaging
- ❌ No rate limiting or spam protection

## 🔮 Future Improvements

- [ ] Add TLS/SSL encryption
- [ ] Implement user authentication
- [ ] Add private messaging support
- [ ] Message history/logging
- [ ] Configurable color themes
- [ ] Emoji support
- [ ] File transfer capability
- [ ] Multiple chat rooms

## 🤝 Contributing

This is an experimental project for learning purposes. Feel free to fork and experiment!

## 📄 License

MIT — See [LICENSE](./LICENSE)

## ✨ Author

[Jelius Basumatary](https://jelius.dev) — Systems & App Developer in Practice

## 🙏 Acknowledgments

- Go team for excellent `cgo` and concurrency primitives
- Terminal emulator developers for ANSI standard support

---

**Built with ❤️ using Go and Swift**

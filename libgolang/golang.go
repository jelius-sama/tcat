package main

/*
#include <stdint.h>

// Function pointer types
typedef void (*c_void_func_t)(void*);
typedef void* (*c_ptr_func_t)(void*);

typedef uint64_t TaskHandle;
typedef uint64_t ChannelHandle;

typedef struct {
    ChannelHandle statsChannel;
    int intervalMs;
} MonitorConfig;

// Helper to invoke C function pointers from Go
static inline void invoke_void_func(c_void_func_t fn, void* arg) {
    fn(arg);
}

static inline void* invoke_ptr_func(c_ptr_func_t fn, void *arg) {
    return fn(arg);
}
*/
import "C"

import (
    "net"
    "sync"
    "sync/atomic"
    "time"
    "unsafe"
)

const (
    TCP_OK  C.int = 0
    TCP_ERR C.int = 1
)

var (
    connTable     = make(map[C.uint64_t]net.Conn)
    listenerTable = make(map[C.uint64_t]net.Listener)
    handleSeq     C.uint64_t
    mu            sync.Mutex
)

func newHandle() C.uint64_t {
    mu.Lock()
    handleSeq++
    id := handleSeq
    mu.Unlock()
    return id
}

//export TCPListen
func TCPListen(addr *C.char, out *C.uint64_t) C.int {
    goAddr := C.GoString(addr)
    ln, err := net.Listen("tcp", goAddr)
    if err != nil {
        return TCP_ERR
    }
    h := newHandle()
    mu.Lock()
    listenerTable[h] = ln
    mu.Unlock()
    *out = h
    return TCP_OK
}

//export TCPConnect
func TCPConnect(addr *C.char, out *C.uint64_t) C.int {
    goAddr := C.GoString(addr)
    c, err := net.Dial("tcp", goAddr)
    if err != nil {
        return TCP_ERR
    }
    h := newHandle()
    mu.Lock()
    connTable[h] = c
    mu.Unlock()
    *out = h
    return TCP_OK
}

//export TCPAccept
func TCPAccept(listener C.uint64_t, out *C.uint64_t) C.int {
    mu.Lock()
    ln := listenerTable[listener]
    mu.Unlock()
    if ln == nil {
        return TCP_ERR
    }
    c, err := ln.Accept()
    if err != nil {
        return TCP_ERR
    }
    h := newHandle()
    mu.Lock()
    connTable[h] = c
    mu.Unlock()
    *out = h
    return TCP_OK
}

//export TCPRead
func TCPRead(conn C.uint64_t, buf unsafe.Pointer, bufLen C.int, outRead *C.int) C.int {
    mu.Lock()
    c := connTable[conn]
    mu.Unlock()
    if c == nil {
        return TCP_ERR
    }

    slice := (*[1 << 30]byte)(buf)[:bufLen:bufLen]
    n, err := c.Read(slice)
    if err != nil {
        return TCP_ERR
    }
    *outRead = C.int(n)
    return TCP_OK
}

//export TCPWrite
func TCPWrite(conn C.uint64_t, buf unsafe.Pointer, bufLen C.int, outWritten *C.int) C.int {
    mu.Lock()
    c := connTable[conn]
    mu.Unlock()
    if c == nil {
        return TCP_ERR
    }

    slice := (*[1 << 30]byte)(buf)[:bufLen:bufLen]
    n, err := c.Write(slice)
    if err != nil {
        return TCP_ERR
    }
    *outWritten = C.int(n)
    return TCP_OK
}

// broadcast same bytes to all connections except 'except'
// if except == 0, no exception
//
//export TCPBroadcast
func TCPBroadcast(buf unsafe.Pointer, bufLen C.int, except C.uint64_t) C.int {
    slice := (*[1 << 30]byte)(buf)[:bufLen:bufLen]

    mu.Lock()
    conns := make([]net.Conn, 0, len(connTable))
    for h, c := range connTable {
        if c == nil {
            continue
        }
        if except != 0 && h == except {
            continue
        }
        conns = append(conns, c)
    }
    mu.Unlock()

    for _, c := range conns {
        _, _ = c.Write(slice) // ignore per-conn errors for now
    }
    return TCP_OK
}

//export TCPConnClose
func TCPConnClose(conn C.uint64_t) C.int {
    mu.Lock()
    c := connTable[conn]
    delete(connTable, conn)
    mu.Unlock()
    if c == nil {
        return TCP_ERR
    }
    c.Close()
    return TCP_OK
}

//export TCPListenerClose
func TCPListenerClose(listener C.uint64_t) C.int {
    mu.Lock()
    ln := listenerTable[listener]
    delete(listenerTable, listener)
    mu.Unlock()
    if ln == nil {
        return TCP_ERR
    }
    ln.Close()
    return TCP_OK
}

type TaskHandle uint64

type asyncTask struct {
    completionSignal chan struct{}
    result           unsafe.Pointer
    hasResult        bool
}

var (
    taskRegistry   sync.Map // map[TaskHandle]*asyncTask
    nextTaskHandle uint64
)

func allocateTask(withResult bool) (TaskHandle, *asyncTask) {
    handle := TaskHandle(atomic.AddUint64(&nextTaskHandle, 1))
    task := &asyncTask{
        completionSignal: make(chan struct{}),
        hasResult:        withResult,
    }
    taskRegistry.Store(handle, task)
    return handle, task
}

func completeTask(handle TaskHandle, result unsafe.Pointer) {
    if val, exists := taskRegistry.Load(handle); exists {
        task := val.(*asyncTask)
        if task.hasResult {
            task.result = result
        }
        close(task.completionSignal)
    }
}

func getTask(handle TaskHandle) *asyncTask {
    if val, exists := taskRegistry.Load(handle); exists {
        return val.(*asyncTask)
    }
    return nil
}

func cleanupTask(handle TaskHandle) {
    taskRegistry.Delete(handle)
}

//export TaskLaunch
func TaskLaunch(fn unsafe.Pointer, arg unsafe.Pointer) C.uint64_t {
    handle, _ := allocateTask(true)

    go func() {
        result := C.invoke_ptr_func((C.c_ptr_func_t)(fn), arg)
        completeTask(handle, result)
    }()

    return C.uint64_t(handle)
}

//export TaskLaunchVoid
func TaskLaunchVoid(fn unsafe.Pointer, arg unsafe.Pointer) C.uint64_t {
    handle, _ := allocateTask(false)

    go func() {
        C.invoke_void_func((C.c_void_func_t)(fn), arg)
        completeTask(handle, nil)
    }()

    return C.uint64_t(handle)
}

//export TaskPoll
func TaskPoll(handle C.uint64_t, resultPtr *unsafe.Pointer) C.int {
    task := getTask(TaskHandle(handle))
    if task == nil {
        return -2
    }

    select {
    case <-task.completionSignal:
        if task.hasResult && resultPtr != nil {
            *resultPtr = task.result
        }
        return 0
    default:
        return -1
    }
}

//export TaskAwait
func TaskAwait(handle C.uint64_t, resultPtr *unsafe.Pointer) {
    task := getTask(TaskHandle(handle))
    if task == nil {
        return
    }

    <-task.completionSignal

    if task.hasResult && resultPtr != nil {
        *resultPtr = task.result
    }
}

//export TaskAwaitTimeout
func TaskAwaitTimeout(handle C.uint64_t, timeoutMs C.int64_t, resultPtr *unsafe.Pointer) C.int {
    task := getTask(TaskHandle(handle))
    if task == nil {
        return -2
    }

    select {
    case <-task.completionSignal:
        if task.hasResult && resultPtr != nil {
            *resultPtr = task.result
        }
        return 0
    case <-time.After(time.Duration(timeoutMs) * time.Millisecond):
        return -1
    }
}

//export TaskCleanup
func TaskCleanup(handle C.uint64_t) {
    cleanupTask(TaskHandle(handle))
}

type ChannelHandle uint64

var (
    channelRegistry sync.Map // map[ChannelHandle]chan unsafe.Pointer
    nextChanHandle  uint64
)

//export ChannelCreate
func ChannelCreate(bufferSize C.int) C.uint64_t {
    handle := ChannelHandle(atomic.AddUint64(&nextChanHandle, 1))
    ch := make(chan unsafe.Pointer, int(bufferSize))
    channelRegistry.Store(handle, ch)
    return C.uint64_t(handle)
}

//export ChannelSend
func ChannelSend(handle C.uint64_t, value unsafe.Pointer) C.int {
    if val, exists := channelRegistry.Load(ChannelHandle(handle)); exists {
        ch := val.(chan unsafe.Pointer)
        ch <- value
        return 0
    }
    return -1
}

//export ChannelRecv
func ChannelRecv(handle C.uint64_t) unsafe.Pointer {
    if val, exists := channelRegistry.Load(ChannelHandle(handle)); exists {
        ch := val.(chan unsafe.Pointer)
        value, ok := <-ch
        if !ok {
            return nil
        }
        return value
    }
    return nil
}

//export ChannelTryRecv
func ChannelTryRecv(handle C.uint64_t, valuePtr *unsafe.Pointer) C.int {
    if val, exists := channelRegistry.Load(ChannelHandle(handle)); exists {
        ch := val.(chan unsafe.Pointer)
        select {
        case value, ok := <-ch:
            if !ok {
                return -2
            }
            if valuePtr != nil {
                *valuePtr = value
            }
            return 0
        default:
            return -1
        }
    }
    return -3
}

//export ChannelClose
func ChannelClose(handle C.uint64_t) {
    if val, exists := channelRegistry.Load(ChannelHandle(handle)); exists {
        ch := val.(chan unsafe.Pointer)
        channelRegistry.Delete(ChannelHandle(handle))
        close(ch)
    }
}

func main() {}

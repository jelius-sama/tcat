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
	"fmt"
<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> 6d8f194 (Added C Stuff)
	"net/http"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"
<<<<<<< HEAD
)

var (
	httpRouter     = http.NewServeMux()
	requestCounter uint64
)

// ============================================================================
// ASYNC TASK SYSTEM - Unified approach for all async operations
// ============================================================================

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

// Launch a function that returns void* asynchronously
//
//export TaskLaunch
func TaskLaunch(fn unsafe.Pointer, arg unsafe.Pointer) C.uint64_t {
	handle, _ := allocateTask(true)

	go func() {
		result := C.invoke_ptr_func((C.c_ptr_func_t)(fn), arg)
		completeTask(handle, result)
	}()

	return C.uint64_t(handle)
}

// Launch a function that returns nothing (fire-and-forget with tracking)
//
//export TaskLaunchVoid
func TaskLaunchVoid(fn unsafe.Pointer, arg unsafe.Pointer) C.uint64_t {
	handle, _ := allocateTask(false)

	go func() {
		C.invoke_void_func((C.c_void_func_t)(fn), arg)
		completeTask(handle, nil)
	}()

	return C.uint64_t(handle)
}

// Non-blocking check if task is complete (0=done, -1=running, -2=invalid)
//
//export TaskPoll
func TaskPoll(handle C.uint64_t, resultPtr *unsafe.Pointer) C.int {
	task := getTask(TaskHandle(handle))
	if task == nil {
		return -2 // Invalid or already cleaned up
	}

	select {
	case <-task.completionSignal:
		if task.hasResult && resultPtr != nil {
			*resultPtr = task.result
		}
		return 0
	default:
		return -1 // Still running
	}
}

// Blocking wait for task completion
//
//export TaskAwait
func TaskAwait(handle C.uint64_t, resultPtr *unsafe.Pointer) {
	task := getTask(TaskHandle(handle))
	if task == nil {
		return // Already done or invalid
	}

	<-task.completionSignal

	if task.hasResult && resultPtr != nil {
		*resultPtr = task.result
	}
}

// Blocking wait with timeout (0=success, -1=timeout, -2=invalid)
//
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

// Cleanup task resources (optional - useful for long-running programs)
//
//export TaskCleanup
func TaskCleanup(handle C.uint64_t) {
	cleanupTask(TaskHandle(handle))
}

// ============================================================================
// CHANNEL SYSTEM - Go channels exposed to C
// ============================================================================

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
	return -1 // Invalid channel
}

//export ChannelRecv
func ChannelRecv(handle C.uint64_t) unsafe.Pointer {
	if val, exists := channelRegistry.Load(ChannelHandle(handle)); exists {
		ch := val.(chan unsafe.Pointer)
		value, ok := <-ch
		if !ok {
			return nil // Channel closed
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
				return -2 // Channel closed
			}
			if valuePtr != nil {
				*valuePtr = value
			}
			return 0
		default:
			return -1 // Would block
		}
	}
	return -3 // Invalid channel
}

//export ChannelClose
func ChannelClose(handle C.uint64_t) {
	if val, exists := channelRegistry.Load(ChannelHandle(handle)); exists {
		ch := val.(chan unsafe.Pointer)
		channelRegistry.Delete(ChannelHandle(handle))
		close(ch)
	}
}

// ============================================================================
// HTTP SERVER - Demo application
// ============================================================================

//export HttpRegisterRoute
func HttpRegisterRoute(path, response *C.char) *C.char {
	pathStr := C.GoString(path)
	responseStr := C.GoString(response)

	httpRouter.HandleFunc(pathStr, func(w http.ResponseWriter, r *http.Request) {
		atomic.AddUint64(&requestCounter, 1)
		w.Write([]byte(responseStr))
	})

	return C.CString(fmt.Sprintf("✓ Registered route: %s\n", pathStr))
}

//export HttpGetRequestCount
func HttpGetRequestCount() C.uint64_t {
	return C.uint64_t(atomic.LoadUint64(&requestCounter))
}

//export HttpStartServer
func HttpStartServer(addr *C.char) *C.char {
	addrStr := C.GoString(addr)
	fmt.Printf("🚀 HTTP server listening on %s\n", addrStr)

	if err := http.ListenAndServe(addrStr, httpRouter); err != nil {
		return C.CString(fmt.Sprintf("ERROR: %v", err))
	}

	return C.CString("Unreachable: Server stopped")
=======
=======
>>>>>>> 6d8f194 (Added C Stuff)
)

//export Add
func Add(x, y C.int) C.int {
	return x + y
>>>>>>> d955cc3 (Strings example)
}

//export StringInterpolation
func StringInterpolation(x, y *C.char) *C.char {
	return C.CString(fmt.Sprintf("StringInterpolation(): %s, %s!", C.GoString(x), C.GoString(y)))
}

var (
	httpRouter     = http.NewServeMux()
	requestCounter uint64
)

// ============================================================================
// ASYNC TASK SYSTEM - Unified approach for all async operations
// ============================================================================

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

// Launch a function that returns void* asynchronously
//
//export TaskLaunch
func TaskLaunch(fn unsafe.Pointer, arg unsafe.Pointer) C.uint64_t {
	handle, _ := allocateTask(true)

	go func() {
		result := C.invoke_ptr_func((C.c_ptr_func_t)(fn), arg)
		completeTask(handle, result)
	}()

	return C.uint64_t(handle)
}

// Launch a function that returns nothing (fire-and-forget with tracking)
//
//export TaskLaunchVoid
func TaskLaunchVoid(fn unsafe.Pointer, arg unsafe.Pointer) C.uint64_t {
	handle, _ := allocateTask(false)

	go func() {
		C.invoke_void_func((C.c_void_func_t)(fn), arg)
		completeTask(handle, nil)
	}()

	return C.uint64_t(handle)
}

// Non-blocking check if task is complete (0=done, -1=running, -2=invalid)
//
//export TaskPoll
func TaskPoll(handle C.uint64_t, resultPtr *unsafe.Pointer) C.int {
	task := getTask(TaskHandle(handle))
	if task == nil {
		return -2 // Invalid or already cleaned up
	}

	select {
	case <-task.completionSignal:
		if task.hasResult && resultPtr != nil {
			*resultPtr = task.result
		}
		return 0
	default:
		return -1 // Still running
	}
}

// Blocking wait for task completion
//
//export TaskAwait
func TaskAwait(handle C.uint64_t, resultPtr *unsafe.Pointer) {
	task := getTask(TaskHandle(handle))
	if task == nil {
		return // Already done or invalid
	}

	<-task.completionSignal

	if task.hasResult && resultPtr != nil {
		*resultPtr = task.result
	}
}

// Blocking wait with timeout (0=success, -1=timeout, -2=invalid)
//
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

// Cleanup task resources (optional - useful for long-running programs)
//
//export TaskCleanup
func TaskCleanup(handle C.uint64_t) {
	cleanupTask(TaskHandle(handle))
}

// ============================================================================
// CHANNEL SYSTEM - Go channels exposed to C
// ============================================================================

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
	return -1 // Invalid channel
}

//export ChannelRecv
func ChannelRecv(handle C.uint64_t) unsafe.Pointer {
	if val, exists := channelRegistry.Load(ChannelHandle(handle)); exists {
		ch := val.(chan unsafe.Pointer)
		value, ok := <-ch
		if !ok {
			return nil // Channel closed
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
				return -2 // Channel closed
			}
			if valuePtr != nil {
				*valuePtr = value
			}
			return 0
		default:
			return -1 // Would block
		}
	}
	return -3 // Invalid channel
}

//export ChannelClose
func ChannelClose(handle C.uint64_t) {
	if val, exists := channelRegistry.Load(ChannelHandle(handle)); exists {
		ch := val.(chan unsafe.Pointer)
		channelRegistry.Delete(ChannelHandle(handle))
		close(ch)
	}
}

// ============================================================================
// HTTP SERVER - Demo application
// ============================================================================

//export HttpRegisterRoute
func HttpRegisterRoute(path, response *C.char) *C.char {
	pathStr := C.GoString(path)
	responseStr := C.GoString(response)

	httpRouter.HandleFunc(pathStr, func(w http.ResponseWriter, r *http.Request) {
		atomic.AddUint64(&requestCounter, 1)
		w.Write([]byte(responseStr))
	})

	return C.CString(fmt.Sprintf("✓ Registered route: %s\n", pathStr))
}

//export HttpGetRequestCount
func HttpGetRequestCount() C.uint64_t {
	return C.uint64_t(atomic.LoadUint64(&requestCounter))
}

//export HttpStartServer
func HttpStartServer(addr *C.char) *C.char {
	addrStr := C.GoString(addr)
	fmt.Printf("🚀 HTTP server listening on %s\n", addrStr)

	if err := http.ListenAndServe(addrStr, httpRouter); err != nil {
		return C.CString(fmt.Sprintf("ERROR: %v", err))
	}

	return C.CString("Unreachable: Server stopped")
}

func main() {}

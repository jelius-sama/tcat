package internal

/*
#cgo CFLAGS: -I${SRCDIR}/internal
#include "shared.h"
*/
import "C"
import (
	"sync"
	"sync/atomic"
	"time"
)

type TaskHandle uint64

type asyncTask struct {
	completionSignal chan struct{}
	result           CPtr
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

func completeTask(handle TaskHandle, result CPtr) {
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
func TaskLaunch(fn, arg CPtr) CUint64T {
	handle, _ := allocateTask(true)

	go func() {
		result := C.invoke_ptr_func((CPtrFuncT)(fn), arg)
		completeTask(handle, result)
	}()

	return CUint64T(handle)
}

// Launch a function that returns nothing (fire-and-forget with tracking)
func TaskLaunchVoid(fn, arg CPtr) CUint64T {
	handle, _ := allocateTask(false)

	go func() {
		C.invoke_void_func((CVoidFuncT)(fn), arg)
		completeTask(handle, nil)
	}()

	return CUint64T(handle)
}

// Non-blocking check if task is complete (0=done, -1=running, -2=invalid)
func TaskPoll(handle CUint64T, resultPtr *CPtr) CInt {
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
func TaskAwait(handle CUint64T, resultPtr *CPtr) {
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
func TaskAwaitTimeout(handle CUint64T, timeoutMs CInt64T, resultPtr *CPtr) CInt {
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
func TaskCleanup(handle CUint64T) {
	cleanupTask(TaskHandle(handle))
}

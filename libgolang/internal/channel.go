package internal

import (
	"sync"
	"sync/atomic"
	"unsafe"
)

type ChannelHandle uint64

var (
	channelRegistry sync.Map // map[ChannelHandle]chan unsafe.Pointer
	nextChanHandle  uint64
)

func ChannelCreate(bufferSize CInt) CUint64T {
	handle := ChannelHandle(atomic.AddUint64(&nextChanHandle, 1))
	ch := make(chan unsafe.Pointer, int(bufferSize))
	channelRegistry.Store(handle, ch)
	return CUint64T(handle)
}

func ChannelSend(handle CUint64T, value unsafe.Pointer) CInt {
	if val, exists := channelRegistry.Load(ChannelHandle(handle)); exists {
		ch := val.(chan unsafe.Pointer)
		ch <- value
		return 0
	}
	return -1 // Invalid channel
}

func ChannelRecv(handle CUint64T) unsafe.Pointer {
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

func ChannelTryRecv(handle CUint64T, valuePtr *unsafe.Pointer) CInt {
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

func ChannelClose(handle CUint64T) {
	if val, exists := channelRegistry.Load(ChannelHandle(handle)); exists {
		ch := val.(chan unsafe.Pointer)
		channelRegistry.Delete(ChannelHandle(handle))
		close(ch)
	}
}

package main

import (
	"libgolang/internal"
	"unsafe"
)

//export TCPListen
func TCPListen(addr *internal.CChar, out *internal.CUint64T) internal.CInt {
	return internal.TCPListen(addr, out)
}

//export TCPAccept
func TCPAccept(listener internal.CUint64T, out *internal.CUint64T) internal.CInt {
	return internal.TCPAccept(listener, out)
}

//export TCPRead
func TCPRead(conn internal.CUint64T, buf internal.CPtr, bufLen internal.CInt, outRead *internal.CInt) internal.CInt {
	return internal.TCPRead(conn, buf, bufLen, outRead)
}

//export TCPWrite
func TCPWrite(conn internal.CUint64T, buf internal.CPtr, bufLen internal.CInt, outWritten *internal.CInt) internal.CInt {
	return internal.TCPWrite(conn, buf, bufLen, outWritten)
}

//export TCPConnClose
func TCPConnClose(conn internal.CUint64T) internal.CInt {
	return internal.TCPConnClose(conn)
}

//export TCPListenerClose
func TCPListenerClose(listener internal.CUint64T) internal.CInt {
	return internal.TCPListenerClose(listener)
}

//export ChannelCreate
func ChannelCreate(bufferSize internal.CInt) internal.CUint64T {
	return internal.ChannelCreate(bufferSize)
}

//export ChannelSend
func ChannelSend(handle internal.CUint64T, value unsafe.Pointer) internal.CInt {
	return internal.ChannelSend(handle, value)
}

//export ChannelRecv
func ChannelRecv(handle internal.CUint64T) unsafe.Pointer {
	return internal.ChannelRecv(handle)
}

//export ChannelTryRecv
func ChannelTryRecv(handle internal.CUint64T, valuePtr *unsafe.Pointer) internal.CInt {
	return internal.ChannelTryRecv(handle, valuePtr)
}

//export ChannelClose
func ChannelClose(handle internal.CUint64T) {
	internal.ChannelClose(handle)
}

//export TaskLaunch
func TaskLaunch(fn, arg unsafe.Pointer) internal.CUint64T {
	return internal.TaskLaunch(fn, arg)
}

//export TaskLaunchVoid
func TaskLaunchVoid(fn, arg unsafe.Pointer) internal.CUint64T {
	return internal.TaskLaunchVoid(fn, arg)
}

//export TaskPoll
func TaskPoll(handle internal.CUint64T, resultPtr *unsafe.Pointer) internal.CInt {
	return internal.TaskPoll(handle, resultPtr)
}

//export TaskAwait
func TaskAwait(handle internal.CUint64T, resultPtr *unsafe.Pointer) {
	internal.TaskPoll(handle, resultPtr)
}

//export TaskAwaitTimeout
func TaskAwaitTimeout(handle internal.CUint64T, timeoutMs internal.CInt64T, resultPtr *unsafe.Pointer) internal.CInt {
	return internal.TaskAwaitTimeout(handle, timeoutMs, resultPtr)
}

//export TaskCleanup
func TaskCleanup(handle internal.CUint64T) {
	internal.TaskCleanup(handle)
}

func main() {}

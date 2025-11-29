package internal

/*
#cgo CFLAGS: -I${SRCDIR}/internal
#include "shared.h"
*/
import "C"
import (
	"net"
	"sync"
)

const (
	TCP_OK  CInt = 0
	TCP_ERR CInt = 1
)

var (
	connTable     = make(map[CUint64T]net.Conn)
	listenerTable = make(map[CUint64T]net.Listener)
	handleSeq     CUint64T
	mu            sync.Mutex
)

func newHandle() CUint64T {
	mu.Lock()
	handleSeq++
	id := handleSeq
	mu.Unlock()
	return id
}

func TCPListen(addr *CChar, out *CUint64T) CInt {
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

func TCPAccept(listener CUint64T, out *CUint64T) CInt {
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

func TCPRead(conn CUint64T, buf CPtr, bufLen CInt, outRead *CInt) CInt {
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
	*outRead = CInt(n)
	return TCP_OK
}

func TCPWrite(conn CUint64T, buf CPtr, bufLen CInt, outWritten *CInt) CInt {
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
	*outWritten = CInt(n)
	return TCP_OK
}

func TCPConnClose(conn CUint64T) CInt {
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

func TCPListenerClose(listener CUint64T) CInt {
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

package internal

/*
#cgo CFLAGS: -I${SRCDIR}/internal
#include "shared.h"
*/
import "C"
import "unsafe"

type CChar = C.char
type CInt = C.int
type CUint64T = C.uint64_t
type CInt64T = C.int64_t
type CVoidFuncT = C.c_void_func_t
type CPtrFuncT = C.c_ptr_func_t
type CPtr = unsafe.Pointer

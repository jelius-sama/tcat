#ifndef  INTERNAL_SHARED_H
#define INTERNAL_SHARED_H

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

#endif //INTERNAL_SHARED_H

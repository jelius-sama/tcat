#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <signal.h>
#include "da.c"

volatile sig_atomic_t running = 1;    // shared between main and signal handler

static inline void handle_sigint(int sig) {
    (void)sig; // unused
    printf("\nSIGINT received. Cleaning up...\n");
    running = 0;   // tell main loop to exit
}

static inline void* monitor_loop(void* context) {
    MonitorConfig* config = (MonitorConfig*)context;

    for (;;) {
        usleep(config->intervalMs * 1000);

        uint64_t currentCount = HttpGetRequestCount();

        // Allocate on heap so it persists across channel
        uint64_t* countPtr = malloc(sizeof(uint64_t));
        *countPtr = currentCount;

        ChannelSend(config->statsChannel, countPtr);
    }

    return NULL;  // Never reached
}

int HandleCServer() {
    dynamic_arrays();

    if (signal(SIGINT, handle_sigint) == SIG_ERR) {
        perror("signal");
        exit(1);
    }
    uint64_t hist = 0;

    printf("╔═════════════════════════════════════════════════════════════════╗\n");
    printf("║           C-Go-Swift FFI Demo: Async Tasks & Channels           ║\n");
    printf("╚═════════════════════════════════════════════════════════════════╝\n");

    // Register HTTP routes
    char* msg;
    msg = HttpRegisterRoute("/", "Hello, FFI World!");
printf("%s", msg);
    free(msg);

    msg = HttpRegisterRoute("/kazu", "Hello, Kazuma!");
    printf("%s", msg);
    free(msg);

    msg = HttpRegisterRoute("/coding", "ABSOLUTE CODING!!!");
    printf("%s", msg);
    free(msg);

    msg = HttpRegisterRoute("/ping", "pong");
    printf("%s", msg);
    free(msg);

    // Launch HTTP server asynchronously (returns char* on error)
    TaskHandle serverTask = TaskLaunch(HttpStartServer, ":6969");

    // Create buffered channel for statistics
    ChannelHandle statsChannel = ChannelCreate(16);

    // Configure and launch monitor
    MonitorConfig* monitorConfig = malloc(sizeof(MonitorConfig));
    monitorConfig->statsChannel = statsChannel;
    monitorConfig->intervalMs = 1000;

    TaskHandle monitorTask = TaskLaunch(monitor_loop, monitorConfig);

    printf("\n📊 Real-time Statistics (Ctrl+C to quit)\n");
    printf("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

    // Event loop using non-blocking poll pattern
    while (running) {
        // Check if server crashed (non-blocking)
        void* errorMsg = NULL;
        int serverStatus = TaskPoll(serverTask, &errorMsg);

        if (serverStatus == 0) {
            // Server task completed (should never happen unless error)
            printf("\n❌ SERVER ERROR: %s\n", (char*)errorMsg);
            free(errorMsg);
            break;
        } else if (serverStatus == -2) {
            printf("\n⚠️  Server task handle invalid\n");
            break;
        }
        /* NOTE:
         * serverStatus == -1 means still running (expected)
        */

        // Receive statistics from monitor (blocking)
        uint64_t* statsPtr = (uint64_t*)ChannelRecv(statsChannel);

        if (statsPtr == NULL) {
            printf("\n📡 Stats channel closed\n");
            break;
        }

        if (hist != *statsPtr) {
            // Display statistics
            printf("┃ Total Requests: %llu\n", (unsigned long long)*statsPtr);
        }

        hist = *statsPtr;
        free(statsPtr);
    }

    ChannelClose(statsChannel);
    TaskCleanup(serverTask);
    TaskCleanup(monitorTask);
    free(monitorConfig);

    printf("\n🧹 Cleaned up.\n");
    printf("👋 Goodbye!\n");
    return 0;
}

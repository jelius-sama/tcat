#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int   *items;
    size_t count;
    size_t capacity;
} Numbers;

void dynamic_arrays() {
    Numbers xs = {0};

    for (int x = 0; x < 10; ++x) {
        if (xs.count >= xs.capacity) {
            if (xs.capacity == 0)
                xs.capacity = 256;
            else
                xs.capacity *= 2;

            xs.items = realloc(xs.items, xs.capacity * sizeof *xs.items);
        }

        xs.items[xs.count++] = x;
    }

    for (size_t i = 0; i < xs.count; ++i) {
        printf("%d\n", xs.items[i]);
    }
}

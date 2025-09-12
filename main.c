// main.c

#include <stdio.h>
#include <stdlib.h>
#include "grand.h"

int main() {
    int down, up;

    printf("Enter smaller and bigger values: ");
    if (scanf("%d %d", &down, &up) != 2) {
        fprintf(stderr, "Error: Invalid input.\n");
        return 1;
    }

    if (down >= up) {
        fprintf(stderr, "Error: Smaller value (%d) must be less than bigger value (%d).\n", down, up);
        return 1;
    }

    printf("Generating 100 random numbers between %d and %d:\n", down, up);
    gen_random_num(down, up, 100);

    return 0;
}


// grand.c

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "grand.h"

void gen_random_num(int down, int count, int up) {
    srand(time(NULL));

    for (int i = 0; i < count; i++) {
        int num = down + rand() % (up - down + 1);
        printf("%d\n", num);
    }
}


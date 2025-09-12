#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <spoofed-name> <fib-arg>\n", argv[0]);
        fprintf(stderr, "Example: %s rfib 10\n", argv[0]);
        return 1;
    }

    // Path to the target executable
    char *tgt = "./fibdispatch";

    // Build argv for the exec call
    char *newargv[3];
    newargv[0] = argv[1];  // spoofed argv[0] up to the rfib
    newargv[1] = argv[2];  // the number that go up to 10
    newargv[2] = NULL;

    // Execute the program with spoofed argv[0]
    execv(tgt, newargv);

    // If execv fails
    perror("execv");
    return 1;
}

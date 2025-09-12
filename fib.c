#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Iterative Fibonacci
int fib(int n) {
    if (n <= 1) return n;
    int a = 0, b = 1, c;
    for (int i = 2; i <= n; ++i) {
        c = a + b;
        a = b;
        b = c;
    }
    return b;
}

// Naive recursive Fibonacci
int rfib(int n) {
    if (n <= 1) return n;
    return rfib(n - 1) + rfib(n - 2);
}

// Tail-recursive-style helper
int ifib_helper(int a, int b, int n) {
    if (n == 0) return a;
    return ifib_helper(b, a + b, n - 1);
}

int ifib(int n) {
    return ifib_helper(0, 1, n);
}

// Main dispatcher
int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <n>\n", argv[0]);
        return 1;
    }

    int n = atoi(argv[1]);
    if (n < 0) {
        fprintf(stderr, "Please provide a non-negative integer.\n");
        return 1;
    }

    const char *pn = strrchr(argv[0], '/');
    pn = pn ? pn + 1 : argv[0];  // strip path

    int outcome;

    if (strcmp(pn, "fib") == 0) {
        outcome = fib(n);
        printf("fib(%d) = %d (iterative)\n", n, outcome);
    } else if (strcmp(pn, "rfib") == 0) {
        outcome = rfib(n);
        printf("rfib(%d) = %d (recursive)\n", n, outcome);
    } else if (strcmp(pn, "ifib") == 0) {
        outcome = ifib(n);
        printf("ifib(%d) = %d (tail-recursive-style)\n", n, outcome);
    } else {
        fprintf(stderr, "Unknown invocation name '%s'. Use fib, rfib, or ifib.\n", pn);
        return 1;
    }

    return 0;
}

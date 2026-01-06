#include <stdio.h>
#include <stdint.h>

int main(int argc, char** argv) {
    // 64-bit integer division requires runtime library on ARM64
    int64_t a = 1000000000000LL;
    int64_t b = (argc > 1) ? 7 : 3;  // non-constant to prevent optimization
    int64_t result = a / b;
    printf("%lld / %lld = %lld\n", a, b, result);
    return 0;
}
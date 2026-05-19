#include <string.h>
#include <stdint.h>

#define MAX_SUPPORT_SIZE 65535  // Constraints from the instruction set LinxISA 1.0
#define unlikely(X) __builtin_expect(!!(X), 0)

void *memset(void *mm, int c, size_t n)
{
    char *m = (char *)mm;
    while (unlikely(n > MAX_SUPPORT_SIZE)) {
        __asm__ __volatile__("MSET [%0, %1, %2]\n" : : "r"(m), "r"(c), "r"(MAX_SUPPORT_SIZE) : "memory");
        n = n - MAX_SUPPORT_SIZE;
        m = m + MAX_SUPPORT_SIZE;
    }
    __asm__ __volatile__("MSET [%0, %1, %2]\n" : : "r"(m), "r"(c), "r"(n) : "memory");
    return mm;
}

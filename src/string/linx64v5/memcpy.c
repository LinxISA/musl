#include <string.h>
#include <stdint.h>
#include <endian.h>

#define MAX_SUPPORT_SIZE 65535  // Constraints from the instruction set LinxISA 1.0
#define unlikely(X) __builtin_expect(!!(X), 0)

void *memcpy(void *__restrict aa, const void *__restrict bb, size_t n)
{
    char *a = (char *)aa;
    char *b = (char *)bb;
    while (unlikely(n > MAX_SUPPORT_SIZE)) {
        __asm__ __volatile__("MCOPY [%0, %1, %2]\n" : : "r"(a), "r"(b), "r"(MAX_SUPPORT_SIZE) : "memory");
        n = n - MAX_SUPPORT_SIZE;
        a = a + MAX_SUPPORT_SIZE;
        b = b + MAX_SUPPORT_SIZE;
    }
    __asm__ __volatile__("MCOPY [%0, %1, %2]\n" : : "r"(a), "r"(b), "r"(n) : "memory");
    return aa;
}

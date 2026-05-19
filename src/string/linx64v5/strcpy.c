#include <stdio.h>
#include <string.h>

#define MAX_SIZE 65535
#define unlikely(x) __builtin_expect(!!(x), 0)

char * strcpy(char *dest, const char *src) {

    int len = strlen(src);
  	char *dest_backup = (char *)dest;
    while (unlikely(len > MAX_SIZE)) {
        __asm__ __volatile__("MCOPY [%0, %1, %2]\n"::"r"(dest),"r"(src),"r"(MAX_SIZE) : "memory");
        dest += MAX_SIZE;
        src += MAX_SIZE;
        len -= MAX_SIZE;
    }
    __asm__ __volatile__("MCOPY [%0, %1, %2]\n"::"r"(dest),"r"(src),"r"(len) : "memory");
    
    // 添加结束符
    dest += len;
    *dest = '\0';
	return dest_backup;
}
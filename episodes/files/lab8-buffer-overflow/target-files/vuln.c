#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void win() {
    printf("\n=== ACCESS GRANTED ===\n");
    printf("flag{lab8_ret2win_stack_overflow}\n");
    fflush(stdout);
    system("/bin/sh");
}

void vulnerable() {
    char buffer[64];
    printf("Enter your input: ");
    fflush(stdout);
    read(0, buffer, 200);  /* deliberately larger than buffer[64] - no bounds check */
}

int main() {
    setvbuf(stdout, NULL, _IONBF, 0);
    vulnerable();
    printf("Normal execution finished.\n");
    return 0;
}

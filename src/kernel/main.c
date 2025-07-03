#include "stdint.h"
#include "stdio.h"


//_cdecl is use to integrate(entry point for out asm file)
void _cdecl cstart_(){
    puts("hello from C");
}
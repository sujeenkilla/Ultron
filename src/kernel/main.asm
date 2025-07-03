BITS 16

section _ENTRY class=CODE

extern _cstart_

global entry

entry:
    CLI ;clear intrupt
    MOV ax,ds
    MOV ss,ax
    MOV sp,0
    MOV bp,sp
    STI

    CALL _cstart_

    CLI
    HLT
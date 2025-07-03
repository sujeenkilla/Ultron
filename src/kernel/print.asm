BITS 16

section _TEXT class   =   CODE

global _x86_Viedo_WriteCharTeletype
_x86_Viedo_WriteCharTeletype:
    PUSH bp
    MOV bp,sp

    PUSH bx

    MOV ah,0Eh
    MOV al, [bp+4] ;arg
    MOV bh, [bp+6]  ;page number(arg 2)

    INT 10h

    POP bx
    MOV sp,bp

    POP bp

    RET


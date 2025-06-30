ORG 0x7C00
BITS 16


JMP SHORT main
NOP

bdb_oem: DB 'MSWIN4.1'
bdb_bytes_per_sector: DW 512
bdb_sector_per_cluster: DB 1
bdb_reserved_sector: DW 1
bdb_fat_count: DB 2
bdb_dir_entries_count: DW 0E0h
bdb_total_sector: DW 2880
bdb_media_descriptor_type: DB 0F0h
bdb_sector_per_fat: DW 9
bdb_sectors_per_track: DW 18
bdb_heads: DW 2
bdb_hidden_sector: DD 0
bdb_large_sector_count: DD 0

ebr_drive_number: DB 0
                DB 0
ebr_signature: DB 29h
ebr_volume_id: DB 12h,34h,56h,78h
ebr_volume_label: DB 'Ultron     '
ebr_system_id:  DB 'FAT12   '
main:
    MOV ax,0
    MOV ds,ax
    MOV es,ax
    MOV ss,ax

    MOV sp,0x7C00

    MOV [ebr_drive_number],dl
    MOV ax, 1 ; lba_index number
    MOV cl, 1
    MOV bx, 0x7E00

    CALL disk_read




    MOV si,os_boot_msg
    CALL print
    HLT
halt:
    JMP halt


;input: LBA index in ax
;cx[bits 0-5] :sector number
;cx[bits 6-15] :cylinder
lba_to_chs:
    PUSH ax
    PUSH dx

    XOR dx,dx

    DIV word [bdb_sectors_per_track] ; normally when we do division it divides what we provided with eax and store it in the eax and reminder into dx
                                      ;and the formula for converting chs to lba is " (lba% sectors per track)+1 "
    INC dx                           ; here we are incrementing dx with +1
    MOV cx, dx
    XOR dx,dx
    DIV word [bdb_heads] ;result in eax and remindder in dx
    MOV dh,dl ; moving lower 6 bits(of dx) into dh
    MOV ch,al ; moving lower 6bits(of ax) into ch
    SHL ah, 6 ; shifting 6bits left in ax
    OR CL,AH

    POP ax
    MOV dl,al
    POP ax
    RET

disk_read:
    PUSH ax
    PUSH bx
    PUSH cx
    PUSH dx
    PUSH di

    CALL lba_to_chs

    MOV ah, 02h ; to read
    MOV di, 3   ;counter


retry:
    STC     ;enabling carry to check if read is ok or not
    INT 13h ; BIOS interupt for reading
    jnc doneRead ;jnc -> 0 if sucess , jnc -> 1 if not

    CALL diskReset
    DEC di
    TEST di,di
    JNZ retry ; retryings

failDiskRead:
    MOV si, read_failure
    CALL print
    HLT
    JMP halt
diskReset:
    pusha
    MOV ah, 0 ;reset read a
    STC
    INT 13h
    JC failDiskRead
    POPA
    RET
doneRead:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    ret

print:
    PUSH si
    PUSH ax
    PUSH bx

print_loop:
    LODSB
    OR al,al
    JZ done_print

    MOV ah,0x0E
    MOV bh,0
    INT 0x10
    JMP print_loop

done_print:
    POP bx
    POP ax
    POP si
    RET


os_boot_msg: DB "OUR OS has booted",0x0D,0x0A,0
read_failure: DB "Failed to read DISK",0x0D,0x0A,0
TIMES 510-($-$$) DB 0
DW 0AA55h
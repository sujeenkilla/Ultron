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

    ;
    ;Creating A File System(Reading and Loading)
    ;
    MOV ax,[bdb_sector_per_fat] ; FAT contains sectors(9)
    MOV bl,[bdb_fat_count]      ;total 2 FATS
    XOR bh,bh
    MUL bx                      ;stores value in ax (9*2)=18
    ADD ax, [bdb_reserved_sector]; LBA root directory
    PUSH ax

    MOV ax, [bdb_dir_entries_count]
    SHL ax, 5 ; shifting power 2 to left i.e 5=32 (and storing in ax)

    XOR dx,dx ; clear dx
    DIV word [bdb_bytes_per_sector] ; 512 with ax(32*entry)

    TEST dx,dx  ; testing if this contain value
    JZ rootDirAfter
    INC ax ;next dir in root

rootDirAfter:
    MOV cl,al
    POP ax
    MOV dl, [ebr_drive_number]
    MOV bx, buffer
    CALL disk_read

    XOR bx,bx
    MOV di,buffer ; pushing all dirs into di


searchKernel:
    MOV si, [file_kernel_bin] ; takes the file name
    MOV cl,11                 ;set size (11) 11= sile name size
    PUSH di                   ;preserve di value in STACK
    REPE CMPSB                ;compare it
    POP di                    ;pop off the value di after comp
    JE foundKernal            ;JUMP if equal

    ADD di ,32                ; moving immidate value into di
    INC bx                    ; increament by 1
    CMP bx, [bdb_dir_entries_count] ; comp bx and total entires
    JL searchKernel             ; if < the value then jump to ***

    JMP kernelNotFound          ; or else jmp to ***

kernelNotFound:
    MOV si,[msg_kernel_not_found]  ; moving msg to source index
    CALL print                      ; printing the msg
    HLT
    JMP halt                        ;loop

foundKernal:
    MOV ax, [di+26]                 ; mov inital FAT offset
    MOV [kernel_cluster], ax        ;loading ax into kernel_cluster

    MOV ax, [bdb_reserved_sector]    ; load data from ***
    MOV bx, buffer                  ; loading buffer into bx
    MOV cl, [bdb_sector_per_fat]     ; 9 int cl
    MOV dl, [ebr_drive_number]       ; *** int dl

    CALL disk_read                      ;calling disk_read

    MOV bx, kernel_load_segment         ; mov kernal segment 0x2000
    MOV es, bx                          ; actual reading after all ellocations and locatng
    MOV bx, kernel_load_offset          ; kernal offset() into bx

loadKernel:
    MOV ax, [kernel_cluster]            ;value of cluster (current cluster that is iin it)
    ADD ax, 31                          ; in floppy we add 31(channge)
    MOV cl, 1                           ;load number of sector
    MOV dl, [ebr_drive_number]          ; drive number

    CALL disk_read
    ADD bx, [bdb_bytes_per_sector]      ; adding bytes into bx after reading

    MOV ax, [kernel_cluster]            ; as it overrites we need to load again
    MOV cx, 3                           ; mov val
    MUL cx                              ; mul with ax
    MOV cx, 2                           ; mov 2
    DIV cx                              ; ax/2(cx=2) = ax= (kernalcluster*3)/2
                                        ; after perform ops if the value is even=lower 12bit and if odd higher 12bits
                                        ; to get next location in ax (as ax has current file)

    MOV si, buffer                      ; SI now points to start of buffer
    ADD si, ax                          ; SI points file in the ax in buffer offset
    MOV ax, [ds:si]                     ; AX gets the 16-bit value at that offset

    ; shifting based on ax value
     OR dx,dx                           ; check reminder (as we perform DIV result store in ax and reminder in dx)
     JZ even                            ; if even Lower 12bits, odd Upper 12bits


odd:
    SHR ax,4                            ; shifting 4 bytes
    JMP nextClusterAfter
even:
    AND ax, 0x0FFF                          ;get other 12bitss

nextClusterAfter:
    CMP ax, 0x0FF8                      ; comparing value in ax and last in buffer
    JAE readFinish                      ; eql then ***

    MOV [kernel_cluster], ax            ; ax into ***
    JMP loadKernel

readFinish:
    MOV dl, [ebr_drive_number]            ; drive number into dl
    MOV ax, kernel_load_segment
    MOV ds,ax
    MOV es,ax

    JMP kernel_load_segment:kernel_load_offset ; jum to kernal entry point

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


os_boot_msg: DB "OUR OS has booted from bootloader not from kernal",0x0D,0x0A,0
read_failure DB "Failed to read DISK",0x0D,0x0A,0
file_kernel_bin DB "KERNEL  BIN"
msg_kernel_not_found DB "KERNEL.BIN not found",0

kernel_cluster DW 0

kernel_load_segment EQU 0x2000
kernel_load_offset EQU 0

TIMES 510-($-$$) DB 0
DW 0AA55h

buffer:
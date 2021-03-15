; Note that the highest BRAM address is 0xFFFF.
; SRAM addresses start from 0x10000 and end at 0x80000.

; _start:
    MOV r0, FF00h               ; AICT base
    MOV r1, 4E2h                ; Clock divider: 12Mhz / 9600Hz
    STR [r0+BCh], r1
    
    MOV r10, FFFFh              ; Setup buffer address
    ADD r10, r10, 1
    MOV r11, 0

waitrx:
    LDR r1, [r0+B8h]            ; Load uart status
    TST r1, 40h                 ; Test received bit
    BEQ waitrx

    LDR r2, [r0+B4h]            ; Read rx buffer
    STR [r10+r11], r2           ; Store it
    MOV r1, 2                   ; Set rx ack bit
    STR [r0+B8h], r1

    CMP r2, 0Ah
    BEQ print

    ADD r11, r11, 4
    B waitrx

print:
    MOV r12, 0

print_loop:
    CMP r12, r11
    BGE print_end

    LDR r1, [r10+r12]           ; Read character from memory
    STR [r0+B0h], r1
    MOV r1, 1                   ; Set tx send bit
    STR [r0+B8h], r1

    ADD r12, r12, 4

waittx:
    LDR r1, [r0+B8h]
    TST r1, 20h                 ; Test tx busy bit
    BNE waittx
    B print_loop

print_end:
    MOV r11, 0
    B waitrx

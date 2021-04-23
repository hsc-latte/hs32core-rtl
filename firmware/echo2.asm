; This program reads UART input into a buffer in high mem
; and prints it back when the newline character is deteted.

; _start:
    MOV r0, FF00h               ; AICT base
    MOV r1, 4E2h                ; Clock divider: 12Mhz / 9600Hz
    STR [r0+BCh], r1

; Note that the highest BRAM address is 0x0FFF (2^12 address bits = 8 * 4 kibit).
; SRAM addresses start from 0x1000 and end at 0x80000 (512 kib - 4 kib).

    MOV r10, FFFFh              ; Setup buffer address
    ADD r10, r10, FFFFh
    ADD r10, r10, 2
    MOV r11, 0

waitrx:
    LDR r1, [r0+B8h]            ; Load uart status
    TST r1, 40h                 ; Test received bit
    BEQ waitrx

    LDR r2, [r0+B4h]            ; Read rx buffer
    STR [r10+r11], r2           ; Store it
    MOV r1, 2                   ; Set rx ack bit
    STR [r0+B8h], r1
    ADD r11, r11, 4

    CMP r2, 0Ah
    BEQ print

    B waitrx

print:
    MOV r9, 0

print_loop:
    CMP r9, r11
    BEQ print_end

    LDR r1, [r10+r9]            ; Read character from memory
    STR [r0+B0h], r1
    MOV r1, 1                   ; Set tx send bit
    STR [r0+B8h], r1

    ADD r9, r9, 4

waittx:
    LDR r1, [r0+B8h]
    TST r1, 20h                 ; Test tx busy bit
    BNE waittx
    B print_loop

print_end:
    MOV r11, 0
    B waitrx

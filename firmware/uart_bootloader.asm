; This program reads UART input into a buffer in high mem
; and prints it back when the newline character is deteted.

; _start:
    MOV r0, FF00h               ; AICT base
    MOV r1, 4E2h                ; Clock divider: 12Mhz / 9600Hz
    STR [r0+BCh], r1


; print the hello message
    STR [r0+80h] <- r1
start_hello:
    ADD r1 <- pc + hello_msg         ; Calculate absolute address of data
    SUB r1 <- r1 - 7            ; Offset by (-3 - 4)
hello_loop:
    LDR r2 <- [r1]
    AND r2 <- r2 & FFh
    CMP r2, 0
    BEQ end_hello
    BL write_hello
    ADD r1 <- r1 + 1
    B hello_loop

write_hello:
    MOV r3 <- 1                 ; Do TX write
    STR [r0+B0h] <- r2
    STR [r0+B8h] <- r3

waittx_hello:
    LDR r4 <- [r0+B8h]
    TST r4, 20h                 ; Test TX busy bit
    BNE waittx_hello
    MOV pc <- lr                ; Return

end_hello:
; Read 4 byte size.
    MOV r8 <- 0                 ; The size int we are building, init to 0
    BL readbyte                 ; return value is in r5
    ADD r8 <- r8 + r5 shl 24
    BL readbyte                 ; return value is in r5
    ADD r8 <- r8 + r5 shl 16
    BL readbyte                 ; return value is in r5
    ADD r8 <- r8 + r5 shl 8
    BL readbyte                 ; return value is in r5
    ADD r8 <- r8 + r5


    ; Now r8 = Size

    ; Count down till Size is zero, filling memory with the program

; Note that the highest BRAM address is 0x0FFF (2^12 address bits = 8 * 4 kibit).
; SRAM addresses start from 0x1000 and end at 0x80000 (512 kib - 4 kib).

    ; r10 = base program address, set to 1 + FFFF
    ; r11 = program current pointer

    MOV r10, FFFFh              ; Setup base program address
    ADD r10, r10, 1
    MOV r11, 0                  

read_prog_loop:
    MOV r9 <- 0                 ; The prog word we are building, init to 0
    BL readbyte                 ; return value is in r5
    ADD r9 <- r9 + r5 shl 24
    BL readbyte                 ; return value is in r5
    ADD r9 <- r9 + r5 shl 16
    BL readbyte                 ; return value is in r5
    ADD r9 <- r9 + r5 shl 8
    BL readbyte                 ; return value is in r5
    ADD r9 <- r9 + r5
    ; Now r9 = prog word

    STR [r10+r11], r9           ; Store it in program memory
    ADD r11, r11, 4             ; Increment program address by 4, word size.
    
    CMP r8, r11                 ; Compare program pointer with size to read
    BGE read_prog_loop                        ; Branch if greater than, go back to start
    ; B   start_hello          ; else read the next program word


; All done loading code, now print code out to verify it
    MOV r11, 0                  ; reset the pointer to code to 0


print_code_loop:
    LDR r6 <- [r10+r11]
    ; MOV r2 <- r6 shr 24
    ; AND r2 <- r6 & FFh
    ; CMP r2, 0                 ; check if character is 0 (strings)
    CMP r8, r11                 ; Compare program pointer with size to read
    BEQ end_print_code
    MOV r2 <- r6 shr 24
    BL write_code
    MOV r2 <- r6 shr 16
    BL write_code
    MOV r2 <- r6 shr 8
    BL write_code
    MOV r2 <- r6
    BL write_code
    ADD r11 <- r11 + 4
    B print_code_loop

write_code:
    MOV r3 <- 1                 ; Do TX write
    AND r2 <- r2 & FFh          ; only fill the low bytes, write 8 bits at a time
    STR [r0+B0h] <- r2
    STR [r0+B8h] <- r3

waittx_code:
    LDR r4 <- [r0+B8h]
    TST r4, 20h                 ; Test TX busy bit
    BNE waittx_code
    MOV pc <- lr                ; Return

; All done printing code, now run it.
end_print_code:

    MOV  pc <- r10              ; jump to loaded code

    ; MOV r2 <- 0400h             ; Turn on green LED
    ; STR [r0+84h] <- r2
    ;B 0                        ; loop forever


readbyte:
    LDR r1, [r0+B8h]            ; Load uart status
    TST r1, 40h                 ; Test received bit
    BEQ readbyte                ; keep waiting

    LDR r5, [r0+B4h]            ; Read rx buffer
    MOV r1, 2                   ; Set rx ack bit
    STR [r0+B8h], r1

    MOV pc <- lr                ; Return

hello_msg: db "Hi! I’m the UART Bootloader! Please feed me bytes, I am hungry!",0Ah, 0h

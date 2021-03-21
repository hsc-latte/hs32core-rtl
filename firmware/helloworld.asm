; _start:
    MOV r0 <- FF00h             ; AICT base
    MOV r1 <- 4E2h              ; Clock divider: 12Mhz / 9600Hz
    STR [r0+BCh] <- r1
    MOV r1 <- 0FFFh             ; Set GPIO mode out
    STR [r0+80h] <- r1

    ADD r1 <- pc + data         ; Calculate absolute address of data
    ADD r1 <- r1 + 1            ; Offset by (-3 + 4)

loop:
    LDR r2 <- [r1]
    AND r2 <- r2 & FFh
    CMP r2, 0
    BEQ end
    BL write
    ADD r1 <- r1 + 1
    B loop

write:
    STR [r0+B0h] <- r2
    MOV r3 <- 1                 ; Do TX write
    STR [r0+B8h] <- r3

waittx:
    LDR r4 <- [r0+B8h]
    TST r4, 20h                 ; Test TX busy bit
    BNE waittx
    MOV pc <- lr                ; Return

end:
    MOV r2 <- 0400h             ; Turn on green LED
    STR [r0+84h] <- r2
    B 0

data: db "Hello, World!", 0h
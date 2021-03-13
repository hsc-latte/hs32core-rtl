; _start:
    MOV r0 <- FF00h         ; AICT base
    MOV r1 <- 68h           ; 12Mhz/115200Hz
    STR [r0+BCh] <- r1
    MOV r1 <- 0FFFh         ; Set GPIO mode out
    STR [r0+80h] <- r1
    MOV r1 <- data+17       ; We need to offset at pc-3 = 17

loop:
    LDR r2 <- [r1]
    AND r2 <- r2 & FFh
    CMP r2, 0
    BEQ end
    BL write
    ADD r1 <- r1 + 1
    B loop

end:
    MOV r2 <- 0800h     ; Set green LED
    STR [r0+84h] <- r2
    B 0

write:
    MOV r3 <- 1         ; Do TX write (badness 1000)
    STR [r0+B0h] <- r2
    STR [r0+B8h] <- r3
readtx:
    LDR r4 <- [r0+B8h]
    TST r4, 20h         ; Test TX ready
    BNE readtx          ; Loop if not zero
    MOV pc <- lr        ; Return

data: db "Hello, World!", 0h
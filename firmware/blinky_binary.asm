; _start:
    MOV r0 <- FF00h             ; AICT base address
    MOV r1 <- 0FFFh             ; Set GPIO mode out
    STR [r0+80h] <- r1

    MOV r1 <- 1

loop:
    MOV r2 <- r1 shr 16
    STR [r0+84h] <- r2
    ADD r1 <- r1 + 1
    B loop
    
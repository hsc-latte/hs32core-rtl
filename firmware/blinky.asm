; _start:
    MOV r0 <- FF00h     ; AICT base address
    MOV r1 <- 0FFFh     ; Set GPIO mode out
    STR [r0+80h] <- r1
    MOV r1 <- 16E3h     ; Timer match ~ 1 Hz
    MOV r2 <- 2Dh       ; Timer config = 01 01 101 (toggle normal 1024)
    STR [r0+A4h] <- r1
    STR [r0+A0h] <- r2
    B 0
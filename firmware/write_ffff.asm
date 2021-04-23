MOV r0, FF00h
MOV r1 <- 0FFFh
STR [r0+80h] <- r1

; LDR r1, [buffer-4]
MOV r1, 0010h
MOV r1, r1 shl 16

; r2 <- FFFF_FFFF
MOV r2, F0F0h
ADD r2, r2, 0F0Fh
MOV r2, r2 shl 16
ADD r2, r2, F0F0h
ADD r2, r2, 0F0Fh

; MOV r1, r1
STR [r1], r2

; MOV r1, r1
LDR r6, [r1]

; Write led
; MOV r1, r1
STR [r0+84h] <- r6

B 0

buffer: db 00h, 01h, 00h, 00h

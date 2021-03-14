; _start:
    MOV r0, FF00h               ; AICT base
    MOV r1, 68h                 ; Clock divider: 12Mhz / 115200Hz
    STR [r0+BCh], r1

waitrx:
    LDR r2, [r0+B8h]            ; Load uart status
    TST r2, 40h                 ; Test rx received bit
    BEQ waitrx

    LDR r2, [r0+B4h]            ; Read tx buffer
    STR [r0+B0h], r2            ; Write rx buffer
    MOV r2, 3                   ; Set tx and rx ack bits
    STR [r0+B8h], r2
    B waitrx

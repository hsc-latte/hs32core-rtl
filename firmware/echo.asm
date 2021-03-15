; _start:
    MOV r0, FF00h               ; AICT base
    MOV r1, 4E2h                ; Clock divider: 12Mhz / 9600Hz
    STR [r0+BCh], r1
    MOV r1, 0FFFh               ; Set GPIO mode out (for LED)
    STR [r0+80h], r1

waitrx:
    MOV r1, 0                   ; Turn off green LED
    STR [r0+84h], r1
    LDR r1, [r0+B8h]            ; Load uart status
    TST r1, 40h                 ; Test rx received bit
    BEQ waitrx

    MOV r1, 0400h               ; Turn on green LED
    STR [r0+84h], r1
    LDR r1, [r0+B4h]            ; Read tx buffer
    STR [r0+B0h], r1            ; Write rx buffer
    MOV r1, 3                   ; Set tx and rx ack bits
    STR [r0+B8h], r1

waittx:
    LDR r1, [r0+B8h]
    TST r1, 20h                 ; Test TX busy bit
    BNE waittx
    B waitrx                    ; Go back and wait for rx

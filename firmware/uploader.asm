; _start:

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

puts:
    STR [r0+B0h], r1            ; Write to tx buffer 
    MOV r1, 1                   ; Do tx write
    STR [r0+B8h], r1
waittx:
    LDR r1, [r0+B8h]
    TST r1, 20h                 ; Test tx busy bit
    BNE waittx
    MOV pc, lr                  ; Return

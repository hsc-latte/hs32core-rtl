.. raw:: html

    <style>
        svg { width: 100% !important; }
        html.writer-html5 .rst-content dl.footnote>dd,
        .rst-content dl p {
            margin-bottom: 0px !important;
        }
        .opcode-table tr td:last-child code {
            background: none !important;
            border: none !important;
            padding: 0px !important;
            font-size: 90% !important;
        }
    </style>

.. |br| raw:: latex

   \\

.. |bh| raw:: html

    <br />

.. role:: u
    :class: underline

Base ISA Specification
===============================================================================

Changelog since rev1.

- Removed user mode and added extra banks for IRQ mode
- Moved MCR to the flags bank, freeing up one more GPR
- Moved NZCV from flags[31:28] to flags[11:8]
- Changed PC to be the current instruction address (instead of cur+4)

Unprivileged register model
-------------------------------------------------------------------------------

The base HS32 ISA supports 13 general-purpose ``r`` registers in addition to
the PC, LR and the special purpose FLAGS and MCR banked registers.
All registers have a fixed length of 32-bits.

Below is a table of the register banks across all modes. The processor's default
state is supervisor mode and enters IRQ mode upon an interrupt.

+-----------+-------------------------+-------------------------------------+
| Encoding  | Mode (bank)             | Description                         |
|           +---------------+---------+                                     |
|           | Supervisor (1)| IRQ (2) |                                     |
+===========+===============+=========+=====================================+
| 0000      | r0                      | General purpose                     |
+-----------+-------------------------+-------------------------------------+
| ...       | ...                     | ...                                 |
+-----------+-------------------------+-------------------------------------+
| 0111      | r7                      | General purpose                     |
+-----------+---------------+---------+-------------------------------------+
| 1000      | r8_s          | r8_i    | General purpose                     |
+-----------+---------------+---------+-------------------------------------+
| ...       | ...           | ...     | ...                                 |
+-----------+---------------+---------+-------------------------------------+
| 1100      | r12_s         | r12_i   | General purpose/Frame pointer [1]_  |
+-----------+---------------+---------+-------------------------------------+
| 1101      | r13_s         | r13_i   | General purpose/Stack pointer [1]_  |
+-----------+---------------+---------+-------------------------------------+
| 1110      | lr_s          | lr_i    | Link register                       |
+-----------+---------------+---------+-------------------------------------+
| 1111      | pc                      | Program counter                     |
+-----------+---------------+---------+-------------------------------------+

+-----------+-------------------------+-------------------------------------+
| Encoding  | Bank 3                  | Description                         |
+===========+=========================+=====================================+
| 0000      | flags                   | Program status register             |
+-----------+-------------------------+-------------------------------------+
| 0001      | mcr                     | Machine configuration register      |
+-----------+-------------------------+-------------------------------------+
| ...       | Reserved                | Reserved for future use             |
+-----------+-------------------------+-------------------------------------+

.. [1] By convention, r11/r12 and r13 are the frame and stack pointers, 
       respectively. Their contents do not influence the documented behaviour of 
       the instructions.

Registers r0-r7, MCR and PC are shared between the supervisor and IRQ modes. The 
program counter holds the address of the current instruction.

.. note:: Interrupt latency can be decreased if the interrupt service routine
          only uses r8 to r13, as the current execution context does not
          need to be saved.

The following figure describes the contents of the MCR: |br|

.. bitfield::
    :bits: 32
    :vspace: 48
    :lanes: 1

        [
            { "name": "I", "bits": 1 },
            { "name": "S", "bits": 1 },
            { "name": "", "bits": 1, "type": 1 },
            { "name": "V", "bits": 5 },
            { "name": "F", "bits": 4 },
            { "name": "", "bits": 2, "type": 1 },
            { "name": "Debug flags", "bits": 10 },
            { "name": "DSn", "bits": 8 }
        ]

========== ======= ============================================================
Bits       Name    Description
========== ======= ============================================================
mcr[0:0]   I       Mask all interrupts when 0
mcr[1:1]   S       Set when in supervisor mode
mcr[2:2]   --      Reserved
mcr[7:3]   V       Interrupt vector number
mcr[11:8]  F       Saved flag register ``flags[3:0]``
mcr[13:12] --      Reserved
mcr[23:14] --      Debug flags (documented below)
mcr[31:24] DSn     Debug step amount
========== ======= ============================================================

The following figure describes the debug flags: |br|

.. bitfield::
    :bits: 10
    :vspace: 48
    :lanes: 1

        [
            { "name": "DBG",    "bits": 1, "type": 3 },
            { "name": "DBG_B",  "bits": 1 },
            { "name": "DBG_L",  "bits": 1 },
            { "name": "DBG_R",  "bits": 1 },
            { "name": "DBG_W",  "bits": 1 },
            { "name": "DBGi_S", "bits": 1, "type": 5 },
            { "name": "DBGi_B", "bits": 1 },
            { "name": "DBGi_L", "bits": 1 },
            { "name": "DBGi_R", "bits": 1 },
            { "name": "DBGi_W", "bits": 1 }
        ]

========== ======== ===========================================================
Bits       Name     Description
========== ======== ===========================================================
mcr[14:14]  DBG     Debug mode enable
mcr[15:15]  DBG_B   Break on branch
mcr[16:16]  DBG_L   Break on branch and link
mcr[17:17]  DBG_R   Break on memory read
mcr[18:18]  DBG_W   Break on memory write
mcr[19:19]  DBGi_S  Breakpoint reached
mcr[20:20]  DBGi_B  Current breakpoint type: "Break on branch"
mcr[21:21]  DBGi_L  Current breakpoint type: "Break on branch and link"
mcr[22:22]  DBGi_R  Current breakpoint type: "Break on memory read"
mcr[23:23]  DBGi_W  Current breakpoint type: "Break on memory write"
========== ======== ===========================================================

The following figure describes the flags register: |br|

.. bitfield::
    :bits: 32
    :vspace: 48
    :lanes: 1

        [
            { "name": "Reserved", "bits": 8, "type": 1 },
            { "name": "V", "bits": 1 },
            { "name": "C", "bits": 1 },
            { "name": "Z", "bits": 1 },
            { "name": "N", "bits": 1 },
            { "name": "Reserved", "bits": 20, "type": 1 }
        ]

|bh|
where NZCV are the standard ALU arithmetic flags: :u:`N`\ egative, :u:`Z`\ ero,
:u:`C`\ arry and o\ :u:`V`\ erflow.

Encoding formats
-------------------------------------------------------------------------------

The base HS32 ISA describes 2 instruction encodings I/R. All instructions are a 
fixed 32-bits long and must be aligned on a 4-byte boundary in memory.

.. note:: The behaviour of executing from an unaligned address is undefined.

Furthermore, each encoding has its opcode, destination register (Rd) and source 
register (Rm) fields in the same position to simplify decoding.

**I-Type**:
    This encoding describes an operation involving Rd, Rm and a 16-bit immediate 
    value. The immediate is reconstructed as a sign-extended 32-bit value, with 
    bits ``imm[31:16]`` set to ``imm[15]``.

.. bitfield::
    :bits: 32
    :vspace: 62
    :lanes: 1

        [
            { "name": "imm[15:0]", "bits": 16, "attr": "" },
            { "name": "rm", "bits": 4, "attr": "src1 reg" },
            { "name": "rd", "bits": 4, "attr": "dest reg" },
            { "name": "opcode", "bits": 8, "attr": "" }
        ]

**R-Type**:
    This encoding describes an operation involving Rd, Rm and Rn. The bank field 
    dictates the register bank of Rm [2]_. The fields ``sh`` and ``dir`` encodes 
    the shift direction and amount. Shifting applies to Rn only. Further, the PC 
    register can not be specified as Rn and results in an #UD exception.

.. bitfield::
    :bits: 32
    :vspace: 62
    :lanes: 1

        [
            { "name": "bank", "bits": 2, "attr": "" },
            { "name": "dir", "bits": 2, "attr": "" },
            { "name": "sh", "bits": 4, "attr": "shift amount" },
            { "bits": 4, "name": "func" },
            { "name": "rn", "bits": 4, "attr": "src2 reg" },
            { "name": "rm", "bits": 4, "attr": "src1 reg" },
            { "name": "rd", "bits": 4, "attr": "dest reg" },
            { "name": "opcode", "bits": 8, "attr": "" }
        ]

.. [2] Only applicable for selected instructions. Otherwise, the field is ignored.

The table below describes the fields of ``bank`` and ``sh``.

=== =========================== ==== ===========================
dir Description                 bank Description
=== =========================== ==== ===========================
00  Left shift                  00   Reserved
01  Right shift                 01   Supervisor bank
10  Sign extended right shift   10   Interrupt bank
11  Rotate right                11   Bank 3
=== =========================== ==== ===========================

**M-Type**:
    This encoding describes a load/store operation involving Rd, Rm and a 14-bit
    immediate, reconstructed as a 32-bit sign-extended immediate.

.. bitfield::
    :bits: 32
    :vspace: 62
    :lanes: 1

        [
            { "name": "imm[13:0]", "bits": 14, "attr": "" },
            { "name": "func", "bits": 2, "attr": "" },
            { "name": "rm", "bits": 4, "attr": "src1 reg" },
            { "name": "rd", "bits": 4, "attr": "dest reg" },
            { "name": "opcode", "bits": 8, "attr": "" }
        ]

Reserved fields result in undefined behaviour. Their values are unspecified and 
thus, can be used to implement nonstandard extensions to the base ISA. In the 
standard HSC Core implementing the HS32 rev2 ISA, reserved fields are ignored and 
will not generate an exception upon execution.

Instruction table
-------------------------------------------------------------------------------

.. sss: m/x i/n d/x
.. dd: xx, ad, mr, ma
.. flags: r, W/R, f, g, DD, B

.. rst-class:: opcode-table
======  ======================= === ===========
Instr   Operation               Enc Opcode     
======  ======================= === ===========
LDR_.x  Rd <- [Rm + imm]        I   00_1000    
\       Rd <- [Rm + sh(Rn)]     R   01_1000    
STR_.x  [Rm + imm] <- Rd        I   00_1001    
\       [Rm + sh(Rn)] <- Rd     R   01_1001    
MOVT_   Rd.upper <- imm         I   00_0001    
MOV_    Rd <- imm               I   00_0000    
\       Rd <- sh(Rn)            R   01_0001    
\       Rd <- Rm_b              R   01_0010    
\       Rd_b <- Rm              R   01_0011    
ADD     Rd <- Rm + imm          I   10_0000    
\       Rd <- Rm + sh(Rn)       R   11_0000    
ADDC    Rd <- Rm + imm + C      I   10_0001    
\       Rd <- Rm + sh(Rn) + C   R   11_0001    
SUB     Rd <- Rm - imm          I   10_0010    
\       Rd <- Rm - sh(Rn)       R   11_0010    
SUBC    Rd <- Rm - imm - C      I   10_0011    
\       Rd <- Rm - sh(Rn) - C   R   11_0011    
AND     Rd <- Rm & imm          I   10_0100    
\       Rd <- Rm & sh(Rn)       R   11_0100    
BIC     Rd <- Rm & ~imm         I   10_0101    
\       Rd <- Rm & sh(Rn)       R   11_0101    
OR      Rd <- Rm | imm          I   10_0110    
\       Rd <- Rm | sh(Rn)       R   11_0110    
XOR     Rd <- Rm ^ imm          I   10_0111    
\       Rd <- Rm ^ sh(Rn)       R   11_0111    
CMP     Rm - imm                I   10_1010    
\       Rm - sh(Rn)             R   11_1010    
TST     Rm & imm                I   10_1100    
\       Rm & sh(Rn)             R   11_1100    
B<c>    PC + Offset             I   01_1001    
B<c>L   PC + Offset             I   01_1001    
INT     imm                     I   01_1000    
======  ======================= === ===========
The above table describes all standard instructions part of the HS32 base ISA 
specification. Note that the internal control signals are implementation-specific 
and not part of the standard ISA specification. The control signals represent the 
behaviour of each instruction and are documented in the :doc:`core` section.

Instruction index
-------------------------------------------------------------------------------

LDR
~~~

**Description of LDR/Load memory to register**
    LDR.B/W/D will load 1/2/4 byte(s) from the address as specified by the operands into the 
    destination register. Restrictions apply to the operand register Rn as 
    described under `Encoding formats`_.

**Variants**

.. rst-class:: opcode-table
===     ==========================  ===========================================
Op      Mnemonic                    Summary
===     ==========================  ===========================================
TBD     LDR.x Rd <- [Rm + imm]      Load 1/2/4 byte(s) from address ``Rm+imm`` to Rd
TBD     LDR.x Rd <- [Rm + sh(Rn)]   Load 1/2/4 byte(s) from address ``Rm+sh(Rn)`` to Rd
===     ==========================  ===========================================

**Flags and exceptions**
    ALU flags are not modified. May throw an #AC exception if alignment checking is 
    enabled and the address is not aligned to a 4-byte boundary.

STR
~~~

**Description of STR/Store register to memory**
    STR.B/W/D will store 1/2/4 byte(s) of the destination register to the memory address as 
    specified by the operands. The same restrictions apply to Rn as in `LDR`_.

**Variants**

.. rst-class:: opcode-table
===     ==========================  ===========================================
Op      Mnemonic                    Summary
===     ==========================  ===========================================
TBD     STR.x [Rm + imm] <- Rd      Store 1/2/4 byte(s) in Rd to address ``Rm+imm``
TBD     STR.x [Rm + sh(Rn)] <- Rd   Store 1/2/4 byte(s) in Rd to address ``Rm+sh(Rn)``
===     ==========================  ===========================================

**Flags and exceptions**
    Same as `LDR`_.

MOV
~~~
**Description of MOV/Move**
    If an immediate is specified, the reconstructed 32-bit immediate is placed
    in the destination register. Otherwise, the value of the source register,
    possibly shifted, is placed in the destination register. The bank field applies
    to either the source or destination operand only when the banked MOV variant
    is used.

**Variants**

.. rst-class:: opcode-table
===     ========================    ===========================================
Op      Mnemonic                    Summary
===     ========================    ===========================================
TBD     Rd <- imm                   Sets Rd to the value of imm
TBD     Rd <- sh(Rn)                Sets Rd to the value of Rn, shifted.
TBD     Rd <- Rm_b                  Sets Rd to the value of a banked source register.
TBD     Rd_b <- Rm                  Sets the value of a banked destination register to Rm.
===     ========================    ===========================================

**Flags and exceptions**
    ALU flags are not modified. This instruction generates no exceptions.

MOVT
~~~~
**Description of MOVT/Move top**
    Will overwrite the upper 16-bits of the destination register with
    the specified 16-bit immediate.

**Variants**

.. rst-class:: opcode-table
===     ========================    ===========================================
Op      Mnemonic                    Summary
===     ========================    ===========================================
TBD     MOVT Rd <- imm              Replaces the upper 16-bits of Rd with ``imm``
===     ========================    ===========================================

**Flags and exceptions**
    Same as `MOV`_.

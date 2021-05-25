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

.. role:: u
    :class: underline

Base ISA Specification
===============================================================================

Changelog since rev1.

- Removed user mode and added extra banks for IRQ mode
- Moved MCR to the flags bank, freeing up one more GPR
- Moved NZCV from flags[31:28] to flags[11:8]

Unprivileged register model
-------------------------------------------------------------------------------

The base HS32 ISA supports 13 general purpose ``r`` registers in addition to
the PC, LR special purpose and FLAGS, MCR banked registers.
All registers have a fixed length of 32-bits.

Below is a table of the register banks across all modes. Supervisor mode is
the default state of the processor while IRQ mode is entered upon an interrupt.

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

.. [1] By convention, r11/r12 and r13 are assigned as the frame and stack
       pointers respectively. Their contents do not influence the documented
       behaviour of the instructions.

As can be seen, the supervisor and IRQ modes only share registers r0 to r7,
MCR and PC.

.. note:: Interrupt latency can be decreased if the interrupt service
          routine is made to use only r8 to r13 as the current execution context
          does not need to be saved.

The following figure describes the contents of the MCR: |br|

.. bitfield::
    :bits: 32
    :vspace: 50
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
    :vspace: 50
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
    :vspace: 50
    :lanes: 1

        [
            { "name": "Reserved", "bits": 8, "type": 1 },
            { "name": "V", "bits": 1 },
            { "name": "C", "bits": 1 },
            { "name": "Z", "bits": 1 },
            { "name": "N", "bits": 1 },
            { "name": "Reserved", "bits": 20, "type": 1 }
        ]

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
    Describes an operation involving Rd, Rm and a 16-bit immediate value.
    The immediate will be reconstructed as a sign-extended 32-bit value, with bits ``imm[31:16]``
    set to ``imm[15]``.

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
    Describes an operation involving Rd, Rm and Rn. The register bank of
    Rm is dictated by the bank field [2]_. The shift direction and amount is
    encoded by ``sh`` and ``dir`` and is applied to Rn only.

.. bitfield::
    :bits: 32
    :vspace: 62
    :lanes: 1

        [
            { "bits": 3, "name": "reserved", "type": 0  },
            { "name": "bank", "bits": 2, "attr": "" },
            { "name": "dir", "bits": 2, "attr": "" },
            { "name": "sh", "bits": 5, "attr": "shift amount" },
            { "name": "rn", "bits": 4, "attr": "src2 reg" },
            { "name": "rm", "bits": 4, "attr": "src1 reg" },
            { "name": "rd", "bits": 4, "attr": "dest reg" },
            { "name": "opcode", "bits": 8, "attr": "" }
        ]

.. [2] Only applicable for selected instructions. Otherwise, the field is ignored.

The fields of ``bank`` and ``sh`` are described in the table below.

=== =========================== ==== ===========================
dir Description                 bank Description
=== =========================== ==== ===========================
00  Left shift                  00   Reserved
01  Right shift                 01   Supervisor bank
10  Sign extended right shift   10   Interrupt bank
11  Rotate right                11   Bank 3
=== =========================== ==== ===========================

Reserved fields will result in undefined behaviour. Their values are unspecified
and thus can be used to implement nonstandard extensions too the base ISA.
In the standard HSC architecture implementing the HS32 rev2 ISA,
reserved fields are ignored and will not generate an exception upon execution.

Instruction table
-------------------------------------------------------------------------------

.. sss: m/x i/n d/x
.. dd: xx, ad, mr, ma
.. flags: r, W/R, f, g, DD, B

.. rst-class:: opcode-table

=====   ======================= === =========== ========================
Instr   Operation               Enc Opcode      Internal control signals
=====   ======================= === =========== ========================
LDR_    Rd <- [imm]             I   TBD         ``mr -i- -------``
\       Rd <- [Rm + imm]        I   TBD         ``mr mi- -------``
\       Rd <- [Rm + sh(Rn)]     R   TBD         ``mr mn- ----DD-``
STR_    [imm] <- Rd             I   TBD         ``ma -id -------``
\       [Rm + imm] <- Rd        I   TBD         ``ma mid -------``
\       [Rm + sh(Rn)] <- Rd     R   TBD         ``ma mnd ----DD-``
MOVT    Rd.upper <- imm         I   TBD         ``ad -i- -------``
MOV     Rd <- imm               I   TBD         ``ad -i- -------``
\       Rd <- sh(Rn)            R   TBD         ``ad -n- ----DD-``
\       Rd <- Rm_b              R   TBD         ``ad mi- -R----B``
\       Rd_b <- Rm              R   TBD         ``ad mi- -W----B``
ADD     Rd <- Rm + imm          I   TBD         ``ad mi- --f----``
\       Rd <- Rm + sh(Rn)       R   TBD         ``ad mn- --f-DD-``
ADDC    Rd <- Rm + imm + C      I   TBD         ``ad mi- --f----``
\       Rd <- Rm + sh(Rn) + C   R   TBD         ``ad mn- --f-DD-``
SUB     Rd <- Rm - imm          I   TBD         ``ad mi- --f----``
\       Rd <- Rm - sh(Rn)       R   TBD         ``ad mn- --f-DD-``
SUBC    Rd <- Rm - imm - C      I   TBD         ``ad mi- --f----``
\       Rd <- Rm - sh(Rn) - C   R   TBD         ``ad mn- --f-DD-``
RSUB    Rd <- imm - Rm          I   TBD         ``ad mi- r-f----``
\       Rd <- sh(Rn) - Rm       R   TBD         ``ad mn- r-f-DD-``
RSUBC   Rd <- imm - Rm - C      I   TBD         ``ad mi- r-f----``
\       Rd <- sh(Rn) - Rm - C   R   TBD         ``ad mn- r-f-DD-``
AND     Rd <- Rm & imm          I   TBD         ``ad mi- --f----``
\       Rd <- Rm & sh(Rn)       R   TBD         ``ad mn- --f-DD-``
BIC     Rd <- Rm & ~imm         I   TBD         ``ad mi- --f----``
\       Rd <- Rm & sh(Rn)       R   TBD         ``ad mn- --f-DD-``
OR      Rd <- Rm | imm          I   TBD         ``ad mi- --f----``
\       Rd <- Rm | sh(Rn)       R   TBD         ``ad mn- --f-DD-``
XOR     Rd <- Rm ^ imm          I   TBD         ``ad mi- --f----``
\       Rd <- Rm ^ sh(Rn)       R   TBD         ``ad mn- --f-DD-``
CMP     Rm - imm                I   TBD         ``-- mi- --f----``
\       Rm - sh(Rn)             R   TBD         ``-- mn- --f-DD-``
TST     Rm & imm                I   TBD         ``-- mi- --f----``
\       Rm & sh(Rn)             R   TBD         ``-- mn- --f-DD-``
B<c>    PC + Offset             I   TBD         ``-- -i- ---g---``
B<c>L   PC + Offset             I   TBD         ``ad -n- r--g---``
INT     imm                     I   TBD         ``0``
=====   ======================= === =========== ========================

Interal control signal specification
-------------------------------------------------------------------------------

TBD

Instruction index
-------------------------------------------------------------------------------

LDR
~~~



STR
~~~


.. opcode[7:5]
.. opcode[0:0]: Set when R-Type

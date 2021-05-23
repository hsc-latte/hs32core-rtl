.. HS32 ISA Specification
.. raw:: html

    <style>
        svg { width: 100% !important; }
        html.writer-html5 .rst-content dl.footnote>dd,
        .rst-content dl p {
            margin-bottom: 0px !important;
        }
    </style>

Base ISA Specification
===============================================================================

Changelog since rev1 (codename: latte). Updated May/22/2021.

- Removed user mode and added extra banks for IRQ mode.
- Moved MCR to the flags bank, freeing up one more GPR. FP can be r11/r12 now.

Unprivileged register model
-------------------------------------------------------------------------------

The base HS32 ISA supports 13 general purpose ``r`` registers in addition to
the PC, LR special purpose and FLAGS, MCR banked registers.
All registers have a fixed length of 32-bits.

Below is a table of the register banks across all modes. Supervisor mode is
the default state of the processor while IRQ mode is entered upon an interrupt.

+-----------+-------------------------+-------------------------------------+
| Encoding  | Mode and bank           | Description                         |
|           +---------------+---------+                                     |
|           | Supervisor    | IRQ     |                                     |
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
| 0000 [2]_ | flags_s       | flags_i | Program status register             |
+-----------+---------------+---------+-------------------------------------+
| 0001 [2]_ | mcr                     | Machine configuration register      |
+-----------+---------------+---------+-------------------------------------+

.. [1] By convention, r11/r12 and r13 are assigned as the frame and stack
       pointers respectively. Their contents do not influence the documented
       behaviour of the instructions.
.. [2] Can only be accessed through the "flags" bank

As can be seen, the supervisor and IRQ modes only share registers r0 to r7,
MCR and PC.

.. note:: Interrupt latency can be decreased if the interrupt service
          routine is made to use only r8 to r13 as the current execution context
          does not need to be saved.

The following figure describes the contents of the MCR:

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

The following figure describes the debug flags:

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

The following figure describes the flags register:

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

.. role:: underline
    :class: underline

where NZCV are the standard ALU arithmetic flags:
:underline:`N`\ egative, :underline:`Z`\ ero,
:underline:`C`\ arry and o\ :underline:`V`\ erflow.

Encoding formats
-------------------------------------------------------------------------------

The base HS32 ISA describes 2 instruction encodings I/R. All instructions are a
fixed 32-bits long and must be aligned on a 4-byte boundary in memory.

.. note:: The behaviour of executing from an unaligned address is undefined.

Furthermore, each encoding has its operand, destination register (Rd) and source
register (Rm) fields in the same position to simplify decoding.

**I-Type**:
    Describes an operation involving Rd, Rm and a 16-bit immediate value.
    The immediate will be reconstructed as a 32-bit value, with bits ``imm[31:16]``
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
    Rm is dictated by the bank field [3]_. The shift direction and amount is
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

.. [3] Only applicable for selected instructions. Otherwise, the field is ignored.



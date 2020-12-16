/**
 * Copyright (c) 2020 The HSC Core Authors
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     https://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 * @file   hs32_xuconst.v
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on November 21 2020, 3:04 AM
 */

`ifndef HS32_XUCONST
`define HS32_XUCONST

// Control signals bit selects
`define CTL_d       ctlsig[15:14]   // Destination
`define CTL_r       ctlsig[13   ]   // Reverse bus
`define CTL_s       ctlsig[12:10]   // Source
`define CTL_b       ctlsig[9:6  ]   // Branch conditions
`define CTL_i       ctlsig[5    ]   // Bank source/dest (1 for write, 0 for read)
`define CTL_f       ctlsig[4    ]   // Modify flags
`define CTL_g       ctlsig[3    ]   // 0 to ignore branch
`define CTL_D       ctlsig[2:1  ]   // Shift mode
`define CTL_B       ctlsig[0    ]   // 0 to ignore bank

// Source signal types
`define CTL_s_xxx   3'b000
`define CTL_s_xix   3'b001
`define CTL_s_mix   3'b010
`define CTL_s_mnx   3'b011
`define CTL_s_xnx   3'b100
`define CTL_s_mid   3'b101
`define CTL_s_mnd   3'b110

// Destination signal types
`define CTL_d_none  2'b00
`define CTL_d_rd    2'b01
`define CTL_d_dt_ma 2'b10
`define CTL_d_ma    2'b11

// Shift directions
`define CTL_D_shl   2'b00
`define CTL_D_shr   2'b01
`define CTL_D_ssr   2'b10
`define CTL_D_ror   2'b11

// FSM States
`define IDLE        0
`define TB1         1
`define TB2         2
`define TR1         3
`define TR2         4
`define TM1         6
`define TM2         7
`define TW2         8
`define INT         9
`define DIE         10
`define TID         11
`define INTRET      12

// MCR defines current machine mode
`define MCR_INTEN   mcr_s[0]        // Interrupt enable
`define MCR_MDE     mcr_s[1]        // Supervisor mode bit
`define MCR_USR     mcr_s[2]        // User mode bit
`define MCR_VEC     mcr_s[7:3]      // Interrupt vector
`define MCR_NZCVi   mcr_s[11:8]     // Saved flags
`define MCR_USRi    mcr_s[12]       // Saved user mode bit
`define MCR_MDEi    mcr_s[13]       // Saved super mode bit

// Debug modes
`define MCR_DBG     mcr_s[14]       // Debug mode enable
`define MCR_DBG_B   mcr_s[15]       // Break when branch
`define MCR_DBG_L   mcr_s[16]       // Break when link
`define MCR_DBG_R   mcr_s[17]       // Break when memory read
`define MCR_DBG_W   mcr_s[18]       // Break when memory write
`define MCR_DBGi_S  mcr_s[19]       // Debug interrupted
`define MCR_DBGi_B  mcr_s[20]
`define MCR_DBGi_L  mcr_s[21]
`define MCR_DBGi_R  mcr_s[22]
`define MCR_DBGi_W  mcr_s[23]
`define MCR_DBGSn   mcr_s[31:24]    // Step amount

// Mode check macros
`define IS_USR      (`MCR_USR == 1)
`define IS_SUP      (`MCR_USR == 0)
`define IS_INT      (`MCR_USR == 0 && `MCR_MDE == 1)
`define BANK_U      (`CTL_B == 1 && bank == 0)
`define BANK_S      (`CTL_B == 1 && bank == 1)
`define BANK_I      (`CTL_B == 1 && bank == 2)
`define BANK_F      (`CTL_B == 1 && bank == 3)

// ALU Conditional flags
`define ALU_N       alu_nzcv[3]
`define ALU_Z       alu_nzcv[2]
`define ALU_C       alu_nzcv[1]
`define ALU_V       alu_nzcv[0]

`endif

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
 * @file   hs32_decode.v
 * @author Anthony Kung <hi@anth.dev>
 * @date   Created on October 24 2020, 10:34 PM
 */

`default_nettype none

//
// Decode Cycle: Determine how to pass
//               instruction to Execute Cycle
//

/* Include OP Codes Definitions */
`include "cpu/hs32_opcodes.v"

/* Include ALU OP Codes Definitions */
`include "cpu/hs32_aluops.v"

`define HS32_NULLI     16'b0
`define HS32_SHIFT     instd[11:7]
`define HS32_SHIFTDIR  instd[6:5]
`define HS32_BANK      instd[4:3]
`define HS32_IMM       instd[15:0]
`define HS32_RD        instd[23:20]
`define HS32_RM        instd[19:16]
`define HS32_RN        instd[15:12]

module hs32_decode (
    input clk,                  // 12 MHz Clock
    input reset,                // Reset

    // Fetch
    input   wire [31:0] instd,  // Next instruction
    output  reg  reqd,          // Valid
    input   wire rdyd,          // Ready

    // Execute
    output  reg  [3:0]  aluop,  // ALU Operation
    output  reg  [4:0]  shift,  // 5-bit shift
    output  reg  [15:0] imm,    // Immediate value
    output  reg  [3:0]  rd,     // Register Destination Rd
    output  reg  [3:0]  rm,     // Register Source Rm
    output  reg  [3:0]  rn,     // Register Operand Rn
    output  reg  [1:0]  bank,   // Bank (bb)
    output  reg  [15:0] ctlsig, // Control signals

    // Execute pipeline logic
    output wire reqe,
    input  wire rdye,

    // Interrupts
    output wire [23:0] int_line
);
    parameter IMUL = 0;

    reg intrq;
    reg intloop;
    reg invalid;
    reg reqel;

    assign reqe = !intloop && reqel;

    assign int_line[0]  = (imm == 0  && intrq) || invalid ? 1 : 0;
    assign int_line[1]  = imm == 1  && intrq ? 1 : 0;
    assign int_line[2]  = imm == 2  && intrq ? 1 : 0;
    assign int_line[3]  = imm == 3  && intrq ? 1 : 0;
    assign int_line[4]  = imm == 4  && intrq ? 1 : 0;
    assign int_line[5]  = imm == 5  && intrq ? 1 : 0;
    assign int_line[6]  = imm == 6  && intrq ? 1 : 0;
    assign int_line[7]  = imm == 7  && intrq ? 1 : 0;
    assign int_line[8]  = imm == 8  && intrq ? 1 : 0;
    assign int_line[9]  = imm == 9  && intrq ? 1 : 0;
    assign int_line[10] = imm == 10 && intrq ? 1 : 0;
    assign int_line[11] = imm == 11 && intrq ? 1 : 0;
    assign int_line[12] = imm == 12 && intrq ? 1 : 0;
    assign int_line[13] = imm == 13 && intrq ? 1 : 0;
    assign int_line[14] = imm == 14 && intrq ? 1 : 0;
    assign int_line[15] = imm == 15 && intrq ? 1 : 0;
    assign int_line[16] = imm == 16 && intrq ? 1 : 0;
    assign int_line[17] = imm == 17 && intrq ? 1 : 0;
    assign int_line[18] = imm == 18 && intrq ? 1 : 0;
    assign int_line[19] = imm == 19 && intrq ? 1 : 0;
    assign int_line[20] = imm == 20 && intrq ? 1 : 0;
    assign int_line[21] = imm == 21 && intrq ? 1 : 0;
    assign int_line[22] = imm == 22 && intrq ? 1 : 0;
    assign int_line[23] = imm == 23 && intrq ? 1 : 0;

    reg full;

    always @(posedge clk)
    if(reset) begin
        reqd <= 0;
        reqel <= 0;
        full <= 0;
    end else if(!intloop) begin
        if(!full) begin
            if(reqd && rdyd) begin
                full <= 1;
                reqd <= 0;
                reqel <= 1;
            end else begin
                reqd <= 1;
                reqel <= 0;
            end
        end else begin
            if(reqe && rdye) begin
                full <= 0;
                reqd <= 1;
                reqel <= 0;
            end else begin
                reqd <= 0;
                reqel <= 1;
            end
        end
    end else begin
        reqd <= 0;
        reqel <= 0;
    end

    // Generate IMUL
    generate always @(posedge clk)
    if(reset) begin
        invalid <= 0;
        intrq <= 0;
        intloop <= 0;
    end else begin
        // Reset interrupts
        if(intrq || invalid) begin
            intrq <= 0;
            invalid <= 0;
        end

        /* If Ready Received */
        if (reqd && rdyd) begin
            /* ISA OP Code Decoding */

            /*************************************************************************/
            /*                            IMPORTANT NOTES                            */
            /* By [IGNORED] the value is being ignored (don't care) by Ececute unit  */
            /* By [ZERO] the value 0 is required and NOT ignored by Ececute unit     */
            /* Critical fields are marked with comments and indicate required values */
            /*************************************************************************/
            casez (instd[31:24])
                default: begin
                    invalid <= 1;
                    intloop <= 1;
                end

                /**************/
                /*    LDR     */
                /**************/

                /* LDR     Rd <- [Rm + imm] */
                `HS32_LDRI: begin
                    aluop <= `HS32A_ADD;     // ADD
                    shift <= 5'd0;   // [IGNORED] Shift
                    imm <= `HS32_IMM;       // Imm
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;         // [IGNORED] Rn
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b10_0_010_0000_000, `HS32_SHIFTDIR, 1'b0 };    // [IGNORED] SHIFTDIR
                end
                /* LDR     Rd <- [Rm] */
                `HS32_LDR: begin
                    aluop <= `HS32A_ADD;     // ADD
                    shift <= 5'd0;   // [IGNORED] Shift
                    imm <= `HS32_NULLI;     // [ZERO] Imm
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;         // [IGNORED] Rn
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b10_0_010_0000_000, `HS32_SHIFTDIR, 1'b0 };    // [IGNORED] SHIFTDIR
                end
                /* LDR     Rd <- [Rm + sh(Rn)] */
                `HS32_LDRA: begin
                    aluop <= `HS32A_ADD;     // ADD
                    shift <= `HS32_SHIFT;   // Shift
                    imm <= `HS32_NULLI;     // [IGNORED] Imm
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b10_0_011_0000_000, `HS32_SHIFTDIR, 1'b0 };    // SHIFTDIR
                end

                /**************/
                /*    STR     */
                /**************/

                /* STR     [Rm + imm] <- Rd */
                `HS32_STRI: begin
                    aluop <= `HS32A_ADD;     // ADD
                    shift <= 5'd0;   // [IGNORED] Shift
                    imm <= `HS32_IMM;       // Imm
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;         // [IGNORED] Rn
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b11_0_101_0000_000, `HS32_SHIFTDIR, 1'b0 };    // [IGNORED] SHIFTDIR
                end
                /* STR     [Rm] <- Rd */
                `HS32_STR: begin
                    aluop <= `HS32A_ADD;     // ADD
                    shift <= 5'd0;   // [IGNORED] Shift
                    imm <= `HS32_NULLI;     // [ZERO] Imm
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;         // [IGNORED] Rn
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b11_0_101_0000_000, `HS32_SHIFTDIR, 1'b0 };    // [IGNORED] SHIFTDIR
                end
                /* STR     [Rm + sh(Rn)] <- Rd */
                `HS32_STRA: begin
                    aluop <= `HS32A_ADD;     // ADD
                    shift <= `HS32_SHIFT;   // Shift
                    imm <= `HS32_NULLI;     // [IGNORED] Imm
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b11_0_110_0000_000, `HS32_SHIFTDIR, 1'b0 };    // SHIFTDIR
                end

                /**************/
                /*    MOV     */
                /**************/

                /* MOV     Rd <- imm */
                `HS32_MOVI: begin
                    aluop <= `HS32A_MOV;     // MOV
                    shift <= 5'd0;   // [IGNORED] Shift
                    imm <= `HS32_IMM;       // Imm
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;         // [IGNORED] Rm
                    rn <= `HS32_RN;         // [IGNORED] Rn
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_001_0000_000, `HS32_SHIFTDIR, 1'b0 };    // [IGNORED] SHIFTDIR
                end
                /* MOV     Rd <- sh(Rn) */
                `HS32_MOVN: begin
                    aluop <= `HS32A_MOV;    // MOV
                    shift <= `HS32_SHIFT;   // Shift
                    imm <= `HS32_NULLI;     // [IGNORED] Imm
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;         // [IGNORED] Rm
                    rn <= `HS32_RN;         // Rn
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_100_0000_000, `HS32_SHIFTDIR, 1'b0 };    // SHIFTDIR
                end
                /* MOV     Rd <- Rm_b */
                `HS32_MOV: begin
                    aluop <= `HS32A_MOV;    // MOV
                    shift <= 5'd0;          // [IGNORED] Shift
                    imm <= `HS32_NULLI;     // [ZERO] Imm
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;         // [IGNORED] Rn
                    bank <= `HS32_BANK;     // Bank
                    ctlsig <= { 13'b01_0_010_0000_000, `HS32_SHIFTDIR, 1'b1 };    // [IGNORED] SHIFTDIR
                end
                /* MOV     Rd_b <- Rm */
                `HS32_MOVR: begin
                    aluop <= `HS32A_MOV;    // MOV
                    shift <= 5'd0;          // [IGNORED] Shift
                    imm <= `HS32_NULLI;     // [ZERO] Imm
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;         // [IGNORED] Rn
                    bank <= `HS32_BANK;     // Bank
                    ctlsig <= { 13'b01_0_010_0000_100, `HS32_SHIFTDIR, 1'b1 };    // [IGNORED] SHIFTDIR
                end

                /**************/
                /*  MATH REG  */
                /**************/

                /* ADD     Rd <- Rm + sh(Rn) */
                `HS32_ADD: begin
                    aluop <= `HS32A_ADD;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;     // [IGNORED]
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_011_0000_010, `HS32_SHIFTDIR, 1'b0 };    // SHIFTDIR
                end
                /* ADDC    Rd <- Rm + sh(Rn) + C */
                `HS32_ADDC: begin
                    aluop <= `HS32A_ADC;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;     // [IGNORED]
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_011_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* SUB     Rd <- Rm - sh(Rn) */
                `HS32_SUB: begin
                    aluop <= `HS32A_SUB;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;     // [IGNORED]
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_011_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* RSUB    Rd <- sh(Rn) - Rm */
                `HS32_RSUB: begin
                    aluop <= `HS32A_SUB;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;     // [IGNORED]
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_1_011_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* SUBC    Rd <- Rm - sh(Rn) - C */
                `HS32_SUBC: begin
                    aluop <= `HS32A_SBC;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_011_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* RSUBC   Rd <- sh(Rn) - Rm - C */
                `HS32_RSUBC: begin
                    aluop <= `HS32A_SBC;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_1_011_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end

                /* MUL     Rd <- Rm * sh(Rn) */
                `HS32_MUL: if(IMUL) begin
                    aluop <= `HS32A_MUL;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;     // [IGNORED]
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_011_0000_010, `HS32_SHIFTDIR, 1'b0 };    // SHIFTDIR
                end else begin
                    invalid <= 1;
                    intloop <= 1;
                end

                /**************/
                /*  MATH IMM  */
                /**************/

                /* ADD     Rd <- Rm + imm */
                `HS32_ADDI: begin
                    aluop <= `HS32A_ADD;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_010_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* ADDC    Rd <- Rm + imm + C */
                `HS32_ADDIC: begin
                    aluop <= `HS32A_ADC;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_010_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* SUB     Rd <- Rm - imm */
                `HS32_SUBI: begin
                    aluop <= `HS32A_SUB;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_010_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* RSUB    Rd <- imm - Rm */
                `HS32_RSUBI: begin
                    aluop <= `HS32A_SUB;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_1_010_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* SUBC    Rd <- Rm - imm - C */
                `HS32_SUBIC: begin
                    aluop <= `HS32A_SBC;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_010_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* RSUBC   Rd <- imm - Rm - C */
                `HS32_RSUBIC: begin
                    aluop <= `HS32A_SBC;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_1_010_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end

                /**************/
                /* LOGIC REG  */
                /**************/

                /* AND     Rd <- Rm & sh(Rn) */
                `HS32_AND: begin
                    aluop <= `HS32A_AND;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_011_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* BIC     Rd <- Rm & ~sh(Rn) */
                `HS32_BIC: begin
                    aluop <= `HS32A_BIC;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_011_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* OR      Rd <- Rm | sh(Rn) */
                `HS32_OR: begin
                    aluop <= `HS32A_OR;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_011_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* XOR     Rd <- Rm ^ sh(Rn) */
                `HS32_XOR: begin
                    aluop <= `HS32A_XOR;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_011_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end

                /**************/
                /* LOGIC IMM  */
                /**************/

                /* AND     Rd <- Rm & imm */
                `HS32_ANDI: begin
                    aluop <= `HS32A_AND;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_010_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* BIC     Rd <- Rm & ~imm */
                `HS32_BICI: begin
                    aluop <= `HS32A_BIC;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_010_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* OR      Rd <- Rm | imm */
                `HS32_ORI: begin            // Halo are the Ori >:]
                    aluop <= `HS32A_OR;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_010_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* XOR     Rd <- Rm ^ imm */
                `HS32_XORI: begin
                    aluop <= `HS32A_XOR;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b01_0_010_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end

                /**************/
                /* CONDITIONS */
                /**************/

                /* CMP     Rm - sh(Rn) */
                `HS32_CMP: begin
                    aluop <= `HS32A_SUB;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b00_0_011_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* CMP     Rm - imm */
                `HS32_CMPI: begin
                    aluop <= `HS32A_SUB;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b00_0_010_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* TST     Rm & sh(Rn) */
                `HS32_TST: begin
                    aluop <= `HS32A_AND;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_NULLI;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b00_0_011_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end
                /* TST     Rm & imm */
                `HS32_TSTI: begin
                    aluop <= `HS32A_AND;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b00_0_010_0000_010, `HS32_SHIFTDIR, 1'b0 };
                end

                /**************/
                /*   BRANCH   */
                /**************/

                /* B<c>    PC + Offset */
                `HS32_BRCH: begin
                    aluop <= `HS32A_ADD;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 6'b00_0_000, instd[27:24], 3'b00, `HS32_SHIFTDIR, 1'b0 };
                end
                /* B<c>L   PC + Offset */
                `HS32_BRCL: begin
                    aluop <= `HS32A_MOV;
                    shift <= `HS32_SHIFT;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RN;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 6'b01_1_010, instd[27:24], 3'b000, `HS32_SHIFTDIR, 1'b0 };
                end

                /**************/
                /* INTERRUPTS */
                /**************/

                /* INT     imm8 */
                `HS32_INT: begin
                    intrq <= 1;
                    intloop <= 1;
                    imm <= `HS32_IMM;
                end
            endcase
        end
    end
    endgenerate
endmodule
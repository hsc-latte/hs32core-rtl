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
    input   wire clk,           // 12 MHz Clock
    input   wire reset,         // Reset

    // Fetch
    input   wire [31:0] instd,  // Next instruction
    input   wire reqd,          // Valid
    output  wire rdyd,          // Ready

    // Execute
    output  wire[54:0] control,

    // Execute pipeline logic
    output wire reqe,
    input  wire rdye,

    // Interrupts
    output wire [23:0] int_line,
    output reg ii
);
    parameter IMUL = 0;

    // Interrupt status registers
    reg intrq, doint, intloop, invalid;

    // Control signal outputs
    reg [3:0]   aluop;  // ALU Operation
    reg [4:0]   shift;  // 5-bit shift
    reg [15:0]  imm;    // Immediate value
    reg [3:0]   rd;     // Register Destination Rd
    reg [3:0]   rm;     // Register Source Rm
    reg [3:0]   rn;     // Register Operand Rn
    reg [1:0]   bank;   // Bank (bb)
    reg [15:0]  ctlsig; // Control signals
    assign control = { aluop, shift, imm, rd, rm, rn, bank, ctlsig };
    
    // Interrupt assignments
    genvar i;
    generate
        assign int_line[0]  = (imm == 0 || invalid) && doint ? 1 : 0;
        for(i = 1; i < 24; i=i+1) begin
            assign int_line[i] = imm == i && doint ? 1 : 0;
        end
    endgenerate

    reg r_reqe, r_rdyd, r_hasnext;
    assign rdyd = !intloop && r_rdyd;
    assign reqe = !intloop && r_hasnext;
    
    always @(posedge clk)
    if(reset) begin
        r_reqe <= 0;
        r_hasnext <= 0;
        r_rdyd <= 1;
    end else begin
        if(rdyd && reqd) begin
            r_hasnext <= 1;
            if(rdye && !reqe) begin
                r_reqe <= 1;
            end else begin
                r_rdyd <= 0;
            end
        end else if(rdye && r_hasnext) begin
            r_rdyd <= 1;
            r_hasnext <= 0;
        end else if(rdye && !r_hasnext) begin
            r_reqe <= 0;
        end
    end

    // Generate IMUL
    generate always @(posedge clk)
    if(reset) begin
        invalid <= 0;
        intrq <= 0;
        intloop <= 0;
        doint <= 0;
        ii <= 0;
    end else begin
        // Reset interrupts
        if((intrq || invalid) && rdye) begin
            intrq <= 0;
            doint <= 1;
        end
        if(doint) begin
            invalid <= 0;
            doint <= 0;
        end

        /* If Ready Received */
        if (( (rdyd && reqd) || (rdye && r_hasnext) ) && !intloop) begin
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
                    shift <= 5'd0;           // [IGNORED] Shift
                    imm <= `HS32_IMM;        // Imm
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;         // [IGNORED] Rn
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= { 13'b10_0_010_0000_000, `HS32_SHIFTDIR, 1'b0 };    // [IGNORED] SHIFTDIR
                end
                /* LDR     Rd <- [Rm] */
                `HS32_LDR: begin
                    aluop <= `HS32A_ADD;     // ADD
                    shift <= 5'd0;           // [IGNORED] Shift
                    imm <= `HS32_NULLI;      // [ZERO] Imm
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
                    shift <= 5'd0;           // [IGNORED] Shift
                    imm <= `HS32_IMM;        // Imm
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
                    shift <= 5'd0;           // [IGNORED] Shift
                    imm <= `HS32_IMM;        // Imm
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
                    aluop <= `HS32A_MOV2;   // MOV
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
                    aluop <= `HS32A_MOV2;   // MOV
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
                    shift <= 0;
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
                    shift <= 0;
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
                    shift <= 0;
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
                    shift <= 0;
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
                    shift <= 0;
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
                    shift <= 0;
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
                    shift <= 0;
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
                    shift <= 0;
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
                    shift <= 0;
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
                    shift <= 0;
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
                    shift <= 0;
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
                    shift <= 0;
                    imm <= `HS32_IMM;
                    rd <= `HS32_RD;
                    rm <= `HS32_RM;
                    rn <= `HS32_RN;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= {
                        6'b00_0_000,
                        instd[27:24],
                        3'b001, `HS32_SHIFTDIR, 1'b0
                    };
                end
                /* B<c>L   PC + Offset */
                `HS32_BRCL: begin
                    aluop <= `HS32A_MOV;
                    shift <= 0;
                    imm <= `HS32_IMM;
                    rd <= 4'b1110;
                    rm <= 4'b1111;
                    rn <= 4'b1111;
                    bank <= `HS32_BANK;     // [IGNORED] Bank
                    ctlsig <= {
                        6'b01_1_010,
                        instd[27:24],
                        3'b001, `HS32_SHIFTDIR, 1'b0
                    };
                end

                /**************/
                /* INTERRUPTS */
                /**************/

                /* INT     imm8 */
                `HS32_INT: begin
                    intrq <= 1;
                    intloop <= 1;
                    imm <= `HS32_IMM;
                    ii <= 1;
                end
            endcase
        end
    end
    endgenerate
endmodule
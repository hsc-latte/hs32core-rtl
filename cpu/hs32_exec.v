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
 * @file   hs32_exec.v
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on October 24 2020, 10:33 PM
 */

`default_nettype none

`include "./cpu/hs32_reg.v"
`include "./cpu/hs32_alu.v"
`include "./cpu/hs32_xuconst.v"

module hs32_exec (
    input   wire clk,           // 12 MHz Clock
    input   wire reset,         // Active Low Reset
    input   wire req,           // Request line
    output  wire rdy,           // Output ready

    // Fetch
    output  reg [31:0] newpc,   // New program
    output  reg flush,          // Flush

    // Decode
    input   wire [54:0] control,

    // Memory arbiter interface
    output  wire [31:0] addr,   // Address
    input   wire [31:0] dtrm,   // Data input
    output  wire [31:0] dtwm,   // Data output
    output  reg  stbm,          // Valid address
    input   wire ackm,          // Valid data
    input   wire stlm,          // Request rejected
    output  reg  rw_mem,        // Read write

    // Interrupts
    input   wire intrq,         // Interrupt signal
    input   wire nmi,           // Non maskable?
    input   wire [31:0] isr,    // Interrupt handler
    input   wire [4:0] code,    // Interrupt vector
    output  reg  iack,          // Interrupt acknowledge
    output  reg  int_inval,

    // Misc
    output reg fault,
    output wire userbit
);
    parameter IMUL = 0;
    parameter BARREL_SHIFTER = 0;

    // Assign ready signal (only when IDLE)
    assign rdy = state == `IDLE;
    reg r_bsy;

    //===============================//
    // Input control signals
    //===============================//
    
    wire[54:0]  ctl;
    reg [54:0]  r_control;
    wire[4:0]   shift;
    wire[15:0]  imm, ctlsig;
    wire[3:0]   aluop, rd, rm, rn;
    wire[1:0]   bank;
    assign ctl = state == `IDLE ? control : r_control;
    assign aluop = ctl[54:51];
    assign shift = ctl[50:46];
    assign imm = ctl[45:30];
    assign rd = ctl[29:26];
    assign rm = ctl[25:22];
    assign rn = ctl[21:18];
    assign bank = ctl[17:16];
    assign ctlsig = ctl[15:0];

    //===============================//
    // Interrupts
    //===============================//

    // Latch incoming interrupts
    reg int_latch, nmi_latch;
    reg[31:0] isr_latch;
    reg[4:0] code_latch;
    always @(posedge clk)
    if(reset)
        int_latch <= 0;
    else if(state == `INT) begin
        int_latch <= 0;
        nmi_latch <= 0;
    end else if(intrq) begin
        int_latch <= 1;
        isr_latch <= isr;
        nmi_latch <= nmi;
        code_latch <= code;
    end

    //===============================//
    // Busses
    //===============================//

    wire [31:0] ibus1, ibus2, ibus2_sh, obus;
    // Memory address and data registers
    reg  [31:0] mar, dtw, r_dtrm;
    assign addr = mar;
    assign dtwm = dtw;
    assign userbit = `MCR_USR;

    //===============================//
    // Banked registers control logic
    //===============================//

    // Special banked registers
    reg  [31:0] pc_u, pc_s, lr_i, sp_i, mcr_s, flags;
    // Register file control signals
    wire [3:0]  regadra, regadrb;
    // User bank
    wire reg_we_u;
    wire [31:0] regouta_u, regoutb_u;
    // Supervisor bank
    wire reg_we_s;
    wire [31:0] regouta_s, regoutb_s;
    // General access switching
    reg reg_we;
    wire[31:0] regouta, regoutb;
    assign reg_we_u =  (`IS_USR || (`BANK_U && `CTL_i)) ? reg_we : 0;
    assign reg_we_s = !(`IS_USR || (`BANK_U && `CTL_i)) ? reg_we : 0;
    assign regouta =
        // User bank select
        (`IS_USR || (`BANK_U && !`CTL_i)) ?
            // PC select
            regadra == 4'b1111 ? pc_u : regouta_u :
        // Flags select
        (`BANK_F && !`CTL_i) ? flags :
        // PC select
        regadra == 4'b1111 ? pc_s :
        // MCR select
        regadra == 4'b1100 ? mcr_s :
        // Interrupt bank select
        (`IS_INT || (`BANK_I && !`CTL_i)) ?
            regadra == 4'b1101 ? sp_i :
            regadra == 4'b1110 ? lr_i : regouta_s :
        regouta_s;
    assign regoutb =
        (`IS_USR || (`BANK_U && !`CTL_i)) ?
            regadrb == 4'b1111 ? pc_u : regoutb_u :
        (`BANK_F && !`CTL_i) ? flags :
        regadrb == 4'b1111 ? pc_s :
        regadrb == 4'b1100 ? mcr_s :
        (`IS_INT || (`BANK_I && !`CTL_i)) ?
            regadrb == 4'b1101 ? sp_i :
            regadrb == 4'b1110 ? lr_i : regoutb_s :
        regoutb_s;
    // Register select
    assign regadra =
        state == `IDLE ?
            (`CTL_s == `CTL_s_mid || `CTL_s == `CTL_s_mnd ? rd : rm)
        : rm;
        /*state == `TR1 ?
        (`CTL_s == `CTL_s_mid || `CTL_s == `CTL_s_mnd ?
            rd : rm)
        : rm;*/
    assign regadrb = rn;

    //===============================//
    // Bus assignments
    //===============================//

    assign ibus1 = regouta;
    assign ibus2 =
        (`CTL_s == `CTL_s_xix ||
         `CTL_s == `CTL_s_mix ||
         `CTL_s == `CTL_s_mid) ? { 16'b0, imm } : regoutb;
    assign obus =
        state == `TW2 ? r_dtrm :
        state == `IDLE ?
            (`CTL_d == `CTL_d_dt_ma ? r_dtrm : aluout)
        : aluout;
    // Generate barrel shifter
    generate
        if(BARREL_SHIFTER) begin
            assign ibus2_sh =
                shift == 0 ? ibus2 :
                `CTL_D == `CTL_D_shl ? ibus2 << shift :
                `CTL_D == `CTL_D_shr ? ibus2 >> shift :
                `CTL_D == `CTL_D_ssr ? ibus2 >>> shift :
                ibus2 >> shift | ibus2 << (32-shift);
        end else begin
            assign ibus2_sh = ibus2;
        end
    endgenerate

    //===============================//
    // Status lines (reusable code)
    //===============================//

    wire int_except = `IS_USR && (`BANK_S || `BANK_I || `BANK_F);
    wire int_dbg = !`IS_INT && `MCR_DBG;
    wire int_dbg_s = int_dbg && !(|`MCR_DBGSn);
    wire int_dbg_b = int_dbg && `CTL_g && (flags[{ 1'b0, `CTL_b }] == 1'b1);
    wire int_dbg_l = int_dbg_b && `CTL_d == `CTL_d_rd;
    wire int_dbg_r = int_dbg && `CTL_d == `CTL_d_dt_ma;
    wire int_dbg_w = int_dbg && `CTL_d == `CTL_d_ma;

    //===============================//
    // FSM
    //===============================//

    // State transitions only (drive: state, fault, int_inval)
    reg[3:0] state;
    always @(posedge clk)
    if(reset) begin
        state <= 0;
        fault <= 0;
        int_inval <= 0;
    end else case(state)
        // NMI forces an interrupt, otherwise check interrupt enable
        `IDLE: if(
            (int_latch || intrq) &&
            ((nmi || nmi_latch) || !(`MCR_INTEN))
        ) begin
            state <= `INT;
            if(`IS_INT) begin
                fault <= 1;
            end
        end else if(req) begin
            r_control <= control;
            state <=
                int_except ? `DIE :
                // All states (except branch) start with `TR1
                (`CTL_g == 0) ? `TR1 :
                // Return from interrupt
                (`CTL_b == 4'b1111 && `IS_INT) ? `INTRET :
                // Decide whether to branch or not
                (flags[{ 1'b0, `CTL_b }] == 1'b1) ? `TB1 :
                // No branch taken
                `IDLE;
            int_inval <= int_except || int_dbg_s || int_dbg_b || int_dbg_l
                || int_dbg_r || int_dbg_w;
        end
        `TB1: begin
            state <= `TR1;
        end
        `TB2: begin
            state <= `IDLE;
        end
        `TR1: case(`CTL_s)
            `CTL_s_mid, `CTL_s_mnd:
                state <= `TR2;
            default: case(`CTL_d)
                `CTL_d_none:
                    state <= `IDLE;
                `CTL_d_rd:
                    state <= (rd == 4'b1111) ? `TB2 : `IDLE;
                `CTL_d_dt_ma:
                    state <= `TM1;
                `CTL_d_ma: begin
                    // TODO: Error
                end
            endcase
        endcase
        `TR2: begin
            state <= `TM2;
        end
        `TM1: begin
            if(r_bsy && ackm) begin
                state <= `TW2;
            end else begin
                state <= `TM1;
            end
        end
        `TM2: begin
            if(r_bsy && ackm)
                state <= `IDLE;
            else
                state <= `TM2;
        end
        `TW2: begin
            state <= (rd == 4'b1111) ? `TB2 : `IDLE;
        end
        `INT: begin
            state <= `TB2;
            fault <= 0;
        end
        `INTRET: begin
            state <= `TB2;
        end
        `DIE: begin
            int_inval <= 0;
            if(int_latch || intrq)
                state <= `IDLE;
        end
        `TID: state <= `TID;
    endcase

    //===============================//
    // State processes
    //===============================//

    // Write to Rd (drive: reg_we, mcr_s, sp_i, lr_i)
    always @(posedge clk)
    if(reset) begin
        lr_i <= 0;
        sp_i <= 0;
        mcr_s <= 0;
        reg_we <= 0;
    end else case(state)
        `IDLE: if(req) begin
            // Determine if reg_we will go high
            reg_we <=
                `CTL_s != `CTL_s_mid &&
                `CTL_s != `CTL_s_mnd &&
                `CTL_d == `CTL_d_rd &&
                !(rd == 4'b1100 && `IS_SUP) &&
                !(rd == 4'b1101 && (`IS_INT || (!`IS_USR && `BANK_I && `CTL_i))) &&
                !(rd == 4'b1110 && (`IS_INT || (!`IS_USR && `BANK_I && `CTL_i))) &&
                !(rd == 4'b1111);
            // Debug interrupt values
            `MCR_DBGSn <= int_dbg ? `MCR_DBGSn - 1 : `MCR_DBGSn;
            `MCR_DBGi_S <= int_dbg_s;
            `MCR_DBGi_B <= int_dbg_b;
            `MCR_DBGi_L <= int_dbg_l;
            `MCR_DBGi_R <= int_dbg_r;
            `MCR_DBGi_W <= int_dbg_w;
        end
        // On TR1, then we haven't written to MAR yet if CTL_s is mid/mnd.
        //         so we must check for CTL_d and CTL_s
        // On TW2, then we finished memory access and we just write.
        //         Since TW2 is only for LDR, we don't need to check ctlsigs
        `TW2, `TR1: if(
            state == `TW2 || (
                `CTL_s != `CTL_s_mid &&
                `CTL_s != `CTL_s_mnd &&
                `CTL_d == `CTL_d_rd
            )
        ) case(rd)
            // Deal with register bankings
            default: begin
                reg_we <= 0;
            end
            4'b1100: if(`IS_SUP)
                mcr_s <= obus;
            else begin
                reg_we <= 0;
            end
            4'b1101: if(`IS_INT || (!`IS_USR && `BANK_I && `CTL_i))
                sp_i <= obus;
            else begin
                reg_we <= 0;
            end
            4'b1110: if(`IS_INT || (!`IS_USR && `BANK_I && `CTL_i))
                lr_i <= obus;
            else begin
                reg_we <= 0;
            end
            4'b1111: begin end
        endcase
        `TB1: reg_we <= 0;
        // Memory read
        `TM1: if(r_bsy && ackm) begin
            reg_we <=
                !(rd == 4'b1100 && `IS_SUP) &&
                !(rd == 4'b1101 && (`IS_INT || (!`IS_USR && `BANK_I && `CTL_i))) &&
                !(rd == 4'b1110 && (`IS_INT || (!`IS_USR && `BANK_I && `CTL_i))) &&
                !(rd == 4'b1111);
        end
        // Interrupt
        `INT: begin
            lr_i <= `IS_USR ? pc_u : pc_s;
            `MCR_INTEN <= 0;
            `MCR_USR <= 0;
            `MCR_MDE <= 1;
            `MCR_VEC <= code_latch;
            `MCR_NZCVi <= flags[31:28];
            `MCR_USRi <= `MCR_USR;
            `MCR_MDEi <= `MCR_MDE;
        end
        // Return from interrupt
        `INTRET: begin
            `MCR_USR <= `MCR_USRi;
            `MCR_MDE <= `MCR_MDEi;
        end
    endcase

    // Write to MAR (drive: mar, dtw)
    always @(posedge clk)
    if(reset) begin
        mar <= 0;
        dtw <= 0;
    end else case(state)
        `TR1: if(`CTL_d == `CTL_d_ma)
            dtw <= ibus1;
        else if(`CTL_d == `CTL_d_dt_ma)
            mar <= obus;
        `TR2: mar <= obus;
    endcase

    // Memory requests (drive: reqm, rw_mem, r_dtrm)
    always @(posedge clk)
    if(reset) begin
        stbm <= 0;
        rw_mem <= 0;
        r_dtrm <= 0;
        r_bsy <= 0;
    end else case(state)
        // Read (TM1)/Write (TM2) from memory
        `TM1, `TM2:
        if(!r_bsy) begin
            stbm <= 1;
            rw_mem <= state == `TM2;
            r_bsy <= 1;
        end else if(r_bsy) begin
            if(!stlm) begin
                stbm <= 0;
            end
            if(ackm) begin
                r_dtrm <= dtrm;
                r_bsy <= 0;
            end
        end
    endcase

    // Branch (drive: flush, pc_u, pc_s, iack)
    always @(posedge clk)
    if(reset) begin
        flush <= 0;
        pc_u <= 0;
        pc_s <= 0;
        iack <= 0;
        newpc <= 0;
    end else case(state)
        `IDLE: begin
            flush <= 0;
            if(
                // If request and not interrupt
                req && !(int_latch || intrq)
            ) begin
                // Increment PC before we change states
                if(`IS_USR)
                    pc_u <= pc_u+4;
                else
                    pc_s <= pc_s+4;
            end
        end
        // Update PC since we take the branch
        `TB1: begin
            newpc <= { {16{imm[15]}}, imm } + (`IS_USR ? pc_u : pc_s) - 4;
            flush <= 1;
            if(`IS_USR)
                pc_u <= { {16{imm[15]}}, imm } + pc_u - 4;
            else
                pc_s <= { {16{imm[15]}}, imm } + pc_s - 4;
        end
        `INT: begin
            flush <= 1;
            pc_s <= isr_latch;
            newpc <= isr_latch;
        end
        `TB2: begin
            iack <= 0;
        end
        // Update the PC from a Rd instruction (see "write to Rd")
        `TW2, `TR1: if(
            `CTL_s != `CTL_s_mid &&
            `CTL_s != `CTL_s_mnd &&
            `CTL_d == `CTL_d_rd && rd == 4'b1111
        ) begin
            newpc <= obus;
            flush <= 1;
            if(`IS_USR || (`BANK_U && `CTL_i))
                pc_u <= obus;
            else
                pc_s <= obus;
        end
        // Return from interrupt
        `INTRET: begin
            iack <= 1;
            flush <= 1;
            newpc <= lr_i;
            if(`MCR_USRi) begin
                pc_u <= lr_i;
            end else begin
                pc_s <= lr_i;
            end
        end
    endcase

    // Write to flags on `TR1 cycles only (drive: flags)
    always @(posedge clk) begin
        if(reset) begin
            flags <= { 16'b0, 16'h8001 };
        end else case(state)
            `TR1, `TW2: if(
                `CTL_s != `CTL_s_mid &&
                `CTL_s != `CTL_s_mnd &&
                `CTL_d == `CTL_d_rd &&
                `BANK_F && `CTL_i
            ) begin
                flags <= obus;
            end else if(
                state == `TR1 &&
                `CTL_d == `CTL_d_rd &&
                `CTL_f == 1'b1
            ) begin
                flags <= { alu_nzcv, 12'b0, branch_conds };
            end
            // Restore flags
            `INTRET: flags <= { `MCR_NZCVi, 12'b0, 16'h8001 };
        endcase
    end

    //===============================//
    // Register files
    //===============================//

    hs32_reg regfile_u (
        .clk(clk), .reset(reset),
        .we(reg_we_u),
        .wadr(rd), .din(obus),
        .dout1(regouta_u), .radr1(regadra),
        .dout2(regoutb_u), .radr2(regadrb)
    );

    hs32_reg regfile_s (
        .clk(clk), .reset(reset),
        .we(reg_we_s),
        .wadr(rd), .din(obus),
        .dout1(regouta_s), .radr1(regadra),
        .dout2(regoutb_s), .radr2(regadrb)
    );

    //===============================//
    // ALU
    //===============================//

    wire [31:0] aluout;
    wire [3:0] alu_nzcv, alu_nzcv_out;
    assign alu_nzcv = `CTL_f ? alu_nzcv_out : flags[31:28];
    hs32_alu #(
        .IMUL(IMUL)
    ) alu (
        .i_a(`CTL_r ? ibus2_sh : ibus1),
        .i_b(`CTL_r ? ibus1 : ibus2_sh),
        .i_op(aluop), .o_r(aluout),
        .i_fl(flags[31:28]), .o_fl(alu_nzcv_out)
    );
    wire [15:0] branch_conds;
    assign branch_conds = {
        1'b1, // Always true
        `ALU_Z | (`ALU_N ^ `ALU_V),     // LE
        !`ALU_Z & !(`ALU_N ^ `ALU_V),   // GT
        `ALU_N ^ `ALU_V,                // LT
        !(`ALU_N ^ `ALU_V),             // GE
        !`ALU_C | `ALU_Z,               // BE
        `ALU_C | !`ALU_Z,               // AB
        !`ALU_V,                        // NV
        `ALU_V,                         // OV
        !`ALU_N,                        // NS
        `ALU_N,                         // SS
        !`ALU_C,                        // NC
        `ALU_C,                         // CS
        !`ALU_Z,                        // NE
        `ALU_Z,                         // EQ
        1'b1  // Always true
    };

`ifdef FORMAL
    // $past gaurd
    reg f_past_valid;
    initial f_past_valid = 0;
    always @(posedge clk)
        f_past_valid <= 1;

    // 0.

    `include "cpu/hs32_exec_proof.v"
`endif
endmodule

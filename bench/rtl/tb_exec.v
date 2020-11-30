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
 * @file   tb_exec.v
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on November 21 2020, 11:29 PM
 */

`ifdef SIM
`include "cpu/hs32_aluops.v"
`include "cpu/hs32_exec.v"
`include "soc/bram_ctl.v"

`timescale 1ns / 1ns
module tb_exec;
    parameter PERIOD = 2;

    reg clk = 0;
    reg reset = 1;
    reg [3:0]  aluop    = `HS32A_REVMOV;
    reg [4:0]  shift    = 0;
    reg [15:0] imm      = 1;
    reg [3:0]  rd       = 4'b1110;
    reg [3:0]  rm       = 4'b1111;
    reg [3:0]  rn       = 0;
    reg [15:0] ctlsig   = 16'b01_0_010_1111_001_000;
    reg [1:0]  bank     = 0;

    wire[31:0] addr, dtw;
    reg [31:0] dtr = 32'hCAFEBABE;
    wire rw, valid;
    reg ready = 1;

    always #(PERIOD/2) clk=~clk;

    initial begin
        $dumpfile("tb_exec.vcd");
        $dumpvars(0, exec);
        // Initialize some registers
        exec.regfile_s.regs[0] = 32'hAAAA_0000;
        exec.regfile_s.regs[1] = 32'hBBBB_BBBB;

        // Power on reset, no touchy >:[
        #PERIOD
        reset <= 0;
        exec.pc_s = 32'h0000_1000;
        #(PERIOD*20);
        $finish;
    end

    hs32_exec exec(
        .clk(clk),
        .reset(reset),
        .req(1),
        .rdy(),

        .flush(),
        .newpc(),

        .aluop(aluop),
        .shift(shift),
        .imm(imm),
        .rd(rd),
        .rm(rm),
        .rn(rn),
        .ctlsig(ctlsig),
        .bank(bank),

        .addr(addr),
        .dtrm(16'hCAFE),
        .dtwm(dtw),
        .reqm(valid),
        .rdym(ready),
        .rw_mem(rw),

        .intrq(0),
        .addi(0)
    );

    /*soc_bram_ctl #(
        .addr_width(8)
    ) bram_ctl(
        .clk(clk),
        .addr(addr[7:0]), .rw(rw),
        .dread(dtr), .dwrite(dtw),
        .valid(valid), .ready(ready)
    );*/
endmodule
`endif

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
 * @file   tb_soc.v
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on December 01 2020, 5:24 PM
 */

`ifdef SIM

`include "cpu/hs32_cpu.v"
`include "soc/bram_ctl.v"

`timescale 1ns / 1ns
module tb_soc;
    parameter PERIOD = 2;
    parameter IMUL = 0;
    parameter BARREL_SHIFTER = 1;

    reg clk = 1;
    reg reset = 1;

    wire[31:0] addr, dread, dwrite;
    wire rw, stb, ack, flush;

    always #(PERIOD/2) clk=~clk;

    initial begin
        $dumpfile("tb_soc.vcd");
        $dumpvars(0, cpu, bram_ctl);

        // Power on reset, no touchy >:[
        #(PERIOD*1)
        reset <= 0;
        #(PERIOD*100);
        $finish;
    end

    hs32_cpu #(
        .IMUL(1), .BARREL_SHIFTER(1), .PREFETCH_SIZE(3)
    ) cpu (
        .i_clk(clk), .reset(reset),
        // External interface
        .addr(addr), .rw(rw),
        .din(dread), .dout(dwrite),
        .stb(stb), .ack(ack),
        .intrq(1'b0), .flush(flush)
    );
    soc_bram_ctl #(
        .addr_width(8),
        .data0("../bench/bram0.hex"),
        .data1("../bench/bram1.hex"),
        .data2("../bench/bram2.hex"),
        .data3("../bench/bram3.hex")
    ) bram_ctl(
        .i_clk(clk),
        .i_reset(reset || flush),
        .i_addr(addr[7:0]), .i_rw(rw),
        .o_dread(dread), .i_dwrite(dwrite),
        .i_stb(stb), .o_ack(ack)
    );
endmodule

`endif

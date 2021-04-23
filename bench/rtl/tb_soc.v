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

`include "soc/main.v"
`include "bench/board.v"

`timescale 1ns / 1ns
module tb_soc;
    reg clk = 0, reset = 1;
    always #1 clk=~clk;
    initial begin
        $dumpfile("tb_soc.vcd");
        $dumpvars(0, top, devboard);
        repeat (2000) @(posedge clk);
        $finish;
    end

    wire ledr, ledg, oe, we, bhe;
    wire[8:0] gpio;
    wire[15:0] ad, out;
    wire[1:0] le;
    assign ad = oe ? 16'bz : out;

    main #(
        .data0("../../bench/bram0.hex"),
        .data1("../../bench/bram1.hex"),
        .data2("../../bench/bram2.hex"),
        .data3("../../bench/bram3.hex"),
        .RST_BITS(3)
    ) top (
        .CLK(clk), .RST_N(reset),
        .LEDR_N(ledr), .LEDG_N(ledg),
        .GPIO9(1'b1), .GPIO8(gpio[8]),
        .GPIO7(gpio[7]), .GPIO6(gpio[6]),
        .GPIO5(gpio[5]), .GPIO4(gpio[4]), 
        .GPIO3(gpio[3]), .GPIO2(gpio[2]), 
        .GPIO1(gpio[1]), .GPIO0(gpio[0]),

        // Other GPIO
        .IO0(ad[0]), .IO1(ad[1]), .IO2(ad[2]), .IO3(ad[3]),
        .IO4(ad[4]), .IO5(ad[5]), .IO6(ad[6]), .IO7(ad[7]),
        .IO8(ad[8]), .IO9(ad[9]), .IO10(ad[10]), .IO11(ad[11]),
        .IO12(ad[12]), .IO13(ad[13]), .IO14(ad[14]), .IO15(ad[15]),
        .OE_N(oe), .WE_N(we), .ALE0(le[0]), .ALE1(le[1]), .BHE_N(bhe)
    );

    // Devboard behavourial simulation
    board devboard (
        .inp(ad), .le(le), .bhe(bhe), .we(we), .out(out)
    );

    always @(ledr, ledg) begin
		#1 $display("LED R,G state = %b", ledr, ledg);
	end
    always @(gpio) begin
        #1 $display("GPIO state = %b", gpio);
    end
endmodule

`endif

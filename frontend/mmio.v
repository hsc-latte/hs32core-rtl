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
 * @file   mmio.v
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on November 29 2020, 9:04 PM
 */

`default_nettype none

module mmio(
    input  wire clk,
    input  wire reset,

    // Memory interface in
    input  wire stb,
    output wire ack,
    input  wire[31:0] addr,
    input  wire[31:0] dtw,
    output wire[31:0] dtr,
    input  wire rw,

    // SRAM Interface
    output wire sstb,
    input  wire sack,
    output wire[31:0] saddr,
    output wire[31:0] sdtw,
    input  wire[31:0] sdtr,
    output wire srw,

    // Interrupt controller
    input   wire[23:0] interrupts,  // Interrupt lines
    output  wire[31:0] handler,     // ISR address
    output  wire intrq,             // Request interrupt
    output  wire[4:0] vec,          // Interrupt vector
    output  wire nmi,               // Non maskable interrupt

    // AICT Exposed read interal + external ports
    input  wire[31:0] aict_r[AICT_NUM_RE-1:0],
    output wire[31:0] aict_w[AICT_NUM_RI-1:0]
);
    parameter AICT_NUM_RE = 0; // Registers read-only from inside (external)
    parameter AICT_NUM_RI = 0; // Registers read-only from outside (internal)
    parameter AICT_LENGTH = AICT_NUM_RE+AICT_NUM_RI+24+1; // 24 IVT + 1 base

    // Advanced Interrupt Controller Table
    reg[31:0] aict[AICT_LENGTH-1:0];

    // Check if there's interrupt(s)
    assign intrq = (|interrupts) & (aict[vec + 1][0] | nmi);

    // NMI
    assign nmi = interrupts[0] || interrupts[1];

    // Interrupt Priority
    // LSB gets higher priority
    assign vec =
        interrupts[0] ? 0 :
        interrupts[1] ? 1 :
        interrupts[2] ? 2 :
        interrupts[3] ? 3 :
        interrupts[4] ? 4 :
        interrupts[5] ? 5 :
        interrupts[6] ? 6 :
        interrupts[7] ? 7 :
        interrupts[8] ? 8 :
        interrupts[9] ? 9 :
        interrupts[10] ? 10 :
        interrupts[11] ? 11 :
        interrupts[12] ? 12 :
        interrupts[13] ? 13 :
        interrupts[14] ? 14 :
        interrupts[15] ? 15 :
        interrupts[16] ? 16 :
        interrupts[17] ? 17 :
        interrupts[18] ? 18 :
        interrupts[19] ? 19 :
        interrupts[20] ? 20 :
        interrupts[21] ? 21 :
        interrupts[22] ? 22 : 23;
    assign handler = aict[vec + 1] & (~32'b1111);

    // Write ready
    reg wack;

    // AICT is from aict_base to aict_base + AICT_LENGTH*4
    wire is_aict;
    assign is_aict = aict[0] <= addr && addr <= aict[0] + AICT_LENGTH*4;

    // Calculate the aict index from the address
    wire[4:0] aict_idx;
    wire[27:0] __unused___;
    assign {__unused___, aict_idx } = ((addr-aict[0]) >> 2);

    // Multiplex aict entry and sram signals
    // Ready is 1 only when reading
    assign ack = is_aict ? rw ? wack : 1 : sack;
    assign dtr = is_aict ? aict[aict_idx] : sdtr;

    // Assign all sram output
    assign srw = rw;
    assign sstb = stb && !is_aict;
    assign saddr = addr;
    assign sdtw = dtw;

    // Reset
    integer i;
    always @(posedge clk) if(reset) begin
        aict[0] <= 32'h0000_FF00;
        for(i = 1; i < 25; i++)
            aict[i] <= 0;
    end

    // Bus logic
    always @(posedge clk)
    if(reset) begin
        wack <= 0;
    end else if(stb && rw)
        wack <= 1;
    else begin
        wack <= 0;
    end
endmodule

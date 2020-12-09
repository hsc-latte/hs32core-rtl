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
 * @file   hs32_cpu.v
 * @author Anthony Kung <hi@anth.dev>
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on October 23 2020, 1:36 AM
 */

`default_nettype none

`include "cpu/hs32_mem.v"
`include "cpu/hs32_fetch.v"
`include "cpu/hs32_exec.v"
`include "cpu/hs32_decode.v"

// NO LATCHES ALLOWED!
module hs32_cpu (
    input wire i_clk,
    input wire reset,

    // External interface
    output  wire [31:0] addr,
    output  wire rw,
    input   wire[31:0] din,
    output  wire[31:0] dout,
    output  wire stb,
    input   wire ack,

    // Interrupt controller
    output  wire[23:0] interrupts,  // Interrupt lines
    output  wire iack,              // Interrupt acknowledge
    input   wire[31:0] handler,     // ISR address
    input   wire intrq,             // Request interrupt
    input   wire[4:0] vec,          // Interrupt vector
    input   wire nmi,               // Non maskable interrupt

    // Misc
    output wire userbit,
    output wire fault,
    output wire flush
);
    parameter IMUL = 0;
    parameter BARREL_SHIFTER = 0;
    parameter PREFETCH_SIZE = 3; // Depth of 2^PREFETCH_SIZE instructions
    
    wire[31:0] newpc;

    wire[31:0] addr_e, dtr_e, dtw_e;
    wire stb_e, ack_e, stl_e, rw_e;

    wire[31:0] addr_f, dtr_f;
    wire stb_f, ack_f, stl_f;
    hs32_mem MEM(
        .clk(i_clk), .reset(reset | flush),
        // External interface
        .addr(addr), .rw(rw), .din(din), .dout(dout),
        .stb(stb), .ack(ack),
        
        // Channel 0 (Execute)
        .addr0(addr_e), .dtr0(dtr_e), .dtw0(dtw_e),
        .rw0(rw_e), .stb0(stb_e), .ack0(ack_e), .stl0(stl_e),

        // Channel 1 (Fetch)
        .addr1(addr_f), .dtr1(dtr_f), .dtw1(0),
        .rw1(1'b0), .stb1(stb_f), .ack1(ack_f), .stl1(stl_f)
    );

    wire[31:0] inst_d;
    wire req_d, rdy_d;
    hs32_fetch #(
        .PREFETCH_SIZE(PREFETCH_SIZE)
    ) FETCH(
        .clk(i_clk), .reset(reset),
        // Memory arbiter interface
        .addr(addr_f), .dtr(dtr_f),
        .stbm(stb_f), .ackm(ack_f), .stlm(stl_f),
        // Decode
        .instd(inst_d), .reqd(req_d), .rdyd(rdy_d),
        // Pipeline controller
        .newpc(newpc), .flush(flush | reset)
    );
    
    wire [54:0] control;
    wire [23:0] int_line;

    // OR the interrupt line from the exec and decode
    assign interrupts = int_line | { 22'b0, int_inval, 1'b0 };

    hs32_decode #(
        .IMUL(IMUL)
    ) DECODE (
        .clk(i_clk), .reset(reset | flush),
        // Fetch
        .instd(inst_d), .reqd(req_d), .rdyd(rdy_d),

        // Execute
        .reqe(req_ed),
        .rdye(rdy_ed),
        .control(control),
        .int_line(int_line)
    );

    wire req_ed, rdy_ed;
    wire int_inval;
    hs32_exec #(
        .IMUL(IMUL),
        .BARREL_SHIFTER(BARREL_SHIFTER)
    ) EXEC(
        .clk(i_clk), .reset(reset),
        // Pipeline controller
        .newpc(newpc), .flush(flush),
        .req(req_ed), .rdy(rdy_ed),

        // Decode
        .control(control),
        
        // Memory arbiter interface
        .stbm(stb_e), .ackm(ack_e), .stlm(stl_e),
        .addr(addr_e),
        .dtrm(dtr_e), .dtwm(dtw_e),
        .rw_mem(rw_e),
        
        // Interrupts
        .intrq(intrq),
        .isr(handler),
        .code(vec),
        .iack(iack),
        .nmi(nmi),

        // Misc
        .userbit(userbit),
        .fault(fault),

        // Privilege violation
        .int_inval(int_inval)
    );
endmodule

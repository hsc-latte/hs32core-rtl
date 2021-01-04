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
 * @file   main.v
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on October 29 2020, 6:15 PM
 */

`include "cpu/hs32_cpu.v"
`include "cpu/hs32_aic16.v"
`include "soc/soc_bram_ctl.v"
`include "soc/dev_intercon.v"
`include "soc/dev_gpio8.v"

module main (
    input   wire CLK,
    input   wire RX,
    output  wire TX,
    output  wire LEDR_N,
    output  wire LEDG_N,

    // GPIO
    input wire GPIO9, inout wire GPIO8,
    inout wire GPIO7, inout wire GPIO6, inout wire GPIO5, inout wire GPIO4,
    inout wire GPIO3, inout wire GPIO2, inout wire GPIO1, inout wire GPIO0
);
    parameter data0 = "bench/bram0.hex";
    parameter data1 = "bench/bram1.hex";
    parameter data2 = "bench/bram2.hex";
    parameter data3 = "bench/bram3.hex";

    wire clk = CLK;
    reg rst, state;
    initial rst = 0;
    initial state = 0;

    always @(posedge clk) begin
        if(!state) begin
            rst <= 1;
            if(rst) begin
                state <= 1;
            end
        end
        else rst <= 0;
    end

    //===============================//
    // Main CPU core
    //===============================//

    wire[31:0] addr, dread, dwrite;
    wire rw, stb, ack, flush;
    wire userbit;

    hs32_cpu #(
        .IMUL(1), .BARREL_SHIFTER(2),
        .PREFETCH_SIZE(1), .LOW_WATER(1)
    ) cpu (
        .i_clk(clk), .reset(rst),
        // External interface
        .addr(addr), .rw(rw),
        .din(dread), .dout(dwrite),
        .stb(stb), .ack(ack),

        .interrupts(inte),
        .iack(), .handler(isr),
        .intrq(irq), .vec(ivec),
        .nmi(nmi),

        .flush(flush), .fault(), .userbit(userbit)
    );
    assign ram_dwrite = dwrite;
    assign ram_addr = addr;
    assign ram_rw = rw;

    //===============================//
    // Memory bus interconnect
    //===============================//

    wire[7:0] mmio_addr;
    dev_intercon #(
        .NS(2),
        .BASE({
            { 1'b0, 7'b0 },
            { 1'b1, 2'b00, 5'b0 }
        }),
        .MASK({
            { 1'b1, 7'b0 },
            { 1'b1, 2'b11, 5'b0 }
        }),
        .MASK_LEN(8),
        .LIMITS(8)
    ) mmio_conn (
        .clk(clk), .reset(rst), .userbit(userbit),
        
        // Input
        .i_stb(stb), .o_ack(ack),
        .i_addr(addr), .o_dtr(dread),
        .i_rw(rw), .i_dtw(dwrite),

        // Devices
        .i_dtr({ aic_dtr, gpt_dtr }),
        .i_ack({ aic_ack, gpt_ack }),
        .o_stb({ aic_stb, gpt_stb }),
        .o_addr(mmio_addr),

        // SRAM
        .sstb(ram_stb), .sack(ram_ack), .sdtr(ram_dread),

        // Buf
        .estb(), .eack(1'b1), .edtr(0)
    );

    //===============================//
    // Interrupts
    //===============================//

    wire [23:0] inte;
    wire [4:0] ivec;
    wire [31:0] isr;
    wire irq, nmi;

    wire [31:0] aic_dtr;
    wire aic_ack, aic_stb;

    hs32_aic16 aict (
        .clk(clk), .reset(rst),
        // Bus
        .stb(aic_stb), .ack(aic_ack),
        .addr(mmio_addr[4:2]), .dtw(dwrite),
        .dtr(aic_dtr), .rw(rw),
        // Interrupt controller
        .interrupts(hw_irq | inte), .handler(isr),
        .intrq(irq), .vec(ivec), .nmi(nmi)
    );

    wire[23:0] hw_irq = 0;

    //===============================//
    // GPIO
    //===============================//
    
    wire[31:0] gpt_dtr;
    wire gpt_ack, gpt_stb, gpt_irqr, gpt_irqf;

    localparam NUM_IO = 12;

    // IO rise/fall triggers
    wire[NUM_IO-1:0] io_in_sync, io_in_rise, io_in_fall;
    wire[NUM_IO-1:0] io_out_buf, io_oeb_buf;
    wire[NUM_IO-1:0] io_in;

    dev_gpio8 #(
        .NUM_IO(NUM_IO)
    ) gpio (
        .clk(clk), .reset(rst),
        .io_in(io_in),
        .io_out(io_out_buf),
        .io_oeb(io_oeb_buf),
        .io_in_sync(io_in_sync),
        .io_in_rise(io_in_rise),
        .io_in_fall(io_in_fall),
        
        .stb(gpt_stb), .ack(gpt_ack),
        .rw(rw), .addr(mmio_addr[4:2]),
        .dwrite(dwrite), .dtr(gpt_dtr),

        .io_irqr(gpt_irqr),
        .io_irqf(gpt_irqf)
    );

    // GPIO assignments
    assign GPIO0 = io_oeb_buf[0] ? io_out_buf[0] : 1'bz;
    assign GPIO1 = io_oeb_buf[1] ? io_out_buf[1] : 1'bz;
    assign GPIO2 = io_oeb_buf[2] ? io_out_buf[2] : 1'bz;
    assign GPIO3 = io_oeb_buf[3] ? io_out_buf[3] : 1'bz;
    assign GPIO4 = io_oeb_buf[4] ? io_out_buf[4] : 1'bz;
    assign GPIO5 = io_oeb_buf[5] ? io_out_buf[5] : 1'bz;
    assign GPIO6 = io_oeb_buf[6] ? io_out_buf[6] : 1'bz;
    assign GPIO7 = io_oeb_buf[7] ? io_out_buf[7] : 1'bz;
    assign GPIO8 = io_oeb_buf[8] ? io_out_buf[8] : 1'bz;
    assign LEDR_N = ~io_out_buf[10];
    assign LEDG_N = ~io_out_buf[11];
    assign io_in = {
        io_out_buf[11], io_out_buf[10],
        GPIO9, GPIO8,
        GPIO7, GPIO6, GPIO5, GPIO4,
        GPIO3, GPIO2, GPIO1, GPIO0
    };

    //===============================//
    // Internal SRAM controller
    //===============================//

    wire[31:0] ram_addr, ram_dread, ram_dwrite;
    wire ram_rw, ram_stb, ram_ack;

    soc_bram_ctl #(
        .addr_width(8),
        .data0(data0),
        .data1(data1),
        .data2(data2),
        .data3(data3)
    ) bram_ctl(
        .i_clk(clk),
        .i_reset(rst || flush),
        .i_addr(ram_addr[7:0]), .i_rw(ram_rw),
        .o_dread(ram_dread), .i_dwrite(ram_dwrite),
        .i_stb(ram_stb), .o_ack(ram_ack)
    );
endmodule
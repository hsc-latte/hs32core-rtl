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

`define FPGA

`include "cpu/hs32_cpu.v"
`include "cpu/hs32_aic16.v"
`include "soc/soc_bram_ctl.v"
`include "soc/dev_intercon.v"
`include "soc/dev_gpio8.v"
`include "soc/dev_timer.v"
`include "soc/dev_uart.v"
`include "frontend/sram.v"

module main (
    input   wire CLK,
    input   wire RST_N,
    input   wire RX,
    output  wire TX,
    output  wire LEDR_N,
    output  wire LEDG_N,

    // Input button (GPIO9)
    input wire GPIO9,
    
    // GPIO
    inout wire GPIO8,
    inout wire GPIO7, inout wire GPIO6, inout wire GPIO5, inout wire GPIO4,
    inout wire GPIO3, inout wire GPIO2, inout wire GPIO1, inout wire GPIO0,

    // I/O Bus
    inout IO0, inout IO1, inout IO2, inout IO3, inout IO4,
    inout IO5, inout IO6, inout IO7, inout IO8, inout IO9,
    inout IO10, inout IO11, inout IO12, inout IO13,
    inout IO14, inout IO15,

    // Control signals
    output OE_N, output WE_N, output ALE0, output ALE1, output BHE_N,

    // OE BYTEn
    output reg OE_BY0_N, output reg OE_BY1_N,
    output reg OE_BY2_N, output reg OE_BY3_N
);
    parameter data0 = "bench/bram0.hex";
    parameter data1 = "bench/bram1.hex";
    parameter data2 = "bench/bram2.hex";
    parameter data3 = "bench/bram3.hex";
    parameter RST_BITS = 16;

    wire clk = CLK;
    reg[RST_BITS-1:0] ctr = 0;
    always @(posedge clk)
    if(!RST_N) begin
        ctr <= 0;
    end else begin
        if(!ctr[RST_BITS-1]) begin
            ctr <= ctr + 1;
        end
    end
    wire rst = !ctr[RST_BITS-1] && (ctr != 0);

    // Address latch OE pulldown
    initial OE_BY0_N = 0;
    initial OE_BY1_N = 0;
    initial OE_BY2_N = 0;
    initial OE_BY3_N = 0;

    //===============================//
    // External I/O Bus Signals
    //===============================//

    wire we, oe, oe_neg, ale0_neg, ale1_neg, bhe, isout;
    wire[15:0] data_in;
    wire[15:0] data_out;
    assign { IO15, IO14, IO13, IO12, IO11, IO10, IO9, IO8,
             IO7, IO6, IO5, IO4, IO3, IO2, IO1, IO0 } = isout ? data_out : 16'bz;
    assign data_in = { IO15, IO14, IO13, IO12, IO11, IO10, IO9, IO8, IO7, IO6, IO5, IO4, IO3, IO2, IO1, IO0 };
    assign OE_N = !(oe & oe_neg);
    assign WE_N = !we;
    assign ALE0 = ale0_neg;
    assign ALE1 = ale1_neg;
    assign BHE_N = !bhe;

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
        .NS(4),
        .BASE({
            { 1'b0, 7'b0 },
            { 1'b1, 2'b00, 5'b0 },
            { 1'b1, 2'b01, 1'b0, 4'b0 },
            { 1'b1, 2'b01, 1'b1, 4'b0 }
        }),
        .MASK({
            { 1'b1, 7'b0 },
            { 1'b1, 2'b11, 5'b0 },
            { 1'b1, 2'b11, 1'b1, 4'b0 },
            { 1'b1, 2'b11, 1'b1, 4'b0 }
        }),
        .MASK_LEN(8),
        .LIMITS(BRAM_ADDR)
    ) mmio_conn (
        .clk(clk), .reset(rst), .userbit(userbit),
        
        // Input
        .i_stb(stb), .o_ack(ack),
        .i_addr(addr), .o_dtr(dread),
        .i_rw(rw), .i_dtw(dwrite),

        // Devices
        .i_dtr({ aic_dtr, gpt_dtr, t0_dtr, uart_dtr }),
        .i_ack({ aic_ack, gpt_ack, t0_ack, uart_ack }),
        .o_stb({ aic_stb, gpt_stb, t0_stb, uart_stb }),
        .o_addr(mmio_addr),

        // SRAM
        .sstb(ram_stb), .sack(ram_ack), .sdtr(ram_dread),

        // Buf
        .estb(eram_stb), .eack(eram_ack), .edtr(eram_dread)
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

    wire[23:0] hw_irq = {
        8'b0,
        gpt_irqr,
        gpt_irqf,
        tn_ints,
        12'b0
    };

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

    wire io0 = t0_io_oe ? t0_io_out : io_out_buf[0];

    // GPIO assignments
    assign GPIO0 = io_oeb_buf[0] ? io0 : 1'bz;
    assign GPIO1 = io_oeb_buf[1] ? io_out_buf[1] : 1'bz;
    assign GPIO2 = io_oeb_buf[2] ? io_out_buf[2] : 1'bz;
    assign GPIO3 = io_oeb_buf[3] ? io_out_buf[3] : 1'bz;
    assign GPIO4 = io_oeb_buf[4] ? io_out_buf[4] : 1'bz;
    assign GPIO5 = io_oeb_buf[5] ? io_out_buf[5] : 1'bz;
    assign GPIO6 = io_oeb_buf[6] ? io_out_buf[6] : 1'bz;
    assign GPIO7 = io_oeb_buf[7] ? io_out_buf[7] : 1'bz;
    assign GPIO8 = io_oeb_buf[8] ? io_out_buf[8] : 1'bz;
    assign LEDR_N = ~(io_out_buf[11] | rst);
    assign LEDG_N = ~io_out_buf[10];
    assign io_in = {
        io_out_buf[11], io_out_buf[10],
        GPIO9, GPIO8,
        GPIO7, GPIO6, GPIO5, GPIO4,
        GPIO3, GPIO2, GPIO1, GPIO0
    };

    //===============================//
    // Timer
    //===============================//

    localparam T0_IO_NUM = 0;
    wire t0_stb, t0_ack;
    wire[31:0] t0_dtr;
    wire[1:0] tn_ints;

    // Timer 0
    wire t0_io_out, t0_io_oe;
    dev_timer #(
        .TIMER_BITS(16)
    ) dev_timer0 (
        .clk(clk), .reset(rst),
        .int_match(tn_ints[0]),
        .int_ovf(tn_ints[1]),
        .io(t0_io_out),
        .io_oe(t0_io_oe),
        .io_risen(io_in_rise[T0_IO_NUM]),
        .io_fallen(io_in_fall[T0_IO_NUM]),
        .we(rw), .stb(t0_stb), .ack(t0_ack),
        .addr(mmio_addr[3:2]),
        .dtw(dwrite), .dtr(t0_dtr)
    );

    //===============================//
    // UART
    //===============================//

    wire uart_stb, uart_ack;
    wire[31:0] uart_dtr;

    dev_uart uart(
        .clk(clk), .reset(rst),
        .rx(RX), .tx(TX),
        .stb(uart_stb), .ack(uart_ack),
        .we(rw), .addr(mmio_addr[3:2]),
        .dtw(dwrite), .dtr(uart_dtr),
        .irq()
    );

    //===============================//
    // Internal SRAM controller
    //===============================//

    localparam BRAM_ADDR = 12;

    wire[31:0] ram_addr, ram_dread, ram_dwrite;
    wire ram_rw, ram_stb, ram_ack;

    soc_bram_ctl #(
        .addr_width(BRAM_ADDR),
        .data0(data0),
        .data1(data1),
        .data2(data2),
        .data3(data3)
    ) bram_ctl(
        .i_clk(clk),
        .i_reset(rst || flush),
        .i_addr(ram_addr[BRAM_ADDR-1:0]), .i_rw(ram_rw),
        .o_dread(ram_dread), .i_dwrite(ram_dwrite),
        .i_stb(ram_stb), .o_ack(ram_ack)
    );

    //===============================//
    // External SRAM controller
    //===============================//

    wire eram_stb, eram_ack;
    wire[31:0] eram_dread;
    wire[31:0] sram_addr = { ~ram_addr[31], ram_addr[31], ram_addr[29:0] };

    ext_sram #(
        .SRAM_LATCH_LAZY(1),
        .SRAM_STALL_CYC(1)
    ) sram (
        .clk(clk), .reset(rst || flush),
        // Memory requests
        .ack(eram_ack), .stb(eram_stb), .i_rw(rw),
        .i_addr(sram_addr), .i_dtw(dwrite), .dtr(eram_dread),

        // External IO interface, active >> HIGH <<
        .din(data_in), .dout(data_out),
        .we(we), .oe(oe), .oe_negedge(oe_neg),
        .ale0_negedge(ale0_neg),
        .ale1_negedge(ale1_neg),
        .bhe(bhe), .isout(isout)
    );
endmodule
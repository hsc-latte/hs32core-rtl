/**
 * Copyright (c) 2021 The HSC Core Authors
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
 * @file   dev_uart.v
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on January 04 2021, 5:41 PM
 */

`include "third_party/uart/uart.v"

module dev_uart (
    input   wire clk,
    input   wire reset,

    // Serial wires
    input wire rx,
    output wire tx,

    // Memory bus
    input wire stb,
    output wire ack,
    input wire we,
    input wire[1:0] addr,
    input wire[31:0] dtw,
    output reg[31:0] dtr,

    // Interrupts
    output wire irq
);
    parameter CLK_WIDTH = 16;

    assign ack = 1;
    assign irq = 0;

    // Configuration
    reg[CLK_WIDTH-1:0] clock_div;
    reg[4:0] uart_cfg;
    reg[7:0] txbuf;
    wire[7:0] rxbuf;
    wire[1:0] uart_status;
    always @(*) case(addr)
        0: dtr = { 24'b0, txbuf };
        1: dtr = { 24'b0, rxbuf };
        2: dtr = { 25'b0, uart_status, uart_cfg };
        3: dtr = { 16'b0, clock_div };
        default: dtr = 0;
    endcase
    always @(posedge clk) if(reset) begin
        uart_cfg <= 0;
        clock_div <= 0;
        txbuf <= 0;
    end else if(stb && we) case(addr)
        0: txbuf <= dtw[7:0];
        2: uart_cfg <= dtw[4:0];
        3: clock_div <= dtw[15:0];
        default: begin end
    endcase else begin
        if(uart_cfg[0]) uart_cfg[0] <= 0;
        if(uart_cfg[1]) uart_cfg[1] <= 0;
    end

    UART #(
        .CLOCK_DIVIDER_WIDTH(CLK_WIDTH)
    ) uart (
        .clock_i(clk), .reset_i(reset),
        .clock_divider_i(clock_div),
        .serial_i(rx),
        .serial_o(tx),
        .data_i(txbuf),
        .data_o(rxbuf),
        .write_i(uart_cfg[0]),
        .write_busy_o(uart_status[0]),
        .read_ready_o(uart_status[1]),
        .ack_i(uart_cfg[1]),
        .two_stop_bits_i(uart_cfg[2]),
        .parity_bit_i(uart_cfg[3]),
        .parity_even_i(uart_cfg[4])
    );
endmodule

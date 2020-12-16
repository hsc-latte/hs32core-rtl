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
 * @file   hs32_mem.v
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on October 24 2020, 10:09 PM
 */

 `default_nettype none

// Internal Memory Arbiter (IMA):
// Schedules and arbitrates memory requests.
//
// Note: channel0 gets priority over channel1
// When channel0 wants access, it drives req0 HIGH.
// When channel1 wants access, it drives req1 HIGH.

module hs32_mem (
    input wire clk,
    input wire reset,

    // External interface
    output  wire[31:0] addr,    // Output address
    output  wire rw,            // Read/write signal
    input   wire[31:0] din,     // Data input from memory
    output  wire[31:0] dout,    // Data output to memory
    output  wire stb,           // Valid outputs
    input   wire ack,           // Operation completed (valid din too)

    // Channel 0
    input   wire[31:0] addr0,   // Address request from
    input   wire rw0,           // Read/write signal from
    output  wire[31:0] dtr0,    // Data to read
    input   wire[31:0] dtw0,    // Data to write
    input   wire stb0,          // Valid input
    output  wire ack0,          // Valid output
    output  reg  stl0,          // Rejected request (stall)

    // Channel 1
    input   wire[31:0] addr1,   // Address request from
    input   wire rw1,           // Read/write signal from
    output  wire[31:0] dtr1,    // Data to read
    input   wire[31:0] dtw1,    // Data to write
    input   wire stb1,          // Valid input
    output  wire ack1,          // Valid output
    output  reg  stl1
);
    // Assign inputs
    assign dtr0 = din;
    assign dtr1 = din;
    // Not busy, then go with stb. Else, go with r_sel
    assign addr = (stl0 || stl1) ?
        r_sel ? addr1 : addr0 :
        stb0 ? addr0 : addr1;
    assign dout = (stl0 || stl1) ?
        r_sel ? dtw1 : dtw0 :
        stb0 ? dtw0 : dtw1;
    assign rw = (stl0 || stl1) ?
        r_sel ? rw1 : rw0 :
        stb0 ? rw0 : rw1;
    // If busy, stb should be low. Else, go with stb
    assign stb = (stl0 || stl1) ? 0 : stb0 | stb1;
    // Only if busy, go with r_sel, otherwise, 0
    assign ack0 = (stl0 || stl1) ? r_sel ? 0 : ack : 0;
    assign ack1 = (stl0 || stl1) ? r_sel ? ack : 0 : 0;

    // Selected active channel
    reg r_sel;
    always @(posedge clk)
    if(reset) begin
        stl0 <= 0;
        stl1 <= 0;
        r_sel <= 0;
    end else begin
        // Request and not busy
        if((stb0 || stb1) && !(stl0 || stl1)) begin
            if(stb0) begin
                stl0 <= 0;
                stl1 <= 1;
                r_sel <= 0;
            end else begin
                stl0 <= 1;
                stl1 <= 0;
                r_sel <= 1;
            end
        // Currently busy
        end else if(stl0 || stl1) begin
            // If ack, then deal with it
            if(ack) begin
                stl0 <= 0;
                stl1 <= 0;
            end
        end
        // IDLE
    end
endmodule

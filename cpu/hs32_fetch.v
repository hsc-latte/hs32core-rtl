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
 * @file   hs32_fetch.v
 * @author Anthony Kung <hi@anth.dev>
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on October 24 2020, 10:34 PM
 */

`default_nettype none

// Fetches instructions from the memory arbiter and holds
// them in an internal queue/fifo.

module hs32_fetch (
    input clk, input reset,

    // Memory arbiter interface
    output  wire [31:0] addr,       // Address
    input   wire [31:0] dtr,        // Data input
    output  reg  stbm,              // Valid address
    input   wire ackm,              // Valid data
    input   wire stlm,              // Stall

    // Decode
    output  wire[31:0] instd,       // Next instruction
    output  wire reqd,              // Valid input
    input   wire rdyd,              // Valid output

    // Pipeline controller
    input   wire[31:0] newpc,       // New program counter
    input   wire flush              // Flush
);
    parameter PREFETCH_SIZE = 2;
    parameter LOW_WATER = (1 << PREFETCH_SIZE)/2 - 1;

    // Program counter and init values
    reg[31:0] pc;

    // Fifo Logic, fill is size of fifo
    reg [PREFETCH_SIZE:0] wp, rp, fill, fill_next;
    wire[PREFETCH_SIZE:0] wp_next;
    assign wp_next = wp + 1;
    reg full, full_next;
    reg[31:0] fifo[(1<<PREFETCH_SIZE)-1:0];
    integer i; // For flush

`ifdef SIM
    initial begin
        for(i = 0; i < (1<<PREFETCH_SIZE); i++)
            $dumpvars(1, fifo[i]);
    end
    always @(*) begin
        if(flush) begin
            $display($time, " Flush, newpc: %X", newpc);
        end
    end
`endif

    // Combinatorial logic to update the values of fill and full
    always @(*) fill = wp - rp;
    always @(*) fill_next = wp_next - rp;
    always @(*) full = fill == { 1'b1, {(PREFETCH_SIZE) {1'b0}} };
    always @(*) full_next = fill_next == { 1'b1, {(PREFETCH_SIZE) {1'b0}} };

    // Decode request
    generate
        if(LOW_WATER == 0) begin
            assign reqd = !(flush) && (fill > 1);
        end else begin
            assign reqd = !(flush) && (refill ? fill > LOW_WATER : fill > 1);
        end
    endgenerate
    assign instd = fifo[rp[PREFETCH_SIZE-1:0]];
    always @(posedge clk)
    if(flush) begin
        rp <= 0;
    end else if(rdyd && reqd) begin
        rp <= rp+1;
    end

    reg refill;
    always @(posedge clk)
    if(flush) begin
        refill <= 1;
    end else if(refill && fill > LOW_WATER) begin
        refill <= 0;
    end else if(fill < 1) begin
        refill <= 1;
    end

    // Memory request
    assign addr = pc;
    // Internal busy state
    reg r_bsy;
    always @(posedge clk)
    if(flush) begin
        pc <= newpc;
        wp <= 0;
        for(i = 0; i < (1<<PREFETCH_SIZE); i++) begin
            fifo[i] <= 0;
        end
        stbm <= 0;
        r_bsy <= 0;
    end else begin
        // Not busy and able to request
        if(!r_bsy && !full) begin
            stbm <= 1; // Request pulse
            r_bsy <= 1;
        end else if(r_bsy) begin
            stbm <= 0;
            if(stlm) begin
                r_bsy <= 0;
            end else if(ackm) begin
                pc <= pc+4;
                fifo[wp[PREFETCH_SIZE-1:0]] <= dtr;
                wp <= wp_next;
                r_bsy <= 0;
                if(!full_next) begin
                    stbm <= 1;
                    r_bsy <= 1;
                end
            end
        end
        // IDLE
    end

`ifdef FORMAL
    // $past gaurd
    reg f_past_valid;
    initial f_past_valid = 0;
    always @(posedge clk)
        f_past_valid <= 1;
    
    // 0. Assume every reqm will have a rdym
    always @(posedge clk)
    if(reqm)
        assume property (s_eventually rdym);
    
    // 1. Assert bus contract
    // - If reqm but !rdym, the outputs must be stable
    always @(posedge clk)
    if(f_past_valid)
        if(!reset && !rdym && reqm && $stable(rdym) && $stable(reqm))
            assert($stable(addr));
    
    // 3. FIFO invariants
    // - Size of FIFO must be <= (1 << PREFETCH_SIZE)
    // - FIFO's size must be the FIFO's size
    // - FIFO is full when it's size is the maximum size
    // - FIFO cannot be read from if it is empty
    // - FIFO is empty IFF write pointer == read pointer
    wire[PREFETCH_SIZE:0] f_size;
    assign f_size = wp-rp;
    always @(*) begin
        assert(f_size <= { 1'b1, {(PREFETCH_SIZE) {1'b0}} });
        assert(fill == f_size);
        assert(full == (f_size == { 1'b1, {(PREFETCH_SIZE) {1'b0}} }) );
        assert(!(wp == rp) || !rdyd);
        assert((wp == rp) == (f_size == 0));
    end

    // 4. Output invariant
    // - FIFO's output must be instd when requested and ready
    always @(*)
    if(rdyd && reqd)
        assert(fifo[rp[PREFETCH_SIZE-1:0]] == instd);
    
    // 5. Prefetch behaviour invariant
    // -- Instructions must leave the prefetch in the order they entered
    // -> Then i1 at t1, i2 at t2 must leave i1 at tn and i2 at tn+x with
    //    no other instructions leaving in between.
    // -- If we flush, we must bail and restart
    reg[3:0] f_state;
    initial f_state = 0;
    (* anyconst *) reg[31:0] f_addr;
    (* anyconst *) reg[31:0] f_instd1;
    (* anyconst *) reg[31:0] f_instd2;
    reg[31:0] f_pc1, f_pc_next;
    reg[PREFETCH_SIZE:0] f_wp1, f_wp2, f_wp1_correct;
    always @(posedge clk)
    case(f_state)
        0: if(flush) begin
            f_state <= 0;
        end else if(rdym && reqm && !reqd && dtr == f_instd1 && addr == f_addr) begin
            f_state <= 1;
            f_pc1 <= addr+4;
            f_pc_next <= addr+4*((1<<PREFETCH_SIZE)-1);
            f_wp1 <= wp;
        end
        1: if(reqd || flush) begin
            f_state <= 0;
        end else begin
            if(rdym && reqm && dtr == f_instd2 && addr == f_pc1) begin
                f_state <= 2;
                f_wp2 <= wp;
            end else begin
                f_state <= 0;
            end
        end
        2: if(flush) begin
            f_state <= 0;
        end else if(rdyd && reqd && rp == f_wp1) begin
            f_state <= 3;
            f_wp1_correct <= f_wp1+1;
            assert(instd == f_instd1);
        end
        3: if(flush) begin
            f_state <= 0;
        end else if(rdyd && reqd) begin
            f_state <= 0;
            assert(instd == f_instd2);
            assert(rp == f_wp2);
            assert(f_wp2 == f_wp1_correct);
        end
    endcase

    // 6. Cover conditions
    // - Ensure reset always is flushed
    // - TODO: Add more
    always @(posedge clk) begin
        cover($fell(reset_latch));
        cover($fell(full));
        cover($rose(rdyd));
    end

    // 7. Reset assertions
    // - Assume when we flush, we will eventually stop flushing
    // - Check if reset will fall then
    always @(posedge clk)
    if(flush)
        assume property (s_eventually !flush);
    always @(posedge clk) begin
        if(flush)
            assert property(s_eventually !reset_latch || $fell(reset));
    end
`endif
endmodule
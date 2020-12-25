//`include "third_party/devboard/CY74FCT573.v"
//`include "third_party/devboard/AS6C1008.v"
`include "cpu/hs32_cpu.v"
`include "frontend/sram.v"

module tb_devboard;
    parameter PERIOD = 2;

    reg clk = 1;
    reg reset = 1;

    always #(PERIOD/2) clk=~clk;

    initial begin
        $dumpfile("tb_devboard.vcd");
        $dumpvars(0, tb_devboard);

        // Power on reset, no touchy >:[
        #(PERIOD*2)
        reset <= 0;
        #(PERIOD*200);
        $finish;
    end

    wire ack, stb, rw;
    wire[31:0] addr, dtw, dtr;

    hs32_cpu #(
        .IMUL(1), .BARREL_SHIFTER(1), .PREFETCH_SIZE(2)
    ) cpu (
        .i_clk(clk),
        .reset(reset),
        .addr(addr),
        .rw(rw),
        .din(dtr),
        .dout(dtw),
        .stb(stb),
        .ack(ack)
    );

    ext_sram #(
        .SRAM_LATCH_LAZY(0)
    ) sram (
        .clk(clk), .reset(reset),
        .ack(ack), .stb(stb),
        .i_rw(rw), .i_addr(addr),
        .i_dtw(dtw), .dtr(dtr)
    );
endmodule

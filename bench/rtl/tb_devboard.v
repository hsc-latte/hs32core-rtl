`include "third_party/devboard/CY74FCT573.v"
`include "third_party/devboard/AS6C1008.v"

module tb_devboard;
    parameter PERIOD = 2;

    reg clk = 1;
    reg reset = 1;

    always #(PERIOD/2) clk=~clk;

    initial begin
        $dumpfile("tb_soc.vcd");
        $dumpvars(0, );

        // Power on reset, no touchy >:[
        #(PERIOD*2)
        reset <= 0;
        #(PERIOD*200);
        $finish;
    end

    hs32_cpu #(
        .IMUL(1), .BARREL_SHIFTER(1), .PREFETCH_SIZE(2)
    ) cpu (

    );

endmodule

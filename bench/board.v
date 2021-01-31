module board(
    input wire[15:0] inp,
    input wire[1:0] le,
    input wire bhe,
    input wire we,
    output wire[15:0] out
);
    parameter SIZE = 8;

    reg[15:0] mem[(1<<SIZE)-1:0];
    reg[15:0] a0, a1;

    wire[31:0] addr = { a1, a0 };
    wire ble = addr[31];
    wire ce_we = !addr[29] && !we;

    assign out = mem[addr[SIZE-1:0]];

    always @(le[0]) a0 = inp;
    always @(le[1]) a1 = inp;
    always @(ce_we) begin
        if(!ble)
            mem[addr[SIZE-1:0]][7:0] = inp[7:0];
        if(!bhe)
            mem[addr[SIZE-1:0]][15:8] = inp[15:8];
    end
    always @(negedge ce_we) begin
        $display("Board memory write %b [%X] <- %X", { bhe, ble }, addr, inp);
    end
endmodule
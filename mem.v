module mem (
    input        clk,
    input        we,
    input  [31:0] addr,
    input  [31:0] wd,
    output [31:0] rd
);

    // REQUIRED NAME
    reg [31:0] RAM [0:1023];

    assign rd = RAM[addr[11:2]];

    always @(posedge clk) begin
        if (we)
            RAM[addr[11:2]] <= wd;
    end

endmodule

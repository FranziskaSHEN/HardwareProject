module dmem (
    input  wire        clk,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wd,
    output wire [31:0] rd
);
    reg [31:0] mem [0:65535];

    always @(posedge clk) begin
        if (we)
            mem[addr[17:2]] <= wd;
    end

    assign rd = mem[addr[17:2]];

endmodule

module regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  rs1, rs2, rd,
    input  wire [31:0] wd,
    output wire [31:0] rd1, rd2
);
    reg [31:0] regs [31:0];

    // write
    always @(posedge clk) begin
        if (we && rd != 0)
            regs[rd] <= wd;
    end

    // read
    assign rd1 = (rs1 == 0) ? 0 : regs[rs1];
    assign rd2 = (rs2 == 0) ? 0 : regs[rs2];

endmodule
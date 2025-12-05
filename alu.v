module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_control, // width depends on your design
    output reg  [31:0] y,
    output wire        zero
);
    assign zero = (y == 32'b0);

    always @(*) begin
        case (alu_control)
            4'b0000: y = a + b;                   // add
            4'b0001: y = a - b;                   // sub
            4'b0010: y = a << b[4:0];             // sll
            4'b0011: y = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0; // slt
            4'b0100: y = (a < b) ? 32'b1 : 32'b0; // sltu
            4'b0101: y = a ^ b;                   // xor
            4'b0110: y = a >> b[4:0];             // srl (logical)
            4'b0111: y = $signed(a) >>> b[4:0];   // sra (arithmetic)
            4'b1000: y = a | b;                   // or
            4'b1001: y = a & b;                   // and
            default: y = 32'b0;
        endcase
    end

endmodule

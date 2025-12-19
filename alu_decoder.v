module alu_decoder (
    input  [1:0] alu_op,
    input  [2:0] funct3,
    input        funct7b5,
    output reg [3:0] alu_ctrl
);

    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0000; // ADD
            2'b01: alu_ctrl = 4'b0001; // SUB
            2'b10: begin
                case (funct3)
                    3'b000: alu_ctrl = funct7b5 ? 4'b0001 : 4'b0000;
                    3'b111: alu_ctrl = 4'b0010;
                    3'b110: alu_ctrl = 4'b0011;
                    3'b100: alu_ctrl = 4'b0100;
                    3'b010: alu_ctrl = 4'b0101;
                    3'b001: alu_ctrl = 4'b0110;
                    3'b101: alu_ctrl = funct7b5 ? 4'b1000 : 4'b0111;
                    default: alu_ctrl = 4'b0000;
                endcase
            end
            default: alu_ctrl = 4'b0000;
        endcase
    end

endmodule

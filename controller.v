module controller (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg        rf_we,
    output reg [2:0]  imm_sel,
    output reg        sel_alu_src_b,
    output reg        dmem_we,
    output reg [1:0]  sel_result,
    output reg [1:0]  alu_op,
    output reg [3:0]  alu_control,
    output reg        branch,
    output reg        jump
);

    always @(*) begin
        rf_we         = 0;
        imm_sel       = 3'b000;
        sel_alu_src_b = 0;
        dmem_we       = 0;
        sel_result    = 2'b00;
        alu_op        = 2'b00;
        branch        = 0;
        jump          = 0;

        case (opcode)
            7'b0110011: begin
                rf_we         = 1;
                sel_alu_src_b = 0;
                sel_result    = 2'b00;
                alu_op        = 2'b01;
            end
            7'b0010011: begin
                rf_we         = 1;
                imm_sel       = 3'b000;
                sel_alu_src_b = 1;
                sel_result    = 2'b00;
                alu_op        = 2'b10;
            end
            7'b0000011: begin
                rf_we         = 1;
                imm_sel       = 3'b000;
                sel_alu_src_b = 1;
                sel_result    = 2'b01;
                alu_op        = 2'b00;
            end
            7'b0100011: begin
                imm_sel       = 3'b001;
                sel_alu_src_b = 1;
                dmem_we       = 1;
                alu_op        = 2'b00;
            end
            7'b1100011: begin
                branch        = 1;
                imm_sel       = 3'b010;
                sel_alu_src_b = 0;
                alu_op        = 2'b11;
            end
            7'b1101111: begin
                jump          = 1;
                rf_we         = 1;
                imm_sel       = 3'b100;
                sel_result    = 2'b10;
            end
            7'b0110111: begin
                rf_we         = 1;
                imm_sel       = 3'b011;
                sel_result    = 2'b11;
            end
        endcase
    end

    always @(*) begin
        alu_control = 4'b0000;

        case (alu_op)

            2'b00: alu_control = 4'b0000;

            2'b01: begin
                case (funct3)
                    3'b000: alu_control = (funct7 == 7'b0100000) ? 4'b0001 : 4'b0000;
                    3'b001: alu_control = 4'b0010;
                    3'b010: alu_control = 4'b0011;
                    3'b011: alu_control = 4'b0100;
                    3'b100: alu_control = 4'b0101;
                    3'b101: alu_control = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110;
                    3'b110: alu_control = 4'b1000;
                    3'b111: alu_control = 4'b1001;
                endcase
            end

            2'b10: begin
                case (funct3)
                    3'b000: alu_control = 4'b0000;
                    3'b010: alu_control = 4'b0011;
                    3'b011: alu_control = 4'b0100;
                    3'b100: alu_control = 4'b0101;
                    3'b110: alu_control = 4'b1000;
                    3'b111: alu_control = 4'b1001;
                    3'b001: alu_control = 4'b0010;
                    3'b101: alu_control = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110;
                endcase
            end

            2'b11: begin
                case (funct3)
                    3'b000: alu_control = 4'b0001;
                    default: alu_control = 4'b0000;
                endcase
            end

        endcase
    end

endmodule

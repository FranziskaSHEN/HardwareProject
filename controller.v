module controller (
    input        clk,
    input        rst,
    input  [6:0] opcode,

    output reg        sel_mem_addr,   // 0 = PC, 1 = ALU
    output reg        ir_we,
    output reg        pc_update,
    output reg        mem_we,
    output reg        rf_we,
    output reg        sel_alu_src_a,   // 0 = PC, 1 = rs1
    output reg [1:0]  sel_alu_src_b,   // 00 = rs2, 01 = imm, 10 = 4
    output reg [1:0]  alu_op,          // to ALU decoder
    output reg [1:0]  sel_result       // 00 = ALU, 01 = MEM, 10 = PC+4, 11 = IMM(U)
);

    // -------------------------------------------------
    // STATE ENCODING (binary, pure Verilog)
    // -------------------------------------------------
    localparam S0_FETCH   = 4'd0;
    localparam S1_DECODE  = 4'd1;
    localparam S2_EXE_ADR = 4'd2;
    localparam S3_MEM_RD  = 4'd3;
    localparam S4_WB_MEM  = 4'd4;
    localparam S5_MEM_WR  = 4'd5;
    localparam S6_EXE_R   = 4'd6;
    localparam S7_WB_ALU  = 4'd7;
    localparam S8_BEQ     = 4'd8;
    localparam S9_EXE_I   = 4'd9;
    localparam S10_JAL    = 4'd10;
    localparam S11_LUI    = 4'd11;

    reg [3:0] state;
    reg [3:0] next_state;

    // -------------------------------------------------
    // STATE REGISTER
    // -------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= S0_FETCH;
        else
            state <= next_state;
    end

    // -------------------------------------------------
    // NEXT STATE LOGIC
    // -------------------------------------------------
    always @(*) begin
        next_state = state;

        case (state)

            S0_FETCH:
                next_state = S1_DECODE;

            S1_DECODE: begin
                case (opcode)
                    7'b0000011: next_state = S2_EXE_ADR; // LW
                    7'b0100011: next_state = S2_EXE_ADR; // SW
                    7'b0110011: next_state = S6_EXE_R;   // R-type
                    7'b0010011: next_state = S9_EXE_I;   // I-type ALU
                    7'b1100011: next_state = S8_BEQ;     // BEQ
                    7'b1101111: next_state = S10_JAL;    // JAL
                    7'b0110111: next_state = S11_LUI;    // LUI
                    default:    next_state = S0_FETCH;
                endcase
            end

            S2_EXE_ADR:
                next_state = (opcode == 7'b0000011) ? S3_MEM_RD : S5_MEM_WR;

            S3_MEM_RD:
                next_state = S4_WB_MEM;

            S4_WB_MEM:
                next_state = S0_FETCH;

            S5_MEM_WR:
                next_state = S0_FETCH;

            S6_EXE_R:
                next_state = S7_WB_ALU;

            S9_EXE_I:
                next_state = S7_WB_ALU;

            S7_WB_ALU:
                next_state = S0_FETCH;

            S8_BEQ:
                next_state = S0_FETCH;

            S10_JAL:
                next_state = S0_FETCH;

            S11_LUI:
                next_state = S0_FETCH;

            default:
                next_state = S0_FETCH;

        endcase
    end

    // -------------------------------------------------
    // OUTPUT LOGIC (MOORE FSM)
    // -------------------------------------------------
    always @(*) begin
        // defaults
        sel_mem_addr  = 1'b0;
        ir_we         = 1'b0;
        pc_update     = 1'b0;
        mem_we        = 1'b0;
        rf_we         = 1'b0;
        sel_alu_src_a = 1'b0;
        sel_alu_src_b = 2'b00;
        alu_op        = 2'b00;
        sel_result    = 2'b00;

        case (state)

            // ---------------- FETCH ----------------
            S0_FETCH: begin
                sel_mem_addr  = 1'b0;   // memory address = PC
                ir_we         = 1'b1;   // load instruction
                sel_alu_src_a = 1'b0;   // A = PC
                sel_alu_src_b = 2'b10;  // B = 4
                alu_op        = 2'b00;  // ADD
                pc_update     = 1'b1;   // PC = PC + 4
            end

            // ----------- ADDRESS CALC --------------
            S2_EXE_ADR: begin
                sel_alu_src_a = 1'b1;   // rs1
                sel_alu_src_b = 2'b01;  // immediate
                alu_op        = 2'b00;  // ADD
            end

            // ------------ MEMORY READ --------------
            S3_MEM_RD: begin
                sel_mem_addr = 1'b1;    // address = ALU
            end

            // ------------ MEMORY WRITE -------------
            S5_MEM_WR: begin
                sel_mem_addr = 1'b1;
                mem_we       = 1'b1;
            end

            // ----------- WRITEBACK MEM --------------
            S4_WB_MEM: begin
                rf_we      = 1'b1;
                sel_result = 2'b01;     // data from memory
            end

            // ------------ R-TYPE EXEC --------------
            S6_EXE_R: begin
                sel_alu_src_a = 1'b1;
                sel_alu_src_b = 2'b00;
                alu_op        = 2'b10;
            end

            // ------------ I-TYPE EXEC --------------
            S9_EXE_I: begin
                sel_alu_src_a = 1'b1;
                sel_alu_src_b = 2'b01;
                alu_op        = 2'b10;
            end

            // ----------- WRITEBACK ALU --------------
            S7_WB_ALU: begin
                rf_we      = 1'b1;
                sel_result = 2'b00;
            end

            // ---------------- BEQ ------------------
            S8_BEQ: begin
                sel_alu_src_a = 1'b1;
                sel_alu_src_b = 2'b00;
                alu_op        = 2'b01;  // SUB
                pc_update     = 1'b1;   // datapath should gate with zero
            end

            // ---------------- JAL ------------------
            S10_JAL: begin
                sel_alu_src_a = 1'b0;   // PC
                sel_alu_src_b = 2'b01;  // immediate
                pc_update     = 1'b1;
                rf_we         = 1'b1;
                sel_result    = 2'b10;  // PC+4
            end

            // ---------------- LUI ------------------
            S11_LUI: begin
                rf_we      = 1'b1;
                sel_result = 2'b11;     // imm_u
            end

        endcase
    end

endmodule

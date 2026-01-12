`timescale 1ns/1ps

// ============================================================
// Top-level core + memory
// ============================================================
module rv_pl(
    input  wire clk,
    input  wire rst_n
);

    // --------------------------
    // IF stage: PC + fetch
    // --------------------------
    wire        pc_en;
    wire [31:0] F_PC, F_PC_next, F_PC_P4;
    wire [31:0] F_instr;

    // control redirect from EX
    wire        E_take_ctrl;      // taken beq OR jal
    wire [31:0] E_target_PC;

    assign F_PC_P4   = F_PC + 32'd4;
    assign F_PC_next = E_take_ctrl ? E_target_PC : F_PC_P4;

    pc_reg PC0 (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (pc_en),
        .d     (F_PC_next),
        .q     (F_PC)
    );

    // Instruction memory
    instruction_mem IMEM (
        .addr (F_PC),
        .rd   (F_instr)
    );

    // --------------------------
    // PLR1: IF/ID
    // --------------------------
    wire        plr1_en;
    wire        plr1_clr;
    wire [31:0] D_instr, D_PC, D_PC_P4;

    plr1_if_id PLR1 (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (plr1_en),
        .clr       (plr1_clr),
        .in_instr  (F_instr),
        .in_pc     (F_PC),
        .in_pc_p4  (F_PC_P4),
        .out_instr (D_instr),
        .out_pc    (D_PC),
        .out_pc_p4 (D_PC_P4)
    );

    // --------------------------
    // ID stage: decode + regfile + imm
    // --------------------------
    wire [6:0] D_opcode = D_instr[6:0];
    wire [2:0] D_funct3 = D_instr[14:12];
    wire [6:0] D_funct7 = D_instr[31:25];

    wire [4:0] D_rs1 = D_instr[19:15];
    wire [4:0] D_rs2 = D_instr[24:20];
    wire [4:0] D_rd  = D_instr[11:7];

    wire [31:0] D_imm;
    imm_gen IMM0 (
        .instr (D_instr),
        .imm   (D_imm)
    );

    // WB stage writeback wires (from PLR4)
    wire        W_we_rf;
    wire [4:0]  W_rd;
    wire [31:0] W_result;

    wire [31:0] D_rf_rd1, D_rf_rd2;

    // Register file (negedge write)
    your_reg_file_module RF (
        .clk  (clk),
        .rst_n(rst_n),
        .ra1  (D_rs1),
        .ra2  (D_rs2),
        .wa   (W_rd),
        .wd   (W_result),
        .we   (W_we_rf),
        .rd1  (D_rf_rd1),
        .rd2  (D_rf_rd2)
    );

    // Controller
    wire        D_we_rf, D_we_dm, D_branch, D_jump;
    wire [1:0]  D_sel_result;
    wire        D_sel_alu_src_b;
    wire [3:0]  D_alu_control;

    controller CTRL0 (
        .opcode        (D_opcode),
        .funct3        (D_funct3),
        .funct7        (D_funct7),
        .we_rf         (D_we_rf),
        .we_dm         (D_we_dm),
        .branch        (D_branch),
        .jump          (D_jump),
        .sel_result    (D_sel_result),
        .sel_alu_src_b (D_sel_alu_src_b),
        .alu_control   (D_alu_control)
    );

    // --------------------------
    // PLR2: ID/EX
    // --------------------------
    wire        plr2_clr;

    wire [31:0] E_PC, E_PC_P4, E_imm;
    wire [31:0] E_rf_rd1, E_rf_rd2;
    wire [4:0]  E_rs1, E_rs2, E_rd;
    wire [2:0]  E_funct3;
    wire [6:0]  E_opcode;

    wire        E_we_rf, E_we_dm, E_branch, E_jump;
    wire [1:0]  E_sel_result;
    wire        E_sel_alu_src_b;
    wire [3:0]  E_alu_control;

    plr2_id_ex PLR2 (
        .clk   (clk),
        .rst_n (rst_n),
        .clr   (plr2_clr),

        .in_pc     (D_PC),
        .in_pc_p4  (D_PC_P4),
        .in_imm    (D_imm),
        .in_rd1    (D_rf_rd1),
        .in_rd2    (D_rf_rd2),
        .in_rs1    (D_rs1),
        .in_rs2    (D_rs2),
        .in_rd     (D_rd),
        .in_funct3 (D_funct3),
        .in_opcode (D_opcode),

        .in_we_rf        (D_we_rf),
        .in_we_dm        (D_we_dm),
        .in_branch       (D_branch),
        .in_jump         (D_jump),
        .in_sel_result   (D_sel_result),
        .in_sel_alu_src_b(D_sel_alu_src_b),
        .in_alu_control  (D_alu_control),

        .out_pc     (E_PC),
        .out_pc_p4  (E_PC_P4),
        .out_imm    (E_imm),
        .out_rd1    (E_rf_rd1),
        .out_rd2    (E_rf_rd2),
        .out_rs1    (E_rs1),
        .out_rs2    (E_rs2),
        .out_rd     (E_rd),
        .out_funct3 (E_funct3),
        .out_opcode (E_opcode),

        .out_we_rf        (E_we_rf),
        .out_we_dm        (E_we_dm),
        .out_branch       (E_branch),
        .out_jump         (E_jump),
        .out_sel_result   (E_sel_result),
        .out_sel_alu_src_b(E_sel_alu_src_b),
        .out_alu_control  (E_alu_control)
    );

    // --------------------------
    // EX stage: forwarding + ALU + branch/jump decision
    // --------------------------
    // From later stages
    wire        M_we_rf;
    wire [4:0]  M_rd;
    wire [31:0] M_alu_o;
    wire [1:0]  M_sel_result;
    wire [31:0] M_dm_rd;

    // MUST declare these before using them in M_wb_value
    wire [31:0] M_PC_P4;
    wire [31:0] M_imm_u;

    // What MA-stage instruction would write (for forwarding)
    wire [31:0] M_wb_value;
    assign M_wb_value = (M_sel_result == 2'b00) ? M_alu_o  :
                        (M_sel_result == 2'b10) ? M_PC_P4  :
                        (M_sel_result == 2'b11) ? M_imm_u  :
                                                  M_dm_rd; // load

    // Forwarding selects
    wire [1:0] E_fwd_a, E_fwd_b, E_fwd_store;

    wire [31:0] E_op_a_pre = E_rf_rd1;
    wire [31:0] E_op_b_pre = E_rf_rd2;

    wire [31:0] E_op_a_fwd = (E_fwd_a == 2'b10) ? M_wb_value :
                             (E_fwd_a == 2'b01) ? W_result   :
                                                  E_op_a_pre;

    wire [31:0] E_op_b_fwd = (E_fwd_b == 2'b10) ? M_wb_value :
                             (E_fwd_b == 2'b01) ? W_result   :
                                                  E_op_b_pre;

    // Store data forwarding (rs2 value)
    wire [31:0] E_store_wd = (E_fwd_store == 2'b10) ? M_wb_value :
                             (E_fwd_store == 2'b01) ? W_result   :
                                                      E_rf_rd2;

    // ALU operand B
    wire [31:0] E_alu_in_b = E_sel_alu_src_b ? E_imm : E_op_b_fwd;

    wire [31:0] E_alu_o;
    wire        E_zero;

    alu ALU0 (
        .a        (E_op_a_fwd),
        .b        (E_alu_in_b),
        .alu_ctrl (E_alu_control),
        .y        (E_alu_o),
        .zero     (E_zero)
    );

    // Branch/jump target and decision
    assign E_target_PC   = E_PC + E_imm;
    wire E_take_branch   = E_branch && E_zero; // beq
    wire E_take_jal      = E_jump;
    assign E_take_ctrl   = E_take_branch || E_take_jal;

    // --------------------------
    // PLR3: EX/MA
    // --------------------------
    wire        M_we_dm;
    wire [31:0] M_dm_wd;

    plr3_ex_ma PLR3 (
        .clk   (clk),
        .rst_n (rst_n),

        .in_we_rf      (E_we_rf),
        .in_we_dm      (E_we_dm),
        .in_sel_result (E_sel_result),

        .in_rd     (E_rd),
        .in_alu_o  (E_alu_o),
        .in_dm_wd  (E_store_wd),
        .in_pc_p4  (E_PC_P4),
        .in_imm_u  (E_imm),     // for LUI, imm_gen produces U-imm

        .out_we_rf      (M_we_rf),
        .out_we_dm      (M_we_dm),
        .out_sel_result (M_sel_result),

        .out_rd     (M_rd),
        .out_alu_o  (M_alu_o),
        .out_dm_wd  (M_dm_wd),
        .out_pc_p4  (M_PC_P4),
        .out_imm_u  (M_imm_u)
    );

    // --------------------------
    // MA stage: data memory access
    // --------------------------
    data_mem DMEM (
        .clk  (clk),
        .we   (M_we_dm),
        .addr (M_alu_o),
        .wd   (M_dm_wd),
        .rd   (M_dm_rd)
    );

    // --------------------------
    // PLR4: MA/WB
    // --------------------------
    wire [1:0]  W_sel_result;
    wire [31:0] W_alu_o, W_dm_rd, W_PC_P4, W_imm_u;

    plr4_ma_wb PLR4 (
        .clk   (clk),
        .rst_n (rst_n),

        .in_we_rf      (M_we_rf),
        .in_sel_result (M_sel_result),
        .in_rd         (M_rd),

        .in_alu_o  (M_alu_o),
        .in_dm_rd  (M_dm_rd),
        .in_pc_p4  (M_PC_P4),
        .in_imm_u  (M_imm_u),

        .out_we_rf      (W_we_rf),
        .out_sel_result (W_sel_result),
        .out_rd         (W_rd),

        .out_alu_o  (W_alu_o),
        .out_dm_rd  (W_dm_rd),
        .out_pc_p4  (W_PC_P4),
        .out_imm_u  (W_imm_u)
    );

    // WB mux
    assign W_result = (W_sel_result == 2'b00) ? W_alu_o :
                      (W_sel_result == 2'b01) ? W_dm_rd :
                      (W_sel_result == 2'b10) ? W_PC_P4 :
                                                W_imm_u;

    // --------------------------
    // Hazard unit
    // --------------------------
    wire stall_lw;

    hazard_unit HZ0 (
        .D_rs1      (D_rs1),
        .D_rs2      (D_rs2),

        .E_rs1      (E_rs1),
        .E_rs2      (E_rs2),
        .E_rd       (E_rd),
        .E_opcode   (E_opcode),
        .E_take_ctrl(E_take_ctrl),

        .M_rd       (M_rd),
        .M_we_rf    (M_we_rf),
        .M_is_lw    (M_sel_result == 2'b01),

        .W_rd       (W_rd),
        .W_we_rf    (W_we_rf),

        .E_fwd_a    (E_fwd_a),
        .E_fwd_b    (E_fwd_b),
        .E_fwd_store(E_fwd_store),

        .stall_lw   (stall_lw),
        .pc_en      (pc_en),
        .plr1_en    (plr1_en),
        .plr2_clr   (plr2_clr),
        .plr1_clr   (plr1_clr)
    );

endmodule

// ============================================================
// PC register with synchronous active-low reset and enable
// ============================================================
module pc_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire [31:0] d,
    output reg  [31:0] q
);
    always @(posedge clk) begin
        if (!rst_n) q <= 32'd0;
        else if (en) q <= d;
    end
endmodule

// ============================================================
// PLR1 IF/ID with EN (stall) and CLR (flush)
// ============================================================
module plr1_if_id (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire        clr,
    input  wire [31:0] in_instr,
    input  wire [31:0] in_pc,
    input  wire [31:0] in_pc_p4,
    output reg  [31:0] out_instr,
    output reg  [31:0] out_pc,
    output reg  [31:0] out_pc_p4
);
    localparam [31:0] NOP = 32'h00000013; // addi x0,x0,0

    always @(posedge clk) begin
        if (!rst_n) begin
            out_instr <= NOP;
            out_pc    <= 32'd0;
            out_pc_p4 <= 32'd0;
        end else if (clr) begin
            out_instr <= NOP;
            out_pc    <= 32'd0;
            out_pc_p4 <= 32'd0;
        end else if (en) begin
            out_instr <= in_instr;
            out_pc    <= in_pc;
            out_pc_p4 <= in_pc_p4;
        end
    end
endmodule

// ============================================================
// PLR2 ID/EX with CLR (bubble/flush)
// ============================================================
module plr2_id_ex (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        clr,

    input  wire [31:0] in_pc,
    input  wire [31:0] in_pc_p4,
    input  wire [31:0] in_imm,
    input  wire [31:0] in_rd1,
    input  wire [31:0] in_rd2,
    input  wire [4:0]  in_rs1,
    input  wire [4:0]  in_rs2,
    input  wire [4:0]  in_rd,
    input  wire [2:0]  in_funct3,
    input  wire [6:0]  in_opcode,

    input  wire        in_we_rf,
    input  wire        in_we_dm,
    input  wire        in_branch,
    input  wire        in_jump,
    input  wire [1:0]  in_sel_result,
    input  wire        in_sel_alu_src_b,
    input  wire [3:0]  in_alu_control,

    output reg  [31:0] out_pc,
    output reg  [31:0] out_pc_p4,
    output reg  [31:0] out_imm,
    output reg  [31:0] out_rd1,
    output reg  [31:0] out_rd2,
    output reg  [4:0]  out_rs1,
    output reg  [4:0]  out_rs2,
    output reg  [4:0]  out_rd,
    output reg  [2:0]  out_funct3,
    output reg  [6:0]  out_opcode,

    output reg         out_we_rf,
    output reg         out_we_dm,
    output reg         out_branch,
    output reg         out_jump,
    output reg  [1:0]  out_sel_result,
    output reg         out_sel_alu_src_b,
    output reg  [3:0]  out_alu_control
);
    always @(posedge clk) begin
        if (!rst_n) begin
            out_pc <= 32'd0; out_pc_p4 <= 32'd0; out_imm <= 32'd0;
            out_rd1 <= 32'd0; out_rd2 <= 32'd0;
            out_rs1 <= 5'd0; out_rs2 <= 5'd0; out_rd <= 5'd0;
            out_funct3 <= 3'd0; out_opcode <= 7'd0;

            out_we_rf <= 1'b0; out_we_dm <= 1'b0;
            out_branch <= 1'b0; out_jump <= 1'b0;
            out_sel_result <= 2'b00; out_sel_alu_src_b <= 1'b0;
            out_alu_control <= 4'd0;
        end else if (clr) begin
            out_pc <= 32'd0; out_pc_p4 <= 32'd0; out_imm <= 32'd0;
            out_rd1 <= 32'd0; out_rd2 <= 32'd0;
            out_rs1 <= 5'd0; out_rs2 <= 5'd0; out_rd <= 5'd0;
            out_funct3 <= 3'd0; out_opcode <= 7'd0;

            out_we_rf <= 1'b0; out_we_dm <= 1'b0;
            out_branch <= 1'b0; out_jump <= 1'b0;
            out_sel_result <= 2'b00; out_sel_alu_src_b <= 1'b0;
            out_alu_control <= 4'd0;
        end else begin
            out_pc <= in_pc; out_pc_p4 <= in_pc_p4; out_imm <= in_imm;
            out_rd1 <= in_rd1; out_rd2 <= in_rd2;
            out_rs1 <= in_rs1; out_rs2 <= in_rs2; out_rd <= in_rd;
            out_funct3 <= in_funct3; out_opcode <= in_opcode;

            out_we_rf <= in_we_rf; out_we_dm <= in_we_dm;
            out_branch <= in_branch; out_jump <= in_jump;
            out_sel_result <= in_sel_result; out_sel_alu_src_b <= in_sel_alu_src_b;
            out_alu_control <= in_alu_control;
        end
    end
endmodule

// ============================================================
// PLR3 EX/MA
// ============================================================
module plr3_ex_ma (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_we_rf,
    input  wire        in_we_dm,
    input  wire [1:0]  in_sel_result,

    input  wire [4:0]  in_rd,
    input  wire [31:0] in_alu_o,
    input  wire [31:0] in_dm_wd,
    input  wire [31:0] in_pc_p4,
    input  wire [31:0] in_imm_u,

    output reg         out_we_rf,
    output reg         out_we_dm,
    output reg  [1:0]  out_sel_result,

    output reg  [4:0]  out_rd,
    output reg  [31:0] out_alu_o,
    output reg  [31:0] out_dm_wd,
    output reg  [31:0] out_pc_p4,
    output reg  [31:0] out_imm_u
);
    always @(posedge clk) begin
        if (!rst_n) begin
            out_we_rf <= 1'b0; out_we_dm <= 1'b0; out_sel_result <= 2'b00;
            out_rd <= 5'd0; out_alu_o <= 32'd0; out_dm_wd <= 32'd0;
            out_pc_p4 <= 32'd0; out_imm_u <= 32'd0;
        end else begin
            out_we_rf <= in_we_rf; out_we_dm <= in_we_dm; out_sel_result <= in_sel_result;
            out_rd <= in_rd; out_alu_o <= in_alu_o; out_dm_wd <= in_dm_wd;
            out_pc_p4 <= in_pc_p4; out_imm_u <= in_imm_u;
        end
    end
endmodule

// ============================================================
// PLR4 MA/WB
// ============================================================
module plr4_ma_wb (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_we_rf,
    input  wire [1:0]  in_sel_result,
    input  wire [4:0]  in_rd,

    input  wire [31:0] in_alu_o,
    input  wire [31:0] in_dm_rd,
    input  wire [31:0] in_pc_p4,
    input  wire [31:0] in_imm_u,

    output reg         out_we_rf,
    output reg  [1:0]  out_sel_result,
    output reg  [4:0]  out_rd,

    output reg  [31:0] out_alu_o,
    output reg  [31:0] out_dm_rd,
    output reg  [31:0] out_pc_p4,
    output reg  [31:0] out_imm_u
);
    always @(posedge clk) begin
        if (!rst_n) begin
            out_we_rf <= 1'b0; out_sel_result <= 2'b00; out_rd <= 5'd0;
            out_alu_o <= 32'd0; out_dm_rd <= 32'd0; out_pc_p4 <= 32'd0; out_imm_u <= 32'd0;
        end else begin
            out_we_rf <= in_we_rf; out_sel_result <= in_sel_result; out_rd <= in_rd;
            out_alu_o <= in_alu_o; out_dm_rd <= in_dm_rd; out_pc_p4 <= in_pc_p4; out_imm_u <= in_imm_u;
        end
    end
endmodule

// ============================================================
// Register File: 2R1W, async read, negedge write
// ============================================================
module your_reg_file_module (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [4:0]  ra1,
    input  wire [4:0]  ra2,
    input  wire [4:0]  wa,
    input  wire [31:0] wd,
    input  wire        we,

    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] R[0:31];
    integer i;

    assign rd1 = (ra1 == 5'd0) ? 32'd0 : R[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : R[ra2];

    always @(negedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) R[i] <= 32'd0;
        end else begin
            if (we && (wa != 5'd0)) R[wa] <= wd;
            R[0] <= 32'd0;
        end
    end
endmodule

// ============================================================
// ALU
// ============================================================
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] y,
    output wire        zero
);
    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_XOR  = 4'd2;
    localparam ALU_OR   = 4'd3;
    localparam ALU_AND  = 4'd4;
    localparam ALU_SLL  = 4'd5;
    localparam ALU_SRL  = 4'd6;
    localparam ALU_SRA  = 4'd7;
    localparam ALU_SLT  = 4'd8;
    localparam ALU_SLTU = 4'd9;

    wire [4:0] shamt = b[4:0];

    always @(*) begin
        case (alu_ctrl)
            ALU_ADD:  y = a + b;
            ALU_SUB:  y = a - b;
            ALU_XOR:  y = a ^ b;
            ALU_OR:   y = a | b;
            ALU_AND:  y = a & b;
            ALU_SLL:  y = a << shamt;
            ALU_SRL:  y = a >> shamt;
            ALU_SRA:  y = $signed(a) >>> shamt;
            ALU_SLT:  y = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: y = (a < b) ? 32'd1 : 32'd0;
            default:  y = 32'd0;
        endcase
    end

    assign zero = (y == 32'd0);
endmodule

// ============================================================
// Immediate Generator (I, S, B, J, U)
// ============================================================
module imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm
);
    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            7'b0010011, // I-type ALU
            7'b0000011: // lw
                imm = {{20{instr[31]}}, instr[31:20]};

            7'b0100011: // sw
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            7'b1100011: // beq
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

            7'b1101111: // jal
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

            7'b0110111: // lui
                imm = {instr[31:12], 12'b0};

            default:
                imm = 32'd0;
        endcase
    end
endmodule

// ============================================================
// Controller
// sel_result: 00 ALU, 01 DMEM, 10 PC+4 (jal), 11 IMM(U) (lui)
// ============================================================
module controller (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        we_rf,
    output reg        we_dm,
    output reg        branch,
    output reg        jump,
    output reg [1:0]  sel_result,
    output reg        sel_alu_src_b,
    output reg [3:0]  alu_control
);
    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_XOR  = 4'd2;
    localparam ALU_OR   = 4'd3;
    localparam ALU_AND  = 4'd4;
    localparam ALU_SLL  = 4'd5;
    localparam ALU_SRL  = 4'd6;
    localparam ALU_SRA  = 4'd7;
    localparam ALU_SLT  = 4'd8;
    localparam ALU_SLTU = 4'd9;

    always @(*) begin
        // defaults
        we_rf = 1'b0;
        we_dm = 1'b0;
        branch = 1'b0;
        jump = 1'b0;
        sel_result = 2'b00;
        sel_alu_src_b = 1'b0;
        alu_control = ALU_ADD;

        case (opcode)
            7'b0110011: begin // R-type
                we_rf = 1'b1;
                sel_result = 2'b00;
                sel_alu_src_b = 1'b0;
                case (funct3)
                    3'b000: alu_control = (funct7[5] ? ALU_SUB : ALU_ADD);
                    3'b100: alu_control = ALU_XOR;
                    3'b110: alu_control = ALU_OR;
                    3'b111: alu_control = ALU_AND;
                    3'b001: alu_control = ALU_SLL;
                    3'b101: alu_control = (funct7[5] ? ALU_SRA : ALU_SRL);
                    3'b010: alu_control = ALU_SLT;
                    3'b011: alu_control = ALU_SLTU;
                    default: alu_control = ALU_ADD;
                endcase
            end

            7'b0010011: begin // I-type ALU
                we_rf = 1'b1;
                sel_result = 2'b00;
                sel_alu_src_b = 1'b1;
                case (funct3)
                    3'b000: alu_control = ALU_ADD;  // addi
                    3'b100: alu_control = ALU_XOR;  // xori
                    3'b110: alu_control = ALU_OR;   // ori
                    3'b111: alu_control = ALU_AND;  // andi
                    3'b001: alu_control = ALU_SLL;  // slli
                    3'b101: alu_control = (funct7[5] ? ALU_SRA : ALU_SRL); // srai/srli
                    3'b010: alu_control = ALU_SLT;  // slti
                    3'b011: alu_control = ALU_SLTU; // sltiu
                    default: alu_control = ALU_ADD;
                endcase
            end

            7'b0000011: begin // lw
                we_rf = 1'b1;
                sel_result = 2'b01;
                sel_alu_src_b = 1'b1;
                alu_control = ALU_ADD;
            end

            7'b0100011: begin // sw
                we_dm = 1'b1;
                sel_alu_src_b = 1'b1;
                alu_control = ALU_ADD;
            end

            7'b1100011: begin // beq
                branch = 1'b1;
                alu_control = ALU_SUB;
            end

            7'b1101111: begin // jal
                we_rf = 1'b1;
                jump  = 1'b1;
                sel_result = 2'b10; // PC+4
            end

            7'b0110111: begin // lui
                we_rf = 1'b1;
                sel_result = 2'b11; // U-imm
            end
        endcase
    end
endmodule

// ============================================================
// Hazard Unit
// - Forwarding to EX operands and store data
// - LW-use stall: stall PC+PLR1, bubble PLR2
// - Control flush: on taken branch/jal in EX, flush PLR1 and bubble PLR2
// ============================================================
module hazard_unit (
    input  wire [4:0] D_rs1,
    input  wire [4:0] D_rs2,

    input  wire [4:0] E_rs1,
    input  wire [4:0] E_rs2,
    input  wire [4:0] E_rd,
    input  wire [6:0] E_opcode,
    input  wire       E_take_ctrl,

    input  wire [4:0] M_rd,
    input  wire       M_we_rf,
    input  wire       M_is_lw,

    input  wire [4:0] W_rd,
    input  wire       W_we_rf,

    output reg  [1:0] E_fwd_a,
    output reg  [1:0] E_fwd_b,
    output reg  [1:0] E_fwd_store,

    output wire       stall_lw,
    output wire       pc_en,
    output wire       plr1_en,
    output wire       plr2_clr,
    output wire       plr1_clr
);
    wire E_is_lw = (E_opcode == 7'b0000011);

    always @(*) begin
        E_fwd_a     = 2'b00;
        E_fwd_b     = 2'b00;
        E_fwd_store = 2'b00;

        // rs1
        if (M_we_rf && !M_is_lw && (M_rd != 5'd0) && (M_rd == E_rs1)) E_fwd_a = 2'b10;
        else if (W_we_rf && (W_rd != 5'd0) && (W_rd == E_rs1))       E_fwd_a = 2'b01;

        // rs2
        if (M_we_rf && !M_is_lw && (M_rd != 5'd0) && (M_rd == E_rs2)) E_fwd_b = 2'b10;
        else if (W_we_rf && (W_rd != 5'd0) && (W_rd == E_rs2))       E_fwd_b = 2'b01;

        // store data uses rs2
        if (M_we_rf && !M_is_lw && (M_rd != 5'd0) && (M_rd == E_rs2)) E_fwd_store = 2'b10;
        else if (W_we_rf && (W_rd != 5'd0) && (W_rd == E_rs2))       E_fwd_store = 2'b01;
    end

    assign stall_lw = E_is_lw && (E_rd != 5'd0) &&
                      ((E_rd == D_rs1) || (E_rd == D_rs2));

    assign pc_en   = !stall_lw;
    assign plr1_en = !stall_lw;

    assign plr2_clr = stall_lw || E_take_ctrl;
    assign plr1_clr = E_take_ctrl;
endmodule

module instruction_mem #(
    parameter integer MEM_DEPTH = 1024
) (
    input  wire [31:0] addr,
    output wire [31:0] rd
);
    function integer clog2;
        input integer value;
        integer i;
        begin
            clog2 = 0;
            for (i = value - 1; i > 0; i = i >> 1)
                clog2 = clog2 + 1;
        end
    endfunction

    reg [31:0] RAM [0:MEM_DEPTH-1];

    localparam integer ADDR_BITS = clog2(MEM_DEPTH);
    wire [31:0] word_addr = addr >> 2;
    wire [ADDR_BITS-1:0] idx = word_addr[ADDR_BITS-1:0];

    assign rd = RAM[idx];
endmodule


module data_mem #(
    parameter integer MEM_DEPTH = 1024
) (
    input  wire        clk,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wd,
    output wire [31:0] rd
);
    function integer clog2;
        input integer value;
        integer i;
        begin
            clog2 = 0;
            for (i = value - 1; i > 0; i = i >> 1)
                clog2 = clog2 + 1;
        end
    endfunction

    reg [31:0] RAM [0:MEM_DEPTH-1];

    localparam integer ADDR_BITS = clog2(MEM_DEPTH);
    wire [31:0] word_addr = addr >> 2;
    wire [ADDR_BITS-1:0] idx = word_addr[ADDR_BITS-1:0];

    assign rd = RAM[idx];

    always @(posedge clk) begin
        if (we) RAM[idx] <= wd;
    end
endmodule


`include "alu_decoder.v"
`include "alu.v"
`include "controller.v"
`include "mem.v"
`include "regfile.v"
`include "sign_extender.v"

module rv_mc (
    input clk,
    input rst
);

    // -------------------------------------------------
    // REGISTERS
    // -------------------------------------------------
    reg [31:0] pc;
    reg [31:0] instr;
    reg [31:0] alu_reg;
    reg [31:0] data_reg;
    reg [31:0] rd1_reg;
    reg [31:0] rd2_reg;

    // -------------------------------------------------
    // WIRES
    // -------------------------------------------------
    wire [31:0] mem_out;
    wire [31:0] alu_out;
    wire        zero;

    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    // CONTROL SIGNALS
    wire        sel_mem_addr;
    wire        ir_we;
    wire        pc_update;
    wire        mem_we;
    wire        rf_we;
    wire        sel_alu_src_a;
    wire [1:0]  sel_alu_src_b;
    wire [1:0]  alu_op;
    wire [1:0]  sel_result;

    // ALU control
    wire [3:0] alu_ctrl;

    // ALU inputs
    wire [31:0] alu_a;
    wire [31:0] alu_b;

    // WRITEBACK DATA
    wire [31:0] wb_data;

    // -------------------------------------------------
    // PC REGISTER
    // -------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'b0;
        else if (pc_update)
            pc <= alu_out;
    end

    // -------------------------------------------------
    // MEMORY (REQUIRED INSTANCE NAME)
    // -------------------------------------------------
    mem MEM (
        .clk(clk),
        .we(mem_we),
        .addr(sel_mem_addr ? alu_reg : pc),
        .wd(rd2_reg),
        .rd(mem_out)
    );

    // -------------------------------------------------
    // INSTRUCTION REGISTER
    // -------------------------------------------------
    always @(posedge clk) begin
        if (ir_we)
            instr <= mem_out;
    end

    // -------------------------------------------------
    // DATA REGISTER (for loads)
    // -------------------------------------------------
    always @(posedge clk) begin
        data_reg <= mem_out;
    end

    // -------------------------------------------------
    // REGISTER FILE
    // -------------------------------------------------
    wire [31:0] rd1, rd2;

    regfile RF (
        .clk(clk),
        .we(rf_we),
        .rs1(instr[19:15]),
        .rs2(instr[24:20]),
        .rd(instr[11:7]),
        .wd(wb_data),
        .rd1(rd1),
        .rd2(rd2)
    );

    // Latch register operands
    always @(posedge clk) begin
        rd1_reg <= rd1;
        rd2_reg <= rd2;
    end

    // -------------------------------------------------
    // SIGN EXTENDER
    // -------------------------------------------------
    sign_extender SE (
        .instr(instr),
        .imm_i(imm_i),
        .imm_s(imm_s),
        .imm_b(imm_b),
        .imm_u(imm_u),
        .imm_j(imm_j)
    );

    // -------------------------------------------------
    // ALU INPUT MUXES
    // -------------------------------------------------
    assign alu_a = sel_alu_src_a ? rd1_reg : pc;

    assign alu_b = (sel_alu_src_b == 2'b00) ? rd2_reg :
                   (sel_alu_src_b == 2'b01) ? imm_i :
                                               32'd4;

    // -------------------------------------------------
    // ALU
    // -------------------------------------------------
    alu ALU (
        .a(alu_a),
        .b(alu_b),
        .alu_ctrl(alu_ctrl),
        .result(alu_out),
        .zero(zero)
    );

    // Latch ALU result
    always @(posedge clk) begin
        alu_reg <= alu_out;
    end

    // -------------------------------------------------
    // ALU DECODER
    // -------------------------------------------------
    alu_decoder ALU_DEC (
        .alu_op(alu_op),
        .funct3(instr[14:12]),
        .funct7b5(instr[30]),
        .alu_ctrl(alu_ctrl)
    );

    // -------------------------------------------------
    // WRITEBACK MUX
    // -------------------------------------------------
    assign wb_data =
        (sel_result == 2'b00) ? alu_reg  :
        (sel_result == 2'b01) ? data_reg :
        (sel_result == 2'b10) ? pc + 4    :
                                imm_u;

    // -------------------------------------------------
    // CONTROLLER (FSM)
    // -------------------------------------------------
    controller CTRL (
        .clk(clk),
        .rst(rst),
        .opcode(instr[6:0]),
        .sel_mem_addr(sel_mem_addr),
        .ir_we(ir_we),
        .pc_update(pc_update),
        .mem_we(mem_we),
        .rf_we(rf_we),
        .sel_alu_src_a(sel_alu_src_a),
        .sel_alu_src_b(sel_alu_src_b),
        .alu_op(alu_op),
        .sel_result(sel_result)
    );

endmodule

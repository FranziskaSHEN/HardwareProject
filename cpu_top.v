`include "alu.v"
`include "controller.v"
`include "pc.v"
`include "imem.v"
`include "regfile.v"
`include "dmem.v"
`include "sign_ext.v"
`include "adder.v"
`include "mux2.v"   

module cpu_top (
    input wire clk,
    input wire reset
);

    wire [31:0] pc, next_pc, pc_plus_4, pc_branch, pc_jump;

    wire [31:0] instr;


    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    wire        rf_we, sel_alu_src_b, dmem_we;
    wire [2:0]  imm_sel;
    wire [1:0]  sel_result;
    wire [1:0]  alu_op;
    wire [3:0]  alu_control;
    wire        branch, jump;

    wire [31:0] rd1, rd2;
    wire [31:0] imm;
    wire [31:0] alu_b_src;
    wire [31:0] alu_y;
    wire        alu_zero;
    wire [31:0] dmem_rd;
    wire [31:0] result;
    wire        take_branch;
    wire [31:0] pc_target;


    pc u_pc (
        .clk(clk),
        .reset(reset),
        .next_pc(next_pc),
        .pc(pc)
    );


    adder u_pc_adder (
        .a(pc),
        .b(32'd4),
        .y(pc_plus_4)
    );


    imem u_imem (
        .addr(pc),
        .instr(instr)
    );


    controller u_controller (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rf_we(rf_we),
        .imm_sel(imm_sel),
        .sel_alu_src_b(sel_alu_src_b),
        .dmem_we(dmem_we),
        .sel_result(sel_result),
        .alu_control(alu_control),
        .branch(branch),
        .jump(jump)
    );


    regfile u_regfile (
        .clk(clk),
        .we(rf_we),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .wd(result),
        .rd1(rd1),
        .rd2(rd2)
    );

    sign_ext u_sign_ext (
        .instr(instr),
        .imm_sel(imm_sel),
        .imm(imm)
    );


    mux2 #(32) u_alu_src_mux (
        .a(rd2),
        .b(imm),
        .sel(sel_alu_src_b),
        .y(alu_b_src)
    );


    alu u_alu (
        .a(rd1),
        .b(alu_b_src),
        .alu_control(alu_control),
        .y(alu_y),
        .zero(alu_zero)
    );


    dmem u_dmem (
        .clk(clk),
        .we(dmem_we),
        .addr(alu_y),
        .wd(rd2),       
        .rd(dmem_rd)
    );


    wire [31:0] sel_res0 = (sel_result == 2'b00) ? alu_y   :
                           (sel_result == 2'b01) ? dmem_rd : 32'b0;

    wire [31:0] sel_res1 = (sel_result == 2'b10) ? pc_plus_4 :
                           (sel_result == 2'b11) ? imm       : 32'b0;

    assign result = (sel_result[1] == 1'b0) ? sel_res0 : sel_res1;


    adder u_branch_adder (
        .a(pc),
        .b(imm),
        .y(pc_target)
    );

    assign take_branch = branch && alu_zero;


    assign next_pc = jump        ? pc_target :
                     take_branch ? pc_target :
                                   pc_plus_4;

endmodule

`include "rv-pl.v"
`timescale 1ns/1ps

module tb_rv_pl;

    // ------------------------------------------------------------
    // Testbench Signals
    // ------------------------------------------------------------
    reg clk;
    reg rst_n;
    integer i;

    // ------------------------------------------------------------
    // Instantiate the Core
    // ------------------------------------------------------------
    rv_pl dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    // ------------------------------------------------------------
    // Clock Generation (100MHz)
    // ------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Memory Initialization & Main Test
    // ------------------------------------------------------------
    initial begin
        // 1. Waveform setup
        $dumpfile("rv_pl.vcd");
        $dumpvars(0, tb_rv_pl);

        // 2. Clear Instruction & Data Memory first (safeguard)
        for (i = 0; i < 1024; i = i + 1) begin
            dut.IMEM.RAM[i] = 32'd0;
            dut.DMEM.RAM[i] = 32'd0;
        end

        // 3. LOAD HEX FILE
        // This looks for "program.hex" in the current directory.
        // It loads data into the simulation hierarchy instance of the RAM.
        $readmemh("test.hex", dut.IMEM.RAM);

        // --------------------------------------------------------
        // 4. Run Simulation
        // --------------------------------------------------------
        $display("-------------------------------------------------------------");
        $display(" Loading test.hex...");
        $display("-------------------------------------------------------------");
        $display(" Time | PC (F) | Decode Instr | Ex Op | WB Reg | WB Val | Note ");
        $display("-------------------------------------------------------------");

        rst_n = 0;
        #20;
        rst_n = 1;

        // Run simulation for enough cycles
        #200; 

        // --------------------------------------------------------
        // 5. Final Report
        // --------------------------------------------------------
        $display("-------------------------------------------------------------");
        $display("Final Register State:");
        $display("x1 (10):   %d", dut.RF.R[1]);
        $display("x2 (20):   %d", dut.RF.R[2]);
        $display("x3 (30):   %d", dut.RF.R[3]);
        $display("x4 (30):   %d", dut.RF.R[4]);
        $display("x5 (40):   %d", dut.RF.R[5]);
        $display("x6 (0?):   %d (Should be 0 if branch skipped)", dut.RF.R[6]);
        $display("x7 (1):    %d", dut.RF.R[7]);
        $display("-------------------------------------------------------------");
        $finish;
    end

    // ------------------------------------------------------------
    // Monitoring Logic
    // ------------------------------------------------------------
    always @(negedge clk) begin
        if (rst_n) begin
            $write("%4d | %4h   |  %h    | ", $time, dut.F_PC, dut.D_instr);
            
            // Minimal EX stage info
            if (dut.E_take_ctrl) $write("BR/JMP");
            else if (dut.stall_lw) $write("STALL ");
            else $write("      ");

            $write(" | ");

            // Writeback info
            if (dut.W_we_rf && dut.W_rd != 0) begin
                $write("x%02d    | %4h", dut.W_rd, dut.W_result);
            end else begin
                $write(" --     |  -- ");
            end

            $write("\n");
        end
    end

endmodule
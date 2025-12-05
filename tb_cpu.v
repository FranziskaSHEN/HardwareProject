`timescale 1ns/1ps
`include "cpu_top.v"

module tb_cpu;
    reg clk;
    reg reset;

    cpu_top dut (
        .clk(clk),
        .reset(reset)
    );

    // clock generation: 10ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // reset sequence
    initial begin
        reset = 1;
        #20;
        reset = 0;
    end

    // simulation control
    initial begin
        $dumpfile("cpu_wave.vcd");
        $dumpvars(0, tb_cpu);

        // run long enough to execute your program
        #2000;
        $finish;
    end

endmodule

`include "rv_mc.v"
module tb;

    reg clk;
    reg rst;

    rv_mc DUT (
        .clk(clk),
        .rst(rst)
    );

    // Clock generation: 10 time units period
    always #5 clk = ~clk;

    initial begin
        // -----------------------------
        // LOAD PROGRAM INTO MEMORY
        // -----------------------------
        $readmemh("program.hex", DUT.MEM.RAM);

        $display("RAM[0] = %h", DUT.MEM.RAM[0]);
        $display("RAM[1] = %h", DUT.MEM.RAM[1]);
        $display("RAM[2] = %h", DUT.MEM.RAM[2]);


        $dumpfile("wave.vcd");
        $dumpvars(0, tb);


        // -----------------------------
        // RESET SEQUENCE
        // -----------------------------
        clk = 0;
        rst = 1;

        #20;
        rst = 0;

        // -----------------------------
        // RUN SIMULATION
        // -----------------------------
        #500;

        $display("Simulation finished");
        $finish;
    end

endmodule

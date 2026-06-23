module tb_axi_master;

    logic clk;
    logic rst_n;

    logic [31:0] src_addr;
    logic [31:0] dst_addr;
    logic [31:0] length;

    logic start;
    logic done;

    axi_if mem_if();

    //----------------------------------
    // DUT
    //----------------------------------

    axi4_master dut (

        .clk(clk),
        .rst_n(rst_n),

        .src_addr(src_addr),
        .dst_addr(dst_addr),
        .length(length),

        .start(start),
        .done(done),

        .mem_if(mem_if)

    );

    //----------------------------------
    // Memory Model
    //----------------------------------

    axi_mem_model mem (

        .clk(clk),
        .rst_n(rst_n),

        .mem_if(mem_if)

    );

    //----------------------------------
    // Clock
    //----------------------------------

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //----------------------------------
    // Test
    //----------------------------------

    initial begin

        rst_n = 0;

        start = 0;

        src_addr = 32'h100;
        dst_addr = 32'h200;

        length = 4;

        #20;
        rst_n = 1;

        //----------------------------------
        // Source Data
        //----------------------------------

        mem.mem[64] = 32'hDEADBEEF;
        mem.mem[65] = 32'hAAAAAAAA;
        mem.mem[66] = 32'h12345678;
        mem.mem[67] = 32'hCAFEBABE;

        //----------------------------------
        // Start DMA
        //----------------------------------

        #20;

        start = 1;

        #10;

        start = 0;

        //----------------------------------
        // Wait for completion
        //----------------------------------

        wait(done);

        #20;

        //----------------------------------
        // Display Results
        //----------------------------------

        $display("SRC[64]  = %h", mem.mem[64]);
        $display("SRC[65]  = %h", mem.mem[65]);
        $display("SRC[66]  = %h", mem.mem[66]);
        $display("SRC[67]  = %h", mem.mem[67]);

        $display("--------------------------------");

        $display("DST[128] = %h", mem.mem[128]);
        $display("DST[129] = %h", mem.mem[129]);
        $display("DST[130] = %h", mem.mem[130]);
        $display("DST[131] = %h", mem.mem[131]);

        //----------------------------------
        // Check
        //----------------------------------

        if(mem.mem[128] == 32'hDEADBEEF &&
           mem.mem[129] == 32'hAAAAAAAA &&
           mem.mem[130] == 32'h12345678 &&
           mem.mem[131] == 32'hCAFEBABE)

            $display("PASS : 4 WORD DMA TRANSFER");

        else

            $display("FAIL : DATA MISMATCH");

        #20;
        $finish;

    end

    //----------------------------------
    // Waveforms
    //----------------------------------

    initial begin

        $dumpfile("axi_master.vcd");
        $dumpvars(0,tb_axi_master);

    end

endmodule

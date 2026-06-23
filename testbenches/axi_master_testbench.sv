module tb_axi_master;

    logic clk;
    logic rst_n;

    logic [31:0] src_addr;
    logic [31:0] dst_addr;
    logic [31:0] length;

    logic start;
    logic done;

    axi_if mem_if();

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

    axi_mem_model mem (

        .clk(clk),
        .rst_n(rst_n),

        .mem_if(mem_if)

    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin

        rst_n = 0;

        start = 0;

        src_addr = 32'h100;
        dst_addr = 32'h200;

        length = 1;

        #20;
        rst_n = 1;

        //----------------------------------
        // preload source memory
        //----------------------------------

        mem.mem[64] = 32'hDEADBEEF;

        //----------------------------------
        // start transfer
        //----------------------------------

        #20;
        start = 1;

        #10;
        start = 0;

        //----------------------------------
        // wait
        //----------------------------------

        repeat(50) @(posedge clk);

        $display("SRC DATA = %h", mem.mem[64]);
        $display("DST DATA = %h", mem.mem[128]);

        if(mem.mem[128] == 32'hDEADBEEF)
            $display("PASS");
        else
            $display("FAIL");

        $finish;

    end

endmodule
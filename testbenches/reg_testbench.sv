  // -----------REG TESTBENCH----------
  
 module tb_reg_file;

    logic clk;
    logic rst_n;

    logic        wr_en;
    logic [31:0] wr_addr;
    logic [31:0] wr_data;

    logic        rd_en;
    logic [31:0] rd_addr;
    logic [31:0] rd_data;

    logic [31:0] src_addr [4];
    logic [31:0] dst_addr [4];
    logic [31:0] length   [4];

    logic [3:0] enable;
    logic [3:0] start;

    logic [3:0] busy;
    logic [3:0] done;

    //----------------------------------
    // DUT
    //----------------------------------

    reg_file #(
        .NUM_CH(4)
    ) dut (

        .clk(clk),
        .rst_n(rst_n),

        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),

        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_data(rd_data),

        .src_addr(src_addr),
        .dst_addr(dst_addr),
        .length(length),

        .enable(enable),
        .start(start),

        .busy(busy),
        .done(done)

    );

    //----------------------------------
    // Clock
    //----------------------------------

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //----------------------------------
    // Stimulus
    //----------------------------------

    initial begin

        rst_n   = 0;

        wr_en   = 0;
        wr_addr = 0;
        wr_data = 0;

        rd_en   = 0;
        rd_addr = 0;

        busy    = 4'b0000;
        done    = 4'b0000;

        #20;
        rst_n = 1;

        //----------------------------------
        // Channel 0 Programming
        //----------------------------------

        wr_en   = 1;

        wr_addr = 32'h00;
        wr_data = 32'h1000;
        #10;

        wr_addr = 32'h04;
        wr_data = 32'h2000;
        #10;

        wr_addr = 32'h08;
        wr_data = 32'd128;
        #10;

        wr_addr = 32'h0C;
        wr_data = 32'h3;   // enable=1 start=1
        #10;

        wr_en = 0;

        //----------------------------------
        // Read Back
        //----------------------------------

        rd_en = 1;

        rd_addr = 32'h00;
        #10;
        $display("SRC_ADDR = %h",rd_data);

        rd_addr = 32'h04;
        #10;
        $display("DST_ADDR = %h",rd_data);

        rd_addr = 32'h08;
        #10;
        $display("LENGTH = %d",rd_data);

        rd_addr = 32'h0C;
        #10;
        $display("CTRL = %h",rd_data);

        //----------------------------------
        // Status Registers
        //----------------------------------

        busy = 4'b0101;
        done = 4'b0010;

        rd_addr = 32'h40;
        #10;
        $display("BUSY STATUS = %h",rd_data);

        rd_addr = 32'h44;
        #10;
        $display("DONE STATUS = %h",rd_data);

        rd_en = 0;

        #50;
        $finish;

    end

    //----------------------------------
    // Waveform
    //----------------------------------

    initial begin
        $dumpfile("reg_file.vcd");
        $dumpvars(0,tb_reg_file);
    end

endmodule
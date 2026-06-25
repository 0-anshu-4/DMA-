module tb_axi4_lite_slave;

    logic [31:0] wr_addr;
    logic [31:0] wr_data;
    logic        wr_en;

    logic [31:0] rd_addr;
    logic        rd_en;

    logic [31:0] rd_data;

    axil_if cfg_if();

    //----------------------------------
    // DUT
    //----------------------------------

    axi4_lite_slave dut (

        .cfg_if(cfg_if),

        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_en(wr_en),

        .rd_addr(rd_addr),
        .rd_en(rd_en),

        .rd_data(rd_data)

    );

    //----------------------------------
    // Stimulus
    //----------------------------------

    initial begin

        //----------------------------------
        // Initialize
        //----------------------------------

        cfg_if.awaddr  = 0;
        cfg_if.awvalid = 0;

        cfg_if.wdata   = 0;
        cfg_if.wvalid  = 0;

        cfg_if.bready  = 0;

        cfg_if.araddr  = 0;
        cfg_if.arvalid = 0;

        cfg_if.rready  = 0;

        rd_data = 32'h12345678;

        #10;

        //----------------------------------
        // WRITE TRANSACTION
        //----------------------------------

        $display("----------------------------");
        $display("WRITE TEST");
        $display("----------------------------");

        cfg_if.awaddr  = 32'h00;
        cfg_if.awvalid = 1;

        cfg_if.wdata   = 32'h1000;
        cfg_if.wvalid  = 1;

        #10;

        $display("WR_ADDR  = %h",wr_addr);
        $display("WR_DATA  = %h",wr_data);
        $display("WR_EN    = %b",wr_en);

        $display("AWREADY  = %b",cfg_if.awready);
        $display("WREADY   = %b",cfg_if.wready);
        $display("BVALID   = %b",cfg_if.bvalid);

        //----------------------------------
        // End Write
        //----------------------------------

        cfg_if.awvalid = 0;
        cfg_if.wvalid  = 0;

        #10;

        //----------------------------------
        // READ TRANSACTION
        //----------------------------------

        $display("----------------------------");
        $display("READ TEST");
        $display("----------------------------");

        cfg_if.araddr  = 32'h00;
        cfg_if.arvalid = 1;

        #10;

        $display("RD_ADDR  = %h",rd_addr);
        $display("RD_EN    = %b",rd_en);

        $display("RDATA    = %h",cfg_if.rdata);
        $display("RVALID   = %b",cfg_if.rvalid);

        //----------------------------------
        // End Read
        //----------------------------------

        cfg_if.arvalid = 0;

        #20;

        $finish;

    end

    //----------------------------------
    // Waveform
    //----------------------------------

    initial begin

        $dumpfile("axi4_lite_slave.vcd");
        $dumpvars(0,tb_axi4_lite_slave);

    end

endmodule
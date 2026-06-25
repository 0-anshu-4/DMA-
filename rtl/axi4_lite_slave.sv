module axi4_lite_slave (

    axil_if cfg_if,

    output logic [31:0] wr_addr,
    output logic [31:0] wr_data,
    output logic        wr_en,

    output logic [31:0] rd_addr,
    output logic        rd_en,

    input  logic [31:0] rd_data

);

always_comb begin

    //----------------------------------
    // Defaults
    //----------------------------------

    wr_addr = 32'd0;
    wr_data = 32'd0;
    wr_en   = 1'b0;

    rd_addr = 32'd0;
    rd_en   = 1'b0;

    cfg_if.awready = 1'b0;
    cfg_if.wready  = 1'b0;

    cfg_if.bvalid  = 1'b0;
    cfg_if.bresp   = 2'b00;      // OKAY response

    cfg_if.arready = 1'b0;

    cfg_if.rvalid  = 1'b0;
    cfg_if.rresp   = 2'b00;      // OKAY response
    cfg_if.rdata   = 32'd0;

    //----------------------------------
    // WRITE TRANSACTION
    //----------------------------------

    if(cfg_if.awvalid && cfg_if.wvalid) begin

        wr_addr = cfg_if.awaddr;
        wr_data = cfg_if.wdata;
        wr_en   = 1'b1;

        cfg_if.awready = 1'b1;
        cfg_if.wready  = 1'b1;

        cfg_if.bvalid = 1'b1;
        cfg_if.bresp  = 2'b00;

    end

    //----------------------------------
    // READ TRANSACTION
    //----------------------------------

    if(cfg_if.arvalid) begin

        rd_addr = cfg_if.araddr;
        rd_en   = 1'b1;

        cfg_if.arready = 1'b1;

        cfg_if.rvalid = 1'b1;
        cfg_if.rresp  = 2'b00;
        cfg_if.rdata  = rd_data;

    end

end

endmodule
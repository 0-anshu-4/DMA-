module dma_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter NUM_CH     = 4
)(
    input logic clk,
    input logic rst_n,

    axil_if cfg_if,
    axi_if  mem_if
);

    // ------------------------------------
    // AXI-Lite Slave <-> Reg File
    // ------------------------------------

    logic [31:0] wr_addr;
    logic [31:0] wr_data;
    logic        wr_en;
    
    logic rd_en;
    logic [31:0] rd_addr;
    logic [31:0] rd_data;

    // ------------------------------------
    // Reg File <-> Channel FSM
    // ------------------------------------

    logic [31:0] src_addr [NUM_CH];
    logic [31:0] dst_addr [NUM_CH];
    logic [31:0] length   [NUM_CH];

    logic [NUM_CH-1:0] enable;
    logic [NUM_CH-1:0] start;

    logic [NUM_CH-1:0] busy;
    logic [NUM_CH-1:0] done;

    // ------------------------------------
    // FSM <-> Arbiter
    // ------------------------------------

    logic [NUM_CH-1:0] ch_req;
    logic [NUM_CH-1:0] ch_grant;

    // ------------------------------------
    // FSM -> AXI Master
    // ------------------------------------

    logic [31:0] fsm_src_addr [NUM_CH];
    logic [31:0] fsm_dst_addr [NUM_CH];
    logic [31:0] fsm_length   [NUM_CH];

    logic [NUM_CH-1:0] fsm_start;
    logic [NUM_CH-1:0] fsm_done;

        //------------------------------------
    // MUX -> AXI Master
    //------------------------------------

    logic [31:0] axi_src_addr;
    logic [31:0] axi_dst_addr;
    logic [31:0] axi_length;

    logic        axi_start;
    logic        axi_done;

    // ------------------------------------
    // AXI Lite Slave
    // ------------------------------------

    axi4_lite_slave u_axil_slave (

        .cfg_if (cfg_if),

        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_en  (wr_en),
         
      .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_data(rd_data)
    );

    // ------------------------------------
    // Register File
    // ------------------------------------

    reg_file #(
        .NUM_CH(NUM_CH)
    ) u_reg_file (

        .clk(clk),
        .rst_n(rst_n),

        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_en(wr_en),

        .rd_addr(rd_addr),
        .rd_data(rd_data),
      .rd_en(rd_en),
      

        .src_addr(src_addr),
        .dst_addr(dst_addr),
        .length(length),

        .enable(enable),
        .start(start),

        .busy(busy),
        .done(done)
    );

    // ------------------------------------
    // Channel FSMs
    // ------------------------------------

    genvar i;

    generate
        for(i=0;i<NUM_CH;i++) begin : CH_FSM_GEN

            ch_fsm u_ch_fsm (

                .clk(clk),
                .rst_n(rst_n),

                .src_addr(src_addr[i]),
                .dst_addr(dst_addr[i]),
                .length(length[i]),

                .enable(enable[i]),
                .start(start[i]),

                .ch_req(ch_req[i]),
                .ch_grant(ch_grant[i]),

                .fsm_src_addr(fsm_src_addr[i]),
                .fsm_dst_addr(fsm_dst_addr[i]),
                .fsm_length(fsm_length[i]),

                .fsm_start(fsm_start[i]),
                .fsm_done(fsm_done[i]),

                .busy(busy[i]),
                .done(done[i])
            );

        end
    endgenerate

    // ------------------------------------
    // Arbiter
    // ------------------------------------

    arbiter #(
        .NUM_CH(NUM_CH)
    ) u_arbiter (

        .clk(clk),
        .rst_n(rst_n),

        .ch_req(ch_req),
        .ch_grant(ch_grant)
    );

    // ------------------------------------
    // AXI Master
    // ------------------------------------

    axi4_master u_axi_master (

        .clk(clk),
        .rst_n(rst_n),

        .src_addr(fsm_src_addr[0]),
        .dst_addr(fsm_dst_addr[0]),
        .length(fsm_length[0]),

        .start(fsm_start[0]),
        .done(fsm_done[0]),

        .mem_if(mem_if)
    );

endmodule
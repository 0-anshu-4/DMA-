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

    logic [ADDR_WIDTH-1:0] wr_addr;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  wr_en;

    logic [ADDR_WIDTH-1:0] rd_addr;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  rd_en;

    // ------------------------------------
    // Reg File <-> Channel FSM
    // ------------------------------------

    logic [ADDR_WIDTH-1:0] src_addr [NUM_CH];
    logic [ADDR_WIDTH-1:0] dst_addr [NUM_CH];
    logic [DATA_WIDTH-1:0] length   [NUM_CH];

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

    logic [ADDR_WIDTH-1:0] fsm_src_addr [NUM_CH];
    logic [ADDR_WIDTH-1:0] fsm_dst_addr [NUM_CH];
    logic [DATA_WIDTH-1:0] fsm_length   [NUM_CH];

    logic [NUM_CH-1:0] fsm_start;
    logic [NUM_CH-1:0] fsm_done;

    //------------------------------------
    // MUX -> AXI Master
    //------------------------------------

    logic [ADDR_WIDTH-1:0] axi_src_addr;
    logic [ADDR_WIDTH-1:0] axi_dst_addr;
    logic [DATA_WIDTH-1:0] axi_length;

    logic axi_start;
    logic axi_done;

    // ------------------------------------
    // AXI Lite Slave
    // ------------------------------------

    axi4_lite_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_axil_slave (

        .cfg_if (cfg_if),

        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .wr_en  (wr_en),

        .rd_addr(rd_addr),
        .rd_en  (rd_en),
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
        for(i = 0; i < NUM_CH; i++) begin : CH_FSM_GEN

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
    // Channel MUX
    // ------------------------------------

    channel_mux #(
        .NUM_CH(NUM_CH)
    ) u_channel_mux (

        .fsm_src_addr(fsm_src_addr),
        .fsm_dst_addr(fsm_dst_addr),
        .fsm_length(fsm_length),

        .fsm_start(fsm_start),
        .ch_grant(ch_grant),

        .axi_src_addr(axi_src_addr),
        .axi_dst_addr(axi_dst_addr),
        .axi_length(axi_length),

        .axi_start(axi_start)
    );

    // ------------------------------------
    // AXI Master
    // ------------------------------------

    axi4_master u_axi_master (

        .clk(clk),
        .rst_n(rst_n),

        .src_addr(axi_src_addr),
        .dst_addr(axi_dst_addr),
        .length(axi_length),

        .start(axi_start),
        .done(axi_done),

        .mem_if(mem_if)
    );

    //------------------------------------
    // Route AXI done to granted FSM
    //------------------------------------

    always_comb begin

        fsm_done = '0;

        if (axi_done) begin
            for (int i = 0; i < NUM_CH; i++) begin
                if (ch_grant[i])
                    fsm_done[i] = 1'b1;
            end
        end

    end

endmodule
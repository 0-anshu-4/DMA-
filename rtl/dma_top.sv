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
    logic [$clog2(NUM_CH)-1:0] active_ch;

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
    // Remember Active Channel
    //------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin

        if(!rst_n)

            active_ch <= '0;

        else begin

            for(int i = 0; i < NUM_CH; i++) begin

                if(ch_grant[i])
                    active_ch <= i;

            end

        end

    end
    //------------------------------------
    // Route AXI done to granted FSM
    //------------------------------------

      //------------------------------------
      // Route AXI done to Active FSM
      //------------------------------------

      always_comb begin

          fsm_done = '0;

          if(axi_done)

              fsm_done[active_ch] = 1'b1;

      end

        // ============================================================
// SystemVerilog Assertions (SVA)
// Added at bottom of dma_top.sv, before endmodule
// ============================================================

// ----------------------------------------------------------
// Assertion 1: Arbiter never grants more than one channel
// at the same time (one-hot check)
// Why: if two channels get granted simultaneously, both FSMs
// will try to drive the shared AXI master — undefined behavior
// ----------------------------------------------------------
property p_onehot_grant;
    @(posedge clk) disable iff (!rst_n)
    $onehot0(ch_grant);
endproperty

a_onehot_grant: assert property (p_onehot_grant)
else $error("[SVA FAIL] a_onehot_grant: multiple channels granted at time %0t", $time);


// ----------------------------------------------------------
// Assertion 2: AXI master start only fires when a grant
// is active — no spurious transfers
// Why: axi_start without ch_grant means channel_mux is
// routing garbage addresses to the AXI master
// ----------------------------------------------------------
property p_start_needs_grant;
    @(posedge clk) disable iff (!rst_n)
    axi_start |-> |ch_grant;
endproperty

a_start_needs_grant: assert property (p_start_needs_grant)
else $error("[SVA FAIL] a_start_needs_grant: axi_start high with no active grant at time %0t", $time);


// ----------------------------------------------------------
// Assertion 3: axi_done is a 1-cycle pulse only
// Why: if done stays high for 2+ cycles, the active channel
// FSM could see it twice and double-complete, or the
// wrong channel could catch the second cycle
// ----------------------------------------------------------
property p_done_single_cycle;
    @(posedge clk) disable iff (!rst_n)
    axi_done |=> !axi_done;
endproperty

a_done_single_cycle: assert property (p_done_single_cycle)
else $error("[SVA FAIL] a_done_single_cycle: axi_done held high >1 cycle at time %0t", $time);


// ----------------------------------------------------------
// Assertion 4: A channel that is busy must have valid
// src and dst addresses (not zero simultaneously)
// Why: a transfer with src=0 and dst=0 would overwrite
// the base of memory with itself — likely a config error
// ----------------------------------------------------------
property p_valid_transfer_addr;
    @(posedge clk) disable iff (!rst_n)
    // for each channel: if busy, src and dst can't both be 0
    // checking channel 0 as example — extend per channel
    busy[0] |-> !(src_addr[0] == 32'h0 && dst_addr[0] == 32'h0);
endproperty

a_valid_transfer_addr: assert property (p_valid_transfer_addr)
else $error("[SVA FAIL] a_valid_transfer_addr: ch0 busy with src=0 and dst=0 at time %0t", $time);


// ----------------------------------------------------------
// Assertion 5: Once granted, a channel must stay busy
// until it gets done — grant should not be held while
// the channel is not busy (would mean idle channel holds bus)
// ----------------------------------------------------------
property p_grant_implies_busy;
    @(posedge clk) disable iff (!rst_n)
    |ch_grant |-> |busy;
endproperty

a_grant_implies_busy: assert property (p_grant_implies_busy)
else $error("[SVA FAIL] a_grant_implies_busy: grant active but no channel busy at time %0t", $time);


endmodule
module channel_mux #(
    parameter NUM_CH = 4
)(

    input logic [31:0] fsm_src_addr [NUM_CH],
    input logic [31:0] fsm_dst_addr [NUM_CH],
    input logic [31:0] fsm_length   [NUM_CH],

    input logic [NUM_CH-1:0] fsm_start,
    input logic [NUM_CH-1:0] ch_grant,

    output logic [31:0] axi_src_addr,
    output logic [31:0] axi_dst_addr,
    output logic [31:0] axi_length,

    output logic axi_start

);

always_comb begin

    //----------------------------------
    // Defaults
    //----------------------------------

    axi_src_addr = 32'd0;
    axi_dst_addr = 32'd0;
    axi_length   = 32'd0;

    axi_start    = 1'b0;

    //----------------------------------
    // Select Granted Channel
    //----------------------------------

    if(ch_grant[0]) begin

        axi_src_addr = fsm_src_addr[0];
        axi_dst_addr = fsm_dst_addr[0];
        axi_length   = fsm_length[0];

        axi_start    = fsm_start[0];

    end

    else if(ch_grant[1]) begin

        axi_src_addr = fsm_src_addr[1];
        axi_dst_addr = fsm_dst_addr[1];
        axi_length   = fsm_length[1];

        axi_start    = fsm_start[1];

    end

    else if(ch_grant[2]) begin

        axi_src_addr = fsm_src_addr[2];
        axi_dst_addr = fsm_dst_addr[2];
        axi_length   = fsm_length[2];

        axi_start    = fsm_start[2];

    end

    else if(ch_grant[3]) begin

        axi_src_addr = fsm_src_addr[3];
        axi_dst_addr = fsm_dst_addr[3];
        axi_length   = fsm_length[3];

        axi_start    = fsm_start[3];

    end

end

endmodule
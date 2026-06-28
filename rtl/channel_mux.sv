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

    axi_src_addr = '0;
    axi_dst_addr = '0;
    axi_length   = '0;
    axi_start    = 1'b0;

    for (int i = 0; i < NUM_CH; i++) begin
        if (ch_grant[i]) begin
            axi_src_addr = fsm_src_addr[i];
            axi_dst_addr = fsm_dst_addr[i];
            axi_length   = fsm_length[i];
            axi_start    = fsm_start[i];
        end
    end

end

endmodule
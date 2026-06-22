module reg_file #(
    parameter NUM_CH = 4
)(

    input  logic clk,
    input  logic rst_n,

    input  logic        wr_en,
    input  logic [31:0] wr_addr,
    input  logic [31:0] wr_data,

    input  logic        rd_en,
    input  logic [31:0] rd_addr,

    output logic [31:0] rd_data,

    output logic [31:0] src_addr [NUM_CH],
    output logic [31:0] dst_addr [NUM_CH],
    output logic [31:0] length   [NUM_CH],

    output logic [NUM_CH-1:0] enable,
    output logic [NUM_CH-1:0] start,

    input logic [NUM_CH-1:0] busy,
    input logic [NUM_CH-1:0] done

);

    integer i;

    //----------------------------------
    // Write Logic
    //----------------------------------

    always_ff @(posedge clk or negedge rst_n) begin

        if(!rst_n) begin

            for(i=0;i<NUM_CH;i++) begin
                src_addr[i] <= 32'h0;
                dst_addr[i] <= 32'h0;
                length[i]   <= 32'h0;
                enable[i]   <= 1'b0;
                start[i]    <= 1'b0;
            end

        end

        else if(wr_en) begin

            case(wr_addr)

                // -------------------
                // Channel 0
                // -------------------

                32'h00: src_addr[0] <= wr_data;
                32'h04: dst_addr[0] <= wr_data;
                32'h08: length[0]   <= wr_data;

                32'h0C: begin
                    enable[0] <= wr_data[0];
                    start[0]  <= wr_data[1];
                end

                // -------------------
                // Channel 1
                // -------------------

                32'h10: src_addr[1] <= wr_data;
                32'h14: dst_addr[1] <= wr_data;
                32'h18: length[1]   <= wr_data;

                32'h1C: begin
                    enable[1] <= wr_data[0];
                    start[1]  <= wr_data[1];
                end

                // -------------------
                // Channel 2
                // -------------------

                32'h20: src_addr[2] <= wr_data;
                32'h24: dst_addr[2] <= wr_data;
                32'h28: length[2]   <= wr_data;

                32'h2C: begin
                    enable[2] <= wr_data[0];
                    start[2]  <= wr_data[1];
                end

                // -------------------
                // Channel 3
                // -------------------

                32'h30: src_addr[3] <= wr_data;
                32'h34: dst_addr[3] <= wr_data;
                32'h38: length[3]   <= wr_data;

                32'h3C: begin
                    enable[3] <= wr_data[0];
                    start[3]  <= wr_data[1];
                end

            endcase

        end

    end

    //----------------------------------
    // Read Logic
    //----------------------------------

    always_comb begin

        rd_data = 32'h0;

        if(rd_en) begin

            case(rd_addr)

                // -------------------
                // Channel 0
                // -------------------

                32'h00: rd_data = src_addr[0];
                32'h04: rd_data = dst_addr[0];
                32'h08: rd_data = length[0];
                32'h0C: rd_data = {30'b0,start[0],enable[0]};

                // -------------------
                // Channel 1
                // -------------------

                32'h10: rd_data = src_addr[1];
                32'h14: rd_data = dst_addr[1];
                32'h18: rd_data = length[1];
                32'h1C: rd_data = {30'b0,start[1],enable[1]};

                // -------------------
                // Channel 2
                // -------------------

                32'h20: rd_data = src_addr[2];
                32'h24: rd_data = dst_addr[2];
                32'h28: rd_data = length[2];
                32'h2C: rd_data = {30'b0,start[2],enable[2]};

                // -------------------
                // Channel 3
                // -------------------

                32'h30: rd_data = src_addr[3];
                32'h34: rd_data = dst_addr[3];
                32'h38: rd_data = length[3];
                32'h3C: rd_data = {30'b0,start[3],enable[3]};

                // -------------------
                // Status Registers
                // -------------------

                32'h40: rd_data = {28'b0,busy};
                32'h44: rd_data = {28'b0,done};

                default: rd_data = 32'h0;

            endcase

        end

    end

endmodule
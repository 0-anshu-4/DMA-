module arbiter #(
    parameter NUM_CH = 4
)(
    input logic clk,
    input logic rst_n,

    input logic [NUM_CH-1:0] ch_req,
    output logic [NUM_CH-1:0] ch_grant
);

  logic [$clog2(NUM_CH)-1:0] last_grant;
  logic [$clog2(NUM_CH)-1:0] next_grant;

  logic found;

  always_ff @(posedge clk or negedge rst_n) begin
      if(!rst_n)
          last_grant <= 0;
      else if(|ch_grant)
          last_grant <= next_grant;
  end

  always_comb begin

      ch_grant   = '0;
      found      = 0;
      next_grant = last_grant;

      // Sticky grant: if the currently granted channel is still
      // requesting, keep granting it instead of round-robining away
      // mid-transfer.
      if (ch_req[last_grant]) begin
          ch_grant[last_grant] = 1'b1;
          next_grant           = last_grant;
          found                = 1'b1;
      end

      if (!found) begin
          for(int i=1;i<=NUM_CH;i++) begin

              int idx;
              idx = (last_grant + i) % NUM_CH;

              if(!found && ch_req[idx]) begin

                  ch_grant[idx] = 1'b1;
                  next_grant    = idx;
                  found         = 1'b1;

              end
          end
      end

  end

endmodule
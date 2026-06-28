// module tb_dma_partial;

//     logic clk;
//     logic rst_n;

//     //----------------------------------
//     // FSM <-> Arbiter Signals
//     //----------------------------------

//     logic [3:0] ch_req;
//     logic [3:0] ch_grant;

//     logic [3:0] enable;
//     logic [3:0] start;

//     logic [3:0] busy;
//     logic [3:0] done;

//     logic [3:0] fsm_done;
//     logic [3:0] fsm_start;

//     logic [31:0] src_addr [4];
//     logic [31:0] dst_addr [4];
//     logic [31:0] length   [4];

//     logic [31:0] fsm_src_addr [4];
//     logic [31:0] fsm_dst_addr [4];
//     logic [31:0] fsm_length   [4];

//     //----------------------------------
//     // 4 FSM Instances
//     //----------------------------------

//     genvar i;

//     generate
//         for(i=0;i<4;i++) begin : CH_FSM_GEN

//             ch_fsm u_fsm (

//                 .clk(clk),
//                 .rst_n(rst_n),

//                 .src_addr(src_addr[i]),
//                 .dst_addr(dst_addr[i]),
//                 .length(length[i]),

//                 .enable(enable[i]),
//                 .start(start[i]),

//                 .ch_req(ch_req[i]),
//                 .ch_grant(ch_grant[i]),

//                 .fsm_src_addr(fsm_src_addr[i]),
//                 .fsm_dst_addr(fsm_dst_addr[i]),
//                 .fsm_length(fsm_length[i]),

//                 .fsm_start(fsm_start[i]),
//                 .fsm_done(fsm_done[i]),

//                 .busy(busy[i]),
//                 .done(done[i])

//             );

//         end
//     endgenerate

//     //----------------------------------
//     // Arbiter
//     //----------------------------------

//     arbiter #(
//         .NUM_CH(4)
//     ) u_arbiter (

//         .clk(clk),
//         .rst_n(rst_n),

//         .ch_req(ch_req),
//         .ch_grant(ch_grant)

//     );

//     //----------------------------------
//     // Clock
//     //----------------------------------

//     initial begin
//         clk = 0;
//         forever #5 clk = ~clk;
//     end

//     //----------------------------------
//     // Stimulus
//     //----------------------------------

//     initial begin

//         rst_n = 0;

//         enable = 4'b0000;
//         start  = 4'b0000;

//         fsm_done = 4'b0000;

//         //----------------------------------
//         // Initialize Addresses
//         //----------------------------------

//         for(int j=0;j<4;j++) begin

//             src_addr[j] = 32'h1000 + j*32'h100;
//             dst_addr[j] = 32'h2000 + j*32'h100;
//             length[j]   = 32'd128;

//         end

//         #20;
//         rst_n = 1;

//         //----------------------------------
//         // Start CH0 and CH2
//         //----------------------------------

//         enable = 4'b1111;
//         start  = 4'b1111;

//         #10;

//         start = 4'b0000;

//         //----------------------------------
//         // Fake DMA Completion
//          //----------------------------------
//         // Fake DMA Completion
//         //----------------------------------

//         wait(|fsm_start);

//         $display("Transfer Started");

//         #20;
//         fsm_done = 4'b1111;

//         #10;
//         fsm_done = 4'b0000;
//                #50;

//         $display("DONE = %b",done);

//         $finish;

//     end

//     //----------------------------------
//     // Monitor
//     //----------------------------------

//     always @(posedge clk) begin

//         $display(
//         "T=%0t REQ=%b GRANT=%b START=%b DONE=%b",
//         $time,
//         ch_req,
//         ch_grant,
//         fsm_start,
//         done
//         );

//     end

//     //----------------------------------
//     // Waveform
//     //----------------------------------

//     initial begin

//         $dumpfile("dma_partial.vcd");
//         $dumpvars(0,tb_dma_partial);

//     end

// endmodule

/I verified the interaction between multiple Channel FSMs and the round-robin arbiter before integrating the rest of the DMA

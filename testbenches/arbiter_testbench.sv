// // `include "tb_arbiter.sv"
// // module tb;

// //     logic clk;
// //     logic rst_n;

// //     axil_if axil();
// //     axi_if  axi();

// //     dma_top dut (
// //         .clk(clk),
// //         .rst_n(rst_n),
// //         .cfg_if(axil),
// //         .mem_if(axi)
// //     );

// //     initial begin
// //         clk = 0;
// //         forever #5 clk = ~clk;
// //     end

// //     initial begin
// //         rst_n = 0;
// //         #20;
// //         rst_n = 1;
// //     end

// //     initial begin
// //         $display("DMA Project Compiled Successfully!");
// //         #100;
// //         $finish;
// //     end

// // endmodule



// ----------------------------------------------------------------------------------
// module tb_arbiter;

//     logic clk;
//     logic rst_n;

//     logic [3:0] ch_req;
//     logic [3:0] ch_grant;

//     arbiter #(
//         .NUM_CH(4)
//     ) dut (
//         .clk(clk),
//         .rst_n(rst_n),
//         .ch_req(ch_req),
//         .ch_grant(ch_grant)
//     );

//     initial begin
//         clk = 0;
//         forever #5 clk = ~clk;
//     end

//     initial begin

//         rst_n = 0;
//         ch_req = 4'b0000;

//         #20;
//         rst_n = 1;

//         //--------------------------------
//         // Test 1
//         //--------------------------------

//         ch_req = 4'b0001;

//         #10;

//         $display("REQ=%b GRANT=%b",ch_req,ch_grant);

//         //--------------------------------
//         // Test 2
//         //--------------------------------

//         ch_req = 4'b1111;

//       repeat(8) begin
//     #10;
//         $display("TIME=%0t REQ=%b GRANT=%b",$time,ch_req,ch_grant);
//     end

//         #20;
//         $finish;

//     end

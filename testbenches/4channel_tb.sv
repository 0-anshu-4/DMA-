`timescale 1ns/1ps

module tb_dma_top;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter NUM_CH     = 4;

    //----------------------------------
    // Clock / Reset
    //----------------------------------

    logic clk;
    logic rst_n;

    //----------------------------------
    // Interfaces
    //----------------------------------

    axil_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) cfg_if();

    axi_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) mem_if();

    //----------------------------------
    // DUT
    //----------------------------------

    dma_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_CH(NUM_CH)
    ) dut (

        .clk(clk),
        .rst_n(rst_n),

        .cfg_if(cfg_if),
        .mem_if(mem_if)

    );

    //----------------------------------
    // AXI Memory Model
    //----------------------------------

    axi_mem_model u_mem (

        .clk(clk),
        .rst_n(rst_n),

        .mem_if(mem_if)

    );

    //----------------------------------
    // Clock Generation
    //----------------------------------

    initial begin

        clk = 0;

        forever #5 clk = ~clk;

    end

    //----------------------------------
    // Reset Generation
    //----------------------------------

    initial begin

        rst_n = 0;

        //----------------------------------
        // AXI-Lite defaults
        //----------------------------------

        cfg_if.awaddr  = 0;
        cfg_if.awvalid = 0;

        cfg_if.wdata   = 0;
        cfg_if.wvalid  = 0;

        cfg_if.bready  = 1;

        cfg_if.araddr  = 0;
        cfg_if.arvalid = 0;

        cfg_if.rready  = 1;

        repeat(5) @(posedge clk);

        rst_n = 1;

    end;

    //----------------------------------
    // AXI-Lite Write Task
    //----------------------------------

    task automatic axil_write(

        input [31:0] addr,
        input [31:0] data

    );

    begin

        @(posedge clk);

        cfg_if.awaddr  <= addr;
        cfg_if.awvalid <= 1;

        cfg_if.wdata   <= data;
        cfg_if.wvalid  <= 1;

        wait(cfg_if.awready && cfg_if.wready);

        @(posedge clk);

        cfg_if.awvalid <= 0;
        cfg_if.wvalid  <= 0;

        wait(cfg_if.bvalid);

        @(posedge clk);

    end

    endtask

    // ============================================================
    //  TEST 3: ALL 4 CHANNELS SIMULTANEOUS
    // ============================================================

    task automatic test_4ch_simultaneous;

        integer ch;

        begin

            $display("\n==========================================");
            $display("  TEST 3: ALL 4 CHANNELS SIMULTANEOUS");
            $display("==========================================\n");

            //----------------------------------
            // Reset
            //----------------------------------

            rst_n = 0;
            #20;
            rst_n = 1;
            #20;

            //----------------------------------
            // Preload source data for all 4 channels
            //----------------------------------

            // Channel 0: src=0x000, dst=0x100, length=2
            u_mem.mem[0]  = 32'hAAAA_0000;
            u_mem.mem[1]  = 32'hAAAA_0001;

            // Channel 1: src=0x020, dst=0x120, length=2
            u_mem.mem[8]  = 32'hBBBB_0000;
            u_mem.mem[9]  = 32'hBBBB_0001;

            // Channel 2: src=0x040, dst=0x140, length=2
            u_mem.mem[16] = 32'hCCCC_0000;
            u_mem.mem[17] = 32'hCCCC_0001;

            // Channel 3: src=0x060, dst=0x160, length=2
            u_mem.mem[24] = 32'hDDDD_0000;
            u_mem.mem[25] = 32'hDDDD_0001;

            //----------------------------------
            // Configure all 4 channels via AXI-Lite
            //----------------------------------

            // Channel 0
            axil_write(32'h00, 32'h000); // SRC
            axil_write(32'h04, 32'h100); // DST
            axil_write(32'h08, 32'd2);   // LENGTH
            axil_write(32'h0C, 32'h3);   // enable=1 start=1

            // Channel 1
            axil_write(32'h10, 32'h020); // SRC
            axil_write(32'h14, 32'h120); // DST
            axil_write(32'h18, 32'd2);   // LENGTH
            axil_write(32'h1C, 32'h3);   // enable=1 start=1

            // Channel 2
            axil_write(32'h20, 32'h040); // SRC
            axil_write(32'h24, 32'h140); // DST
            axil_write(32'h28, 32'd2);   // LENGTH
            axil_write(32'h2C, 32'h3);   // enable=1 start=1

            // Channel 3
            axil_write(32'h30, 32'h060); // SRC
            axil_write(32'h34, 32'h160); // DST
            axil_write(32'h38, 32'd2);   // LENGTH
            axil_write(32'h3C, 32'h3);   // enable=1 start=1

            $display("[%0t] All 4 channels configured and started", $time);

            //----------------------------------
            // Wait for all 4 channels to complete
            //----------------------------------

            fork
                begin
                    wait(dut.done[0] == 1);
                    $display("[%0t] Channel 0 DONE", $time);
                end
                begin
                    wait(dut.done[1] == 1);
                    $display("[%0t] Channel 1 DONE", $time);
                end
                begin
                    wait(dut.done[2] == 1);
                    $display("[%0t] Channel 2 DONE", $time);
                end
                begin
                    wait(dut.done[3] == 1);
                    $display("[%0t] Channel 3 DONE", $time);
                end
            join

            $display("\n[%0t] All 4 channels completed", $time);

            //----------------------------------
            // Verify memory contents
            //----------------------------------

            $display("\n--- Memory Verification ---");

            // Channel 0
            if (u_mem.mem[64] == 32'hAAAA_0000 && u_mem.mem[65] == 32'hAAAA_0001)
                $display("Ch0 PASS: dst[0x100] = %h %h", u_mem.mem[64], u_mem.mem[65]);
            else
                $display("Ch0 FAIL: got %h %h", u_mem.mem[64], u_mem.mem[65]);

            // Channel 1
            if (u_mem.mem[72] == 32'hBBBB_0000 && u_mem.mem[73] == 32'hBBBB_0001)
                $display("Ch1 PASS: dst[0x120] = %h %h", u_mem.mem[72], u_mem.mem[73]);
            else
                $display("Ch1 FAIL: got %h %h", u_mem.mem[72], u_mem.mem[73]);

            // Channel 2
            if (u_mem.mem[80] == 32'hCCCC_0000 && u_mem.mem[81] == 32'hCCCC_0001)
                $display("Ch2 PASS: dst[0x140] = %h %h", u_mem.mem[80], u_mem.mem[81]);
            else
                $display("Ch2 FAIL: got %h %h", u_mem.mem[80], u_mem.mem[81]);

            // Channel 3
            if (u_mem.mem[88] == 32'hDDDD_0000 && u_mem.mem[89] == 32'hDDDD_0001)
                $display("Ch3 PASS: dst[0x160] = %h %h", u_mem.mem[88], u_mem.mem[89]);
            else
                $display("Ch3 FAIL: got %h %h", u_mem.mem[88], u_mem.mem[89]);

            //----------------------------------
            // Fairness check: verify all 4 completed
            // (round-robin means no starvation)
            //----------------------------------

            if (dut.done[0] && dut.done[1] && dut.done[2] && dut.done[3]) begin
                $display("\n==========================================");
                $display("  ALL 4 CHANNEL TEST PASSED");
                $display("  Round-robin: no channel starved");
                $display("==========================================\n");
            end else begin
                $display("\n==========================================");
                $display("  FAIL: Not all channels completed");
                $display("  done = %b", dut.done);
                $display("==========================================\n");
            end

        end

    endtask

    //----------------------------------
    // Test Sequence
    //----------------------------------

    initial begin

        //----------------------------------
        // Wait for Reset
        //----------------------------------

        wait(rst_n);

        repeat(2) @(posedge clk);

        $display("\n======================================");
        $display(" Starting Multi-Channel DMA Test ");
        $display("======================================\n");

                //----------------------------------
        // Initialize Memory
        //----------------------------------

        u_mem.mem[0]  = 32'hAAAA1111;
        u_mem.mem[1]  = 32'hBBBB2222;

        u_mem.mem[32] = 32'hCCCC3333;
        u_mem.mem[33] = 32'hDDDD4444;
        //----------------------------------
        // Configure Channel 0
        //----------------------------------

        $display("[%0t] Configuring Channel 0",$time);

        axil_write(32'h00,32'h00);   // SRC
        axil_write(32'h04,32'h40);   // DST   
        axil_write(32'h08,32'd2);      // LENGTH = 2 words

        //----------------------------------
        // Configure Channel 1
        //----------------------------------

        $display("[%0t] Configuring Channel 1",$time);

        axil_write(32'h10,32'h80);   // SRC
        axil_write(32'h14,32'hC0);   // DST
        axil_write(32'h18,32'd2);      // LENGTH = 2 words

        //----------------------------------
        // Start BOTH Channels Together
        //----------------------------------

        $display("[%0t] Starting CH0 + CH1",$time);

        axil_write(32'h0C,32'h3);      // enable=1 start=1
        axil_write(32'h1C,32'h3);      // enable=1 start=1

        //----------------------------------
        // Wait until at least one request appears
        //----------------------------------

        wait(|dut.ch_req);

        $display("[%0t] DMA Requests Generated",$time);

        //----------------------------------
        // Wait for both channels to finish
        //----------------------------------

        wait(dut.done[0]);

        $display("[%0t] Channel 0 Completed",$time);

        wait(dut.done[1]);

        $display("[%0t] Channel 1 Completed",$time);
        //----------------------------------
        // Verify Memory Contents
        //----------------------------------

        if(u_mem.mem[16] == 32'hAAAA1111 &&
           u_mem.mem[17] == 32'hBBBB2222 &&
           u_mem.mem[48] == 32'hCCCC3333 &&
           u_mem.mem[49] == 32'hDDDD4444)

            $display("\n******** MEMORY COPY PASSED ********\n");

        else begin

            $display("\n******** MEMORY COPY FAILED ********");

            $display("MEM[16] = %h",u_mem.mem[16]);
            $display("MEM[17] = %h",u_mem.mem[17]);

            $display("MEM[48] = %h",u_mem.mem[48]);
            $display("MEM[49] = %h",u_mem.mem[49]);

        end;

        //----------------------------------
        // After Test 2 (2-channel test) completes,
        // run Test 3: all 4 channels simultaneous
        //----------------------------------

        #100;
        test_4ch_simultaneous;
        #50;
        $finish;

    end
      //----------------------------------
    // Completion Flags
    //----------------------------------

    logic ch0_complete;
    logic ch1_complete;

    always_ff @(posedge clk or negedge rst_n) begin

        if(!rst_n) begin

            ch0_complete <= 0;
            ch1_complete <= 0;

        end

        else begin

            if(dut.done[0])
                ch0_complete <= 1;

            if(dut.done[1])
                ch1_complete <= 1;

        end

    end

    //----------------------------------
    // Grant Order Tracker — confirms round-robin rotation
    //----------------------------------

    logic [3:0] prev_grant;

    always @(posedge clk) begin

        if (prev_grant !== dut.u_arbiter.ch_grant) begin

            if (|dut.u_arbiter.ch_grant)
                $display("[%0t] GRANT CHANGED: %b -> %b",
                         $time,
                         prev_grant,
                         dut.u_arbiter.ch_grant);

            prev_grant <= dut.u_arbiter.ch_grant;

        end

    end

    //----------------------------------
    // Live Monitor
    //----------------------------------

    always @(posedge clk) begin

        $display(
        "T=%0t | REQ=%b | GRANT=%b | BUSY=%b | DONE=%b | START=%b | AXI_START=%b | AXI_DONE=%b",
        $time,
        dut.ch_req,
        dut.ch_grant,
        dut.busy,
        dut.done,
        dut.fsm_start,
        dut.axi_start,
        dut.axi_done
        );

   
      $display(
      "AXI: start=%b state=%0d done=%b word_count=%0d length=%0d src=%h dst=%h arvalid=%b arready=%b rvalid=%b awvalid=%b awready=%b wvalid=%b bvalid=%b",
      dut.axi_start,
      dut.u_axi_master.curr_state,
      dut.u_axi_master.done,
      dut.u_axi_master.word_count,
      dut.axi_length,
      dut.u_axi_master.src_addr_curr,
      dut.u_axi_master.dst_addr_curr,
      mem_if.arvalid,
      mem_if.arready,
      mem_if.rvalid,
      mem_if.awvalid,
      mem_if.awready,
      mem_if.wvalid,
      mem_if.bvalid
      );

        $display(
    "FSM0=%0d FSM1=%0d",
    dut.CH_FSM_GEN[0].u_ch_fsm.curr_state,
    dut.CH_FSM_GEN[1].u_ch_fsm.curr_state
        ); 

        $display(
    "active=%0d fsm_done=%b axi_done=%b FSM0=%0d FSM1=%0d",
    dut.active_ch,
    dut.fsm_done,
    dut.axi_done,
    dut.CH_FSM_GEN[0].u_ch_fsm.curr_state,
    dut.CH_FSM_GEN[1].u_ch_fsm.curr_state
    );  
          $display(
    "AXI state=%0d next=%0d wc=%0d len=%0d done=%b",
    dut.u_axi_master.curr_state,
    dut.u_axi_master.next_state,
    dut.u_axi_master.word_count,
    dut.axi_length,
    dut.axi_done
    );
     end
    //----------------------------------
    // One-Hot Grant Check
    //----------------------------------

    always @(posedge clk) begin

        if($countones(dut.ch_grant) > 1) begin

            $display("\nERROR : Multiple channels granted simultaneously!\n");
            $finish;

        end

    end

    //----------------------------------
    // Timeout + PASS / FAIL
    //----------------------------------

    initial begin

        wait(rst_n);

        repeat(500) @(posedge clk);

        if(ch0_complete && ch1_complete) begin

            $display("\n=========================================");
            $display("        MULTI CHANNEL TEST PASSED");
            $display("=========================================\n");

        end

        else begin

            $display("\n=========================================");
            $display("        TEST FAILED (TIMEOUT)");
            $display("=========================================");

            $display("CH0 Complete = %0d",ch0_complete);
            $display("CH1 Complete = %0d",ch1_complete);

            $display("REQ   = %b",dut.ch_req);
            $display("GRANT = %b",dut.ch_grant);
            $display("BUSY  = %b",dut.busy);
            $display("DONE  = %b",dut.done);

        end

        $finish;

    end

    //----------------------------------
    // Waveform Dump
    //----------------------------------

    initial begin

        $dumpfile("dma_top.vcd");
        $dumpvars(0,tb_dma_top);

    end

endmodule
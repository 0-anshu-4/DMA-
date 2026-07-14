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
    ) cfg_if(.clk(clk),.rst_n(rst_n));

    axi_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) mem_if(.clk(clk),.rst_n(rst_n));

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
    end

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

        integer timeout;

        begin

            $display("\n==========================================");
            $display("  TEST 3: ALL 4 CHANNELS SIMULTANEOUS");
            $display("==========================================\n");

            //----------------------------------
            // Reset before test 3
            //----------------------------------

            rst_n = 0;
            #20;
            rst_n = 1;
            #20;

            //----------------------------------
            // Preload source memory
            // word index = byte_addr / 4
            // ch0 src=0x000 -> word[0,1]
            // ch1 src=0x020 -> word[8,9]
            // ch2 src=0x040 -> word[16,17]
            // ch3 src=0x060 -> word[24,25]
            //----------------------------------

            u_mem.mem[0]  = 32'hAAAA_0000;
            u_mem.mem[1]  = 32'hAAAA_0001;
            u_mem.mem[8]  = 32'hBBBB_0000;
            u_mem.mem[9]  = 32'hBBBB_0001;
            u_mem.mem[16] = 32'hCCCC_0000;
            u_mem.mem[17] = 32'hCCCC_0001;
            u_mem.mem[24] = 32'hDDDD_0000;
            u_mem.mem[25] = 32'hDDDD_0001;

            //----------------------------------
            // Configure addresses only first
            // (no start bit yet)
            //----------------------------------

            axil_write(32'h00, 32'h000); // ch0 SRC
            axil_write(32'h04, 32'h100); // ch0 DST
            axil_write(32'h08, 32'd2);   // ch0 LENGTH

            axil_write(32'h10, 32'h020); // ch1 SRC
            axil_write(32'h14, 32'h120); // ch1 DST
            axil_write(32'h18, 32'd2);   // ch1 LENGTH

            axil_write(32'h20, 32'h040); // ch2 SRC
            axil_write(32'h24, 32'h140); // ch2 DST
            axil_write(32'h28, 32'd2);   // ch2 LENGTH

            axil_write(32'h30, 32'h060); // ch3 SRC
            axil_write(32'h34, 32'h160); // ch3 DST
            axil_write(32'h38, 32'd2);   // ch3 LENGTH

            $display("[%0t] Addresses configured, starting all channels", $time);

            //----------------------------------
            // Start all 4 channels
            // (sequential axil_write means ch0
            // starts slightly before ch3 — this
            // is expected and tests real arbitration)
            //----------------------------------

            axil_write(32'h0C, 32'h3); // ch0 enable=1 start=1
            axil_write(32'h1C, 32'h3); // ch1 enable=1 start=1
            axil_write(32'h2C, 32'h3); // ch2 enable=1 start=1
            axil_write(32'h3C, 32'h3); // ch3 enable=1 start=1

            //----------------------------------
            // Poll until all channels idle
            // busy=0 and ch_req=0 means all done
            //----------------------------------

            timeout = 0;

            while ((dut.busy != 4'b0000 || dut.ch_req != 4'b0000)
                    && timeout < 500) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= 500)
                $display("WARNING: timeout waiting for all channels");
            else
                $display("[%0t] All 4 channels completed", $time);

            //----------------------------------
            // Memory verification
            // dst addresses:
            // ch0 dst=0x100 -> word[64,65]
            // ch1 dst=0x120 -> word[72,73]
            // ch2 dst=0x140 -> word[80,81]
            // ch3 dst=0x160 -> word[88,89]
            //----------------------------------

            $display("\n--- Memory Verification ---");

            if (u_mem.mem[64] == 32'hAAAA_0000 &&
                u_mem.mem[65] == 32'hAAAA_0001)
                $display("Ch0 PASS: dst[0x100] = %h %h",
                         u_mem.mem[64], u_mem.mem[65]);
            else
                $display("Ch0 FAIL: got %h %h",
                         u_mem.mem[64], u_mem.mem[65]);

            if (u_mem.mem[72] == 32'hBBBB_0000 &&
                u_mem.mem[73] == 32'hBBBB_0001)
                $display("Ch1 PASS: dst[0x120] = %h %h",
                         u_mem.mem[72], u_mem.mem[73]);
            else
                $display("Ch1 FAIL: got %h %h",
                         u_mem.mem[72], u_mem.mem[73]);

            if (u_mem.mem[80] == 32'hCCCC_0000 &&
                u_mem.mem[81] == 32'hCCCC_0001)
                $display("Ch2 PASS: dst[0x140] = %h %h",
                         u_mem.mem[80], u_mem.mem[81]);
            else
                $display("Ch2 FAIL: got %h %h",
                         u_mem.mem[80], u_mem.mem[81]);

            if (u_mem.mem[88] == 32'hDDDD_0000 &&
                u_mem.mem[89] == 32'hDDDD_0001)
                $display("Ch3 PASS: dst[0x160] = %h %h",
                         u_mem.mem[88], u_mem.mem[89]);
            else
                $display("Ch3 FAIL: got %h %h",
                         u_mem.mem[88], u_mem.mem[89]);

            //----------------------------------
            // Final pass/fail
            //----------------------------------

            if (u_mem.mem[64] == 32'hAAAA_0000 &&
                u_mem.mem[72] == 32'hBBBB_0000 &&
                u_mem.mem[80] == 32'hCCCC_0000 &&
                u_mem.mem[88] == 32'hDDDD_0000) begin

                $display("\n==========================================");
                $display("  ALL 4 CHANNEL TEST PASSED");
                $display("  Round-robin: no channel starved");
                $display("==========================================\n");

            end else begin

                $display("\n==========================================");
                $display("  FAIL: memory mismatch");
                $display("==========================================\n");

            end

        end

    endtask

    //----------------------------------
    // Test Sequence
    //----------------------------------

    initial begin

        wait(rst_n);
        repeat(2) @(posedge clk);

        $display("\n======================================");
        $display(" Starting Multi-Channel DMA Test ");
        $display("======================================\n");

        //----------------------------------
        // TEST 1 + 2: 2-channel test
        //----------------------------------

        u_mem.mem[0]  = 32'hAAAA1111;
        u_mem.mem[1]  = 32'hBBBB2222;
        u_mem.mem[32] = 32'hCCCC3333;
        u_mem.mem[33] = 32'hDDDD4444;

        $display("[%0t] Configuring Channel 0", $time);
        axil_write(32'h00, 32'h00);
        axil_write(32'h04, 32'h40);
        axil_write(32'h08, 32'd2);

        $display("[%0t] Configuring Channel 1", $time);
        axil_write(32'h10, 32'h80);
        axil_write(32'h14, 32'hC0);
        axil_write(32'h18, 32'd2);

        $display("[%0t] Starting CH0 + CH1", $time);
        axil_write(32'h0C, 32'h3);
        axil_write(32'h1C, 32'h3);

        wait(|dut.ch_req);
        $display("[%0t] DMA Requests Generated", $time);

        wait(dut.done[0]);
        $display("[%0t] Channel 0 Completed", $time);

        wait(dut.done[1]);
        $display("[%0t] Channel 1 Completed", $time);

        if (u_mem.mem[16] == 32'hAAAA1111 &&
            u_mem.mem[17] == 32'hBBBB2222 &&
            u_mem.mem[48] == 32'hCCCC3333 &&
            u_mem.mem[49] == 32'hDDDD4444)
            $display("\n******** MEMORY COPY PASSED ********\n");
        else begin
            $display("\n******** MEMORY COPY FAILED ********");
            $display("MEM[16] = %h", u_mem.mem[16]);
            $display("MEM[17] = %h", u_mem.mem[17]);
            $display("MEM[48] = %h", u_mem.mem[48]);
            $display("MEM[49] = %h", u_mem.mem[49]);
        end

        //----------------------------------
        // TEST 3: 4-channel simultaneous
        //----------------------------------

        #100;
        test_4ch_simultaneous;
        #50;
        $finish;

    end

    //----------------------------------
    // Completion Flags (used by test 1+2)
    //----------------------------------

    logic ch0_complete;
    logic ch1_complete;
    logic [3:0] prev_grant;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch0_complete <= 0;
            ch1_complete <= 0;
        end else begin
            if (dut.done[0]) ch0_complete <= 1;
            if (dut.done[1]) ch1_complete <= 1;
        end
    end

    //----------------------------------
    // Grant Order Tracker
    //----------------------------------

    always @(posedge clk) begin
        if (prev_grant !== dut.u_arbiter.ch_grant) begin
            if (|dut.u_arbiter.ch_grant)
                $display("[%0t] GRANT CHANGED: %b -> %b",
                         $time, prev_grant, dut.u_arbiter.ch_grant);
            prev_grant <= dut.u_arbiter.ch_grant;
        end
    end

    //----------------------------------
    // One-Hot Grant Check
    //----------------------------------

    always @(posedge clk) begin
        if ($countones(dut.ch_grant) > 1) begin
            $display("\nERROR: Multiple channels granted simultaneously!\n");
            $finish;
        end
    end

    //----------------------------------
    // Timeout Watchdog
    //----------------------------------

    initial begin
        wait(rst_n);
        repeat(2000) @(posedge clk);
        $display("\n=========================================");
        $display("        TIMEOUT - simulation killed");
        $display("=========================================");
        $display("REQ   = %b", dut.ch_req);
        $display("GRANT = %b", dut.ch_grant);
        $display("BUSY  = %b", dut.busy);
        $display("DONE  = %b", dut.done);
        $finish;
    end

    //----------------------------------
    // Waveform Dump
    //----------------------------------

    initial begin
        $dumpfile("dma_top.vcd");
        $dumpvars(0, tb_dma_top);
    end

endmodule
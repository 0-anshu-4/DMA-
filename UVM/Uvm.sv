import uvm_pkg::*;
`include "uvm_macros.svh"

class dma_seq_item extends uvm_sequence_item;
  
      rand logic [31:0] src_addr;
    rand logic [31:0] dst_addr;
    rand logic [31:0] length;
    rand logic [1:0]  channel_sel;

    `uvm_object_utils_begin(dma_seq_item)
        `uvm_field_int(src_addr,    UVM_ALL_ON)
        `uvm_field_int(dst_addr,    UVM_ALL_ON)
        `uvm_field_int(length,      UVM_ALL_ON)
        `uvm_field_int(channel_sel, UVM_ALL_ON)
    `uvm_object_utils_end



    constraint c_length {
        length > 0;
        length <= 8;
    }

    constraint c_src_addr {
        src_addr[1:0] == 2'b00;
        src_addr inside {[32'h000:32'h0FC]};
    }

    constraint c_dst_addr {
        dst_addr[1:0] == 2'b00;
        dst_addr inside {[32'h100:32'h1FC]};
    }

    constraint c_src_no_overflow {
        src_addr + (length << 2) <= 32'h100;
    }

    constraint c_dst_no_overflow {
        dst_addr + (length << 2) <= 32'h200;
    }

    constraint c_channel {
        channel_sel inside {2'd0, 2'd1, 2'd2, 2'd3};
    }

    function logic [31:0] get_ch_base();
        return {26'h0, channel_sel, 4'h0};
    endfunction

    function new(string name = "dma_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "ch=%0d base=0x%02h src=0x%08h dst=0x%08h len=%0d",
            channel_sel, get_ch_base(), src_addr, dst_addr, length
        );
    endfunction

endclass

class dma_sequencer extends uvm_sequencer #(dma_seq_item);
    `uvm_component_utils(dma_sequencer)
    function new(string name = "dma_sequencer",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

class dma_driver extends uvm_driver #(dma_seq_item);

    `uvm_component_utils(dma_driver)

    virtual axil_if vif;

    function new(string name = "dma_driver",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual axil_if)::get(
                this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "dma_driver: no vif in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        dma_seq_item item;
        vif.awvalid = 0;
        vif.wvalid  = 0;
        vif.bready  = 1;
        vif.arvalid = 0;
        vif.rready  = 1;
        forever begin
            seq_item_port.get_next_item(item);
            `uvm_info("DRV",
                $sformatf("Driving: %s", item.convert2string()),
                UVM_MEDIUM)
            drive_channel(item);
            seq_item_port.item_done();
        end
    endtask

    task drive_channel(dma_seq_item item);
        logic [31:0] base;
        base = item.get_ch_base();
        axil_write(base + 32'h00, item.src_addr);
        axil_write(base + 32'h04, item.dst_addr);
        axil_write(base + 32'h08, item.length);
        axil_write(base + 32'h0C, 32'h3);
    endtask

    task axil_write(input logic [31:0] addr,
                    input logic [31:0] data);
        @(posedge vif.clk);
        vif.awaddr  <= addr;
        vif.awvalid <= 1;
        vif.wdata   <= data;
        vif.wvalid  <= 1;
        wait(vif.awready && vif.wready);
        @(posedge vif.clk);
        vif.awvalid <= 0;
        vif.wvalid  <= 0;
        wait(vif.bvalid);
        @(posedge vif.clk);
    endtask

endclass
      
      
// monitor 
      
      
class dma_monitor extends uvm_monitor;

    `uvm_component_utils(dma_monitor)

    virtual axil_if vif;
    uvm_analysis_port #(dma_seq_item) ap;

    function new(string name = "dma_monitor",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual axil_if)::get(
                this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "dma_monitor: no vif in config_db")
    endfunction

 task run_phase(uvm_phase phase);
    dma_seq_item obs;
    logic [31:0] addr, data;
    logic [1:0]  ch;

    // Per-channel register capture buffers
    logic [31:0] cap_src  [4];
    logic [31:0] cap_dst  [4];
    logic [31:0] cap_len  [4];

    forever begin
        @(posedge vif.clk);

        if (vif.awvalid && vif.awready &&
            vif.wvalid  && vif.wready) begin

            addr = vif.awaddr;
            data = vif.wdata;
            ch   = addr[5:4]; // channel index from address bits

            // Capture each register write
            case (addr[3:0])
                4'h0: cap_src[ch] = data; // SRC_ADDR
                4'h4: cap_dst[ch] = data; // DST_ADDR
                4'h8: cap_len[ch] = data; // LENGTH
                4'hC: begin               // CONTROL — transfer starts
                    if (data == 32'h3) begin
                        obs = dma_seq_item::type_id::create("obs");
                        obs.channel_sel = ch;
                        obs.src_addr    = cap_src[ch];
                        obs.dst_addr    = cap_dst[ch];
                        obs.length      = cap_len[ch];
                        `uvm_info("MON",
                            $sformatf("Observed: %s", obs.convert2string()),
                            UVM_MEDIUM)
                        ap.write(obs);
                    end
                end
            endcase
        end
    end
endtask

endclass

class dma_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(dma_scoreboard)

    uvm_analysis_imp #(dma_seq_item, dma_scoreboard) analysis_export;

    int pass_count;
    int fail_count;

    function new(string name = "dma_scoreboard",
                 uvm_component parent = null);
        super.new(name, parent);
        pass_count = 0;
        fail_count = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_export = new("analysis_export", this);
    endfunction

    function void write(dma_seq_item item);
        `uvm_info("SB",
            $sformatf("Received: %s", item.convert2string()),
            UVM_MEDIUM)
        pass_count++;
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SB",
            $sformatf("\n=== SCOREBOARD ===\nPASS: %0d FAIL: %0d",
                       pass_count, fail_count),
            UVM_LOW)
    endfunction

endclass
      
      // =====Coverage===
class dma_coverage extends uvm_subscriber #(dma_seq_item);

    `uvm_component_utils(dma_coverage)

    int unsigned cov_channel;
    int unsigned cov_length;

    covergroup dma_cg;

        option.per_instance = 1;
        option.name = "dma_cg";

        cp_channel: coverpoint cov_channel {
            bins ch0 = {0};
            bins ch1 = {1};
            bins ch2 = {2};
            bins ch3 = {3};
        }

        cp_length: coverpoint cov_length {
            bins len_1   = {1};
            bins len_2_4 = {[2:4]};
            bins len_5_8 = {[5:8]};
        }

        cx_ch_len: cross cp_channel, cp_length;

    endgroup

    function new(string name = "dma_coverage",
                 uvm_component parent = null);
        super.new(name, parent);
        cov_channel = 0;
        cov_length  = 0;
        dma_cg      = new();
    endfunction

    function void write(dma_seq_item t);
        cov_channel = int'(t.channel_sel);
        cov_length  = int'(t.length);
        dma_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COV",
            $sformatf("Functional Coverage = %.1f%%",
                       dma_cg.get_coverage()),
            UVM_LOW)
    endfunction

endclass
      
      
      // ----AGENT------
class dma_agent extends uvm_agent;

    `uvm_component_utils(dma_agent)

    dma_driver    driver;
    dma_monitor   monitor;
    dma_sequencer sequencer;

    function new(string name = "dma_agent",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver    = dma_driver::type_id::create("driver",    this);
        monitor   = dma_monitor::type_id::create("monitor",  this);
        sequencer = dma_sequencer::type_id::create("sequencer", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass

class dma_env extends uvm_env;

    `uvm_component_utils(dma_env)

    dma_agent      agent;
    dma_scoreboard scoreboard;
    dma_coverage   coverage;

    function new(string name = "dma_env",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = dma_agent::type_id::create("agent",      this);
        scoreboard = dma_scoreboard::type_id::create("scoreboard", this);
        coverage   = dma_coverage::type_id::create("coverage",    this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.monitor.ap.connect(scoreboard.analysis_export);
        agent.monitor.ap.connect(coverage.analysis_export);
    endfunction

endclass

class dma_base_seq extends uvm_sequence #(dma_seq_item);
    `uvm_object_utils(dma_base_seq)
    function new(string name = "dma_base_seq");
        super.new(name);
    endfunction
endclass

class dma_single_seq extends dma_base_seq;
    `uvm_object_utils(dma_single_seq)
    function new(string name = "dma_single_seq");
        super.new(name);
    endfunction
    task body();
        dma_seq_item item;
        item = dma_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with {
            channel_sel == 2'd0;
            length      == 32'd2;
        })
            `uvm_fatal("RAND", "Randomization failed")
        finish_item(item);
        `uvm_info("SEQ",
            $sformatf("Single: %s", item.convert2string()),
            UVM_LOW)
    endtask
endclass

class dma_multichannel_seq extends dma_base_seq;
    `uvm_object_utils(dma_multichannel_seq)
    function new(string name = "dma_multichannel_seq");
        super.new(name);
    endfunction
    task body();
        dma_seq_item item;
        for (int ch = 0; ch < 4; ch++) begin
            item = dma_seq_item::type_id::create(
                       $sformatf("item_ch%0d", ch));
            start_item(item);
            if (!item.randomize() with { channel_sel == ch; })
                `uvm_fatal("RAND", "Randomization failed")
            finish_item(item);
            `uvm_info("SEQ",
                $sformatf("MultiCh ch=%0d: %s",
                           ch, item.convert2string()),
                UVM_LOW)
        end
    endtask
endclass

class dma_random_seq extends dma_base_seq;
    `uvm_object_utils(dma_random_seq)
    int num_transfers = 20;
    function new(string name = "dma_random_seq");
        super.new(name);
    endfunction
    task body();
        dma_seq_item item;
        repeat(num_transfers) begin
            item = dma_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize())
                `uvm_fatal("RAND", "Randomization failed")
            finish_item(item);
            `uvm_info("SEQ",
                $sformatf("Random: %s", item.convert2string()),
                UVM_MEDIUM)
        end
    endtask
endclass

class dma_base_test extends uvm_test;

    `uvm_component_utils(dma_base_test)

    dma_env env;

    function new(string name = "dma_base_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = dma_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        dma_single_seq seq;
        phase.raise_objection(this);
        `uvm_info("TEST", "Starting single transfer test", UVM_LOW)
        seq = dma_single_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
        #5000;
        phase.drop_objection(this);
    endtask

endclass

class dma_multichannel_test extends dma_base_test;

    `uvm_component_utils(dma_multichannel_test)

    function new(string name = "dma_multichannel_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        dma_multichannel_seq seq;
        phase.raise_objection(this);
        `uvm_info("TEST", "Starting multi-channel test", UVM_LOW)
        seq = dma_multichannel_seq::type_id::create("seq");
        seq.start(env.agent.sequencer);
        #10000;
        phase.drop_objection(this);
    endtask

endclass

class dma_random_test extends dma_base_test;

    `uvm_component_utils(dma_random_test)

    function new(string name = "dma_random_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        dma_random_seq seq;
        phase.raise_objection(this);
        `uvm_info("TEST", "Starting random test", UVM_LOW)
        seq = dma_random_seq::type_id::create("seq");
        seq.num_transfers = 20;
        seq.start(env.agent.sequencer);
        #50000;
        phase.drop_objection(this);
    endtask

endclass

module tb_uvm_top;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter NUM_CH     = 4;

    logic clk;
    logic rst_n;

    axil_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) cfg_if(.clk(clk), .rst_n(rst_n));

    axi_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) mem_if(.clk(clk), .rst_n(rst_n));

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

    axi_mem_model u_mem (
        .clk(clk),
        .rst_n(rst_n),
        .mem_if(mem_if)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n          = 0;
        cfg_if.awvalid = 0;
        cfg_if.wvalid  = 0;
        cfg_if.bready  = 1;
        cfg_if.arvalid = 0;
        cfg_if.rready  = 1;
        repeat(5) @(posedge clk);
        rst_n = 1;
    end

    initial begin
        uvm_config_db #(virtual axil_if)::set(
            null, "uvm_test_top.*", "vif", cfg_if);
      run_test("dma_random_test");
    end

    initial begin
        $dumpfile("uvm_dma.vcd");
        $dumpvars(0, tb_uvm_top);
    end

endmodule
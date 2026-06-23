module axi_mem_model (

    input logic clk,
    input logic rst_n,

    axi_if mem_if

);

    logic [31:0] mem [0:255];

    logic [31:0] write_addr;

    always_ff @(posedge clk or negedge rst_n) begin

        if(!rst_n) begin

            mem_if.arready <= 0;
            mem_if.rvalid  <= 0;

            mem_if.awready <= 0;
            mem_if.wready  <= 0;

            mem_if.bvalid  <= 0;

        end

        else begin

            //----------------------------------
            // READ CHANNEL
            //----------------------------------

            if(mem_if.arvalid) begin

                mem_if.arready <= 1;

                mem_if.rdata  <= mem[mem_if.araddr[9:2]];
                mem_if.rvalid <= 1;
                mem_if.rlast  <= 1;

            end

            else begin

                mem_if.arready <= 0;

                if(mem_if.rready)
                    mem_if.rvalid <= 0;

            end

            //----------------------------------
            // WRITE ADDRESS
            //----------------------------------

            if(mem_if.awvalid) begin

                mem_if.awready <= 1;
                write_addr <= mem_if.awaddr;

            end

            else begin

                mem_if.awready <= 0;

            end

            //----------------------------------
            // WRITE DATA
            //----------------------------------

            if(mem_if.wvalid) begin

                mem_if.wready <= 1;

                mem[write_addr[9:2]] <= mem_if.wdata;

                mem_if.bvalid <= 1;

            end

            else begin

                mem_if.wready <= 0;

                if(mem_if.bready)
                    mem_if.bvalid <= 0;

            end

        end

    end

endmodule
module axi4_lite_slave (

    axil_if cfg_if,

    output logic [31:0] wr_addr,
    output logic [31:0] wr_data,
    output logic        wr_en,

    output logic [31:0] rd_addr,
    output logic        rd_en,
    input  logic [31:0] rd_data
  
);

endmodule
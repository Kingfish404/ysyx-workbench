`include "npc_macro.v"

module ysyx_BUS_ARBITER(
  input clk, rst,

  // ifu
  input reg [DATA_W-1:0] ifu_araddr,
  input reg ifu_arvalid,
  output reg ifu_arready_o,

  output reg [DATA_W-1:0] ifu_rdata_o,
  output reg [1:0] ifu_rresp_o,
  output reg ifu_rvalid_o,
  input ifu_rready

  // lsu
);
  parameter ADDR_W = 32, DATA_W = 32;

  reg [ADDR_W-1:0] araddr;
  reg arvalid;
  wire arready_o;
  wire [DATA_W-1:0] rdata_o;

  wire [1:0] rresp_o;
  wire rvalid_o;
  reg rready;

  reg [ADDR_W-1:0] awaddr;
  reg awvalid;
  wire awready_o;

  reg [DATA_W-1:0] wdata;
  reg [7:0] wstrb;
  reg wvalid;
  wire wready_o;

  wire [1:0] bresp_o;
  reg bvalid_o, bready;

  assign arvalid = ifu_arvalid;

  assign awvalid = 0;
  assign wvalid = 0;

  always @(*) begin
    araddr = 0;
    ifu_arready_o = 0;

    ifu_rdata_o = 0;
    ifu_rresp_o = 0;
    ifu_rvalid_o = 0;
    rready = 0;
    if (ifu_arvalid) begin
      araddr = ifu_araddr;
      ifu_arready_o = arready_o;

      ifu_rdata_o = rdata_o;
      ifu_rresp_o = rresp_o;
      ifu_rvalid_o = rvalid_o;
      rready = ifu_rready;
    end
  end

  reg [19:0] lfsr = 1;
  wire ifsr_ready = `ysyx_IFSR_ENABLE ? lfsr[19] : 1;
  always @(posedge clk ) begin lfsr <= {lfsr[18:0], lfsr[19] ^ lfsr[18]}; end
  ysyx_MEM_SRAM #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) ifu_sram(
    .clk(clk),
    .araddr(araddr), .arvalid(arvalid), .arready_o(arready_o),
    .rdata_o(rdata_o), .rresp_o(rresp_o), .rvalid_o(rvalid_o), .rready(rready),
    .awaddr(awaddr), .awvalid(awvalid), .awready_o(awready_o),
    .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready_o(wready_o),
    .bresp_o(bresp_o), .bvalid_o(bvalid_o), .bready(bready)
  );
endmodule

module ysyx_MEM_SRAM(
  input clk,

  input [ADDR_W-1:0] araddr,
  input arvalid,
  output reg arready_o,

  output reg [DATA_W-1:0] rdata_o,
  output reg [1:0] rresp_o,
  output reg rvalid_o,
  input rready,

  input [ADDR_W-1:0] awaddr,
  input awvalid,
  output reg awready_o,

  input [DATA_W-1:0] wdata,
  input [7:0] wstrb,
  input wvalid,
  output reg wready_o,

  output reg [1:0] bresp_o,
  output reg bvalid_o,
  input bready
);
  parameter ADDR_W = 32, DATA_W = 32;

  reg [31:0] mem_rdata_buf [0:1];
  reg [19:0] lfsr = 101;
  wire ifsr_ready = `ysyx_IFSR_ENABLE ? lfsr[19] : 1;
  always @(posedge clk ) begin lfsr <= {lfsr[18:0], lfsr[19] ^ lfsr[18]}; end
  always @(posedge clk) begin
    mem_rdata_buf <= {0, 0};
    if (arvalid & !rvalid_o & rready) begin
      if (ifsr_ready)
      begin
        pmem_read(araddr, mem_rdata_buf[0]);
        rdata_o <= mem_rdata_buf[0];
        rvalid_o <= 1;
      end
    end else if (wvalid & !wready_o & bready) begin
      if (ifsr_ready)
      begin
        pmem_write(awaddr, wdata, wstrb);
        wready_o <= 1;
      end
    end else begin
      rvalid_o <= 0;
      wready_o <= 0;
    end
  end
endmodule //ysyx_EXU_LSU_SRAM

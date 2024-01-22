`include "npc_macro.v"

module ysyx_IFU (
  input clk, rst,

  input prev_valid, next_ready,
  output valid_o, ready_o,

  input lsu_valid,

  // for bus
  output [DATA_W-1:0] ifu_araddr_o,
  output ifu_arvalid_o,
  input ifu_arready,

  input [DATA_W-1:0] ifu_rdata,
  input [1:0] ifu_rresp,
  input ifu_rvalid,
  output ifu_rready_o,

  input [ADDR_W-1:0] pc, npc,
  output [DATA_W-1:0] inst_o,
  output reg [DATA_W-1:0] pc_o
);
  parameter ADDR_W = 32;
  parameter DATA_W = 32;

  reg [DATA_W-1:0] inst_ifu = 0;
  reg state, valid;
  `ysyx_BUS_FSM()
  always @(posedge clk) begin
    if (rst) begin
      valid <= 0; pvalid <= 1; inst_ifu <= 0;
    end
    else begin
      pc_o <= pc;
      if (ifu_rvalid) begin inst_ifu <= ifu_rdata; end
      if (state == `ysyx_IDLE) begin
        if (prev_valid) begin pvalid <= prev_valid; end
        if (ifu_rvalid) begin valid <= 1; end
      end else if (state == `ysyx_WAIT_READY) begin
        if (next_ready == 1) begin pvalid <= 0; valid <= 0; end
      end
    end
  end
  assign ready_o = !valid_o;

  reg [19:0] lfsr = 1;
  wire ifsr_ready = `ysyx_IFSR_ENABLE ? lfsr[19] : 1;
  always @(posedge clk ) begin lfsr <= {lfsr[18:0], lfsr[19] ^ lfsr[18]}; end
  wire arvalid;
  reg pvalid;
  assign arvalid = (ifsr_ready & (prev_valid)) | pvalid;
  wire arready, awready, rready, wready, bvalid;
  wire [1:0] rresp, bresp;

  assign ifu_araddr_o = prev_valid ? npc : pc;
  assign ifu_arvalid_o = arvalid;
  assign arready = ifu_arready;
  assign inst_o = ifu_rvalid ? ifu_rdata : inst_ifu;
  assign rresp = ifu_rresp;
  assign valid_o = ifu_rvalid | valid;
  assign ifu_rready_o = ifsr_ready;

  // ysyx_MEM_SRAM #(.ADDR_W(ADDR_W), .DATA_W(DATA_W)) ifu_sram(
  //   .clk(clk),
  //   .araddr(prev_valid ? npc : araddr), .arvalid(arvalid), .arready_o(arready),
  //   .rdata_o(inst_o), .rresp_o(rresp), .rvalid_o(valid_o), .rready(ifsr_ready),
  //   .awaddr(0), .awvalid(0), .awready_o(awready),
  //   .wdata(0), .wstrb(0), .wvalid(0), .wready_o(wready),
  //   .bresp_o(bresp), .bvalid_o(bvalid), .bready(0)
  // );
endmodule // ysyx_IFU

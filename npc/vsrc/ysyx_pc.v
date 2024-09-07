`include "ysyx_macro.vh"
`include "ysyx_macro_soc.vh"
`include "ysyx_macro_dpi_c.vh"

module ysyx_pc (
    input clk,
    input rst,
    input prev_valid,
    input use_exu_npc,
    input branch_retire,
    input [DATA_W-1:0] npc_wdata,
    output [DATA_W-1:0] npc_o,
    output change_o,
    output retire_o
);
  parameter bit [7:0] DATA_W = `YSYX_W_WIDTH;
  wire [DATA_W-1:0] npc = pc + 4;
  reg  [DATA_W-1:0] pc;
  reg valid, retire;
  assign change_o = valid | (use_exu_npc);
  assign retire_o = retire;
  assign npc_o = use_exu_npc ? npc_wdata : pc;

  always @(posedge clk) begin
    if (rst) begin
      pc <= `YSYX_PC_INIT;
      valid <= 1;
      `YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF
    end else if (prev_valid) begin
      pc <= npc;
      if (use_exu_npc) begin
        pc <= npc_wdata;
        valid <= 1;
      end else if (branch_retire) begin
        retire <= 1;
      end
    end else begin
      valid  <= 0;
      retire <= 0;
    end
  end
endmodule  //ysyx_PC

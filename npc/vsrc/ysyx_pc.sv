`include "ysyx_soc.svh"
`include "ysyx_dpi_c.svh"

module ysyx_pc (
    input clk,
    input rst,

    input good_speculation,
    input bad_speculation,
    input [DATA_W-1:0] pc_ifu,

    input branch_change,
    input branch_retire,
    input [DATA_W-1:0] npc_wdata,
    output [DATA_W-1:0] npc_o,
    output change_o,
    output retire_o,

    input prev_valid
);
  parameter bit [7:0] DATA_W = `YSYX_W_WIDTH;
  reg [DATA_W-1:0] pc;
  reg change, retire;
  assign change_o = change;
  assign retire_o = retire;
  assign npc_o = pc;

  always @(posedge clk) begin
    if (rst) begin
      pc <= `YSYX_PC_INIT;
      change <= 1;
      `YSYX_DPI_C_NPC_DIFFTEST_SKIP_REF
    end else if (prev_valid & !bad_speculation) begin
      change <= branch_change;
      retire <= branch_retire;
      pc <= branch_change ? npc_wdata : pc + 4;
    end else begin
      change <= 0;
      retire <= 0;
      if (good_speculation) begin
        pc <= pc_ifu;
      end
    end
  end
endmodule  //ysyx_PC

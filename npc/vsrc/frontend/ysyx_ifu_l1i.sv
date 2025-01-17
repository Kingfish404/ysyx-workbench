`include "ysyx.svh"
`include "ysyx_soc.svh"

module ysyx_ifu_l1i #(
    parameter bit [7:0] XLEN = `YSYX_XLEN,
    parameter bit [7:0] L1I_LINE_LEN = `YSYX_L1I_LINE_LEN,
    parameter bit [7:0] L1I_LINE_SIZE = 2 ** L1I_LINE_LEN,
    parameter bit [7:0] L1I_LEN = `YSYX_L1I_LEN,
    parameter bit [7:0] L1I_SIZE = 2 ** L1I_LEN
) (
    input clock,

    input [XLEN-1:0] pc_ifu,
    input ifu_rvalid,
    input [XLEN-1:0] ifu_rdata,
    input invalid_l1i,

    output [XLEN-1:0] out_ifu_araddr,
    output out_ifu_arvalid,
    output out_ifu_required,

    output [XLEN-1:0] out_inst,
    output l1i_valid,
    output l1i_ready,

    input reset
);

  logic [32-1:0] l1i[L1I_SIZE][L1I_LINE_SIZE];
  logic [L1I_SIZE-1:0] l1ic_valid = 0;
  logic [32-L1I_LEN-L1I_LINE_LEN-2-1:0] l1i_tag[L1I_SIZE][L1I_LINE_SIZE];
  logic [2:0] l1i_state = 0;

  logic [32-L1I_LEN-L1I_LINE_LEN-2-1:0] addr_tag = pc_ifu[XLEN-1:L1I_LEN+L1I_LINE_LEN+2];
  logic [L1I_LEN-1:0] addr_idx = pc_ifu[L1I_LEN+L1I_LINE_LEN+2-1:L1I_LINE_LEN+2];
  logic [L1I_LINE_LEN-1:0] addr_offset = pc_ifu[L1I_LINE_LEN+2-1:2];

  logic l1i_cache_hit;
  logic ifu_sdram_arburst;

  assign l1i_valid = l1i_cache_hit;
  assign l1i_ready = (l1i_state == 'b000);

  assign out_ifu_araddr = (l1i_state == 'b00 || l1i_state == 'b01) ?
    (pc_ifu & ~'h4) :
    (pc_ifu | 'h4);
  assign out_ifu_arvalid = ifu_sdram_arburst ?
    !l1i_cache_hit && (l1i_state == 'b000 || l1i_state == 'b001) :
    !l1i_cache_hit && (l1i_state != 'b010 && l1i_state != 'b100);
  assign out_ifu_required = (l1i_state != 'b000);

  assign l1i_cache_hit = (
         (l1i_state == 'b000 || l1i_state == 'b100) &&
         l1ic_valid[addr_idx] == 1'b1) && (l1i_tag[addr_idx][addr_offset] == addr_tag);
  assign ifu_sdram_arburst = `YSYX_I_SDRAM_ARBURST && (pc_ifu >= 'ha0000000) && (pc_ifu <= 'hc0000000);

  assign out_inst = l1i[addr_idx][addr_offset];

  always @(posedge clock) begin
    if (reset) begin
      l1i_state  <= 'b000;
      l1ic_valid <= 0;
    end else begin
      unique case (l1i_state)
        'b000: begin
          if (invalid_l1i) begin
            l1ic_valid <= 0;
          end
          if (out_ifu_arvalid) begin
            l1i_state <= 'b001;
          end
        end
        'b001:
        if (ifu_rvalid && !l1i_cache_hit) begin
          if (ifu_sdram_arburst) begin
            l1i_state <= 'b011;
          end else begin
            l1i_state <= 'b010;
          end
          l1i[addr_idx][0] <= ifu_rdata;
          l1i_tag[addr_idx][0] <= addr_tag;
        end
        'b010: begin
          l1i_state <= 'b011;
        end
        'b011: begin
          if (ifu_rvalid) begin
            l1i_state <= 'b100;
            l1i[addr_idx][1] <= ifu_rdata;
            l1i_tag[addr_idx][1] <= addr_tag;
            l1ic_valid[addr_idx] <= 1'b1;
          end
        end
        'b100: begin
          l1i_state <= 'b000;
        end
        default begin
          l1i_state <= 'b000;
        end
      endcase
    end
  end
endmodule

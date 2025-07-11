`include "ysyx.svh"
`include "ysyx_soc.svh"

module ysyx_ifu_l1i #(
    parameter bit [7:0] XLEN = `YSYX_XLEN,
    parameter bit [`YSYX_L1I_LEN:0] L1I_LINE_LEN = `YSYX_L1I_LINE_LEN,
    parameter bit [`YSYX_L1I_LEN:0] L1I_LINE_SIZE = 2 ** L1I_LINE_LEN,
    parameter bit [`YSYX_L1I_LEN:0] L1I_LEN = `YSYX_L1I_LEN,
    parameter bit [`YSYX_L1I_LEN:0] L1I_SIZE = 2 ** L1I_LEN
) (
    input clock,

    input [XLEN-1:0] pc_ifu,
    output [XLEN-1:0] out_inst,
    output l1i_valid,
    output l1i_ready,

    input invalid_l1i,
    input flush_pipe,

    input bus_ifu_ready,
    output [XLEN-1:0] out_ifu_araddr,
    output out_ifu_arvalid,
    input [XLEN-1:0] ifu_rdata,
    input ifu_rvalid,

    input reset
);
  typedef enum logic [2:0] {
    IDLE = 3'b000,
    RD_0 = 3'b001,
    WAIT = 3'b010,
    RD_1 = 3'b011,
    WB_0 = 3'b100,
    NULL = 3'b111
  } l1i_state_t;
  logic [XLEN-1:0] l1i_pc;
  logic [32-1:0] l1i[L1I_SIZE][L1I_LINE_SIZE];
  logic [L1I_SIZE-1:0] l1ic_valid;
  logic [32-{{2'b0}, L1I_LEN+L1I_LINE_LEN}-2-1:0] l1i_tag[L1I_SIZE][L1I_LINE_SIZE];
  l1i_state_t l1i_state;

  logic [32-{{2'b0}, L1I_LEN+L1I_LINE_LEN}-2-1:0] addr_tag;
  logic [L1I_LEN-1:0] addr_idx;
  logic [L1I_LINE_LEN-1:0] addr_offset;

  logic hit;
  logic ifu_sdram_arburst;
  logic received_flush_pipe;
  logic received_fence_i;
  logic [XLEN-1:0] reverse_pc_ifu;

  assign l1i_pc = received_flush_pipe ? reverse_pc_ifu : pc_ifu;
  assign l1i_valid = ((hit && !flush_pipe) && (!received_flush_pipe && !received_fence_i));
  assign l1i_ready = (l1i_state == IDLE);
  assign addr_tag = l1i_pc[XLEN-1:L1I_LEN+L1I_LINE_LEN+2];
  assign addr_idx = l1i_pc[L1I_LEN+L1I_LINE_LEN+2-1:L1I_LINE_LEN+2];
  assign addr_offset = l1i_pc[L1I_LINE_LEN+2-1:2];

  assign out_ifu_araddr = (l1i_state == IDLE || l1i_state == RD_0) ?
    (l1i_pc & ~'h4) :
    (l1i_pc | 'h4);
  assign out_ifu_arvalid = (ifu_sdram_arburst ?
    !hit && (l1i_state == IDLE || l1i_state == RD_0) :
    !hit && (l1i_state != WAIT && l1i_state != WB_0));

  assign hit = !invalid_l1i && (
         (l1i_state == IDLE || l1i_state == WB_0) &&
         l1ic_valid[addr_idx] == 1'b1) && (l1i_tag[addr_idx][addr_offset] == addr_tag);
  assign ifu_sdram_arburst = (`YSYX_I_SDRAM_ARBURST &&
    (l1i_pc >= 'ha0000000) && (l1i_pc <= 'hc0000000));

  assign out_inst = l1i[addr_idx][addr_offset];

  always @(posedge clock) begin
    if (reset) begin
      l1i_state  <= IDLE;
      l1ic_valid <= 0;
    end else begin
      if ((!hit) && flush_pipe) begin
        received_flush_pipe <= 1;
        reverse_pc_ifu <= pc_ifu;
      end
      if ((!hit) && invalid_l1i) begin
        received_fence_i <= 1;
      end
      unique case (l1i_state)
        IDLE: begin
          if (out_ifu_arvalid && bus_ifu_ready) begin
            l1i_state <= RD_0;
          end
        end
        RD_0:
        if (ifu_rvalid) begin
          if (ifu_sdram_arburst) begin
            l1i_state <= RD_1;
          end else begin
            l1i_state <= WAIT;
          end
        end
        WAIT: begin
          l1i_state <= RD_1;
        end
        RD_1: begin
          if (ifu_rvalid) begin
            l1i_state <= WB_0;
          end
        end
        WB_0: begin
          l1i_state <= IDLE;
          received_flush_pipe <= 0;
          if (received_fence_i) begin
            l1ic_valid <= 0;
            received_fence_i <= 0;
          end
        end
        default begin
          l1i_state <= IDLE;
          received_flush_pipe <= 0;
        end
      endcase
    end
  end

  always @(posedge clock) begin
    if (reset) begin
    end else begin
      if (ifu_rvalid) begin
        l1i[addr_idx][l1i_state==RD_0?0 : 1] <= ifu_rdata;
        l1i_tag[addr_idx][l1i_state==RD_0?0 : 1] <= addr_tag;
        if (l1i_state == RD_1) begin
          l1ic_valid[addr_idx] <= 1'b1;
        end
      end
    end
  end
endmodule

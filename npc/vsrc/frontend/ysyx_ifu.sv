`include "ysyx.svh"
`include "ysyx_soc.svh"

module ysyx_ifu #(
    parameter bit [7:0] XLEN = `YSYX_XLEN,
    parameter bit [$clog2(`YSYX_BTB_SIZE):0] BTB_SIZE = `YSYX_BTB_SIZE
) (
    input clock,

    input [XLEN-1:0] npc,
    input [XLEN-1:0] rpc,
    input sys_retire,

    output [XLEN-1:0] out_inst,
    output [XLEN-1:0] out_pc,
    output [XLEN-1:0] out_pnpc,

    input flush_pipeline,
    input fence_time,

    // for bus
    input bus_ifu_ready,
    output [XLEN-1:0] out_ifu_araddr,
    output out_ifu_arvalid,
    output out_ifu_lock,
    input [XLEN-1:0] ifu_rdata,
    input ifu_rvalid,

    // for iqu
    input fence_i,

    input  prev_valid,
    input  next_ready,
    output out_valid,
    output out_ready,

    input reset
);
  logic [XLEN-1:0] pc_ifu;
  logic [XLEN-1:0] bpu_npc;
  logic ifu_sys_hazard;

  logic [XLEN-1:0] btb, btb_jal;
  logic [XLEN-1:0] bpu_btb[BTB_SIZE];
  logic [BTB_SIZE-1:0] bpu_btb_valid;
  logic [$clog2(BTB_SIZE)-1:0] rpc_idx, pc_idx;
  logic speculation, ifu_b_speculation;

  logic ifu_hazard;
  logic [6:0] opcode;
  logic is_jalr, is_jal, is_b, is_br;
  logic is_sys;
  logic valid;

  logic invalid_l1i;
  logic l1i_valid;
  logic l1i_ready;
  logic [XLEN-1:0] l1_inst;

  assign ifu_hazard = ifu_sys_hazard;
  assign out_inst = l1_inst;
  assign opcode = out_inst[6:0];
  // pre decode
  assign is_jalr = (opcode == `YSYX_OP_JALR__);
  assign is_jal = (opcode == `YSYX_OP_JAL___);
  assign is_b = (opcode == `YSYX_OP_B_TYPE_);
  assign is_br = (is_jal || is_jalr || is_b);
  assign is_sys = (opcode == `YSYX_OP_SYSTEM) || (opcode == `YSYX_OP_FENCE_);

  assign valid = (l1i_valid && !ifu_hazard) && !flush_pipeline;
  assign out_valid = valid;
  assign out_ready = !valid;

  // BTFN (Backward Taken, Forward Not-taken), jalr is always not taken
  assign bpu_npc = (is_br && bpu_btb_valid[pc_idx] ? btb : pc_ifu + 4);
  assign btb = bpu_btb[pc_idx];
  assign rpc_idx = rpc[$clog2(BTB_SIZE)-1+2:2];
  assign pc_idx = pc_ifu[$clog2(BTB_SIZE)-1+2:2];

  assign out_pc = pc_ifu;
  assign out_pnpc = bpu_npc;
  always @(posedge clock) begin
    if (reset) begin
      pc_ifu <= `YSYX_PC_INIT;
      ifu_sys_hazard <= 0;
      bpu_btb_valid <= 0;
    end else begin
      if (flush_pipeline) begin
        pc_ifu <= npc;
        ifu_sys_hazard <= 0;
        bpu_btb[rpc_idx] <= npc;
        if (fence_time) begin
          bpu_btb_valid <= 0;
        end else begin
          bpu_btb_valid[rpc_idx] <= 1;
        end
      end else begin
        if (prev_valid && sys_retire) begin
          ifu_sys_hazard <= 0;
          pc_ifu <= npc;
        end
        if (next_ready && valid) begin
          pc_ifu <= bpu_npc;
          if (is_sys) begin
            ifu_sys_hazard <= 1;
          end
        end
      end
    end
  end

  ysyx_ifu_l1i l1i_cache (
      .clock(clock),

      .pc_ifu(pc_ifu),
      .out_inst(l1_inst),
      .l1i_valid(l1i_valid),
      .l1i_ready(l1i_ready),
      .invalid_l1i(fence_i),
      .flush_pipeline(flush_pipeline),

      // <=> bus
      .bus_ifu_ready(bus_ifu_ready),
      .out_ifu_lock(out_ifu_lock),
      .out_ifu_araddr(out_ifu_araddr),
      .out_ifu_arvalid(out_ifu_arvalid),
      .ifu_rdata(ifu_rdata),
      .ifu_rvalid(ifu_rvalid),

      .reset(reset)
  );
endmodule

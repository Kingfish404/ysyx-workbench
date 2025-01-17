`include "ysyx.svh"
`include "ysyx_soc.svh"

module ysyx_ifu #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,

    input [XLEN-1:0] npc,

    input pc_change,
    input pc_retire,
    input load_retire,

    output [XLEN-1:0] out_inst,
    output [XLEN-1:0] out_pc,

    output out_flush_pipeline,

    // for bus
    output [XLEN-1:0] out_ifu_araddr,
    output out_ifu_arvalid,
    output out_ifu_required,
    input [XLEN-1:0] ifu_rdata,
    input ifu_rvalid,

    input  prev_valid,
    input  next_ready,
    output out_valid,
    output out_ready,

    input reset
);
  logic [XLEN-1:0] pc_ifu;
  logic ifu_lsu_hazard = 0, ifu_branch_hazard = 0;

  logic [XLEN-1:0] btb, btb_jal;
  logic [XLEN-1:0] ifu_speculation;
  logic speculation, bad_speculation, ifu_b_speculation;

  logic ifu_hazard;
  logic [6:0] opcode;
  logic is_jalr, is_jal, is_b_type, is_branch, is_load, is_store, is_fencei, is_sys;
  logic valid;
  logic good_speculationing, bad_speculationing;

  logic invalid_l1i;
  logic l1i_valid;
  logic l1i_ready;

  assign ifu_hazard = ifu_lsu_hazard || ifu_branch_hazard;
  assign opcode = out_inst[6:0];
  assign is_jalr = (opcode == `YSYX_OP_JALR__);
  assign is_jal = (opcode == `YSYX_OP_JAL___);
  assign is_b_type = (opcode == `YSYX_OP_B_TYPE_);
  assign is_branch = (is_jal || is_jalr || is_b_type);
  assign is_load = (opcode == `YSYX_OP_IL_TYPE);
  assign is_store = (opcode == `YSYX_OP_S_TYPE_);
  assign is_fencei = (out_inst == `YSYX_INST_FENCE_I);  // fence.i is system instruction
  assign is_sys = (opcode == `YSYX_OP_SYSTEM);

  assign valid =(l1i_valid && !ifu_hazard) &&
   !bad_speculation && !(speculation && (is_load || is_store));
  assign out_valid = valid;
  assign out_ready = !valid;

  // Branch Prediction
  assign out_flush_pipeline = bad_speculation || bad_speculationing;
  assign good_speculationing = ((pc_change || pc_retire) && npc == ifu_speculation);
  assign bad_speculationing = (speculation) && ((pc_change || pc_retire) && npc != ifu_speculation);

  assign out_pc = pc_ifu;
  always @(posedge clock) begin
    if (reset) begin
      btb <= `YSYX_PC_INIT;
      btb_jal <= `YSYX_PC_INIT;
      pc_ifu <= `YSYX_PC_INIT;
      speculation <= 0;
      ifu_lsu_hazard <= 0;
      ifu_branch_hazard <= 0;
    end else begin
      if (prev_valid) begin
        if (speculation) begin
          if (good_speculationing) begin
            speculation <= 0;
            ifu_b_speculation <= 0;
          end
          if ((bad_speculationing)) begin
            bad_speculation <= 1;
            speculation <= 0;
          end
        end
      end
      if (bad_speculationing || pc_change) begin
        btb <= npc;
        if (ifu_b_speculation) begin
        end else begin
          btb_jal <= npc;
        end
      end
      if (bad_speculation && next_ready && l1i_ready) begin
        bad_speculation <= 0;
        ifu_branch_hazard <= 0;
        ifu_b_speculation <= 0;
        pc_ifu <= npc;
      end
      if (!speculation) begin
        if (ifu_branch_hazard && (pc_change || pc_retire) && l1i_ready) begin
          ifu_branch_hazard <= 0;
          pc_ifu <= npc;
        end
        if (ifu_lsu_hazard && load_retire && l1i_ready) begin
          ifu_lsu_hazard <= 0;
          pc_ifu <= pc_ifu + 4;
        end
      end
      if (!(bad_speculation || bad_speculationing) && next_ready == 1 && valid) begin
        if (!is_branch && !is_load && !is_sys) begin
          pc_ifu <= pc_ifu + 4;
        end else begin
          if (is_branch) begin
            // jalr is always not taken
            if (!speculation) begin
              // BTFN (Backward Taken, Forward Not-taken)
              if (is_b_type && (btb < pc_ifu)) begin
                speculation <= 1;
                ifu_b_speculation <= 1;
                ifu_speculation <= btb;
                pc_ifu <= btb;
              end else if (is_jal && (btb_jal < pc_ifu)) begin
                speculation <= 1;
                ifu_speculation <= btb_jal;
                pc_ifu <= btb_jal;
              end else begin
                ifu_branch_hazard <= 1;
              end
            end else begin
              ifu_branch_hazard <= 1;
            end
          end else if (is_load) begin
            ifu_lsu_hazard <= 1;
          end else if (is_sys) begin
            ifu_branch_hazard <= 1;
          end
        end
      end
    end
  end

  assign invalid_l1i = valid && next_ready && is_fencei;

  ysyx_ifu_l1i l1i_cache (
      .clock(clock),

      .pc_ifu(pc_ifu),
      .ifu_rvalid(ifu_rvalid),
      .ifu_rdata(ifu_rdata),
      .invalid_l1i(invalid_l1i),

      .out_ifu_araddr  (out_ifu_araddr),
      .out_ifu_arvalid (out_ifu_arvalid),
      .out_ifu_required(out_ifu_required),

      .out_inst (out_inst),
      .l1i_valid(l1i_valid),
      .l1i_ready(l1i_ready),

      .reset(reset)
  );
endmodule

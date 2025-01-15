`include "ysyx.svh"
`include "ysyx_if.svh"

module ysyx_exu #(
    parameter bit [7:0] XLEN = `YSYX_XLEN
) (
    input clock,

    // from idu
    idu_pipe_if.in idu_if,
    input flush_pipeline,

    // for lsu
    output logic out_ren,
    output logic out_wen,
    output logic [XLEN-1:0] out_rwaddr,
    output out_lsu_avalid,
    output [4:0] out_alu_op,
    output [XLEN-1:0] out_lsu_mem_wdata,

    // from lsu
    input [XLEN-1:0] lsu_rdata,
    input lsu_exu_rvalid,
    input lsu_exu_wready,

    output logic [31:0] out_inst,
    output [XLEN-1:0] out_pc,

    output [XLEN-1:0] out_reg_wdata,
    output out_load_retire,

    output [XLEN-1:0] out_npc_wdata,
    output out_branch_change,
    output out_branch_retire,

    output logic out_ebreak,
    output logic [`YSYX_REG_LEN-1:0] out_rd,

    input prev_valid,
    input next_ready,
    output logic out_valid,
    output logic out_ready,

    input reset
);
  logic [XLEN-1:0] reg_wdata, reg_wdata_mul, mepc, mtvec;
  logic [XLEN-1:0] imm_exu, pc_exu, src1, src2, addr_exu;
  logic [XLEN-1:0] mem_wdata = src2;
  logic [  12-1:0] csr_addr0;
  logic [XLEN-1:0] csr_wdata, csr_rdata;
  logic is_mul;
  logic [XLEN-1:0] inst_exu;
  logic [4:0] alu_op_exu;
  logic [`YSYX_REG_LEN-1:0] rd;
  logic csr_wen_exu;
  logic jen, ben, ren, wen, ebreak;
  logic ecall, mret;
  logic [XLEN-1:0] mem_rdata;
  logic branch_change, system_exu;
  logic [2:0] func3;

  logic alu_valid, mul_valid, lsu_avalid;
  logic lsu_valid;
  logic ready;
  logic valid;

  ysyx_exu_csr csrs (
      .clock(clock),
      .reset(reset),

      .wen(csr_wen_exu),
      .exu_valid(valid),
      .ecall(ecall),
      .mret(mret),

      .rwaddr(csr_addr0),
      .wdata(csr_wdata),
      .pc(pc_exu),

      .out_rdata(csr_rdata),
      .out_mepc (mepc),
      .out_mtvec(mtvec)
  );

  assign is_mul = (alu_op_exu[4:4] == 1);
  assign out_reg_wdata = {XLEN{(rd != 0)}} & (
    (ren) ? mem_rdata :
    (jen) ? (pc_exu + 4) :
    (system_exu) ? csr_rdata :
    (is_mul) ? reg_wdata_mul: reg_wdata);
  assign csr_addr0 = (imm_exu[11:0]);
  assign out_alu_op = alu_op_exu;
  assign out_branch_change = branch_change;
  assign out_pc = pc_exu;
  assign out_inst = inst_exu;
  assign out_rwaddr = src1 + imm_exu;
  assign out_ren = ren, out_wen = wen, out_ebreak = ebreak;
  assign out_rd = rd;

  assign addr_exu = (jen ? src1 : pc_exu) + imm_exu;

  assign valid = (wen || ren) ? lsu_valid : (is_mul ? mul_valid : alu_valid);
  assign out_valid = valid;
  assign out_ready = ready && next_ready;
  always @(posedge clock) begin
    if (reset || flush_pipeline) begin
      alu_valid <= 0;
      lsu_avalid <= 0;
      lsu_valid <= 0;
      alu_op_exu <= 0;
      ready <= 1;
    end else begin
      if (prev_valid && ready) begin
        pc_exu <= idu_if.pc;
        inst_exu <= idu_if.inst;
        imm_exu <= idu_if.imm;
        src1 <= idu_if.op1;
        src2 <= idu_if.op2;
        alu_op_exu <= idu_if.alu_op;

        rd <= idu_if.rd;
        ren <= idu_if.ren;
        wen <= idu_if.wen;
        jen <= idu_if.jen;
        ben <= idu_if.ben;

        func3 <= idu_if.func3;
        system_exu <= idu_if.system;
        csr_wen_exu <= idu_if.csr_wen;
        ebreak <= idu_if.ebreak;
        ecall <= idu_if.ecall;
        mret <= idu_if.mret;

        if (idu_if.wen || idu_if.ren) begin
          lsu_avalid <= 1;
          ready <= 0;
        end
        if (idu_if.alu_op[4:4] == 1) begin
          ready <= 0;
        end
      end
      if (is_mul) begin
        alu_valid <= 0;
        if (mul_valid) begin
          ready <= 1;
          alu_op_exu <= 0;
        end
      end else begin
        alu_valid <= 1;
      end
      if (next_ready == 1) begin
        lsu_valid <= 0;
        if (prev_valid == 0) begin
          alu_valid <= 0;
        end
      end
      if (wen) begin
        if (lsu_exu_wready) begin
          lsu_valid <= 1;
          lsu_avalid <= 0;
          ready <= 1;
        end
      end
      if (ren) begin
        if (lsu_exu_rvalid) begin
          lsu_valid <= 1;
          lsu_avalid <= 0;
          mem_rdata <= lsu_rdata;
          ready <= 1;
        end
      end
    end
  end

  assign out_lsu_avalid = lsu_avalid;
  assign out_lsu_mem_wdata = mem_wdata;

  // alu for I Extension
  ysyx_exu_alu alu (
      .s1(src1),
      .s2(src2),
      .op(alu_op_exu),
      .out_r(reg_wdata)
  );

`ifdef YSYX_M_EXTENSION
  // alu for M Extension
  ysyx_exu_mul mul (
      .clock(clock),
      .in_a(idu_if.op1),
      .in_b(idu_if.op2),
      .in_op(idu_if.alu_op),
      .in_valid(prev_valid && ready),
      .out_r(reg_wdata_mul),
      .out_valid(mul_valid)
  );
`endif

  // csr
  assign csr_wdata = (
    ({XLEN{(func3 == `YSYX_F3_CSRRW_) || (func3 == `YSYX_F3_CSRRWI)}} & src1) |
    ({XLEN{(func3 == `YSYX_F3_CSRRS_) || (func3 == `YSYX_F3_CSRRSI)}} & (csr_rdata | src1)) |
    ({XLEN{(func3 == `YSYX_F3_CSRRC_) || (func3 == `YSYX_F3_CSRRCI)}} & (csr_rdata & ~src1)) |
    (0)
  );

  // branch
  assign out_branch_retire = ((system_exu) || (ben) || (ren));
  assign out_load_retire = (ren) && valid;
  assign out_npc_wdata = (ecall) ? mtvec : (mret) ? mepc : (branch_change ? addr_exu : pc_exu + 4);

  always_comb begin
    if (ben) begin
      case (alu_op_exu)
        `YSYX_ALU_SUB_: begin
          branch_change = (~|reg_wdata);
        end
        `YSYX_ALU_XOR_, `YSYX_ALU_SLT_, `YSYX_ALU_SLTU, `YSYX_ALU_SLE_, `YSYX_ALU_SLEU: begin
          branch_change = (|reg_wdata);
        end
        default: begin
          branch_change = 0;
        end
      endcase
    end else begin
      branch_change = (ecall || mret || jen);
    end
  end

endmodule

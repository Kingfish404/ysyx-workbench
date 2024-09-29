
module ysyx_idu (
    input clk,
    input rst,

    input [31:0] inst,
    input [BIT_W-1:0] rdata1,
    input [BIT_W-1:0] rdata2,
    input [BIT_W-1:0] pc,
    input speculation,

    input exu_valid,
    input [BIT_W-1:0] exu_forward,
    input [3:0] exu_forward_rd,

    idu_pipe_if idu_if,

    output en_j_o,
    output ren_o,
    output wen_o,
    output system_o,
    output system_func3_o,
    output csr_wen_o,
    output ebreak_o,
    output reg [BIT_W-1:0] op1_o,
    output reg [BIT_W-1:0] op2_o,
    output wire [BIT_W-1:0] op_j_o,
    output reg [31:0] imm_o,
    output reg [3:0] rs1_o,
    output reg [3:0] rs2_o,
    output reg [3:0] rd_o,
    output reg [3:0] alu_op_o,
    output [BIT_W-1:0] pc_o,
    output [31:0] inst_o,
    output speculation_o,

    input [16-1:0] rf_table,

    input prev_valid,
    input next_ready,
    output reg valid_o,
    output reg ready_o
);
  parameter bit [7:0] BIT_W = 32;

  reg [31:0] inst_idu, pc_idu;
  reg valid, ready;
  // wire [4:0] rs1 = inst_idu[19:15], rs2 = inst_idu[24:20], rd = inst_idu[11:7];
  wire [ 3:0] rs1 = inst_idu[18:15], rs2 = inst_idu[23:20], rd = inst_idu[10:7];
  wire [31:0] imm;
  wire wen, ren;
  wire idu_hazard = valid & (
    opcode != `YSYX_OP_LUI & opcode != `YSYX_OP_AUIPC & opcode != `YSYX_OP_JAL &
    ((rf_table[rs1[4-1:0]] == 1) & !(exu_valid & rs1[4-1:0] == exu_forward_rd)) |
    ((rf_table[rs2[4-1:0]] == 1) & !(exu_valid & rs2[4-1:0] == exu_forward_rd)) |
    (0)
    );
  wire [BIT_W-1:0] reg_rdata1 = exu_valid & rs1[4-1:0] == exu_forward_rd ? exu_forward : rdata1;
  wire [BIT_W-1:0] reg_rdata2 = exu_valid & rs2[4-1:0] == exu_forward_rd ? exu_forward : rdata2;
  wire [6:0] opcode = inst_idu[6:0];
  assign valid_o = valid & !idu_hazard;
  assign ready_o = ready & !idu_hazard & next_ready;
  assign inst_o = inst_idu;
  assign pc_o = pc_idu;
  assign imm_o = imm;
  assign ren_o = ren;
  assign wen_o = wen;

  reg state;
  `YSYX_BUS_FSM()
  always @(posedge clk) begin
    if (rst) begin
      valid <= 0;
      ready <= 1;
    end else begin
      if (prev_valid & ready & !idu_hazard & next_ready) begin
        inst_idu <= inst;
        pc_idu <= pc;
        speculation_o <= speculation;
      end
      if (state == `YSYX_IDLE) begin
        if (prev_valid & ready & !idu_hazard & next_ready) begin
          valid <= 1;
          if (idu_hazard) begin
            ready <= 0;
          end
        end
      end else if (state == `YSYX_WAIT_READY) begin
        if (next_ready == 1) begin
          ready <= 1;
          if (prev_valid & ready_o & next_ready) begin
          end else begin
            valid <= 0;
            inst_idu <= 0;
          end
        end
      end
    end
  end

  assign op_j_o = (
    {BIT_W{opcode == `YSYX_OP_JAL | opcode == `YSYX_OP_B_TYPE}} & pc_idu |
    {BIT_W{opcode == `YSYX_OP_JALR | opcode == `YSYX_OP_IL_TYPE | opcode == `YSYX_OP_S_TYPE}}
      & reg_rdata1 |
    (0)
  );
  assign rs1_o = rs1;
  assign rs2_o = rs2;
  assign idu_if.rd = rd_o;
  assign idu_if.imm = imm_o;

  ysyx_idu_decoder idu_de (
      .clock(clk),
      .reset(rst),

      .in_inst(inst_idu),
      .in_pc  (pc_idu),
      .in_rs1v(reg_rdata1),
      .in_rs2v(reg_rdata2),

      .out_rd(rd_o),
      .out_imm(imm),
      .out_op1(op1_o),
      .out_op2(op2_o),
      .out_wen(wen),
      .out_ren(ren),
      .out_alu_op(alu_op_o),
      .out_en_j(en_j_o),

      .out_sys_ebreak(ebreak_o),
      .out_sys_system_func3_zero(system_func3_o),
      .out_sys_csr_wen(csr_wen_o),
      .out_sys_system(system_o)
  );
endmodule  // ysyx_IDU

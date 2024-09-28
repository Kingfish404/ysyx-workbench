`include "ysyx_macro.svh"
`include "ysyx_macro_csr.svh"

module ysyx_exu (
    input clk,
    input rst,

    // for bus
    output lsu_avalid_o,
    output [BIT_W-1:0] lsu_mem_wdata_o,
    input [BIT_W-1:0] lsu_rdata,
    input lsu_exu_rvalid,
    input lsu_exu_wready,

    input [31:0] inst,
    output reg [31:0] inst_o,
    output [BIT_W-1:0] pc_o,

    input ren,
    input wen,
    input system,
    input system_func3,
    input csr_wen,
    input ebreak,

    input [3:0] rd,
    input [BIT_W-1:0] imm,
    input [BIT_W-1:0] op1,
    input [BIT_W-1:0] op2,
    input [BIT_W-1:0] op_j,
    input [BIT_W-1:0] rwaddr,
    input [3:0] alu_op,
    input [BIT_W-1:0] pc,
    input speculation,

    output [BIT_W-1:0] reg_wdata_o,
    output [BIT_W-1:0] npc_wdata_o,
    output use_exu_npc_o,
    output branch_retire_o,
    output ebreak_o,
    output reg [3:0] rd_o,
    output [3:0] alu_op_o,
    output reg [BIT_W-1:0] rwaddr_o,
    output reg ren_o,
    output reg wen_o,
    output reg speculation_o,

    input prev_valid,
    input next_ready,
    output reg valid_o,
    output reg ready_o
);
  parameter bit [7:0] BIT_W = `YSYX_W_WIDTH;

  wire [BIT_W-1:0] addr_data, reg_wdata, mepc, mtvec;
  wire [BIT_W-1:0] mem_wdata = src2;
  wire [12-1:0] csr_addr, csr_addr_add1;
  wire [BIT_W-1:0] csr_wdata1, csr_rdata;
  wire [BIT_W-1:0] csr_wdata;
  reg [BIT_W-1:0] imm_exu, pc_exu, src1, src2, addr_exu;
  reg [BIT_W-1:0] inst_exu;
  reg [3:0] alu_op_exu;
  reg [6:0] opcode_exu = inst_exu[6:0];
  reg csr_wen_exu;
  wire csr_ecallen;
  reg [BIT_W-1:0] mem_rdata;
  reg use_exu_npc, system_exu, system_func3_exu;
  reg [2:0] func3 = inst_exu[14:12];

  ysyx_exu_csr csr (
      .clk(clk),
      .rst(rst),
      .wen(csr_wen_exu),
      .exu_valid(valid_o),
      .ecallen(csr_ecallen),
      .waddr(csr_addr),
      .wdata(csr_wdata),
      .waddr_add1(csr_addr_add1),
      .wdata_add1(csr_wdata1),
      .rdata_o(csr_rdata),
      .mepc_o(mepc),
      .mtvec_o(mtvec)
  );

  assign reg_wdata_o = {BIT_W{(rd_o != 0)}} & (
    (opcode_exu == `YSYX_OP_IL_TYPE) ? mem_rdata :
    (system_exu) ? csr_rdata : reg_wdata);
  assign csr_addr = ((system_func3_exu) && imm_exu ==
      `YSYX_OP_SYSTEM_ECALL
      ?
      `YSYX_CSR_MCAUSE
      : (system_func3_exu) && imm_exu ==
      `YSYX_OP_SYSTEM_MRET
      ?
      `YSYX_CSR_MSTATUS
      : (imm_exu[11:0]));
  assign csr_addr_add1 = (
    ((system_func3_exu) && imm_exu == `YSYX_OP_SYSTEM_ECALL)
    ? `YSYX_CSR_MEPC: (0));
  assign addr_data = addr_exu;
  assign alu_op_o = alu_op_exu;
  assign use_exu_npc_o = use_exu_npc & valid_o;
  assign pc_o = pc_exu;
  assign inst_o = inst_exu;

  reg state, alu_valid, lsu_avalid;
  reg lsu_valid = 0;
  reg busy = 0;
  assign valid_o = (wen_o | ren_o) ? lsu_valid : alu_valid;
  assign ready_o = !busy | lsu_valid;
  `YSYX_BUS_FSM()
  always @(posedge clk) begin
    if (rst) begin
      alu_valid <= 0;
      lsu_avalid <= 0;
      busy <= 0;
    end else begin
      // if (state == `YSYX_IDLE) begin
      if (prev_valid & ready_o) begin
        inst_exu <= inst;
        imm_exu <= imm;
        pc_exu <= pc;
        src1 <= op1;
        src2 <= op2;
        alu_op_exu <= alu_op;
        addr_exu <= op_j + imm;
        rd_o <= rd;
        ren_o <= ren;
        wen_o <= wen;

        system_exu <= system;
        system_func3_exu <= system_func3;
        csr_wen_exu <= csr_wen;
        ebreak_o <= ebreak;

        alu_valid <= 1;
        speculation_o <= speculation;
        if (wen | ren) begin
          lsu_avalid <= 1;
          busy <= 1;
          rwaddr_o <= op1 + imm;
        end
      end
      // end
      // else if (state == `YSYX_WAIT_READY) begin
      if (next_ready == 1) begin
        lsu_valid <= 0;
        // use_exu_npc <= 0;
        if (prev_valid == 0) begin
          alu_valid <= 0;
        end
      end
      // end
      if (lsu_valid & !(wen | ren)) begin
        busy <= 0;
      end
      if (wen_o) begin
        if (lsu_exu_wready) begin
          lsu_valid  <= 1;
          lsu_avalid <= 0;
        end
      end
      if (ren_o) begin
        if (lsu_exu_rvalid) begin
          lsu_valid  <= 1;
          lsu_avalid <= 0;
          mem_rdata  <= lsu_rdata;
        end
      end
    end
  end

  assign lsu_avalid_o = lsu_avalid;
  assign lsu_mem_wdata_o = mem_wdata;

  // alu unit for reg_wdata
  ysyx_exu_alu alu (
      .alu_src1(src1),
      .alu_src2(src2),
      .alu_op(alu_op_exu),
      .alu_res_o(reg_wdata)
  );

  // branch/system unit
  assign csr_wdata1 = ((system_func3_exu) && imm_exu == `YSYX_OP_SYSTEM_ECALL) ? pc_exu : 'h0;
  assign csr_ecallen = (
    ((system_exu) && (system_func3_exu))
    && imm_exu == `YSYX_OP_SYSTEM_ECALL);
  assign csr_wdata = {BIT_W{(system_exu)}} & (
    ({BIT_W{((system_func3_exu) && (imm_exu == `YSYX_OP_SYSTEM_ECALL))}} & 'hb) |
    ({BIT_W{((system_func3_exu) && (imm_exu == `YSYX_OP_SYSTEM_MRET))}} &
     {{csr_rdata[BIT_W-1:'h8]}, 1'b1, {csr_rdata[6:4]}, csr_rdata['h7], csr_rdata[2:0]}) |
    ({BIT_W{((func3 == `YSYX_OP_SYSTEM_CSRRW))}} & src1) |
    ({BIT_W{((func3 == `YSYX_OP_SYSTEM_CSRRS))}} & (csr_rdata | src1)) |
    ({BIT_W{((func3 == `YSYX_OP_SYSTEM_CSRRC))}} & (csr_rdata & ~src1)) |
    ({BIT_W{((func3 == `YSYX_OP_SYSTEM_CSRRWI))}} & src1) |
    ({BIT_W{((func3 == `YSYX_OP_SYSTEM_CSRRSI))}} & (csr_rdata | src1)) |
    ({BIT_W{((func3 == `YSYX_OP_SYSTEM_CSRRCI))}} & (csr_rdata & ~src1))
  );
  assign branch_retire_o = (
    (system_exu) | (opcode_exu == `YSYX_OP_B_TYPE) |
    (opcode_exu == `YSYX_OP_IL_TYPE)
  );

  always_comb begin
    if (system_exu & system_func3_exu) begin
      case (imm_exu)
        `YSYX_OP_SYSTEM_ECALL: begin
          npc_wdata_o = mtvec;
        end
        `YSYX_OP_SYSTEM_MRET: begin
          npc_wdata_o = mepc;
        end
        default: begin
          npc_wdata_o = addr_data;
        end
      endcase
    end else begin
      npc_wdata_o = addr_data;
    end
  end

  always_comb begin
    case (opcode_exu)
      `YSYX_OP_SYSTEM: begin
        if (system_func3_exu) begin
          case (imm_exu)
            `YSYX_OP_SYSTEM_ECALL: begin
              use_exu_npc = 1;
            end
            `YSYX_OP_SYSTEM_MRET: begin
              use_exu_npc = 1;
            end
            default: begin
              use_exu_npc = 0;
            end
          endcase
        end else begin
          use_exu_npc = 0;
        end
      end
      `YSYX_OP_JAL, `YSYX_OP_JALR: begin
        use_exu_npc = 1;
      end
      `YSYX_OP_B_TYPE: begin
        // $display("reg_wdata: %h, npc_wdata: %h, npc: %h", reg_wdata, npc_wdata, npc);
        case (alu_op_exu)
          `YSYX_ALU_OP_SUB: begin
            use_exu_npc = (~|reg_wdata);
          end
          `YSYX_ALU_OP_XOR: begin
            use_exu_npc = (|reg_wdata);
          end
          `YSYX_ALU_OP_SLT: begin
            use_exu_npc = (|reg_wdata);
          end
          `YSYX_ALU_OP_SLTU: begin
            use_exu_npc = (|reg_wdata);
          end
          `YSYX_ALU_OP_SLE: begin
            use_exu_npc = (|reg_wdata);
          end
          `YSYX_ALU_OP_SLEU: begin
            use_exu_npc = (|reg_wdata);
          end
          default: begin
            use_exu_npc = 0;
          end
        endcase
      end
      `YSYX_OP_IL_TYPE: begin
        use_exu_npc = 0;
      end
      default: begin
        use_exu_npc = 0;
      end
    endcase
  end

endmodule  // ysyx_EXU
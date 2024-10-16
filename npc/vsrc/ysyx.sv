`include "ysyx.svh"
`include "ysyx_if.svh"
`include "ysyx_soc.svh"
`include "ysyx_dpi_c.svh"

module ysyx (
    input clock,
    input reset,

    // AXI4 Slave
    input [1:0] io_slave_arburst,
    input [2:0] io_slave_arsize,
    input [7:0] io_slave_arlen,
    input [3:0] io_slave_arid,
    input [ADDR_W-1:0] io_slave_araddr,
    input io_slave_arvalid,
    output reg io_slave_arready,

    output reg [3:0] io_slave_rid,
    output reg io_slave_rlast,
    output reg [63:0] io_slave_rdata,
    output reg [1:0] io_slave_rresp,
    output reg io_slave_rvalid,
    input io_slave_rready,

    input [1:0] io_slave_awburst,
    input [2:0] io_slave_awsize,
    input [7:0] io_slave_awlen,
    input [3:0] io_slave_awid,
    input [ADDR_W-1:0] io_slave_awaddr,
    input io_slave_awvalid,
    output reg io_slave_awready,

    input io_slave_wlast,
    input [63:0] io_slave_wdata,
    input [7:0] io_slave_wstrb,
    input io_slave_wvalid,
    output reg io_slave_wready,

    output reg [3:0] io_slave_bid,
    output reg [1:0] io_slave_bresp,
    output reg io_slave_bvalid,
    input io_slave_bready,

    // AXI4 Master
    output [1:0] io_master_arburst,
    output [2:0] io_master_arsize,
    output [7:0] io_master_arlen,
    output [3:0] io_master_arid,
    output [ADDR_W-1:0] io_master_araddr,
    output io_master_arvalid,
    input reg io_master_arready,

    input reg [3:0] io_master_rid,
    input reg io_master_rlast,
    input reg [63:0] io_master_rdata,
    input reg [1:0] io_master_rresp,
    input reg io_master_rvalid,
    output io_master_rready,

    output [1:0] io_master_awburst,
    output [2:0] io_master_awsize,
    output [7:0] io_master_awlen,
    output [3:0] io_master_awid,
    output [ADDR_W-1:0] io_master_awaddr,
    output io_master_awvalid,
    input reg io_master_awready,

    output io_master_wlast,
    output [63:0] io_master_wdata,
    output [7:0] io_master_wstrb,
    output io_master_wvalid,
    input reg io_master_wready,

    input reg [3:0] io_master_bid,
    input reg [1:0] io_master_bresp,
    input reg io_master_bvalid,
    output io_master_bready,

    input io_interrupt
);
  parameter bit [7:0] DATA_W = `YSYX_W_WIDTH;
  parameter bit [7:0] ADDR_W = `YSYX_W_WIDTH;
  parameter bit [7:0] REG_ADDR_W = 4;
  // PC unit output
  wire [DATA_W-1:0] npc, pc;
  wire pc_change, pc_retire;

  // REGS output
  wire [DATA_W-1:0] reg_rdata1, reg_rdata2;
  wire [16-1:0] rf_table;

  // IFU output
  wire [31:0] inst;
  wire [DATA_W-1:0] pc_ifu;
  wire speculation_ifu;
  wire bad_speculation, good_speculation;
  // IFU bus wire
  wire [DATA_W-1:0] ifu_araddr;
  wire ifu_arvalid, ifu_required;
  wire [DATA_W-1:0] ifu_rdata;
  wire ifu_rvalid;
  wire ifu_valid, ifu_ready;

  // IDU output
  wire [REG_ADDR_W-1:0] rs1, rs2;
  idu_pipe_if idu_if (.clk(clock));
  wire idu_valid, idu_ready;

  // LSU output
  wire [DATA_W-1:0] lsu_rdata;
  wire lsu_exu_rvalid, lsu_exu_wready;
  wire [DATA_W-1:0] lsu_araddr;
  wire lsu_arvalid;
  wire [DATA_W-1:0] lsu_awaddr;
  wire lsu_awvalid;
  wire [DATA_W-1:0] lsu_wdata;
  wire [7:0] lsu_rstrb, lsu_wstrb;
  wire lsu_wvalid;

  // EXU output
  wire [31:0] inst_exu, pc_exu;
  wire [DATA_W-1:0] reg_wdata;
  wire [DATA_W-1:0] npc_wdata;
  wire branch_change, branch_retire, ebreak, load_retire;
  wire [REG_ADDR_W-1:0] rd_exu;
  wire [3:0] alu_op_exu;
  wire ren_exu, wen_exu;
  wire [DATA_W-1:0] rwaddr_exu;
  wire speculation_exu;
  wire exu_valid, exu_ready;

  // WBU output
  wire wbu_valid, wbu_ready;
  wire [31:0] pc_wbu;

  // BUS output
  wire [DATA_W-1:0] bus_lsu_rdata;
  wire lsu_avalid;
  wire [DATA_W-1:0] lsu_mem_wdata;
  wire lsu_rvalid;
  wire lsu_wready;

  ysyx_pc pc_unit (
      .clk(clock),
      .rst(reset),

      .good_speculation(good_speculation),
      .bad_speculation(bad_speculation),
      .pc_ifu(pc_ifu),

      .npc_wdata(npc_wdata),
      .branch_change(branch_change),
      .branch_retire(branch_retire),
      .npc_o(npc),
      .change_o(pc_change),
      .retire_o(pc_retire),

      .prev_valid(exu_valid)
  );

  ysyx_reg regs (
      .clk(clock),
      .rst(reset),

      .idu_valid(idu_valid & exu_ready),
      .rd(idu_if.rd),

      .bad_speculation(bad_speculation),
      .reg_write_en(exu_valid & bad_speculation == 0),
      .waddr(rd_exu),
      .wdata(reg_wdata),

      .s1addr(rs1),
      .s2addr(rs2),
      .rf_table_o(rf_table),
      .src1_o(reg_rdata1),
      .src2_o(reg_rdata2)
  );

  ysyx_bus bus (
      .clk(clock),
      .rst(reset),

      .io_master_arburst(io_master_arburst),
      .io_master_arsize(io_master_arsize),
      .io_master_arlen(io_master_arlen),
      .io_master_arid(io_master_arid),
      .io_master_araddr(io_master_araddr),
      .io_master_arvalid(io_master_arvalid),
      .io_master_arready(io_master_arready),

      .io_master_rid(io_master_rid),
      .io_master_rlast(io_master_rlast),
      .io_master_rdata(io_master_rdata),
      .io_master_rresp(io_master_rresp),
      .io_master_rvalid(io_master_rvalid),
      .io_master_rready(io_master_rready),

      .io_master_awburst(io_master_awburst),
      .io_master_awsize(io_master_awsize),
      .io_master_awlen(io_master_awlen),
      .io_master_awid(io_master_awid),
      .io_master_awaddr(io_master_awaddr),
      .io_master_awvalid(io_master_awvalid),
      .io_master_awready(io_master_awready),

      .io_master_wlast (io_master_wlast),
      .io_master_wdata (io_master_wdata),
      .io_master_wstrb (io_master_wstrb),
      .io_master_wvalid(io_master_wvalid),
      .io_master_wready(io_master_wready),

      .io_master_bid(io_master_bid),
      .io_master_bresp(io_master_bresp),
      .io_master_bvalid(io_master_bvalid),
      .io_master_bready(io_master_bready),

      .ifu_araddr  (ifu_araddr),
      .ifu_arvalid (ifu_arvalid),
      .ifu_required(ifu_required),
      .ifu_rdata_o (ifu_rdata),
      .ifu_rvalid_o(ifu_rvalid),

      .lsu_araddr(lsu_araddr),
      .lsu_arvalid(lsu_arvalid),
      .lsu_rstrb(lsu_rstrb),
      .lsu_rdata_o(bus_lsu_rdata),
      .lsu_rvalid_o(lsu_rvalid),

      .lsu_awaddr(lsu_awaddr),
      .lsu_awvalid(lsu_awvalid),
      .lsu_wdata(lsu_wdata),
      .lsu_wstrb(lsu_wstrb),
      .lsu_wvalid(lsu_wvalid),
      .lsu_wready_o(lsu_wready)
  );

  // IFU(Instruction Fetch Unit): 负责根据当前PC从存储器中取出一条指令
  ysyx_ifu ifu (
      .clk(clock),
      .rst(reset),

      .ifu_araddr_o(ifu_araddr),
      .ifu_arvalid_o(ifu_arvalid),
      .ifu_required_o(ifu_required),
      .ifu_rdata(ifu_rdata),
      .ifu_rvalid(ifu_rvalid),

      .npc(npc),
      .inst_o(inst),
      .pc_o(pc_ifu),

      .pc(pc_wbu),
      .pc_change(pc_change),
      .pc_retire(pc_retire),
      .load_retire(load_retire),

      .speculation_o(speculation_ifu),
      .bad_speculation_o(bad_speculation),
      .good_speculation_o(good_speculation),

      .prev_valid(wbu_valid),
      .next_ready(idu_ready),
      .valid_o(ifu_valid),
      .ready_o(ifu_ready)
  );

  // IDU(Instruction Decode Unit): 负责对当前指令进行译码, 准备执行阶段需要使用的数据和控制信号
  ysyx_idu idu (
      .clk(clock),
      .rst(reset),

      .inst(inst),
      .rdata1(reg_rdata1),
      .rdata2(reg_rdata2),
      .pc(pc_ifu),
      .speculation(speculation_ifu),

      .exu_valid(exu_valid),
      .exu_forward(reg_wdata),
      .exu_forward_rd(rd_exu),

      .rs1_o(rs1),
      .rs2_o(rs2),

      .idu_if(idu_if),

      .rf_table(rf_table),

      .prev_valid(ifu_valid & bad_speculation == 0),
      .next_ready(exu_ready),
      .valid_o(idu_valid),
      .ready_o(idu_ready)
  );

  // EXU(EXecution Unit): 负责根据控制信号对数据进行执行操作, 并将执行结果写回寄存器或存储器
  ysyx_exu exu (
      .clk(clock),
      .rst(reset),

      .idu_if(idu_if),

      // to lsu
      .ren_o(ren_exu),
      .wen_o(wen_exu),
      .rwaddr_o(rwaddr_exu),
      .lsu_avalid_o(lsu_avalid),
      .alu_op_o(alu_op_exu),
      .lsu_mem_wdata_o(lsu_mem_wdata),

      // from lsu
      .lsu_rdata(lsu_rdata),
      .lsu_exu_rvalid(lsu_exu_rvalid),
      .lsu_exu_wready(lsu_exu_wready),

      .inst_o(inst_exu),
      .pc_o  (pc_exu),

      .reg_wdata_o(reg_wdata),
      .npc_wdata_o(npc_wdata),
      .branch_change_o(branch_change),
      .branch_retire_o(branch_retire),
      .load_retire_o(load_retire),

      .ebreak_o(ebreak),
      .rd_o(rd_exu),
      .speculation_o(speculation_exu),

      .prev_valid(idu_valid & bad_speculation == 0),
      .next_ready(wbu_ready),
      .valid_o(exu_valid),
      .ready_o(exu_ready)
  );

  // LSU(Load/Store Unit): 负责对存储器进行读写操作
  ysyx_lsu lsu (
      .clk(clock),
      .rst(reset),
      // from exu
      .addr(rwaddr_exu),
      .ren(ren_exu),
      .wen(wen_exu),
      .lsu_avalid(lsu_avalid),
      .alu_op(alu_op_exu),
      .wdata(lsu_mem_wdata),
      // to exu
      .rdata_o(lsu_rdata),
      .rvalid_o(lsu_exu_rvalid),
      .wready_o(lsu_exu_wready),

      // to-from bus load
      .lsu_araddr_o(lsu_araddr),
      .lsu_arvalid_o(lsu_arvalid),
      .lsu_rstrb_o(lsu_rstrb),
      .lsu_rdata(bus_lsu_rdata),
      .lsu_rvalid(lsu_rvalid),

      // to-from bus store
      .lsu_awaddr_o(lsu_awaddr),
      .lsu_awvalid_o(lsu_awvalid),
      .lsu_wdata_o(lsu_wdata),
      .lsu_wstrb_o(lsu_wstrb),
      .lsu_wvalid_o(lsu_wvalid),
      .lsu_wready(lsu_wready)
  );

  // WBU (Write Back Unit): 指示EXU结果是否已经写回寄存器
  ysyx_wbu wbu (
      .clk(clock),
      .rst(reset),

      .inst(inst_exu),
      .pc  (pc_exu),

      .ebreak(ebreak),
      .pc_o  (pc_wbu),

      .prev_valid(exu_valid & bad_speculation == 0),
      .next_ready(ifu_ready),
      .valid_o(wbu_valid),
      .ready_o(wbu_ready)
  );

endmodule  // top

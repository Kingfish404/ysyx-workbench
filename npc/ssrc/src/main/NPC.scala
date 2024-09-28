package npc

import chisel3._
import chisel3.util._
import chisel3.util.experimental.decode._
import scala.annotation.switch

trait InstrType {
  def N__ = "0000"
  def R__ = "0101"
  def I__ = "0100"
  def S__ = "0010"
  def B__ = "0001"
  def U__ = "0110"
  def J__ = "0111"
  def A__ = "1110"
  def CSR = "1111"
}

trait MicroOP {
  def ALU_ADD_ = "0000"
  def ALU_SUB_ = "1000"
  def ALU_SLT_ = "0010"
  def ALU_SLE_ = "1010"
  def ALU_SLTU = "0011"
  def ALU_SLEU = "1011"
  def ALU_XOR_ = "0100"
  def ALU_OR__ = "0110"
  def ALU_AND_ = "0111"
  def ALU_NAND = "1111"
  def ALU_SLL_ = "0001"
  def ALU_SRL_ = "0101"
  def ALU_SRA_ = "1101"
}

trait Instr {
  def LUI_OPCODE = "b0110111".U(7.W)
  def AUIPC_OPCODE = "b0010111".U(7.W)

  def LUI___ = BitPat("b??????? ????? ????? ??? ????? 0110111")
  def AUIPC_ = BitPat("b??????? ????? ????? ??? ????? 0010111")
  def JAL___ = BitPat("b??????? ????? ????? ??? ????? 1101111")
  def JALR__ = BitPat("b??????? ????? ????? 000 ????? 1100111")

  def BEQ___ = BitPat("b??????? ????? ????? 000 ????? 1100011")
  def BNE___ = BitPat("b??????? ????? ????? 001 ????? 1100011")
  def BLT___ = BitPat("b??????? ????? ????? 100 ????? 1100011")
  def BGE___ = BitPat("b??????? ????? ????? 101 ????? 1100011")
  def BLTU__ = BitPat("b??????? ????? ????? 110 ????? 1100011")
  def BGEU__ = BitPat("b??????? ????? ????? 111 ????? 1100011")

  def LB____ = BitPat("b??????? ????? ????? 000 ????? 0000011")
  def LH____ = BitPat("b??????? ????? ????? 001 ????? 0000011")
  def LW____ = BitPat("b??????? ????? ????? 010 ????? 0000011")

  def LBU___ = BitPat("b??????? ????? ????? 100 ????? 0000011")
  def LHU___ = BitPat("b??????? ????? ????? 101 ????? 0000011")

  def SB____ = BitPat("b??????? ????? ????? 000 ????? 0100011")
  def SH____ = BitPat("b??????? ????? ????? 001 ????? 0100011")
  def SW____ = BitPat("b??????? ????? ????? 010 ????? 0100011")

  def ADDI__ = BitPat("b??????? ????? ????? 000 ????? 0010011")
  def SLTI__ = BitPat("b??????? ????? ????? 010 ????? 0010011")
  def SLTIU_ = BitPat("b??????? ????? ????? 011 ????? 0010011")
  def XORI__ = BitPat("b??????? ????? ????? 100 ????? 0010011")
  def ORI___ = BitPat("b??????? ????? ????? 110 ????? 0010011")
  def ANDI__ = BitPat("b??????? ????? ????? 111 ????? 0010011")

  def SLLI__ = BitPat("b0000000 ????? ????? 001 ????? 0010011")
  def SRLI__ = BitPat("b0000000 ????? ????? 101 ????? 0010011")
  def SRAI__ = BitPat("b0100000 ????? ????? 101 ????? 0010011")

  def ADD___ = BitPat("b0000000 ????? ????? 000 ????? 0110011")
  def SUB___ = BitPat("b0100000 ????? ????? 000 ????? 0110011")
  def SLL___ = BitPat("b0000000 ????? ????? 001 ????? 0110011")
  def SLT___ = BitPat("b0000000 ????? ????? 010 ????? 0110011")
  def SLTU__ = BitPat("b0000000 ????? ????? 011 ????? 0110011")
  def XOR___ = BitPat("b0000000 ????? ????? 100 ????? 0110011")
  def SRL___ = BitPat("b0000000 ????? ????? 101 ????? 0110011")
  def SRA___ = BitPat("b0100000 ????? ????? 101 ????? 0110011")
  def OR____ = BitPat("b0000000 ????? ????? 110 ????? 0110011")
  def AND___ = BitPat("b0000000 ????? ????? 111 ????? 0110011")

  def FENCE_ = BitPat("b0000??? ????? 00000 000 00000 0001111")
  def FENCET = BitPat("b1000001 10011 00000 000 00000 0011111")
  def PAUSE_ = BitPat("b0000000 10000 00000 000 00000 0001111")
  def ECALL_ = BitPat("b0000000 00000 00000 000 00000 1110011")

  def EBREAK = BitPat("b0000000 00001 00000 000 00000 1110011")
  def MRET__ = BitPat("b0011000 00010 00000 000 00000 1110011")

  def FENCEI = BitPat("b??????? ????? ????? 001 ????? 0001111")

  def CSRRW_ = BitPat("b??????? ????? ????? 001 ????? 1110011")
  def CSRRS_ = BitPat("b??????? ????? ????? 010 ????? 1110011")
  def CSRRC_ = BitPat("b??????? ????? ????? 011 ????? 1110011")
  def CSRRWI = BitPat("b??????? ????? ????? 101 ????? 1110011")
  def CSRRSI = BitPat("b??????? ????? ????? 110 ????? 1110011")
  def CSRRCI = BitPat("b??????? ????? ????? 111 ????? 1110011")
}

class ysyx_idu_decoder extends Module with InstrType with Instr with MicroOP {
  val in = IO(new Bundle {
    val inst = Input(UInt(32.W))
    val pc = Input(UInt(32.W))
    val rs1v = Input(UInt(32.W))
    val rs2v = Input(UInt(32.W))
  })
  val out = IO(new Bundle {
    val rd = Output(UInt(4.W))
    val imm = Output(UInt(32.W))
    val op1 = Output(UInt(32.W))
    val op2 = Output(UInt(32.W))
    val wen = Output(UInt(1.W))
    val ren = Output(UInt(1.W))
    val alu_op = Output(UInt(4.W))
    val en_j = Output(UInt(1.W))
  })
  val out_sys = IO(new Bundle {
    var ebreak = Output(UInt(1.W))
    val system_func3_zero = Output(UInt(1.W))
    val csr_wen = Output(UInt(1.W))
    val system = Output(UInt(1.W))
  })
  val rd = in.inst(11, 7)
  val opcode = in.inst(6, 0)
  val funct3 = in.inst(14, 12)
  val funct7 = in.inst(31, 25)
  val ALU_F3OP = Cat(0.U(1.W), funct3)
  val ALU_F3_5 = Cat(funct7(5), funct3)

  val imm_i = Cat(Fill(20, in.inst(31)), in.inst(31, 20))
  val imm_s = Cat(Fill(20, in.inst(31)), in.inst(31, 25), in.inst(11, 7))
  val immbv = Cat(in.inst(31), in.inst(7), in.inst(30, 25), in.inst(11, 8))
  val imm_b = Cat(Fill(19, in.inst(31)), immbv, 0.U)
  val imm_u = Cat(in.inst(31, 12), Fill(12, 0.U))
  val immjv = Cat(in.inst(31), in.inst(19, 12), in.inst(20), in.inst(30, 21))
  val imm_j = Cat(Fill(11, in.inst(31)), immjv, 0.U)

  val imm = in.inst(31, 20)
  val csr = in.inst(31, 20)
  // val table = TruthTable(
  //   Map(
  //     ECALL_ -> BitPat("b0111"),
  //     EBREAK -> BitPat("b1111"),
  //     MRET__ -> BitPat("b0111"),
  //     FENCEI -> BitPat("b0001"),
  //     CSRRW_ -> BitPat("b0011"),
  //     CSRRS_ -> BitPat("b0011"),
  //     CSRRC_ -> BitPat("b0011"),
  //     CSRRWI -> BitPat("b0011"),
  //     CSRRSI -> BitPat("b0011"),
  //     CSRRCI -> BitPat("b0011")
  //   ),
  //   BitPat("b0000")
  // )
  val type_decoder = TruthTable(
    Map(
      // format: off
      //                  | type | sys |  ls |  j  |  alu op |
      LUI___ -> BitPat("b" + U__ + "???0" + "00" + "0" + ALU_ADD_),
      AUIPC_ -> BitPat("b" + U__ + "???0" + "00" + "0" + ALU_ADD_),
      JAL___ -> BitPat("b" + J__ + "???0" + "00" + "1" + ALU_ADD_),
      JALR__ -> BitPat("b" + I__ + "???0" + "00" + "1" + ALU_ADD_),
      BEQ___ -> BitPat("b" + B__ + "???0" + "00" + "1" + ALU_SUB_),
      BNE___ -> BitPat("b" + B__ + "???0" + "00" + "1" + ALU_XOR_),
      BLT___ -> BitPat("b" + B__ + "???0" + "00" + "1" + ALU_SLT_),
      BGE___ -> BitPat("b" + B__ + "???0" + "00" + "1" + ALU_SLE_),
      BLTU__ -> BitPat("b" + B__ + "???0" + "00" + "1" + ALU_SLTU),
      BGEU__ -> BitPat("b" + B__ + "???0" + "00" + "1" + ALU_SLEU),
      LB____ -> BitPat("b" + I__ + "???0" + "10" + "0" +   "0000"),
      LH____ -> BitPat("b" + I__ + "???0" + "10" + "0" +   "0001"),
      LW____ -> BitPat("b" + I__ + "???0" + "10" + "0" +   "0010"),
      LBU___ -> BitPat("b" + I__ + "???0" + "10" + "0" +   "0100"),
      LHU___ -> BitPat("b" + I__ + "???0" + "10" + "0" +   "0101"),
      SB____ -> BitPat("b" + S__ + "???0" + "01" + "0" +   "0000"),
      SH____ -> BitPat("b" + S__ + "???0" + "01" + "0" +   "0001"),
      SW____ -> BitPat("b" + S__ + "???0" + "01" + "0" +   "0010"),
      ADDI__ -> BitPat("b" + I__ + "???0" + "00" + "0" +   "0000"),
      SLTI__ -> BitPat("b" + I__ + "???0" + "00" + "0" +   "0010"),
      SLTIU_ -> BitPat("b" + I__ + "???0" + "00" + "0" +   "0011"),
      XORI__ -> BitPat("b" + I__ + "???0" + "00" + "0" +   "0100"),
      ORI___ -> BitPat("b" + I__ + "???0" + "00" + "0" +   "0110"),
      ANDI__ -> BitPat("b" + I__ + "???0" + "00" + "0" +   "0111"),
      SLLI__ -> BitPat("b" + I__ + "???0" + "00" + "0" +   "0001"),
      SRLI__ -> BitPat("b" + I__ + "???0" + "00" + "0" +   "0101"),
      SRAI__ -> BitPat("b" + I__ + "???0" + "00" + "0" +   "1101"),
      ADD___ -> BitPat("b" + R__ + "???0" + "00" + "0" +   "0000"),
      SUB___ -> BitPat("b" + R__ + "???0" + "00" + "0" +   "1000"),
      SLL___ -> BitPat("b" + R__ + "???0" + "00" + "0" +   "0001"),
      SLT___ -> BitPat("b" + R__ + "???0" + "00" + "0" +   "0010"),
      SLTU__ -> BitPat("b" + R__ + "???0" + "00" + "0" +   "0011"),
      XOR___ -> BitPat("b" + R__ + "???0" + "00" + "0" +   "0100"),
      SRL___ -> BitPat("b" + R__ + "???0" + "00" + "0" +   "0101"),
      SRA___ -> BitPat("b" + R__ + "???0" + "00" + "0" +   "1101"),
      OR____ -> BitPat("b" + R__ + "???0" + "00" + "0" +   "0110"),
      AND___ -> BitPat("b" + R__ + "???0" + "00" + "0" +   "0111"),
      FENCE_ -> BitPat("b" + N__ + "???0" + "00" + "0" +   "0000"),
      FENCET -> BitPat("b" + N__ + "???0" + "00" + "0" +   "0000"),
      PAUSE_ -> BitPat("b" + N__ + "???0" + "00" + "0" +   "0000"),
      ECALL_ -> BitPat("b" + N__ + "0111" + "00" + "1" +   "0000"),
      EBREAK -> BitPat("b" + N__ + "1111" + "00" + "1" +   "0000"),
      MRET__ -> BitPat("b" + N__ + "0111" + "00" + "1" +   "0000"),
      FENCEI -> BitPat("b" + N__ + "0001" + "00" + "0" +   "0000"),
      CSRRW_ -> BitPat("b" + CSR + "0011" + "00" + "1" +   "0001"),
      CSRRS_ -> BitPat("b" + CSR + "0011" + "00" + "1" +   "0010"),
      CSRRC_ -> BitPat("b" + CSR + "0011" + "00" + "1" +   "0011"),
      CSRRWI -> BitPat("b" + CSR + "0011" + "00" + "1" +   "0101"),
      CSRRSI -> BitPat("b" + CSR + "0011" + "00" + "1" +   "0110"),
      CSRRCI -> BitPat("b" + CSR + "0011" + "00" + "1" +   "0111")
    // format: on
    ),
    BitPat("b" + N__ + "????" + "00" + "0" + ALU_ADD_)
  )
  val table1 = Array(
    // format: off
    // inst      | rd |  imm |    op1 |    op2 | alu_op |
    LUI___ -> List( rd, imm_u,     0.U,   imm_u), // U__
    AUIPC_ -> List( rd, imm_u,   in.pc,   imm_u), // U__
    JAL___ -> List( rd, imm_j,   in.pc,     4.U), // J__
    JALR__ -> List( rd, imm_i,   in.pc,     4.U), // I__
    BEQ___ -> List(0.U, imm_b, in.rs1v, in.rs2v), // B__
    BNE___ -> List(0.U, imm_b, in.rs1v, in.rs2v), // B__
    BLT___ -> List(0.U, imm_b, in.rs1v, in.rs2v), // B__
    BGE___ -> List(0.U, imm_b, in.rs2v, in.rs1v), // B__
    BLTU__ -> List(0.U, imm_b, in.rs1v, in.rs2v), // B__
    BGEU__ -> List(0.U, imm_b, in.rs2v, in.rs1v), // B__
    LB____ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    LH____ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    LW____ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    LBU___ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    LHU___ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    SB____ -> List(0.U, imm_s, in.rs1v, in.rs2v), // S__
    SH____ -> List(0.U, imm_s, in.rs1v, in.rs2v), // S__
    SW____ -> List(0.U, imm_s, in.rs1v, in.rs2v), // S__
    ADDI__ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    SLTI__ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    SLTIU_ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    XORI__ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    ORI___ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    ANDI__ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    SLLI__ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    SRLI__ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    SRAI__ -> List( rd, imm_i, in.rs1v,   imm_i), // I__
    ADD___ -> List( rd,   0.U, in.rs1v, in.rs2v), // R__
    SUB___ -> List( rd,   0.U, in.rs1v, in.rs2v), // R__
    SLL___ -> List( rd,   0.U, in.rs1v, in.rs2v), // R__
    SLT___ -> List( rd,   0.U, in.rs1v, in.rs2v), // R__
    SLTU__ -> List( rd,   0.U, in.rs1v, in.rs2v), // R__
    XOR___ -> List( rd,   0.U, in.rs1v, in.rs2v), // R__
    SRL___ -> List( rd,   0.U, in.rs1v, in.rs2v), // R__
    SRA___ -> List( rd,   0.U, in.rs1v, in.rs2v), // R__
    OR____ -> List( rd,   0.U, in.rs1v, in.rs2v), // R__
    AND___ -> List( rd,   0.U, in.rs1v, in.rs2v), // R__
    FENCE_ -> List( rd,   imm, in.rs1v,     0.U), // N__
    FENCET -> List( rd,   imm, in.rs1v,     0.U), // N__
    PAUSE_ -> List( rd,   imm, in.rs1v,     0.U), // N__
    ECALL_ -> List( rd,   imm, in.rs1v,     0.U), // N__
    EBREAK -> List( rd,   imm, in.rs1v,     0.U), // N__
    MRET__ -> List( rd,   imm, in.rs1v,     0.U), // N__
    FENCEI -> List( rd,   imm, in.rs1v,     0.U), // N__
    CSRRW_ -> List( rd,   csr,      0.U,    0.U), // CSR
    CSRRS_ -> List( rd,   csr,      0.U,    0.U), // CSR
    CSRRC_ -> List( rd,   csr,      0.U,    0.U), // CSR
    CSRRWI -> List( rd,   csr,      0.U,    0.U), // CSR
    CSRRSI -> List( rd,   csr,      0.U,    0.U), // CSR
    CSRRCI -> List( rd,   csr,      0.U,    0.U)  // CSR
    // format: on
  )
  val var_decoder =
    ListLookup(in.inst, List(0.U, 0.U, 0.U, 0.U), table1)

  out.rd := var_decoder(0)
  out.imm := var_decoder(1)
  out.op1 := var_decoder(2)
  out.op2 := var_decoder(3)

  // val decoded = decoder(in.inst, table)
  val inst_type = decoder(in.inst, type_decoder)
  out.alu_op := inst_type(3, 0)
  out.en_j := inst_type(4)
  out.wen := inst_type(5)
  out.ren := inst_type(6)
  out_sys.system := inst_type(7)
  out_sys.csr_wen := inst_type(8)
  out_sys.system_func3_zero := inst_type(9)
  out_sys.ebreak := inst_type(10)
}

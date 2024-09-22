package gcd

import chisel3._
import chisel3.util.{switch, is}
import chisel3.util.BitPat
import chisel3.util.Cat
import chisel3.util.experimental.decode._
import scala.annotation.switch

trait InstrType {
  def InstrN = "b0000"
  def InstrI = "b0100"
  def InstrR = "b0101"
  def InstrS = "b0010"
  def InstrB = "b0001"
  def InstrU = "b0110"
  def InstrJ = "b0111"
  def InstrA = "b1110"
}

class Decoder extends Module with InstrType {
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
  val table = TruthTable(
    Map(
      ECALL_ -> BitPat("b0111"),
      EBREAK -> BitPat("b1111"),
      MRET__ -> BitPat("b0111"),
      FENCEI -> BitPat("b0001"),
      CSRRW_ -> BitPat("b0011"),
      CSRRS_ -> BitPat("b0011"),
      CSRRC_ -> BitPat("b0011"),
      CSRRWI -> BitPat("b0011"),
      CSRRSI -> BitPat("b0011"),
      CSRRCI -> BitPat("b0011")
    ),
    BitPat("b0000")
  )
  val type_decoder = TruthTable(
    Map(
      LUI___ -> BitPat(InstrU),
      AUIPC_ -> BitPat(InstrU),
      JAL___ -> BitPat(InstrJ),
      JALR__ -> BitPat(InstrI),
      BEQ___ -> BitPat(InstrB),
      BNE___ -> BitPat(InstrB),
      BLT___ -> BitPat(InstrB),
      BGE___ -> BitPat(InstrB),
      BLTU__ -> BitPat(InstrB),
      BGEU__ -> BitPat(InstrB),
      LB____ -> BitPat(InstrI),
      LH____ -> BitPat(InstrI),
      LW____ -> BitPat(InstrI),
      LBU___ -> BitPat(InstrI),
      LHU___ -> BitPat(InstrI),
      SB____ -> BitPat(InstrS),
      SH____ -> BitPat(InstrS),
      SW____ -> BitPat(InstrS),
      ADDI__ -> BitPat(InstrI),
      SLTI__ -> BitPat(InstrI),
      SLTIU_ -> BitPat(InstrI),
      XORI__ -> BitPat(InstrI),
      ORI___ -> BitPat(InstrI),
      ANDI__ -> BitPat(InstrI),
      SLLI__ -> BitPat(InstrI),
      SRLI__ -> BitPat(InstrI),
      SRAI__ -> BitPat(InstrI),
      ADD___ -> BitPat(InstrR),
      SUB___ -> BitPat(InstrR),
      SLL___ -> BitPat(InstrR),
      SLT___ -> BitPat(InstrR),
      SLTU__ -> BitPat(InstrR),
      XOR___ -> BitPat(InstrR),
      SRL___ -> BitPat(InstrR),
      SRA___ -> BitPat(InstrR),
      OR____ -> BitPat(InstrR),
      AND___ -> BitPat(InstrR),
      FENCE_ -> BitPat(InstrN),
      FENCET -> BitPat(InstrN),
      PAUSE_ -> BitPat(InstrN),
      ECALL_ -> BitPat(InstrN),
      EBREAK -> BitPat(InstrN),
      MRET__ -> BitPat(InstrN),
      FENCEI -> BitPat(InstrN),
      CSRRW_ -> BitPat(InstrN),
      CSRRS_ -> BitPat(InstrN),
      CSRRC_ -> BitPat(InstrN),
      CSRRWI -> BitPat(InstrN),
      CSRRSI -> BitPat(InstrN),
      CSRRCI -> BitPat(InstrN)
    ),
    BitPat(InstrN)
  )
  val in = IO(new Bundle {
    val instruction = Input(UInt(32.W))
    val rd = Input(UInt(4.W))
  })
  val out = IO(new Bundle {
    val inst_type = Output(UInt(4.W))
    val rd = Output(UInt(4.W))
  })
  val out_sys = IO(new Bundle {
    var ebreak_o = Output(UInt(1.W))
    val system_func3_zero_o = Output(UInt(1.W))
    val csr_wen_o = Output(UInt(1.W))
    val system_o = Output(UInt(1.W))
  })

  val decoded = decoder(in.instruction, table)
  out_sys.ebreak_o := decoded(3)
  out_sys.system_func3_zero_o := decoded(2)
  out_sys.csr_wen_o := decoded(1)
  out_sys.system_o := decoded(0)

  val inst_type = decoder(in.instruction, type_decoder)
  val wire = Wire(UInt(4.W))
  wire := inst_type
  out.inst_type := inst_type
  out.rd := 0.U
  switch(wire) {
    is(InstrR.U) { out.rd := in.rd; }
    is(InstrI.U) { out.rd := in.rd; }
    is(InstrS.U) {}
    is(InstrB.U) {}
    is(InstrU.U) { out.rd := in.rd; }
    is(InstrJ.U) { out.rd := in.rd; }
    is(InstrN.U) { out.rd := in.rd; }
  }
}

/** Compute GCD using subtraction method. Subtracts the smaller from the larger
  * until register y is zero. value in register x is then the GCD
  */
class GCD extends Module {
  val io = IO(new Bundle {
    val value1 = Input(UInt(16.W))
    val value2 = Input(UInt(16.W))
    val loadingValues = Input(Bool())
    val outputGCD = Output(UInt(16.W))
    val outputValid = Output(Bool())
  })

  val x = Reg(UInt())
  val y = Reg(UInt())

  when(x > y) { x := x - y }.otherwise { y := y - x }

  when(io.loadingValues) {
    x := io.value1
    y := io.value2
  }

  io.outputGCD := x
  io.outputValid := y === 0.U
}

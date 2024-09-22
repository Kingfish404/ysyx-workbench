package gcd

import chisel3._
import chisel3.util.{switch, is, Cat, Fill}
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

  def InstrCSR = "b1111"
}

trait Instr {
  def LUI_OPCODE = 0b0110111.U
  def AUIPC_OPCODE = 0b0010111.U

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

class ysyx_idu_decoder extends Module with InstrType with Instr {
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
      CSRRW_ -> BitPat(InstrCSR),
      CSRRS_ -> BitPat(InstrCSR),
      CSRRC_ -> BitPat(InstrCSR),
      CSRRWI -> BitPat(InstrCSR),
      CSRRSI -> BitPat(InstrCSR),
      CSRRCI -> BitPat(InstrCSR)
    ),
    BitPat(InstrN)
  )
  val in = IO(new Bundle {
    val inst = Input(UInt(32.W))
    val pc = Input(UInt(32.W))
    val rs1v = Input(UInt(32.W))
    val rs2v = Input(UInt(32.W))
  })
  val out = IO(new Bundle {
    val inst_type = Output(UInt(4.W))
    val rd = Output(UInt(4.W))
    val imm = Output(UInt(32.W))
    val op1 = Output(UInt(32.W))
    val op2 = Output(UInt(32.W))
    val funct3 = Output(UInt(3.W))
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
  val imm_i = Cat(Fill(20, in.inst(31)), in.inst(31, 20))
  val imm_s = Cat(Fill(20, in.inst(31)), in.inst(31, 25), in.inst(11, 7))
  val immbv = Cat(in.inst(31), in.inst(7), in.inst(30, 25), in.inst(11, 8))
  val imm_b = Cat(Fill(19, in.inst(31)), immbv, 0.U)
  val imm_u = Cat(in.inst(31, 12), Fill(12, 0.U))
  val immjv = Cat(in.inst(31), in.inst(19, 12), in.inst(20), in.inst(30, 21))
  val imm_j = Cat(Fill(11, in.inst(31)), immjv, 0.U)

  val imm = in.inst(31, 20)
  val csr = in.inst(31, 20)

  val decoded = decoder(in.inst, table)
  out_sys.ebreak := decoded(3)
  out_sys.system_func3_zero := decoded(2)
  out_sys.csr_wen := decoded(1)
  out_sys.system := decoded(0)

  val inst_type = decoder(in.inst, type_decoder)
  val wire = Wire(UInt(4.W))
  wire := inst_type
  out.inst_type := inst_type
  out.rd := 0.U
  out.imm := 0.U
  out.op1 := 0.U
  out.op2 := 0.U
  out.funct3 := funct3
  switch(wire) {
    is(InstrR.U) { out.rd := rd; out.op1 := in.rs1v; out.op2 := in.rs2v; }
    is(InstrI.U) { 
      out.rd := rd; out.imm := imm_i;
      when (opcode === 0b1100111.U) {
        out.op1 := in.pc; out.op2 := 4.U;
      }.otherwise {
        out.op1 := in.rs1v; out.op2 := imm_i;
      }
    }
    is(InstrS.U) { out.imm := imm_s; out.op1 := in.rs1v; out.op2 := in.rs2v; }
    is(InstrB.U) { 
      out.imm := imm_b;
      switch (funct3) {
        is(0b000.U) { out.op1 := in.rs1v; out.op2 := in.rs2v; }
        is(0b001.U) { out.op1 := in.rs1v; out.op2 := in.rs2v; }
        is(0b100.U) { out.op1 := in.rs1v; out.op2 := in.rs2v; }
        is(0b101.U) { out.op1 := in.rs2v; out.op2 := in.rs1v; }
        is(0b110.U) { out.op1 := in.rs1v; out.op2 := in.rs2v; }
        is(0b111.U) { out.op1 := in.rs2v; out.op2 := in.rs1v; }
      }
      // when (funct3 === 0b101.U || funct3 === 0b111.U) {
      //   out.op1 := in.rs2v; out.op2 := in.rs1v;
      // }.otherwise {
      //   out.op1 := in.rs1v; out.op2 := in.rs2v;
      // }
    }
    is(InstrU.U) {
      out.rd := rd; out.imm := imm_u;
      switch(opcode) {
        is(LUI_OPCODE) { out.op1 := 0.U; out.op2 := imm_u; }
        is(AUIPC_OPCODE) { out.op1 := in.pc; out.op2 := imm_u; }
      }
    }
    is(InstrJ.U) { out.rd := rd; out.imm := imm_j; out.op1 := in.pc; out.op2 := 4.U; }
    is(InstrN.U) { out.rd := rd; out.imm := imm; out.op1 := in.rs1v; }
    is(InstrCSR.U) { out.rd := rd; out.imm := csr; }
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

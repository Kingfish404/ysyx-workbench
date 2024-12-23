package npc

import chisel3._
import chisel3.util._

trait MicroOP {
  def ALU_ADD_ = "00000"
  def ALU_SUB_ = "01000"
  def ALU_SLT_ = "00010"
  def ALU_SLE_ = "01010"
  def ALU_SLTU = "00011"
  def ALU_SLEU = "01011"
  def ALU_XOR_ = "00100"
  def ALU_OR__ = "00110"
  def ALU_AND_ = "00111"

  def ALU_MUL_ = "11000"
  def ALU_MULH = "11001"
  def ALU_MULS = "11010"
  def ALU_MULU = "11011"
  def ALU_DIV_ = "11100"
  def ALU_DIVU = "11101"
  def ALU_REM_ = "11110"
  def ALU_REMU = "11111"

  def ALU_SLL_ = "00001"
  def ALU_SRL_ = "00101"
  def ALU_SRA_ = "01101"

  def LSU_LB_ = "00000"
  def LSU_LH_ = "00001"
  def LSU_LW_ = "00010"
  def LSU_LBU = "00100"
  def LSU_LHU = "00101"
  def LSU_SB_ = "00001" // alu_op to axi wstrb
  def LSU_SH_ = "00011" // alu_op to axi wstrb
  def LSU_SW_ = "01111" // alu_op to axi wstrb

  // Machine Trap Handling
  def MCAUSE  = "h342".U(12.W)
  def MEPC__  = "h341".U(12.W)
  // Machine Trap Settup
  def MTVEC_  = "h305".U(12.W)
  def MSTATUS = "h300".U(12.W)
}

trait Instr {
  def LUI_OPCODE   = "b0110111".U(7.W)
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

  def MUL___ = BitPat("b0000001 ????? ????? 000 ????? 0110011")
  def MULH__ = BitPat("b0000001 ????? ????? 001 ????? 0110011")
  def MULHSU = BitPat("b0000001 ????? ????? 010 ????? 0110011")
  def MULHU_ = BitPat("b0000001 ????? ????? 011 ????? 0110011")
  def DIV___ = BitPat("b0000001 ????? ????? 100 ????? 0110011")
  def DIVU__ = BitPat("b0000001 ????? ????? 101 ????? 0110011")
  def REM___ = BitPat("b0000001 ????? ????? 110 ????? 0110011")
  def REMU__ = BitPat("b0000001 ????? ????? 111 ????? 0110011")
}
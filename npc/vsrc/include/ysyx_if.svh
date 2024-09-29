interface idu_pipe_if (
    input logic clk
);
  logic ren;
  logic wen;
  logic jen;

  logic system;
  logic system_func3_z;
  logic csr_wen;
  logic ebreak;

  logic [31:0] op1;
  logic [31:0] op2;
  logic [31:0] opj;
  logic [3:0] alu_op;

  logic [3:0] rd;
  logic [31:0] imm;

  logic [31:0] pc;
  logic [31:0] inst;
  logic speculation;
endinterface

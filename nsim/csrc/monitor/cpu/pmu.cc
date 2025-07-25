#include <common.h>
#include <difftest.h>
#include <readline/readline.h>
#include <readline/history.h>
#include <npc_verilog.h>

extern NPCState npc;
extern TOP_NAME *top;

PMUState pmu;
word_t g_timer = 0;
word_t main_cycle_cnt = 0;
word_t main_inst_cnt = 0;

float percentage(int a, int b)
{
  float ret = (b == 0) ? 0 : (100.0 * a / b);
  return ret == 100.0 ? 99.0 : ret;
}

void perf_sample_per_cycle()
{
  bool reset = (uint8_t)(VERILOG_RESET);
  if (reset)
  {
    return;
  }
  pmu.active_cycle++;
  bool j = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, wbu__DOT__jen_wbu));
  bool b = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, wbu__DOT__ben_wbu));
  bool wb_valid = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, wbu__DOT__valid));
  if (wb_valid)
  {
    bool is_br = b || j;
    bool br_predict_fail = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, wbu__DOT__flush_pipe));
    pmu.bpu_cnt += is_br ? 1 : 0;
    pmu.bpu_fail_cnt += is_br && br_predict_fail ? 1 : 0;
    pmu.bpu_b_fail += br_predict_fail && b ? 1 : 0;
    pmu.bpu_j_fail += br_predict_fail && j ? 1 : 0;
  }
  bool ifu_valid = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, ifu__DOT__valid));
  bool ifu_sys_hazard = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, ifu__DOT__ifu_sys_hazard));

  bool idu_ready = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, idu_ready));

  bool rou_ready = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, rou_ready));
  uint32_t exu_ooo_valid = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, exu__DOT__rs_valid));
  bool exu_ooo_valid_found = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, exu__DOT__valid_found));
  uint32_t exu_ioq_valid = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, exu__DOT__ioq_valid));
  bool exu_ioq_valid_found = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, exu__DOT__ioq_valid_found));
  bool lsu_rvalid = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, lsu__DOT____Vcellinp__l1d_cache__rvalid));
  bool lsu_l1d_hit = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, lsu__DOT__l1d_cache__DOT__hit));
  uint32_t lsu_sq_valid = *(uint32_t *)&(CONCAT(VERILOG_PREFIX, lsu__DOT__sq_valid));
  bool lsu_sq_ready = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, lsu__DOT__sq_ready));
  bool wbu_valid = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, wbu__DOT__valid));
  uint8_t l1i_state = *(uint8_t *)&(CONCAT(VERILOG_PREFIX, ifu__DOT__l1i_cache__DOT__l1i_state));
  static uint32_t ifu_pc = 0;
  if (ifu_valid && idu_ready)
  {
    pmu.ifu_fetch_cnt++;
  }
  if (!ifu_valid && idu_ready)
  {
    pmu.ifu_stall_cycle++;
  }
  pmu.ifu_sys_hazard_cycle += ifu_sys_hazard ? 1 : 0;
  pmu.rou_hazard_cycle += !rou_ready ? 1 : 0;
  if (exu_ooo_valid && !exu_ooo_valid_found)
  {
    pmu.exu_ooo_stall_cycle++;
  }
  if (exu_ioq_valid && !exu_ioq_valid_found)
  {
    pmu.exu_ioq_stall_cycle++;
  }
  pmu.lsu_l1d_stall_cycle += (lsu_rvalid && !lsu_l1d_hit) ? 1 : 0;
  pmu.lsu_sq_stall_cycle += !lsu_sq_ready ? 1 : 0;
  if (!wbu_valid)
  {
    pmu.wbu_stall_cycle++;
  }
  // cache sample
  static bool i_fetching = false;
  if (i_fetching == false)
  {
    if (!(ifu_valid && idu_ready) && l1i_state == 0b000)
    {
      i_fetching = true;
      pmu.l1i_cache_miss_cnt++;
      pmu.l1i_cache_miss_cycle++;
      pmu.l1i_cache_hit_cnt = pmu.ifu_fetch_cnt - pmu.l1i_cache_miss_cnt;
      pmu.l1i_cache_hit_cycle = pmu.l1i_cache_hit_cnt;
    }
  }
  else
  {
    if (ifu_valid && l1i_state == 0b011)
    {
      i_fetching = false;
    }
    else
    {
      pmu.l1i_cache_miss_cycle++;
    }
  }
}

typedef enum
{
  INST_ECALL = 0x00000073,
  INST_MRET = 0x30200073,
  INST_SRET = 0x10200073,
  INST_RET_ = 0x00008067,
  INST_EBREAK = 0x00100073,
} rv_inst_t;

typedef enum
{
  OP_JAL_ = 0b1101111,
  OP_JALR = 0b1100111,
} rv_opcode_t;

void perf_sample_per_inst()
{
  if (top->reset)
  {
    return;
  }
  pmu.instr_cnt++;
  uint32_t inst = *(uint32_t *)&(CONCAT(VERILOG_PREFIX, wbu__DOT__inst_wbu));
  if (inst == 0x0ff0000f) // fence
  {
    main_cycle_cnt = pmu.active_cycle;
    main_inst_cnt = pmu.instr_cnt;
  }
  uint32_t opcode = inst & 0x7f;
  switch (opcode)
  {
  case 0b0000011: // I type: lb, lh, lw, lbu, lhu
    pmu.ld_inst_cnt++;
    break;
  case 0b0100011: // S type: sb, sh, sw
    pmu.st_inst_cnt++;
    break;
  case 0b0110011: // R type: add, sub, sll, slt, sltu, xor, srl, sra, or, and
  case 0b0010011: // I type: addi, slti, sltiu, xori, ori, andi, slli, srli, srai
    pmu.alu_inst_cnt++;
    break;
  case 0b1100011: // B type: beq, bne, blt, bge, bltu, bgeu
    pmu.b_inst_cnt++;
    break;
  case OP_JAL_: // J type: jal
    pmu.jal_inst_cnt++;
    pmu.call_inst_cnt += ((inst & 0xfff) != 0x0000006f ? 1 : 0);
    break;
  case OP_JALR: // I type: jalr
    pmu.jalr_inst_cnt++;
    pmu.call_inst_cnt += ((inst & 0xfff) != 0x00000067 ? 1 : 0);
    break;
  case 0b1110011: // N type: ecall, ebreak, csrrw, csrrs, csrrc, csrrwi, csrrsi, csrrci, mert
    pmu.csr_inst_cnt++;
    break;
  default:
    pmu.other_inst_cnt++;
    break;
  }
  switch (inst)
  {
  case INST_MRET:
  case INST_SRET:
  case INST_RET_:
    pmu.ret_inst_cnt++;
    break;
  default:
    break;
  }
}

void perf()
{
  Log("======== Instruction Analysis ========");
  uint64_t time_clint = *(uint64_t *)&(CONCAT(VERILOG_PREFIX, bus__DOT__clint__DOT__mtime));
  long long int time_clint_us = time_clint / 2;
  float IPC = (1.0 * pmu.instr_cnt / pmu.active_cycle);
  float MAIN_IPC = (1.0 * (pmu.instr_cnt - main_inst_cnt) / (pmu.active_cycle - main_cycle_cnt));
  float MIPS = (double)((pmu.instr_cnt / 1e6) / (time_clint_us / 1e6));
  Log("#Inst: %lld, cycle: %llu, "
      "" FMT_BLUE("IPC: %2.3f, %2.3f (main)") ", CLINT: %lld (us), " FMT_BLUE(" %2.3f MIPS"),
      pmu.instr_cnt, pmu.active_cycle, IPC,
      (main_cycle_cnt != 0) ? MAIN_IPC : 0,
      (time_clint_us), MIPS);
  Log("|%6s, %%|%6s, %%|%6s, %%|%6s, %%|%6s, %%|%6s, %%|%6s,  %%|%6s,  %%|",
      "LD", "ST", "ALU", "BR", "CSR", "OTH", "JAL", "JALR");
  Log("|%6.0e,%2.0f|%6.0e,%2.0f|%6.0e,%2.0f"
      "|%6.0e,%2.0f|%6lld,%2.0f|%6.0e,%2.0f"
      "|%6.0e,%3.0f|%6.0e,%3.0f|",
      (double)pmu.ld_inst_cnt, percentage(pmu.ld_inst_cnt, pmu.instr_cnt),
      (double)pmu.st_inst_cnt, percentage(pmu.st_inst_cnt, pmu.instr_cnt),
      (double)pmu.alu_inst_cnt, percentage(pmu.alu_inst_cnt, pmu.instr_cnt),

      (double)pmu.b_inst_cnt, percentage(pmu.b_inst_cnt, pmu.instr_cnt),
      pmu.csr_inst_cnt, percentage(pmu.csr_inst_cnt, pmu.instr_cnt),
      (double)pmu.other_inst_cnt, percentage(pmu.other_inst_cnt, pmu.instr_cnt),

      (double)pmu.jal_inst_cnt, percentage(pmu.jal_inst_cnt, pmu.instr_cnt),
      (double)pmu.jalr_inst_cnt, percentage(pmu.jalr_inst_cnt, pmu.instr_cnt));
  Log("======== TOP DOWN Stall Analysis ========");
  Log("|%7s, %%|%7s, %%|%7s, %%|%7s, %%|%7s, %%|%7s, %%|",
      "IFU", "EXU OoO", "EXU IoQ", "LSU L1D", "LSU SQ", "Bubble");
  Log("|%7lld,%2.0f|%7lld,%2.0f|%7lld,%2.0f|%7lld,%2.0f|%7lld,%2.0f|%7lld,%2.0f|",
      pmu.ifu_stall_cycle, percentage(pmu.ifu_stall_cycle, pmu.active_cycle),
      pmu.exu_ooo_stall_cycle, percentage(pmu.exu_ooo_stall_cycle, pmu.active_cycle),
      pmu.exu_ioq_stall_cycle, percentage(pmu.exu_ioq_stall_cycle, pmu.active_cycle),
      pmu.lsu_l1d_stall_cycle, percentage(pmu.lsu_l1d_stall_cycle, pmu.active_cycle),
      pmu.lsu_sq_stall_cycle, percentage(pmu.lsu_sq_stall_cycle, pmu.active_cycle),
      pmu.wbu_stall_cycle, percentage(pmu.wbu_stall_cycle, pmu.active_cycle));
  Log("BPU Success: %lld, Fail: %lld, Rate: %2.1f%% (b: %lld, j: %lld), call: %lld, ret: %lld",
      pmu.bpu_cnt - pmu.bpu_fail_cnt, pmu.bpu_fail_cnt,
      percentage(pmu.bpu_cnt - pmu.bpu_fail_cnt, pmu.bpu_cnt),
      pmu.bpu_b_fail, pmu.bpu_j_fail,
      pmu.call_inst_cnt, pmu.ret_inst_cnt);
  Log("hazard cycle of ifu_sys: %6lld,%2.0f%%, rou_cycle: %6lld,%2.0f%% (structural)",
      pmu.ifu_sys_hazard_cycle, percentage(pmu.ifu_sys_hazard_cycle, pmu.active_cycle),
      pmu.rou_hazard_cycle, percentage(pmu.rou_hazard_cycle, pmu.active_cycle));
  assert(
      pmu.instr_cnt ==
      (pmu.ld_inst_cnt + pmu.st_inst_cnt + pmu.alu_inst_cnt +
       pmu.b_inst_cnt + pmu.csr_inst_cnt + pmu.other_inst_cnt +
       pmu.jal_inst_cnt + pmu.jalr_inst_cnt));
  Log("======== Cache Analysis ========");
  // AMAT: Average Memory Access Time
  Log("|%8s,  %%|%8s, %%|%8s, %%|%8s, %%|%13s|%13s|%6s|",
      "L1I HIT", "L1I MISS", "HIT CYC", "MISS CYC", "HIT Cost AVG", "MISS Cost AVG", "AMAT");
  double l1i_hit_rate = percentage(pmu.l1i_cache_hit_cnt, pmu.l1i_cache_hit_cnt + pmu.l1i_cache_miss_cnt);
  double l1i_access_time = pmu.l1i_cache_hit_cycle / (pmu.l1i_cache_hit_cnt + 1);
  double l1i_miss_penalty = pmu.l1i_cache_miss_cycle / (pmu.l1i_cache_miss_cnt + 1);
  Log("|%8lld,%3.0f|%8lld,%2.0f|%8lld,%2.0f|%8lld,%2.0f|%13lld|%13lld|%6.1f|",
      pmu.l1i_cache_hit_cnt, l1i_hit_rate,
      pmu.l1i_cache_miss_cnt, 100 - l1i_hit_rate,
      pmu.l1i_cache_hit_cycle,
      percentage(pmu.l1i_cache_hit_cycle, pmu.l1i_cache_hit_cycle + pmu.l1i_cache_miss_cycle),
      pmu.l1i_cache_miss_cycle,
      percentage(pmu.l1i_cache_miss_cycle, pmu.l1i_cache_hit_cycle + pmu.l1i_cache_miss_cycle),
      (long long)l1i_access_time, (long long)l1i_miss_penalty,
      l1i_access_time + (100 - l1i_hit_rate) / 100.0 * l1i_miss_penalty);
  // assert((pmu.l1i_cache_hit_cnt + pmu.l1i_cache_miss_cnt) == pmu.ifu_fetch_cnt);
}

void statistic()
{
  perf();
  double time_s = g_timer / 1e6;
  double frequency = pmu.active_cycle / time_s;
  Log("Simulate time:"
      " %d us, %d ms, Freq: %5.3f MHz, Inst: %6.0f I/s, %5.3f MIPS",
      g_timer, (int)(g_timer / 1e3),
      (double)(frequency * 1.0 / 1e6),
      pmu.instr_cnt / time_s, pmu.instr_cnt / time_s / 1e6);
  Log("%s at pc: " FMT_WORD_NO_PREFIX ", inst: " FMT_WORD_NO_PREFIX,
      (*npc.ret == 0 && npc.state != NPC_ABORT ? FMT_GREEN("HIT GOOD TRAP")
       : (npc.state == NPC_QUIT)               ? FMT_BLUE("NPC QUIT")
                                               : FMT_RED("HIT BAD TRAP")),
      *(npc.pc), *(npc.inst));
}
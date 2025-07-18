/***************************************************************************************
 * Copyright (c) 2014-2022 Zihao Yu, Nanjing University
 *
 * NEMU is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 *          http://license.coscl.org.cn/MulanPSL2
 *
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
 * EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
 * MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 *
 * See the Mulan PSL v2 for more details.
 ***************************************************************************************/

#include <common.h>
#include <cpu/cpu.h>
#include <cpu/decode.h>
#include <cpu/difftest.h>
#include <locale.h>

/* The assembly code of instructions executed is only output to the screen
 * when the number of instructions executed is less than this value.
 * This is useful when you use the `si' command.
 * You can modify this value as you want.
 */
#define MAX_INST_TO_PRINT 10
#define MAX_IRING_SIZE 16

extern int boot_from_flash;
extern int ftracedepth_max;
FILE *pc_trace = NULL, *bpu_trace = NULL, *mem_trace = NULL;
size_t pc_continue_cnt = 1;

CPU_state cpu = {};
uint64_t g_nr_guest_inst = 0;
static uint64_t g_timer = 0; // unit: us
static bool g_print_step = false;
Decode iringbuf[MAX_IRING_SIZE];
uint64_t iringhead = 0;

void device_update();

bool wp_check_changed();

static void trace_and_difftest(Decode *_this, vaddr_t dnpc)
{
#ifdef CONFIG_ITRACE_COND
  if (ITRACE_COND)
  {
    log_write("%s\n", _this->logbuf);
  }
#endif
  if (g_print_step)
  {
    IFDEF(CONFIG_ITRACE, puts(_this->logbuf));
  }
  IFDEF(CONFIG_DIFFTEST, difftest_step(_this->pc, dnpc));
#ifdef CONFIG_WATCHPOINT
  if (wp_check_changed())
  {
    set_nemu_state(NEMU_STOP, cpu.pc, -1);
    printf("wp changed at " FMT_WORD ", pc: " FMT_WORD "\n",
           (word_t)g_nr_guest_inst, cpu.pc);
  }
#endif
}

static void exec_once(Decode *s, vaddr_t pc)
{
  cpu.cpc = pc;
  s->pc = pc;
  s->snpc = pc;
  isa_exec_once(s);
  if (boot_from_flash)
  {
    if (pc_trace == NULL)
    {
      pc_trace = fopen("./pc-trace.txt", "w");
      fprintf(pc_trace, FMT_WORD_NO_PREFIX "-", s->pc);
    }
    else
    {
      if (s->dnpc == s->snpc)
      {
        pc_continue_cnt++;
      }
      else
      {
        fprintf(pc_trace, "%zu\n", pc_continue_cnt);
        pc_continue_cnt = 1;
        fprintf(pc_trace, FMT_WORD_NO_PREFIX "-", s->pc);
      }
    }
    uint32_t opcode = BITS(s->isa.inst, 6, 0);
    {
      if (bpu_trace == NULL)
      {
        bpu_trace = fopen("./bpu-trace.txt", "w");
      }
      // branch: 0b1100011; jalr: 0b1100111 ; jal: 0b1101111 ;
      if (opcode == 0b1100011 || opcode == 0b1100111 || opcode == 0b1101111)
      {
        // jalr x0, 0(x1): 0x00008067, a.k.a. ret
        char btype = (s->isa.inst == 0x00008067) ? 'r' : (opcode == 0b1100011 ? 'b' : (opcode == 0b1100111 ? 'j' : 'c'));
        fprintf(bpu_trace, FMT_WORD_NO_PREFIX "-" FMT_WORD_NO_PREFIX "-%c\n",
                s->pc, s->dnpc, btype);
      };
    }
    {
      if (mem_trace == NULL)
      {
        mem_trace = fopen("./mem-trace.txt", "w");
      }
      // record vaddr of load and store at `vaddr.c`
    }
  }
#ifdef CONFIG_ITRACE
  char *p = s->logbuf;
  p += snprintf(p, sizeof(s->logbuf), FMT_WORD ":", cpu.pc);
  int ilen = s->snpc - cpu.pc;
  int i;
  uint8_t *inst = (uint8_t *)&s->isa.inst;
  for (i = ilen - 1; i >= 0; i--)
  {
    p += snprintf(p, 4, " %02x", inst[i]);
  }
  int ilen_max = 4;
  int space_len = ilen_max - ilen;
  if (space_len < 0)
    space_len = 0;
  space_len = space_len * 3 + 1;
  memset(p, ' ', space_len);
  p += space_len;

  void disassemble(char *str, int size, uint64_t pc, uint8_t *code, int nbyte);
  disassemble(p, s->logbuf + sizeof(s->logbuf) - p, s->pc, (uint8_t *)&cpu.inst, ilen);
  iringbuf[iringhead] = *s;
  iringhead = (iringhead + 1) % MAX_IRING_SIZE;
  iringbuf[iringhead].logbuf[0] = '\0';
#endif
  cpu.pc = s->pc;
  cpu.inst = s->isa.inst;
}

static void execute(uint64_t n)
{
  Decode s;
  for (; n > 0; n--)
  {
    exec_once(&s, cpu.pc);

    g_nr_guest_inst++;
    trace_and_difftest(&s, cpu.pc);
    if (nemu_state.state != NEMU_RUNNING)
    {
      break;
    }
    IFDEF(CONFIG_DEVICE, device_update());

    word_t intr = isa_query_intr();
    if (intr != INTR_EMPTY)
    {
      // Log("nemu: intr %x at pc = " FMT_WORD, intr, cpu.pc);
      cpu.pc = isa_raise_intr(intr, cpu.pc);
      difftest_skip_ref();
    }
  }
}

void statistic()
{
  IFNDEF(CONFIG_TARGET_AM, setlocale(LC_NUMERIC, ""));
#define NUMBERIC_FMT MUXDEF(CONFIG_TARGET_AM, "%", "%'") PRIu64
  Log("ftracedepth_max = %d ", ftracedepth_max);
  Log("host time spent = " NUMBERIC_FMT " us", g_timer);
  Log("total guest instructions = " NUMBERIC_FMT, g_nr_guest_inst);
  if (g_timer > 0)
    Log("simulation frequency = " NUMBERIC_FMT " inst/s", g_nr_guest_inst * 1000000 / g_timer);
  else
    Log("Finish running in less than 1 us and can not calculate the simulation frequency");
}

void assert_fail_msg()
{
  isa_reg_display();
  cpu_show_itrace();
  statistic();
}

/* Simulate how the CPU works. */
void cpu_exec(uint64_t n)
{
  g_print_step = (n < MAX_INST_TO_PRINT);
  switch (nemu_state.state)
  {
  case NEMU_END:
  case NEMU_ABORT:
    printf("Program execution has ended. To restart the program, exit NEMU and run again.\n");
    return;
  default:
    nemu_state.state = NEMU_RUNNING;
  }

  uint64_t timer_start = get_time();

  execute(n);

  uint64_t timer_end = get_time();
  g_timer += timer_end - timer_start;

  switch (nemu_state.state)
  {
  case NEMU_RUNNING:
    nemu_state.state = NEMU_STOP;
    break;

  case NEMU_END:
  case NEMU_ABORT:
    if (nemu_state.state == NEMU_ABORT)
    {
      isa_reg_display();
      cpu_show_itrace();
    }
    Log("nemu: %s at pc = " FMT_WORD,
        (nemu_state.state == NEMU_ABORT ? ANSI_FMT("ABORT", ANSI_FG_RED) : (nemu_state.halt_ret == 0 ? ANSI_FMT("HIT GOOD TRAP", ANSI_FG_GREEN) : ANSI_FMT("HIT BAD TRAP", ANSI_FG_RED))),
        nemu_state.halt_pc);
    // fall through
  case NEMU_QUIT:
    statistic();
  }
}

void cpu_show_itrace()
{
#ifdef CONFIG_ITRACE
  for (size_t i = 0; i < MAX_IRING_SIZE; i++)
  {
    if (iringbuf[i].logbuf[0] == '\0')
    {
      continue;
    }
    iringbuf[i].logbuf[0] = ' ';
    iringbuf[i].logbuf[1] = ' ';
    if ((i + 1) % MAX_IRING_SIZE == iringhead)
    {
      printf("-> %-76s\n", iringbuf[i].logbuf);
    }
    else
    {
      printf("   %-76s\n", iringbuf[i].logbuf);
    }
  }
#endif
}
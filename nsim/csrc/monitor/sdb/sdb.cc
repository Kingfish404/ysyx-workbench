#include <common.h>
#include <cpu.h>
#include <readline/readline.h>
#include <readline/history.h>
#include <npc_verilog.h>
#include <verilated.h>
#include "verilated_fst_c.h"
#ifdef CONFIG_NVBoard
#include <nvboard.h>
#endif

extern char *regs[];
extern PMUState pmu;
void difftest_skip_ref();
void difftest_should_diff_mem();

NPCState npc = {
    .state = NPC_RUNNING,
    .gpr = NULL,
    .ret = NULL,
    .pc = NULL,

    .inst = NULL,

    .soc_sram = NULL,
};

VerilatedContext *contextp = NULL;
TOP_NAME *top = NULL;
VerilatedFstC *tfp = NULL;

static bool is_batch_mode = false;
static bool enable_vcd = true;

/* We use the `readline' library to provide more flexibility to read from stdin. */
static char *rl_gets()
{
  static char *line_read = NULL;

  if (line_read)
  {
    free(line_read);
    line_read = NULL;
  }

  line_read = readline("(npc) ");

  if (line_read && *line_read)
  {
    add_history(line_read);
  }

  return line_read;
}

void reset(TOP_NAME *top, int n)
{
  top->reset = 1;
  cpu_exec(n);
  top->reset = 0;
}

void npc_abort()
{
  contextp->gotFinish(true);
  npc.state = NPC_ABORT;
}

extern "C" void npc_exu_ebreak()
{
#if defined(CONFIG_DEBUG)
  contextp->gotFinish(true);
  Log("EBREAK at pc = " FMT_WORD_NO_PREFIX "", *npc.pc);
  npc.state = NPC_END;
#endif
}

void npc_difftest_skip_ref()
{
  difftest_skip_ref();
}

void npc_difftest_mem_diff(int waddr, int wdata, char wstrb)
{
  npc.vwaddr = (word_t)waddr;
  npc.pwaddr = (word_t)waddr;
  npc.wdata = (word_t)wdata;
  npc.wstrb = (word_t)wstrb;
  difftest_should_diff_mem();
}

extern "C" void npc_illegal_inst()
{
  contextp->gotFinish(true);
  Error("Illegal instruction at pc = " FMT_WORD_NO_PREFIX, *npc.pc);
  npc_abort();
}

void sdb_set_batch_mode()
{
  is_batch_mode = true;
}

void soc_show_sram()
{
  if (npc.soc_sram != NULL)
  {
    for (size_t i = 0; i < 1024; i++)
    {
      printf("%02x ", npc.soc_sram[i]);
    }
    printf("\n");
  }
}

int cmd_c(char *args)
{
  cpu_exec(-1);
  return 0;
}

int cmd_info(char *args)
{
  if (args == NULL)
  {
    reg_display(GPR_SIZE);
    return 0;
  }
  while (args[0] == ' ')
  {
    args++;
  }
  switch (args[0])
  {
  case 'r':
    reg_display();
    break;
  case 'i':
    cpu_show_itrace();
    break;
  case 's':
    soc_show_sram();
    break;
  default:
    printf("Unknown argument '%s'.\n", args);
    break;
  }
  return 0;
}

void vaddr_show(vaddr_t addr, int n);

static int cmd_x(char *args)
{
  char *arg = strtok(args, " ");
  if (arg == NULL)
  {
    printf("No argument given.\n");
    return 0;
  }
  char *e = strtok(NULL, " ");
  if (e == NULL)
  {
    printf("Require second argument.\n");
    return 0;
  }

  int n;
  long long addr;
  bool success = true;
  sscanf(arg, "%x", &n);
  sscanf(e, "%llx", &addr);
  vaddr_show(addr, n);
  return 0;
}

int cmd_q(char *args)
{
  if (npc.state == NPC_RUNNING)
  {
    npc.state = NPC_QUIT;
  }
  cpu_exec(0);
  return -1;
}

extern PMUState pmu;

int cmd_si(char *args)
{
  int n = 1;
  if (args != NULL)
  {
    sscanf(args, "%d", &n);
  }
  size_t instr_cnt = pmu.instr_cnt;
  while ((pmu.instr_cnt - instr_cnt) < n)
  {
    cpu_exec(1);
    if (npc.state == NPC_ABORT || npc.state == NPC_END)
    {
      break;
    }
  }
  char cmd[] = "i";
  cmd_info(cmd);
  cmd[0] = 'r';
  cmd_info(cmd);
  return 0;
}

int cmd_sc(char *args)
{
  int n = 1;
  if (args != NULL)
  {
    sscanf(args, "%d", &n);
  }
  cpu_exec(n);
  char cmd[] = "i";
  cmd_info(cmd);
  cmd[0] = 'r';
  cmd_info(cmd);
  return 0;
}

int cmd_help(char *args);

static struct
{
  const char *name;
  const char *description;
  int (*handler)(char *);
} cmd_table[] = {
    {"help", "h\tDisplay information about all supported commands", cmd_help},
    {"c", "c\tContinue the execution of the program", cmd_c},
    {"rs", "Run the execution of the program (same to `c`)", cmd_c},
    {"si", "si/s [N] \tExecute N instructions step by step", cmd_si},
    {"sc", "sc/s [N] \tExecute N cycle step by step", cmd_sc},
    {"info", "info/i [ARG]\tGeneric command for showing things about regs (r), instruction trace (i)", cmd_info},
    {"x", "x N EXPR\tScan 'N' continue 4 bytes, using 'EXPR' as start address.", cmd_x},
    {"q", "q\tExit NPC", cmd_q},
};

int cmd_help(char *args)
{
  printf("The following commands are supported:\n");
  for (int i = 0; i < ARRLEN(cmd_table); i++)
  {
    printf("%s\t- %s\n", cmd_table[i].name, cmd_table[i].description);
  }
  return 0;
}

void sdb_mainloop()
{
  if (is_batch_mode)
  {
    cmd_c(NULL);
    return;
  }

  for (char *str; (str = rl_gets()) != NULL;)
  {
    char *str_end = str + strlen(str);
    char *cmd = strtok(str, " ");
    if (cmd == NULL)
    {
      continue;
    }

    char *args = cmd + strlen(cmd) + 1;
    if (args >= str_end)
    {
      args = NULL;
    }

    int i;
    for (i = 0; i < ARRLEN(cmd_table); i++)
    {
      if ((strcmp(cmd, cmd_table[i].name) == 0) ||
          (strlen(cmd) == 1 && cmd[0] == cmd_table[i].name[0]))
      {
        if (cmd_table[i].handler(args) < 0)
        {
          return;
        }
        break;
      }
    }
    if (i == ARRLEN(cmd_table))
    {
      printf("Unknown command '%s'\n", cmd);
    }
  }
}

void sdb_set_vcd(bool status)
{
  enable_vcd = status;
}

void sdb_sim_init(int argc, char **argv)
{
  contextp = new VerilatedContext;
  contextp->commandArgs(argc, argv);
  top = new TOP_NAME{contextp};
  Verilated::traceEverOn(true);
#ifdef CONFIG_WTRACE
  if (enable_vcd)
  {
    tfp = new VerilatedFstC;
    top->trace(tfp, 99);
    tfp->open("npc.fst");
  }
#endif
  verilog_connect(top, &npc);

  reset(top, 32);
  memset(&pmu, 0, sizeof(PMUState));

#ifdef CONFIG_NVBoard
  nvboard_bind_pin(
      &top->externalPins_gpio_out,
      16, LD15, LD14, LD13, LD12, LD11, LD10, LD9, LD8, LD7, LD6, LD5, LD4, LD3, LD2, LD1, LD0);

  nvboard_bind_pin(
      &top->externalPins_gpio_in,
      16, SW15, SW14, SW13, SW12, SW11, SW10, SW9, SW8, SW7, SW6, SW5, SW4, SW3, SW2, SW1, SW0);

  nvboard_bind_pin(&top->externalPins_gpio_seg_0, 8, SEG0A, SEG0B, SEG0C, SEG0D, SEG0E, SEG0F, SEG0G, DEC0P);
  nvboard_bind_pin(&top->externalPins_gpio_seg_1, 8, SEG1A, SEG1B, SEG1C, SEG1D, SEG1E, SEG1F, SEG1G, DEC1P);
  nvboard_bind_pin(&top->externalPins_gpio_seg_2, 8, SEG2A, SEG2B, SEG2C, SEG2D, SEG2E, SEG2F, SEG2G, DEC2P);
  nvboard_bind_pin(&top->externalPins_gpio_seg_3, 8, SEG3A, SEG3B, SEG3C, SEG3D, SEG3E, SEG3F, SEG3G, DEC3P);
  nvboard_bind_pin(&top->externalPins_gpio_seg_4, 8, SEG4A, SEG4B, SEG4C, SEG4D, SEG4E, SEG4F, SEG4G, DEC4P);
  nvboard_bind_pin(&top->externalPins_gpio_seg_5, 8, SEG5A, SEG5B, SEG5C, SEG5D, SEG5E, SEG5F, SEG5G, DEC5P);
  nvboard_bind_pin(&top->externalPins_gpio_seg_6, 8, SEG6A, SEG6B, SEG6C, SEG6D, SEG6E, SEG6F, SEG6G, DEC6P);
  nvboard_bind_pin(&top->externalPins_gpio_seg_7, 8, SEG7A, SEG7B, SEG7C, SEG7D, SEG7E, SEG7F, SEG7G, DEC7P);

  nvboard_bind_pin(&top->externalPins_uart_tx, 1, UART_TX);
  nvboard_bind_pin(&top->externalPins_uart_rx, 1, UART_RX);

  nvboard_bind_pin(&top->externalPins_ps2_clk, 1, PS2_CLK);
  nvboard_bind_pin(&top->externalPins_ps2_data, 1, PS2_DAT);

  nvboard_bind_pin(&top->externalPins_vga_vsync, 1, VGA_VSYNC);
  nvboard_bind_pin(&top->externalPins_vga_hsync, 1, VGA_HSYNC);
  nvboard_bind_pin(&top->externalPins_vga_valid, 1, VGA_BLANK_N);

  nvboard_bind_pin(&top->externalPins_vga_r, 8, VGA_R7, VGA_R6, VGA_R5, VGA_R4, VGA_R3, VGA_R2, VGA_R1, VGA_R0);
  nvboard_bind_pin(&top->externalPins_vga_g, 8, VGA_G7, VGA_G6, VGA_G5, VGA_G4, VGA_G3, VGA_G2, VGA_G1, VGA_G0);
  nvboard_bind_pin(&top->externalPins_vga_b, 8, VGA_B7, VGA_B6, VGA_B5, VGA_B4, VGA_B3, VGA_B2, VGA_B1, VGA_B0);

  nvboard_init();
#endif
}

void engine_start()
{
  cpu_exec_init();
  sdb_mainloop();
}

void engine_free()
{
  if (tfp)
  {
    tfp->dump(contextp->time());
    tfp->flush();
    tfp->close();
    delete tfp;
  }

  delete top;
  delete contextp;
}
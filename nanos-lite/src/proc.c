#include <proc.h>

#define MAX_NR_PROC 4

void naive_uload(PCB *pcb, const char *filename);
uintptr_t ucontext_load(PCB *pcb, const char *filename);

static PCB pcb[MAX_NR_PROC] __attribute__((used)) = {};
static PCB pcb_boot = {};
PCB *current = NULL;
PCB *last = NULL;

void switch_boot_pcb()
{
  current = &pcb_boot;
}

void hello_fun(void *arg)
{
  int j = 1;
  while (1)
  {
    Log("Hello World from Nanos-lite with arg '%s' for the %dth time!", (const char *)arg, j);
    j++;
    yield();
  }
}

void context_kload(PCB *pcb, void *entry, void *arg)
{
  pcb->cp = kcontext((Area){pcb->stack, pcb->stack + STACK_SIZE}, entry, arg);
  // pcb->cp->GPRx = (uintptr_t)pcb->stack + STACK_SIZE;
}

void context_uload(PCB *pcb, const char *filename)
{
  void *entry = ucontext_load(pcb, filename);
  pcb->cp = ucontext(NULL, (Area){pcb->stack, pcb->stack + STACK_SIZE}, entry);
  pcb->cp->gpr[11] = (uintptr_t)&pcb->stack[STACK_SIZE];
  printf("GPRx: %x\n", pcb->cp->GPRx);
}

void init_proc()
{
  context_kload(&pcb[0], hello_fun, "pcb[0]");
  context_kload(&pcb[1], hello_fun, "pcb[1]");
  // context_kload(&pcb[2], hello_fun, "pcb[1]");
  context_uload(&pcb[1], "/bin/dummy");
  last = &pcb[1];
  switch_boot_pcb();
  Log("Initializing processes...");

  yield();
  // load program here
  // naive_uload(NULL, "/bin/dummy");
}

Context *schedule(Context *prev)
{
  current->cp = prev;
  if (current == &pcb_boot)
  {
    current = &pcb[0];
  }
  else if (current == last)
  {
    current = &pcb[0];
  }
  else
  {
    current++;
  }
  return current->cp;
}
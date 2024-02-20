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

#include <memory/host.h>
#include <memory/paddr.h>
#include <device/mmio.h>
#include <isa.h>

#if   defined(CONFIG_PMEM_MALLOC)
static uint8_t *pmem = NULL;
#else // CONFIG_PMEM_GARRAY
static uint8_t pmem[CONFIG_MSIZE] PG_ALIGN = {};
#endif
static uint8_t sram[CONFIG_SRAM_SIZE] PG_ALIGN = {};
static uint8_t mrom[CONFIG_MROM_BASE] PG_ALIGN = {};

uint8_t* guest_to_host(paddr_t paddr) { return pmem + paddr - CONFIG_MBASE; }
paddr_t host_to_guest(uint8_t *haddr) { return haddr - pmem + CONFIG_MBASE; }

uint8_t* guest_to_sram(paddr_t paddr) { return sram + paddr - CONFIG_SRAM_BASE; }
paddr_t sram_to_guest(uint8_t *haddr) { return haddr - sram + CONFIG_SRAM_BASE; }

uint8_t* guest_to_mrom(paddr_t paddr) { return mrom + paddr - CONFIG_MROM_BASE; }
paddr_t mrom_to_guest(uint8_t *haddr) { return haddr - mrom + CONFIG_MROM_BASE; }

static word_t pmem_read(paddr_t addr, int len) {
  word_t ret = host_read(guest_to_host(addr), len);
  return ret;
}

static word_t sram_read(paddr_t addr, int len) {
  word_t ret = host_read(guest_to_sram(addr), len);
  return ret;
}

static word_t mrom_read(paddr_t addr, int len) {
  word_t ret = host_read(guest_to_mrom(addr), len);
  return ret;
}

static void pmem_write(paddr_t addr, int len, word_t data) {
  host_write(guest_to_host(addr), len, data);
}

static void sram_write(paddr_t addr, int len, word_t data) {
  host_write(guest_to_sram(addr), len, data);
}

static void mrom_write(paddr_t addr, int len, word_t data) {
  host_write(guest_to_mrom(addr), len, data);
}

static void out_of_bound(paddr_t addr) {
  panic("address = " FMT_PADDR " is out of bound of pmem [" FMT_PADDR ", " FMT_PADDR "] at pc = " FMT_WORD,
      addr, PMEM_LEFT, PMEM_RIGHT, cpu.pc);
}

void init_mem() {
#if   defined(CONFIG_PMEM_MALLOC)
  pmem = malloc(CONFIG_MSIZE);
  assert(pmem);
#endif
  IFDEF(CONFIG_MEM_RANDOM, memset(pmem, rand(), CONFIG_MSIZE));
  Log("physical memory area [" FMT_PADDR ", " FMT_PADDR "]", PMEM_LEFT, PMEM_RIGHT);
  memset(sram, 0, sizeof(sram));
  memset(mrom, 0, sizeof(mrom));
}

word_t paddr_read(paddr_t addr, int len) {
#ifdef CONFIG_MTRACE
  printf("paddr_r: " FMT_PADDR ", size: %d\n", addr, len);
#endif

  if (likely(in_pmem(addr))) return pmem_read(addr, len);
  if (in_sram(addr)) return sram_read(addr, len);
  if (in_mrom(addr)) return mrom_read(addr, len);
  IFDEF(CONFIG_DEVICE, return mmio_read(addr, len));
  out_of_bound(addr);
  return 0;
}

void paddr_write(paddr_t addr, int len, word_t data) {
#ifdef CONFIG_MTRACE
  printf("paddr_w: " FMT_PADDR ", size: %d, data: " FMT_WORD "\n", addr, len, data);
#endif

  if (likely(in_pmem(addr))) { pmem_write(addr, len, data); return; }
  if (in_sram(addr)) { sram_write(addr, len, data); return; }
  if (in_mrom(addr)) { mrom_write(addr, len, data); return; }
  IFDEF(CONFIG_DEVICE, mmio_write(addr, len, data); return);
  out_of_bound(addr);
}

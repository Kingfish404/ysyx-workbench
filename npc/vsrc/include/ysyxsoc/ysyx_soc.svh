`ifndef YSYX_SOC_SVH
`define YSYX_SOC_SVH

`define YSYX_PC_INIT `YSYX_XLEN'h30000000

`define YSYX_ROM_ADDR 'h00001000

`define YSYX_BUS_RTC_ADDR 'h02000048
`define YSYX_BUS_RTC_ADDR_UP `YSYX_BUS_RTC_ADDR + 4

`define YSYX_BUS_SERIAL_PORT 'h10000000
`define YSYX_BUS_NS16550_ADDR 'h10000000

`define YSYX_USE_SLAVE 1

`define YSYX_I_SDRAM_ARBURST 1

// random test setting
`define YSYX_IFSR_ENABLE 0

`endif

`define YSYX_PC_INIT `YSYX_XLEN'h80000000

`define YSYX_BUS_SERIAL_PORT    'h10000000
`define YSYX_BUS_RTC_ADDR       'h02000048
`define YSYX_BUS_RTC_ADDR_UP    `YSYX_BUS_RTC_ADDR + 4

`define YSYX_I_SDRAM_ARBURST 0

// random test setting
`define YSYX_IFSR_ENABLE 0

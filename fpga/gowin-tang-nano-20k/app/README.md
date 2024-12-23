# Operating system

files generated by `generate-config.py`:
* `os_config.h` - addresses to leds and uart
* `os_start.S` - setup stack before `os.c` `run()`

source:
* `os.c` - sample "operating system" with entry in `run()`
  
`make.sh` compiles `os.c` and generates:
* `os.bin` - binary
* `os.lst` - assembler with source annotations
* `os.mem` - default RAM content included by `src/Top.v`
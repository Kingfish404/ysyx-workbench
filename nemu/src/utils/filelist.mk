#***************************************************************************************
# Copyright (c) 2014-2024 Zihao Yu, Nanjing University
#
# NEMU is licensed under Mulan PSL v2.
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
#
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
# EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
# MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
#
# See the Mulan PSL v2 for more details.
#**************************************************************************************/

ifeq ($(CONFIG_ITRACE)$(CONFIG_IQUEUE),)
SRCS-BLACKLIST-y += src/utils/disasm.c
else

ifeq ($(shell uname -s),Linux)
suffix = so.5
else ifeq ($(shell uname -s),Darwin)
suffix = 5.dylib
else
  $(error Unsupported OS)
endif

LIBCAPSTONE = tools/capstone/repo/libcapstone.$(suffix)
CFLAGS += -I tools/capstone/repo/include
src/utils/disasm.c: $(LIBCAPSTONE)
$(LIBCAPSTONE):
	$(MAKE) -C tools/capstone
endif
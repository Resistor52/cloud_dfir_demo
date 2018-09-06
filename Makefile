#Copy this to the rekall/tools/linux directory in place of the current Makefile
obj-m += module.o
obj-m += pmem.o

KVER ?= $(shell uname -r)
KHEADER ?= /usr/src/kernels/$(KVER)
KSYSTEMMAP ?= /boot/System.map-$(KVER)
KCONFIG ?= /boot/config-$(KVER)

PWD = `pwd`

-include version.mk

all: dwarf pmem profile

pmem: pmem.c
        $(MAKE) -C $(KHEADER) M=$(PWD) modules
        cp pmem.ko "pmem-$(KVER).ko"

dwarf: module.c
        $(MAKE) -C $(KHEADER) CONFIG_DEBUG_INFO=y M=$(PWD) modules
        cp module.ko module_dwarf.ko

profile: dwarf pmem
        zip "$(KVER).zip" module_dwarf.ko $(KSYSTEMMAP) $(KCONFIG) "pmem-$(KVER).ko"

clean:
        $(MAKE) -C $(KHEADER) M=$(PWD) clean
        rm -f module_dwarf.ko

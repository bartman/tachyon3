# Copyright (c) 2011 by Markus Duft <mduft@gentoo.org>
# This file is part of the 'tachyon' operating system.

#ARCH			:= x86
ARCH			:= x86_64
VERBOSE			:= 0

SHELL			:= bash

SOURCEDIR		:= $(abspath $(dir $(firstword $(MAKEFILE_LIST))))
BUILDDIR		:= $(SOURCEDIR)/.build/$(ARCH)

ARCH_MAKEFILE	:= $(SOURCEDIR)/config/$(ARCH).mk
ARCH_LINKSCRIPT	:= $(SOURCEDIR)/config/$(ARCH).ld
ARCH_PPLSCRIPT  := $(BUILDDIR)/$(ARCH).ld

#.----------------------------------.
#| Include the platform config.     |
#'----------------------------------'

include $(ARCH_MAKEFILE)

GDB				:= x86_64-pc-linux-gnu-gdb

BASE_CPPFLAGS   := -Wall -Wextra -I$(SOURCEDIR)/src
BASE_CFLAGS		:= $(BASE_CPPFLAGS) -Werror -ffreestanding -nostartfiles -nostdlib -Wno-unused-parameter -std=gnu99
BASE_CXXFLAGS	:= $(BASE_CFLAGS) -fno-rtti -fno-exceptions -Wold-style-cast
BASE_LDFLAGS	 = -T $(ARCH_PPLSCRIPT) -Map=$(KERNEL).map

BASE_QFLAGS		:= -curses -serial file:$(BUILDDIR)/serial-qemu.log
BASE_GDBFLAGS	:= 

MAKE			:= $(MAKE) --no-print-directory

GRUB2_CFG		:= $(BUILDDIR)/boot/grub/grub.cfg
GRUB2_PXE		 = $(BUILDDIR)/boot/grub/i386-pc/core.0
GRUB2_ISO		 = $(BUILDDIR)/$(notdir $(KERNEL))-grub2.iso

#.----------------------------------.
#| The all target, keep it first!   |
#'----------------------------------'

all: all-kernel

.PHONY: all

#.----------------------------------.
#| Build internal/accumulated vars. |
#'----------------------------------'

KERNEL_SOURCES	:= \
	$(wildcard $(SOURCEDIR)/src/*.c) \
	$(wildcard $(SOURCEDIR)/src/*.S) \
	$(wildcard $(SOURCEDIR)/src/$(ARCH)/*.c) \
	$(wildcard $(SOURCEDIR)/src/$(ARCH)/*.S) \
    $(wildcard $(SOURCEDIR)/src/contrib/*/*.c) \
	$(KERNEL_ADD)

KERNEL_CSOURCES := $(filter %.c,$(KERNEL_SOURCES))
KERNEL_SSOURCES := $(filter %.S,$(KERNEL_SOURCES))

KERNEL_COBJECTS := $(subst $(SOURCEDIR),$(BUILDDIR),$(KERNEL_CSOURCES:.c=.o))
KERNEL_SOBJECTS := $(subst $(SOURCEDIR),$(BUILDDIR),$(KERNEL_SSOURCES:.S=.o))

KERNEL_OBJECTS  := $(KERNEL_COBJECTS) $(KERNEL_SOBJECTS)

KCPPFLAGS	:= $(BASE_CPPFLAGS) $(CPPFLAGS) $(KERNEL_CPPFLAGS)
KCFLAGS		:= $(BASE_CFLAGS) $(CFLAGS) $(KERNEL_CFLAGS)
KLDFLAGS	:= $(BASE_LDFLAGS) $(LDFLAGS) $(KERNEL_LDFLAGS)

MAKE_BDIR 	 = test -d "$(dir $@)" || mkdir -p "$(dir $@)"

#.----------------------------------.
#| Specialized Rules                |
#'----------------------------------'

$(ARCH_PPLSCRIPT): $(ARCH_LINKSCRIPT)
	@-$(MAKE_BDIR)
	@if test $(VERBOSE) = 0; then \
		echo "[CPP ] $(notdir $@)"; \
	 else \
	 	echo "$(CPP) $(KCPPFLAGS) -P -D__ASM__ -o \"$@\" \"$<\""; \
	 fi
	@$(CPP) $(KCPPFLAGS) -P -D__ASM__ -o "$@" "$<"

$(KERNEL): $(KERNEL).sym.o
	@-$(MAKE_BDIR)
	@if test $(VERBOSE) = 0; then \
		echo "[LD  ] $(notdir $@)"; \
	 else \
	 	echo "$(LD) $(KLDFLAGS) -o \"$@\" $(KERNEL_OBJECTS)"; \
	 fi
	@$(LD) $(KLDFLAGS) -o "$@" $(filter-out %ksym_dummy.o,$(KERNEL_OBJECTS)) $(KERNEL).sym.o

$(KERNEL).dbg: $(KERNEL)
	@if test $(VERBOSE) = 0; then \
		echo "[SPLT] $(notdir $@)"; \
	 else \
		echo "$(OBJCOPY) --only-keep-debug \"$<\" \"$@\""; \
		echo "$(OBJCOPY) --strip-debug \"$<\""; \
		echo "$(OBJCOPY) --add-gnu-debuglink=\"$@\" \"$<\""; \
		echo "touch \"$@\""; \
	 fi
	@$(OBJCOPY) --only-keep-debug "$<" "$@"
	@$(OBJCOPY) --strip-debug "$<"
	@$(OBJCOPY) --add-gnu-debuglink="$@" "$<"
	@touch "$@"

$(KERNEL).sym.dmp: $(KERNEL_OBJECTS) $(ARCH_PPLSCRIPT)
	@-rm -f "$@"
	@-rm -f "$@.bin"
	@$(LD) $(KLDFLAGS) -o "$@.bin" $(KERNEL_OBJECTS)
	@echo "declare -a names" >> "$@"
	@echo "declare -a sizes" >> "$@"
	@$(NM) -n -S --defined-only "$@.bin" | sed -e 's,\(^[0-9a-fA-F]*[ \t]*\)\([tT].*$$\),\10a \2,g' | grep -E '^[0-9a-fA-F]*[ \t]+[0-9a-fA-F]*[ \t]+[Tt]' | while read addr size type name; do \
		test -z "$${size}" && size=1; \
		test -z "$${idx}" && idx=0; \
		echo "names[$${idx}]=\"$${name}\"" >> "$@"; \
        echo "addrs[$${idx}]=$${addr}" >> "$@"; \
		echo "sizes[$${idx}]=$${size}" >> "$@"; \
		((idx += 1)); \
	done;
	@-rm -f "$@.bin"

$(KERNEL).sym.S: $(KERNEL).sym.dmp
	@-rm -f "$@"
	@echo "# GENERATED BY THE MAKEFILE!" >> "$@"
	@echo ".section .rodata" >> "$@"
	@source "$<"; \
	 x=0; while [[ $${x} -lt $${#names[@]} ]]; do \
	 	echo ".sym$${x}: .string \"$${names[$${x}]}\"" >> "$@"; ((x += 1)); \
	 done;
	@echo ".global ksym_table" >> "$@"
	@echo "ksym_table:" >> "$@"
	@source "$<"; \
	 case "$(ARCH)" in x86) op=".long" ;; x86_64) op=".quad" ;; esac; \
	 x=0; while [[ $${x} -lt $${#names[@]} ]]; do \
        if [[ $${x} -gt 0 ]]; then \
            ((y=x-1)); \
            echo "ibase=16" > "$@.calc"; \
            echo "$${addrs[$${x}]} - ($${addrs[$${y}]}+$${sizes[$${y}]})" | tr '[a-z]' '[A-Z]' >> "$@.calc"; \
            echo "quit" >> "$@.calc"; \
            cross=`bc -s -q "$@.calc"`; \
            addrs[$${x}]=$${addrs[$${x}]}; \
            sizes[$${x}]=$${sizes[$${x}]}; \
            if [[ $${cross} -lt 0 && $${cross} -gt -11 ]]; then \
                sizes[$${y}]=$${sizes[$${y}]}$${cross}; \
            fi; \
            rm -f "$@.calc"; \
        fi; \
		((x += 1)); \
		printf "[SYM ] Generated %5d of %5d\r" $${x} $${#names[@]}; \
     done; \
	 printf "\n"; \
	 x=0; while [[ $${x} -lt $${#names[@]} ]]; do \
	 	echo "	$${op} 0x$${addrs[$${x}]}" >> "$@"; \
		echo "	$${op} 0x$${sizes[$${x}]}" >> "$@"; \
		echo "	$${op} .sym$${x}" >> "$@"; \
		((x += 1)); \
		printf "[SYM ] Wrote     %5d of %5d\r" $${x} $${#names[@]}; \
	 done; \
	 printf "\n";

$(KERNEL).sym.o: $(KERNEL).sym.S
	@-$(MAKE_BDIR)
	@if test $(VERBOSE) = 0; then \
		echo "[SYM ] $(notdir $(KERNEL))"; \
	 else \
	 	echo "$(CC) $(KCFLAGS) -D__ASM__ -c -o \"$@\" \"$<\""; \
	 fi
	@$(CC) $(KCFLAGS) -D__ASM__ -c -o "$@" "$<"


all-kernel: $(KERNEL) $(KERNEL).dbg
	@printf "kernel ready: " 
	@(cd $(dir $(KERNEL)) && ls -hs $(notdir $(KERNEL)))

clean:
	@-rm -rf $(SOURCEDIR)/.build

#.----------------------------------.
#| General Template Rules           |
#'----------------------------------'

include $(foreach mf,$(subst .o,.Po,$(KERNEL_OBJECTS)),$(wildcard $(mf)))

$(KERNEL_COBJECTS): $(BUILDDIR)/%.o: $(SOURCEDIR)/%.c
	@-$(MAKE_BDIR)
	@if test $(VERBOSE) = 0; then \
		echo "[CC  ] $(subst $(SOURCEDIR)/,,$<)"; \
	 else \
	 	echo "$(CC) $(KCFLAGS) -c -o \"$@\" \"$<\""; \
	 fi
	@$(CC) -MMD -MF "$(subst .o,.Po,$@)" $(KCFLAGS) -c -o "$@" "$<"

$(KERNEL_SOBJECTS): $(BUILDDIR)/%.o: $(SOURCEDIR)/%.S
	@-$(MAKE_BDIR)
	@if test $(VERBOSE) = 0; then \
		echo "[AS  ] $(subst $(SOURCEDIR)/,,$<)"; \
	 else \
	 	echo "$(CC) $(KCFLAGS) -D__ASM__ -c -o \"$@\" \"$<\""; \
	 fi
	@$(CC) -MMD -MF "$(subst .o,.Po,$@)" $(KCFLAGS) -D__ASM__ -c -o "$@" "$<"

#.----------------------------------.
#| Helper rules                     |
#'----------------------------------'

all-archs:
	@for x in $(SOURCEDIR)/config/*.mk; do arch="$${x%.mk}"; arch=$${arch##*/}; echo "building $$arch ..."; \
	 $(MAKE) -f $(SOURCEDIR)/Makefile ARCH=$${arch} all; done

all-archs-iso:
	@for x in $(SOURCEDIR)/config/*.mk; do arch="$${x%.mk}"; arch=$${arch##*/}; echo "building $$arch ..."; \
	 $(MAKE) -f $(SOURCEDIR)/Makefile ARCH=$${arch} iso; done

#
# qemu direct kernel boot.
#

KQFLAGS := $(BASE_QFLAGS) $(QFLAGS)

qemu: all-kernel
	@arch=$(ARCH); arch=$${arch%%-*}; qe=$$(type -p qemu-system-$${arch}); test -z "$${qe}" && qe=qemu; \
	 echo "using $${qe}..."; $${qe} $(KQFLAGS) -kernel $(KERNEL);

qemu-dbg:
	@$(MAKE) -f $(SOURCEDIR)/Makefile qemu QFLAGS="$(QFLAGS) -s -S"

gdb:
	@gdb=$$(type -p cgdb); test -x "$${gdb}" || gdb=$(GDB); test -x "$${gdb}" || gdb=gdb; \
	 echo "using $${gdb}..."; \
	$${gdb} -x $(SOURCEDIR)/config/misc/gdb-qemu.gdbinit $(KERNEL)
	
#
# grub2 network boot
#

qemu-netboot-grub2: all-kernel $(GRUB2_CFG) $(GRUB2_PXE)
	@arch=$(ARCH); arch=$${arch%%-*}; qe=$$(type -p qemu-system-$${arch}); test -z "$${qe}" && qe=qemu; \
	 echo "using $${qe}..."; $${qe} $(KQFLAGS) -net nic -net user,tftp=$(BUILDDIR),bootfile=$(subst $(BUILDDIR),,$(GRUB2_PXE)) -boot n;

qemu-netboot-grub2-dbg:
	@$(MAKE) -f $(SOURCEDIR)/Makefile qemu-netboot-grub2 QFLAGS="$(QFLAGS) -s -S"

#
# direct network boot - multiboot loaded by gPXE.
#

qemu-netboot: all-kernel
	@arch=$(ARCH); arch=$${arch%%-*}; qe=$$(type -p qemu-system-$${arch}); test -z "$${qe}" && qe=qemu; \
	 echo "using $${qe}..."; $${qe} $(KQFLAGS) -net nic -net user,tftp=$(BUILDDIR),bootfile=/$(notdir $(KERNEL)) -boot n;

qemu-netboot-dbg:
	@$(MAKE) -f $(SOURCEDIR)/Makefile qemu-netboot QFLAGS="$(QFLAGS) -s -S"

#
# cdrom iso boot.
#

qemu-cd: $(GRUB2_ISO)
	@arch=$(ARCH); arch=$${arch%%-*}; qe=$$(type -p qemu-system-$${arch}); test -z "$${qe}" && qe=qemu; \
	 echo "using $${qe}..."; $${qe} $(KQFLAGS) -cdrom $(GRUB2_ISO) -boot d;

qemu-cd-dbg:
	@$(MAKE) -f $(SOURCEDIR)/Makefile qemu-cd-dbg QFLAGS="$(QFLAGS) -s -S"

#
# BOCHS related stuff
#

BOCHS_RC	:= $(BUILDDIR)/bochsrc.txt

$(BOCHS_RC): $(SOURCEDIR)/config/misc/bochsrc.in $(GRUB2_ISO)
	@-$(MAKE_BDIR)
	@sed -e "s,@GRUB2_ISO@,$(GRUB2_ISO),g" -e "s,@SERIAL_FILE@,$(BUILDDIR)/serial-bochs.log,g" < "$<" > "$@"

bochs-cd: $(BOCHS_RC) $(GRUB2_ISO)
	@bochs="$$(type -p bochs)"; test -x "$${bochs}" || { echo "bochs not found!"; exit 1; }; \
	 $${bochs} -qf $(BOCHS_RC) || true

#
# GRUB2 related stuff
#

$(GRUB2_CFG): $(SOURCEDIR)/config/misc/grub2.cfg
	@-$(MAKE_BDIR)
	@sed -e "s,@KERNEL@,$(notdir $(KERNEL)),g" < "$<" > "$@"

$(GRUB2_PXE):
	@mknet=$$(type -p grub-mknetdir); test -x "$${mknet}" || { echo "grub-mknetdir not found!"; exit 1; }; \
	 $${mknet} --net-directory=$(BUILDDIR);

$(GRUB2_ISO): $(GRUB2_CFG) all-kernel
	@-rm -f "$@"
	@mkresc=$$(type -p grub-mkrescue); test -x "$${mkresc}" || { echo "grub-mkrescue not found!"; exit 1; }; \
	 $${mkresc} -o "$@" --modules="biosdisk iso9660 multiboot sh" $(BUILDDIR)
	@echo "iso image \"$@\" built..."

iso: $(GRUB2_ISO)


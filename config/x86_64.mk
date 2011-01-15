# Copyright (c) 2010 by Markus Duft <mduft@gentoo.org>
# This file is part of the 'tachyon' operating system.

CC				:= x86_64-pc-elf-gcc
CXX				:= x86_64-pc-elf-g++
LD				:= x86_64-pc-elf-ld
CPP				:= x86_64-pc-elf-cpp
OBJCOPY         := x86_64-pc-elf-objcopy

KERNEL_CPPFLAGS := -D__X86_64__
KERNEL_CFLAGS	:= -O0 -g -mcmodel=kernel -mno-red-zone $(KERNEL_CPPFLAGS)
KERNEL_CXXFLAGS	:= $(KERNEL_CFLAGS)
KERNEL_LDFLAGS	:= -z max-page-size=0x1000

KERNEL			:= $(BUILDDIR)/$(ARCH)-tachyon

KERNEL_ADD		:=

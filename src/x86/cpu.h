/* Copyright (c) 2010 by Markus Duft <mduft@gentoo.org>
 * This file is part of the 'tachyon' operating system. */

#pragma once

#define CR0_PAGING              (1 << 31)
#define CR0_CACHE_DISABLE       (1 << 30)
#define CR0_NOT_WRITE_THROUGH   (1 << 29)
#define CR0_ALIGNMENT_MASK      (1 << 18)
#define CR0_WRITE_PROTECT       (1 << 16)
#define CR0_NUMERIC_ERROR       (1 << 5)
#define CR0_EXTENSION_TYPE      (1 << 4)
#define CR0_TASK_SWITCHED       (1 << 3)
#define CR0_FPU_EMULATION       (1 << 2)
#define CR0_MONITOR_FPU         (1 << 1)
#define CR0_PROTECTION          (1 << 0)

#define CR4_VME                 (1 << 0)
#define CR4_PMODE_VIRTUAL_INT   (1 << 1)
#define CR4_TIMESTAMP_RESTRICT  (1 << 2)
#define CR4_DEBUGGING_EXT       (1 << 3)
#define CR4_PSE                 (1 << 4)
#define CR4_PAE                 (1 << 5)
#define CR4_MCE                 (1 << 6)
#define CR4_GLOBAL_PAGES        (1 << 7)
#define CR4_PERF_COUNTER        (1 << 8)
#define CR4_OS_FXSR             (1 << 9)
#define CR4_OS_XMMEXCEPT        (1 << 10)
#define CR4_VMX_ENABLE          (1 << 13)
#define CR4_SMX_ENABLE          (1 << 14)
#define CR4_PCID_ENABLE         (1 << 17)
#define CR4_OS_XSAVE            (1 << 18)


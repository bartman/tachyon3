/* copyright (c) 2011 by markus duft <mduft@gentoo.org>
 * this file is part of the 'tachyon' operating system. */

#include "tss.h"
#include "dyngdt.h"

#include <kheap.h>
#include <mem.h>
#include <stka.h>
#include <spc.h>
#include <log.h>

#include "gdt.h"
#include "paging.h"

static stack_allocator_t* kstack_allocator = NULL;

void tss_init() {
    if(kstack_allocator == NULL) {
        stack_allocator_desc_t desc = {
            .top = KSHEAP_END,
            .bottom = KSHEAP_START,
            .space = spc_current(),
            .pg_fl = (PG_WRITABLE),
            .fixed = true
        };

        kstack_allocator = stka_new(&desc);

        if(!kstack_allocator)
            fatal("failed to create kernel stack allocator\n");
    }

    tss_t* tss = kheap_alloc(sizeof(tss_t));
    memset(tss, 0, sizeof(tss_t));

    /* allocate IST stacks, ring stacks...
     * the stack descriptor is currently discarded, as we never want/need
     * to free those stacks again... maybe in the future? cpu hotplug? */
    tss->ist[IST_FAULT_STACK] = stka_alloc(kstack_allocator)->top;

    dyngdt_set(GDT_KTSS, (uintptr_t)tss, sizeof(tss_t), GDT_TYPE_TSS, 0, true, true);
}
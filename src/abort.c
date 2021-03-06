/* Copyright (c) 2011 by Markus Duft <mduft@gentoo.org>
 * This file is part of the 'tachyon' operating system. */

#include <tachyon.h>
#include <log.h>
#include <ksym.h>

void abort(void) {
    // don't use fatal() as this calls abort ;)
    log_write(Fatal, "tachyon aborted.\n");

    list_t* trace = ksym_trace();
    ksym_write_trace(Error, trace);
    ksym_delete(trace);

    stop:
        asm("cli; hlt;");
        goto stop;
}

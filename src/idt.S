# Copyright (c) 2011 by Markus Duft <mduft@gentoo.org>
# This file is part of the 'tachyon' operating system.

#include <defs.h>
#include <asm.h>
#include <idt.h>

SECTION_BOOT_DATA

.global x86_64_idt_init
.global x86_64_idt_set

.type x86_64_idt_init, @function
.type x86_64_idt_set, @function

.size x86_64_idt_init, .x86_64_idt_init_end - x86_64_idt_init
.size x86_64_idt_set, .x86_64_idt_set_end - x86_64_idt_set

# .----------------------------------------.
# | 64 bit IDT                             |
# '----------------------------------------'

.align 0x10
x86_64_idt:
    .fill 120, 0x8, 0x0 # 60 entries a 0x10 bytes, thus 120 times 0x8 bytes room

x86_64_idt_ptr:
    .word . - x86_64_idt - 1
    .quad x86_64_idt

# .----------------------------------------.
# | 64 bit ISRs that delegate              |
# '----------------------------------------'

.section .data

_x86_64_isr_res_error:
    .asciz "warn: ignoring reserved interrupt %d!\n"

_x86_64_isr_reg_dmp:
    .asciz "regs: %x %x %x\n"

.section .text

intr_test:
    # %rsp -> interrupt_t*
    push %rdi
    mov %rsp, %rdi
    add $0x10, %rdi # return address!!!
    push %rsi
    # push rest that should be checked
    push %rsp

    mov %rsp, %rsi
    call intr_do_test

    pop %rsp
    pop %rsi
    pop %rdi
    ret


.macro x86_64_isr num, has_err, res=0
.type _x86_64_isr\num, @function
.size _x86_64_isr\num, ._x86_64_isr_end\num - _x86_64_isr\num
_x86_64_isr\num:
    cli                 # do it now, set the count later (below)
                        # otherwise we would have to save register here!
    
    .if !\has_err
    push $0x0
    .endif
    push $\num

    subq $0x8, %rsp     # reserve space for the context address on the stack

    .if \res
    push %rdi
    push %rsi
    push %rdx

    mov $0x2, %rdi                      # Level = Error
    mov $_x86_64_isr_res_error, %rsi    # message (above)
    mov $\num, %rdx                     # the number.
    call log_write

    pop %rdx
    pop %rsi
    pop %rdi
    .else
    push %rax            # save registers that would otherwise be clobbered.
    push %rbx            # ATTENTION: carefully debugged to find all clobbered
    push %rcx            #            registers. may change if the code changes!!!
    push %rdx
    push %rdi
    push %rsi
    call intr_disable    # fake disabling (adjusts d/a count).
    call thr_ctx_get     # retrieve the current context.
    mov %rax, 0x30(%rsp) # save the pointer to the reserved stack space.
    pop %rsi
    pop %rdi
    pop %rdx
    pop %rcx
    pop %rbx
    pop %rax             # restore the original registers

    call x86_64_isr_state_save

    mov 0x08(%rsp), %rsi # pass in the interrupt number
    mov %rsp, %rdi       # pass in the interrupt state

    push 0x18(%rsp)      # push dummy return address.
    mov $INTR_MAGIC_FRAME, %rax
    push %rax            # push magic number for tracer.
    push %rbp            # new frame to ease tracing.
    mov %rsp, %rbp       # ...

    callq intr_dispatch

    pop %rbp             # restore old frame
    pop %rax             # remove magic frame
    pop %rax             # remove dummy return address.

    call thr_ctx_get     # retrieve current (new?) context.
    mov %rax, (%rsp)     # save new context ptr to stack.

    mov $0x0, %rdi       # don't really enable interrupts, fake it.
    call intr_enable     # decrement interrupt counter.

    call x86_64_isr_state_restore

    # TEST
    call intr_test

    .endif
    # ATTENTION: the cpu does _not_ pop an error code, even when it
    # pushed one, so remove any code here!
    addq $0x18, %rsp

    sti
    iretq
._x86_64_isr_end\num:
.endm

x86_64_isr     EX_DIV_ERR,      0       #DE     0x00
x86_64_isr     EX_DEBUG_EX,     0       #DB     0x01
x86_64_isr     EX_NMI,          0       #NMI    0x02
x86_64_isr     EX_BREAKPOINT,   0       #BP     0x03
x86_64_isr     EX_OVERFLOW,     0       #OF     0x04
x86_64_isr     EX_BOUND_RANGE,  0       #BR     0x05
x86_64_isr     EX_INVALID_OP,   0       #UD     0x06
x86_64_isr     EX_DEVICE_NA,    0       #NM     0x07
x86_64_isr     EX_DFAULT,       1       #DF     0x08
x86_64_isr     EX_CO_SEG_OF,    0,  1   #RESERVED - only in old CPUs
x86_64_isr     EX_INVALID_TSS,  1       #TS     0x0a
x86_64_isr     EX_SEG_NP,       1       #NP     0x0b
x86_64_isr     EX_STACK_FAULT,  1       #SS     0x0c
x86_64_isr     EX_GPF,          1       #GP     0x0d
x86_64_isr     EX_PAGE_FAULT,   1       #PF     0x0e
x86_64_isr     15,              0,  1   #RESERVED
x86_64_isr     EX_FPE,          0       #MF     0x10
x86_64_isr     EX_ALIGN_CHECK,  1       #AC     0x11
x86_64_isr     EX_MCE,          0       #MC     0x12
x86_64_isr     EX_SIMD_FPE,     0       #XM     0x13

x86_64_isr     20,              0,  1   #RESERVED
x86_64_isr     21,              0,  1   #RESERVED
x86_64_isr     22,              0,  1   #RESERVED
x86_64_isr     23,              0,  1   #RESERVED
x86_64_isr     24,              0,  1   #RESERVED
x86_64_isr     25,              0,  1   #RESERVED
x86_64_isr     26,              0,  1   #RESERVED
x86_64_isr     27,              0,  1   #RESERVED
x86_64_isr     28,              0,  1   #RESERVED
x86_64_isr     29,              0,  1   #RESERVED
x86_64_isr     30,              0,  1   #RESERVED
x86_64_isr     31,              0,  1   #RESERVED

x86_64_isr     32,  0
x86_64_isr     33,  0
x86_64_isr     34,  0
x86_64_isr     35,  0
x86_64_isr     36,  0
x86_64_isr     37,  0
x86_64_isr     38,  0
x86_64_isr     39,  0
x86_64_isr     40,  0
x86_64_isr     41,  0
x86_64_isr     42,  0
x86_64_isr     43,  0
x86_64_isr     44,  0
x86_64_isr     45,  0
x86_64_isr     46,  0
x86_64_isr     47,  0
x86_64_isr     48,  0
x86_64_isr     49,  0
x86_64_isr     50,  0
x86_64_isr     51,  0
x86_64_isr     52,  0
x86_64_isr     53,  0
x86_64_isr     54,  0
x86_64_isr     55,  0
x86_64_isr     56,  0
x86_64_isr     57,  0
x86_64_isr     58,  0
x86_64_isr     59,  0

# .----------------------------------------.
# | Functions to init and fill the idt     |
# '----------------------------------------'

.macro set_int_gate num, ist=0
    mov $_x86_64_isr\num, %rsi
    mov $\num, %rdi
    mov $\ist, %r8
    call x86_64_idt_set
.endm

x86_64_idt_init:
    push %rbp
    mov %rsp, %rbp
    push %rcx
    push %rsi
    push %rdi
    push %r8

    set_int_gate 0
    set_int_gate 1
    set_int_gate 2,  1
    set_int_gate 3
    set_int_gate 4
    set_int_gate 5
    set_int_gate 6
    set_int_gate 7
    set_int_gate 8,  1
    set_int_gate 9
    set_int_gate 10
    set_int_gate 11
    set_int_gate 12, 1
    set_int_gate 13
    set_int_gate 14, 1
    set_int_gate 15
    set_int_gate 16
    set_int_gate 17
    set_int_gate 18
    set_int_gate 19

    # reserved ints.
    set_int_gate 20
    set_int_gate 21
    set_int_gate 22
    set_int_gate 23
    set_int_gate 24
    set_int_gate 25
    set_int_gate 26
    set_int_gate 27
    set_int_gate 28
    set_int_gate 29
    set_int_gate 30
    set_int_gate 31

    # IRQs and other implementation defined stuff.
    set_int_gate 32
    set_int_gate 33, 3 # low-level-hardware stack
    set_int_gate 34, 3 # low-level-hardware stack
    set_int_gate 35, 3 # low-level-hardware stack
    set_int_gate 36
    set_int_gate 37
    set_int_gate 38
    set_int_gate 39
    set_int_gate 40
    set_int_gate 41
    set_int_gate 42
    set_int_gate 43
    set_int_gate 44
    set_int_gate 45
    set_int_gate 46
    set_int_gate 47
    set_int_gate 48
    set_int_gate 49
    set_int_gate 50, 2 # syscall
    set_int_gate 51
    set_int_gate 52
    set_int_gate 53
    set_int_gate 54
    set_int_gate 55
    set_int_gate 56
    set_int_gate 57
    set_int_gate 58
    set_int_gate 59

    lidt (x86_64_idt_ptr)

    pop %r8
    pop %rdi
    pop %rsi
    pop %rcx
    pop %rbp
    ret
.x86_64_idt_init_end:

x86_64_idt_set:
    push %rbp
    mov %rsp, %rbp
    push %rax
    push %rbx

    # RDI: the gate number
    # RSI: the target RIP
    # R8: the IST index to use

    # .----------------------------------------.
    # | Calculate the entries address in IDT   |
    # '----------------------------------------'
    
    push %rdx
    mov %rdi, %rax
    mov $0x10, %rdx
    mul %rdx
    pop %rdx

    add $x86_64_idt, %rax

    # .----------------------------------------.
    # | Clear the entry if RIP == 0            |
    # '----------------------------------------'
    
    cmp $0x0, %rsi
    jne 1f

    # RIP is NULL, clear the entry instead of setting it...
    movq $0x0, (%rax)
    movq $0x0, 8(%rax)
    jmp 2f  # immediately exit after setting to zero.

    # .----------------------------------------.
    # | Set the entry if RIP != 0              |
    # '----------------------------------------'

    1:
    xor %ebx, %ebx

    mov %rsi, %rbx
    and $0xFFFF, %ebx
    or $(0x18 << 0x10), %ebx

    mov %ebx, (%rax)
    mov %rsi, %rbx
    and $~0xFFFF, %ebx
    or $(IDTT_LARGE_INT_GATE | IDTE_PRESENT), %ebx
    or %r8d, %ebx
    mov %ebx, 4(%rax)

    shr $0x20, %rsi
    mov %rsi, 8(%rax)

    # .----------------------------------------.
    # | And we're done                         |
    # '----------------------------------------'

    2:
    pop %rbx
    pop %rax
    pop %rbp
    ret
.x86_64_idt_set_end:

.arm
.align 4

.include "definition.s"

b exception_reset
b exception_undefined
b exception_swi
b exception_unused
b exception_unused
b exception_unused
b exception_irq
b exception_unused

exception_reset:
    @ Setup supervisor, IRQ and system mode stacks.
    msr cpsr_c, #MODE_SVC
    ldr r13, =#SVC_STACK
    msr cpsr_c, #MODE_IRQ
    ldr r13, =#IRQ_STACK
    msr cpsr_c, #MODE_SYS
    ldr r13, =#SYS_STACK

    @ Jump into the ROM
    mov r0, #ROM_ENTRYPOINT
    mov r14, r15
    bx r0
    b $

exception_undefined:
    b $

exception_swi:
    b $

@ prefetch abort, data abort, reserved, fast IRQ
exception_unused:
    b $

exception_irq:
    b $

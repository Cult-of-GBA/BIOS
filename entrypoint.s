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
    ldr sp, =#SVC_STACK
    msr cpsr_c, #MODE_IRQ
    ldr sp, =#IRQ_STACK
    msr cpsr_c, #MODE_SYS
    ldr sp, =#SYS_STACK

    @ Jump into the ROM
    mov r0, #ROM_ENTRYPOINT
    mov lr, pc
    bx r0
    b $

exception_irq:
    stmfd sp!, {r0-r3, r12, lr}
    mov r0, #0x04000000
    add lr, pc, #0
    ldr pc, [r0, #-4]
    ldmfd sp!, {r0-r3, r12, lr}
    subs pc, lr, #4

exception_swi:
    stmfd sp!, {r11-r12, lr}

    @ extract SWI call number from the opcode
    ldrb r12, [lr, #-2]
    adr r11, swi_table
    ldr r12, [r11, r12, lsl #2]

    @ save current SPSR value in case an IRQ handler causes
    @ another SWI in which case it would get overwritten.
    mrs r11, spsr
    stmfd sp!, {r11}

    @ enter system mode but keep IRQ-disable bit from the caller mode.
    and r11, #IRQ_DISABLE
    orr r11, #MODE_SYS
    msr cpsr_fc, r11

    @ save r2 because the SWI handler may modify it.
    @ save system mode lr because we overwrite it in the next instruction.
    stmfd sp!, {r2, lr}

    @ set return address and jump to the SWI handler.
    adr lr, .done
    bx r12
.done:
    @ restore system saved registers
    ldmfd sp!, {r2, lr}

    @ switch back to supervisor mode
    @ we can now access the supervisor stack again.
    @ NOTE: I think it should be possible to use an immediate MSR here
    mov r12, #(MODE_SVC | IRQ_DISABLE)
    msr cpsr_fc, r12

    @ restore saved SPSR
    ldmfd sp!, {r11}
    msr spsr_fc, r11

    @ restore supervisor saved registers and return
    ldmfd sp!, {r11-r12, lr}
    movs pc, lr

exception_undefined:
    b $

@ prefetch abort, data abort, reserved, fast IRQ
exception_unused:
    b $

@ NOTE: SWI handler may modify r0-r2, r12 and lr.
dummy_swi:
    bx lr

@ NOTE: this table can be massively shortened if we yolo out-of-bound SWIs.
swi_table:
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi
    .word dummy_swi

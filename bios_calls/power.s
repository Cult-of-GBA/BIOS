swi_Halt:
    mov r11, #0
    mov r12, #MMIO_BASE
    strb r11, [r12, #(REG_HALTCNT - MMIO_BASE)]
    bx lr

swi_Stop:
    mov r11, #0x80
    mov r12, #MMIO_BASE
    strb r11, [r12, #(REG_HALTCNT - MMIO_BASE)]
    bx lr

swi_CustomHalt:
    @ abuse the fact that r12 is overwritten in the SWI return later
    mov r12, #0x04000000
    strb r2, [r12, #0x301]
    bx lr

swi_VBlankIntrWait:
    mov r0, #1
    mov r1, #1
swi_IntrWait:
    stmfd sp!, {r4, lr}
    mov r2, #0
    mov r3, #1
    mov r12, #MMIO_BASE
    cmp r0, #0
    blne .intr_wait_check_processed_irqs

    adr lr, .intr_wait_loop_end
.intr_wait_halt_until_irq:
    @ HALTCNT = 0 (enter halt mode)
    strb r2, [r12, #(REG_HALTCNT - MMIO_BASE)]

.intr_wait_check_processed_irqs:
    @ IME = 0
    @ If we don't do this the SWI and the IRQ handler will race for the BIOS interrupt flags.
    strb r2, [r12, #(REG_IME - MMIO_BASE)]

    @ Read BIOS interrupt flags which are stored at 0x03FFFFF8 and updated by the IRQ handler.
    @ This contains the IRQs that already have been processed by the IRQ handler.
    ldrh r4, [r12, #-8]

    @ Extract already processed IRQs that we were waiting for and acknowledge them.
    ands r0, r1, r4
    eorne r4, r0
    strneh r4, [r12, #-8]

    @ IME = 1
    strb r3, [r12, #(REG_IME - MMIO_BASE)]
    bx lr

.intr_wait_loop_end:
    @ Repeat if we didn't get any IRQ that we were waiting for.
    @ This reuses the zero-flag from the ANDS instruction in .intr_wait_check_processed_irqs.
    beq .intr_wait_halt_until_irq

    ldmfd sp!, {r4, lr}
    bx lr

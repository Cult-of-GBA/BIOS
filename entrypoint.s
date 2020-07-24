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
swi_HardReset:
    @ disable IME
    mov r0, #0x04000000
    strb r0, [r0, #8]
    
    @ set r2 to 0 so that we enter ROM after SoftReset
    @ todo: jump to the boot animation function, and keep "reset_modes" in lr, then mov r2, #0 right before bx lr at the end of it
    mov lr, #ROM_ENTRYPOINT
    b reset_modes
    
swi_SoftReset:
    @ read return address from 0x03007FFA (0x04000000 - 6 with mirroring)
    mov r0, #0x04000000
    ldrb r2, [r0, #-6]
    cmp r2, #0
    moveq lr, #ROM_ENTRYPOINT
    movne lr, #RAM_ENTRYPOINT

reset_modes:
    @ Setup supervisor, IRQ and system mode stacks/link registers/.
    msr cpsr_cf, #MODE_SVC
    ldr sp, =#SVC_STACK
    mov lr, #0
    msr spsr_cf, lr 
    msr cpsr_c, #MODE_IRQ
    ldr sp, =#IRQ_STACK
    mov lr, #0
    msr spsr_cf, lr
    msr cpsr_cf, #MODE_SYS
    ldr sp, =#SYS_STACK
    
    @ clear 0x200 bytes of RAM from 0x03007d00 to 0x03007fff
    @ r0 still contains 0x04000000 from HardReset or SoftReset!
    ldr r1, =#-0x200
    mov r2, #0
    
    .soft_reset_RAM_clear:
        str r2, [r0, r1]
        adds r1, #4
        bne .soft_reset_RAM_clear
    
    @ load all registers from 0 cleared RAM
    ldmfa r0, { r0-r12 }
    
    @ Jump into the ROM or RAM
    bx lr

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
    adr lr, .swi_handler_done
    bx r12
.swi_handler_done:
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
    
@ the real BIOS yolo's out-of-bound SWIs, so we might as well do it too
swi_table:
    .word swi_SoftReset
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_Div
    .word swi_DivArm
    .word swi_Sqrt
    .word swi_ArcTan
    .word swi_ArcTan2
    .word swi_CpuSet
    .word swi_CpuFastSet
    .word swi_GetBiosChecksum
    .word swi_BGAffineSet
    .word swi_ObjAffineSet
    .word swi_DoNothing
    .word swi_LZ77UnCompReadNormalWrite8bit
    .word swi_LZ77UnCompReadNormalWrite8bit
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_HardReset
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing
    .word swi_DoNothing

@ NOTE: SWI handler may modify r0-r2, r12 and lr.
swi_DoNothing:
    bx lr

swi_CpuSet:
    stmfd sp!, {r3, r4}

    @ r3 = word count
    lsl r3, r2, #11
    lsrs r3, r3, #11
    beq .swi_CpuSet_done

    @ r2 = fn table index, bit0=fill, bit1=32-bit
    @ TODO: mask out unused bits to make sure this doesn't break?
    lsrs r2, r2, #25
    orrcs r2, r2, #1
    adr r4, .fn_table
    ldr pc, [r4, r2, lsl #2]
.fn_table:
    .word .copy16
    .word .fill16
    .word .copy32
    .word .fill32
.copy16:
    ldrh r4, [r0], #2
    strh r4, [r1], #2
    subs r3, r3, #1
    bne .copy16
    ldmfd sp!, {r3, r4}
    bx lr
.fill16:
    ldrh r4, [r0]
.fill16_loop:
    strh r4, [r1], #2
    subs r3, r3, #1
    bne .fill16_loop
    ldmfd sp!, {r3, r4}
    bx lr
.copy32:
    ldmia r0!, {r4}
    stmia r1!, {r4}
    subs r3, r3, #1
    bne .copy32
    ldmfd sp!, {r3, r4}
    bx lr
.fill32:
    ldr r4, [r0]
.fill32_loop:
    str r4, [r1], #4
    subs r3, r3, #1
    bne .fill32_loop
.swi_CpuSet_done:
    ldmfd sp!, {r3, r4}
    bx lr

swi_CpuFastSet:
    stmfd sp!, {r3 - r11}

    @ r3 = word count
    lsl r3, r2, #11
    lsrs r3, #11
    beq .swi_CpuFastSet_done

    @ perform copy or fill operation depending on bit24 or r2.
    tst r2, #(1 << 24)
    bne .fill_fast32
.copy_fast32:
    ldmia r0!, {r4 - r11}
    stmia r1!, {r4 - r11}
    subs r3, #8
    bgt .copy_fast32
    ldmfd sp!, {r3 - r11}
    bx lr
.fill_fast32:
    ldr r4, [r0]
    mov r5, r4
    mov r6, r4
    mov r7, r4
    mov r8, r4
    mov r9, r4
    mov r10, r4
    mov r11, r4
.fill_fast32_loop:
    stmia r1!, {r4 - r11}
    subs r3, #8
    bgt .fill_fast32_loop
.swi_CpuFastSet_done:
    ldmfd sp!, {r3 - r11}
    bx lr

swi_LZ77UnCompReadNormalWrite8bit:
    stmfd sp!, {r3 - r6}

    @ Read header word:
    @ bit0-3:  reserved
    @ bit4-7:  compressed type (1 for LZ77)
    @ bit8-31: size of compressed data
    ldr r2, [r0], #4
    lsrs r2, r2, #8
    @ ignore zero-length decompression requests
    beq .lz77_done

.lz77_loop:
    @ read encoder byte, shift to MSB for easier access.
    ldrb r3, [r0], #1
    orr r3, #0x01000000
.lz77_encoder_loop:
    tst r3, #0x80
    bne .lz77_copy_window
.lz77_copy_byte:
    @ copy byte from current source to current destination
    ldrb r4, [r0], #1
    strb r4, [r1], #1

    @ check if decompressed length has been reached.
    subs r2, #1
    beq .lz77_done

    @ read next encoder or process next block
    lsls r3, #1
    bcc .lz77_encoder_loop
    b .lz77_loop
.lz77_copy_window:
    @ read window tuple {displacement, size}
    ldrb r4, [r0], #1
    ldrb r5, [r0], #1

    @ r5 = window displacement
    orr r5, r5, r4, lsl #8
    bic r5, #0xF000
    add r5, #1

    @ r4 = window size
    lsr r4, #4
    add r4, #3
.lz77_copy_window_loop:
    @ copy byte from window to current destination
    ldrb r6, [r1, -r5]
    strb r6, [r1], #1

    @ check if decompressed length has been reached
    subs r2, #1
    beq .lz77_done

    @ check if window has been fully copied
    subs r4, #1
    bne .lz77_copy_window_loop

    @ read next encoder or process next block
    lsls r3, #1
    bcc .lz77_encoder_loop
    b .lz77_loop

.lz77_done:
    ldmfd sp!, {r3 - r6}
    bx lr

.include "arithmetic.s"
.include "misc.s"
.include "rotation_scaling.s"
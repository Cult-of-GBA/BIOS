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
    
    bl reset_modes
    mov r0, #0xff
    bl swi_RegisterRamReset
    
    bl BootScreen
    
    bl reset_modes
    mov r0, #0xff
    bl swi_RegisterRamReset
    
    mov lr, #ROM_ENTRYPOINT
    bx lr
    
swi_SoftReset:
    @ read return address from 0x03007FFA (0x04000000 - 6 with mirroring)
    mov r0, #0x04000000
    ldrb r2, [r0, #-6]
    tst r2, #1
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
    .word swi_RegisterRamReset
    .word swi_Halt
    .word swi_Stop
    .word swi_IntrWait
    .word swi_VBlankIntrWait
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
    .word swi_BitUnpack
    .word swi_LZ77UnCompWrite8bit
    .word swi_LZ77UnCompWrite16bit
    .word swi_HuffUnCompReadNormal
    .word swi_RLUnCompReadNormalWrite8bit
    .word swi_RLUnCompReadNormalWrite16bit
    .word swi_Diff8bitUnfilterWrite8bit
    .word swi_Diff8bitUnfilterWrite16bit
    .word swi_Diff16bitUnfilter
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

.include "memory.s"
.include "arithmetic.s"
.include "misc.s"
.include "rotation_scaling.s"
.include "reset_functions.s"
.include "decompression.s"
.include "power.s"
.include "boot_screen.s"

.pool

@ This probably isn't best practice... whatever.
.org 16384
padding:

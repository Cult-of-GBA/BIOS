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

    msr cpsr, #MODE_SYS
    
    bl reset_modes
    mov r0, #0xff
    bl swi_RegisterRamReset
    
    bl BootScreen
    
    mov r0, #0xff
    bl swi_RegisterRamReset
    @ r0 needs to contain 0x04000000 for the inline with swi_SoftReset to work
    mov r0, #0x04000000
    bl reset_modes

    @ setup IO registers in the same way the official BIOS does
    @ testing on my emulators gave the following non-zero values:
    @ 0000 - 0080
    @ 0020 - 0100
    @ 0026 - 0100
    @ 0030 - 0100
    @ 0036 - 0100
    @ 0082 - 880e
    @ 0088 - 0200
    @ 0134 - 8000
    @ out BIOS still comes out with 
    @ 0004 - 0008
    @ 0008 - 0007
    @ 004a - 3001
    @ 0200 - 0001

    mov r0, #0x04000000
    mov r1, #.hard_reset_IO_values

    .hard_reset_IO_setup:
        ldrh r2, [r1], #2
        ldrh r3, [r1], #2
        strh r3, [r0, r2]
        cmp r1, #.hard_reset_IO_values_end
        blt .hard_reset_IO_setup
    
    @ clear registers that should be 0
    strh r0, [r0, #(REG_DISPSTAT - MMIO_BASE)]
    strh r0, [r0, #(REG_BG0CNT - MMIO_BASE)]
    strh r0, [r0, #(REG_WINOUT - MMIO_BASE)]
    add r1, r0, #(REG_IME - MMIO_BASE)
    strh r0, [r1]
    
    msr cpsr_cf, #MODE_SYS
    mov r0, #0
    mov r1, #0
    mov r2, #0
    mov r3, #0
        
    mov lr, #ROM_ENTRYPOINT
    bx lr

.hard_reset_IO_values:
    @ address, value
    .hword 0x0000, 0x0080
    .hword 0x0020, 0x0100
    .hword 0x0026, 0x0100
    .hword 0x0030, 0x0100
    .hword 0x0036, 0x0100
    .hword 0x0082, 0x880e
    .hword 0x0088, 0x0200
    .hword 0x0134, 0x8000
.hard_reset_IO_values_end:

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
    .word swi_DoNothing @ SoundBias
    .word swi_SoundDriverInit
    .word swi_DoNothing @ SoundDriverMode
    .word swi_DoNothing @ SoundDriverMain
    .word swi_SoundDriverVSync
    .word swi_DoNothing @ SoundChannelClear
    .word swi_MidiKey2Freq
    .word swi_DoNothing @ SoundWhatever0
    .word swi_DoNothing @ SoundWhatever1
    .word swi_DoNothing @ SoundWhatever2
    .word swi_DoNothing @ SoundWhatever3
    .word swi_DoNothing @ SoundWhatever4
    .word swi_DoNothing @ MultiBoot
    .word swi_HardReset
    .word swi_CustomHalt
    .word swi_SoundDriverVSyncOff
    .word swi_SoundDriverVSyncOn
    .word swi_SoundGetJumpList

@ NOTE: SWI handler may modify r0-r2, r12 and lr.

swi_DoNothing:
    bx lr

swi_GetBiosChecksum:
    @ GBATek says this should be the value resulting in r0 for a proper ROM's checksum
    @ In the end, this BIOS is directed more towards emulators, and it wouldn't matter much 
    @ if "not properly checksummed" ROMs can't run with it
    ldr r0, =#0xBAAE187F
    bx lr

.include "bios_calls/cpu_set.s"
.include "bios_calls/decompression.s"
.include "bios_calls/math.s"
.include "bios_calls/power.s"
.include "bios_calls/register_ram_reset.s"
.include "bios_calls/audio.s"

.include "boot_screen/boot_screen.s"

.pool

@ This probably isn't best practice... whatever.
.org 16384
padding:

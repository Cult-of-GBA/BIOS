.register_ram_reset_zero_value:
    .word 0
    
.register_ram_reset_dest_LUT:
    .word 0x02000000, 0x03000000, 0x05000000, 0x06000000
    .word 0x07000000, 0x04000120, 0x04000060
    
.register_ram_reset_len_LUT:
    @ CpuFastSet length in words (MUST be rounded up to 32)
    @ note for eWRAM: we actually want 0x10000 words, but since CpuFastSet rounds stuff up to 8 words anyway, 0xffff does the trick!
    @ note for iWRAM: last 200 bytes not cleared! (stack)
    @ note for IO Sound: we do not clear FIFO_A/B this way, but those will run out anyway, writing 0 to those is not really necessary...
    .hword 0xffff, 0x1F80, 0x0100, 0x6000
    .hword 0x0100, 0x0010, 0x0010

.align 4
.arm
swi_RegisterRamReset:
    @ reset certain parts of memory based on r0 (ResetFlags), never clears RAM area from 0x3007E00-0x3007FFF
    @ r0  ResetFlags
    @    Bit   Expl.
    @    0     Clear 256K on-board WRAM  ;-don't use when returning to WRAM
    @    1     Clear 32K on-chip WRAM    ;-excluding last 200h bytes
    @    2     Clear Palette
    @    3     Clear VRAM
    @    4     Clear OAM              ;-zerofilled! does NOT disable OBJs!
    @    5     Reset SIO registers    ;-switches to general purpose mode!    (0x04000120 - 0x0400015a/0x04000200) (part unused, excluding highest) -> clear 0x20 words (120 - 1a0)
    @    6     Reset Sound registers                                         (0x04000060 - 0x040000a8/0x040000b0) (part unused, excluding highest) -> clear 
    @    7     Reset all other registers (except SIO, Sound)
    
    @ we need to special case bit 7 because it's not one continuous block...
    
    stmfd sp!, { r1-r4, r11, r12, lr }
    
    mov r3, r0          @ we need r0 for the CpuFastSet base address
    mov r4, #0          @ used for offset into LUTs
    @ source address for CpuFastSet
    ldr r0, =#.register_ram_reset_zero_value
    ldr r11, =#.register_ram_reset_dest_LUT - 4     @ extra offset for convenience with r4
    ldr r12, =#.register_ram_reset_len_LUT - 2      @ extra offset for convenience with r4
    ldr lr, =#.register_ram_reset_loop
    
    .register_ram_reset_loop:
        add r4, #2
        lsrs r3, #1
        
        @ don't influence carry with tst instead of cmp
        tst r4, #16
        bne .register_ram_other_IO
        bcc .register_ram_reset_loop
        
        @ we keep adding 2 to r4 because we cant shift it in ldrh, but we can in ldr
        ldr r1, [r11, r4, lsl #1]       @ load dest address
        ldrh r2, [r12, r4]              @ load len
        orr r2, #0x01000000             @ fixed source mode
        
        @ lr contains .register_ram_reset_loop, so we loop back that way
        b swi_CpuFastSet
        
    .register_ram_other_IO:
        @ carry is already checked because we checked it before
        bcc .register_ram_reset_return
        
        @ we want to clear 0x0-0x60 (LCD + unused)/0xb0-0x110(DMA/Timers)/0x200-0x20c(Interrupts + unused)
        mov r1, #0x04000000             @ dest address
        mov r2, #0x01000000             @ fixed source
        add r2, #0x18                   @ length
        bl swi_CpuFastSet
        
        @ in the swi_CpuFastSet, r1 ends up being the first address not written to
        @ r2 is unchanged
        add r1, #0x50                   @ = 0x040000b0
        bl swi_CpuFastSet
        
        add r1, #0xf0                   @ = 0x04000200
        mov r0, #0
        str r0, [r1], #4                @ write to IE/IF
        str r0, [r1], #4                @ write to WAITCNT/unused
        str r0, [r1]                    @ write to IME
        
        @ POSTFLG and HALTCNT are not written to (would otherwise freeze up the GBA)
        
    .register_ram_reset_return:    
        ldmfd sp!, { r1-r4, r11, r12, lr }
        bx lr
    
        
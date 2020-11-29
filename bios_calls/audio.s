@ decompiled from the official BIOS:
@ // @ 0x3104
@ u8 scale_table[] = {
.align 4
.midi_scale_table:
    .byte 0xe0, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xeb
    .byte 0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xdb
    .byte 0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xcb
    .byte 0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xbb
    .byte 0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xab
    .byte 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b
    .byte 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b
    .byte 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x7b
    .byte 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b
    .byte 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x5b
    .byte 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b
    .byte 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b
    .byte 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b
    .byte 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b
    .byte 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b
@ }
@ 
@ // @ 0x31b8
@ u32 freq_table[] = {
.midi_freq_table:
    .word 0x80000000
    .word 0x879C7C97
    .word 0x8FACD61E
    .word 0x9837F052
    .word 0xA14517CC
    .word 0xAADC0848
    .word 0xB504F334
    .word 0xBFC886BB
    .word 0xCB2FF52A
    .word 0xD744FCCB
    .word 0xe411f03a
    .word 0xf1a1bf39
@ }
@ 
@ u32 MidiKey2Freq(void* wa /*r0*/, u8 mk /*r1*/, u8 _fp /*r2*/) {
@     u32 fp = _fp << 24;
@     // store wa into r7
@ 
@     if (mk > 0xb2) {
@         // prevent overflow
@         fp = 0xff000000;
@         mk = 0xb2;
@     }
@ 
@     u8 scale = scale_table[mk];           // r3
@     u32 freq = freq_table[scale & 0xf];   // r4
@     freq >>= (scale >> 4);
@ 
@     u8 scale2 = scale_table[mk + 1];       // r0
@     u32 freq2 = freq_table[scale2 & 0xf];  // r1
@     freq2 >>= (scale2 >> 4);
@     
@     u32 diff = freq2 - freq;               // r0
@     // store fp into r1
@     // umull r2, r0, diff, fp          ; r0 = RdHi, r2 = RdLo
@     // r1 = r0 + freq
@     // wave_freq = *(u32*)(wa + 4);
@     // umull r2, r0, wave_freq, r1     ; r0 = RdHi, r2 = RdLo
@     // return r0;
@ }

@ r0 WaveData* wa
@ r1 u8 mk
@ r2 u8 fp

@ return: r0 u32
swi_MidiKey2Freq:
    stmfd sp!, { r4-r6 }
    
    lsl r2, #24
    cmp r1, #0xb2

    @ if (mk > 0xb2)
    @ probably less likely that mk is out of bounds
    bgt .midi_load_max
    .midi_load_max_return:

    @ load table pointers
    ldr r3, =#.midi_scale_table
    add r4, r3, #.midi_freq_table - .midi_scale_table

    ldrb r5, [r3, r1]!        @ scale = scale_table[mk]
    and r6, r5, #0xf
    ldr r6, [r4, r6, lsl #2]  @ freq = freq_table[scale & 0xf]
    lsr r5, #4
    lsr r6, r5                @ freq >>= (scale >> 4)

    @ r3 holds .midi_scale_table + mk now
    ldrb r3, [r3, #1]         @ scale2 = scale_table[mk + 1]
    and r1, r3, #0xf          @ we don't need mk at this point
    ldr r4, [r4, r1, lsl #2]  @ freq2 = freq_table[scale2 & 0xf]
    lsr r3, #4

    rsb r4, r6, r4, lsr r3    @ freq2 '>>=' (scale2 >> 4);
                              @ diff = freq - freq2
    umull r3, r1, r4, r2      @ r3 is basically a garbage register 
    add r1, r6
    ldr r2, [r0, #4]          @ wave_freq = *(u32*)(wa + 4);
    umull r3, r0, r2, r1

    ldmfd sp!, { r4-r6 }
    bx lr

.midi_load_max:
    mov r2, #0xff000000  @ fp = 0xff000000
    mov r1, #0xb2        @ mk = 0xb2
    b .midi_load_max_return

@ input: r0: destination address for function table
swi_SoundGetJumpList:
    @ Like Normmatt's replacement BIOS: stub by functions that return immediately
    ldr r2, =#.swi_DoNothing
    mov r3, #35  @ 36 entries, but check with ge (for (int i = 35; i >= 0; i--))
    get_jump_list_loop:
        str r2, [r0, r3]
        subs r3, #1
        bge get_jump_list_loop

    bx lr

@ the sound driver has info in a stuct called SoundInfo, described here:
@ https://github.com/pret/pokeemerald/blob/b4f83b4f0fcce8c06a6a5a5fd541fb76b1fe9f4c/include/gba/m4a_internal.h#L154
@ a pointer to this struct should be at 03007ff0 in memory

.sound_init_function_table:
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

swi_SoundDriverInit:
    @ input: r0: pointer to SoundInfo struct
    @ disables DMA 1 and 2 (CNT_H = 0)
    @ sets SOUNDCNT_X to 0x8f
    @ sets SOUNDCNT_H to 0xa90e
    @ r2 = read top byte & 3 from SOUNDBIAS (BIAS level)
    @ set top byte to r2 | 0x40 (8bit / 65.536kHz sampling rate)
    @ set DMA1SAD to &SoundInfo->pcmBuffer
    @ set DMA1DAD to FIFO_A
    @ set DMA2SAD to SoundInfo + 0x13 << 7
    @ set DMA2DAD to FIFO_B
    @ store pointer to SoundInfo at 0x03007ff0
    @ zero out 0x3ec words at SoundInfo struct pointer
    @ set SoundInfo->reverb (offs 6) to 8
    @ set SoundInfo->maxChans (offs 7) to 0xf
    @ set SoundInfo->plynote (offs 0x38) to 00002425
    @ set callbacks to function that immediately returns
    @     offs 0x28, 0x2c, 0x30, 0x3c
    @ set jumptable MPlayJumpTable (offs 0x34) (35 entry jump table)
    @ !!! call function FUN_0000170a(0x40000);
    @ set SoundInfo->ident to Smsh: 6873'6d53
    stmfd sp!, { r4, lr }

    mov r4, r0
    mov r1, #MMIO_BASE

    @ disable DMA 1 and 2
    strh r1, [r1, #REG_DMA1CNT_H - MMIO_BASE]
    strh r1, [r1, #REG_DMA2CNT_H - MMIO_BASE]

    @ set sound registers
    mov r2, #0x8f
    strh r2, [r1, #REG_SOUNDCNT_X - MMIO_BASE]

    ldrh r2, =#0xa90e
    strh r2, [r1, #REG_SOUNDCNT_H - MMIO_BASE]

    @ set SOUNDBIAS
    ldrb r2, [r1, #REG_SOUNDBIAS - MMIO_BASE + 1]
    orr r2, #0x40
    strb r2, [r1, #REG_SOUNDBIAS - MMIO_BASE + 1]

    add r2, r0, #0x350  @ SoundInfo->pcmBuffer
    str r2, [r1, #REG_DMA1SAD - MMIO_BASE]

    add r2, r1, #REG_FIFO_A - MMIO_BASE
    str r2, [r1, #REG_DMA1DAD - MMIO_BASE]

    add r2, r0, #0x980  @ SoundInfo + (0x13 << 7) (second half of pcmBuffer)
    str r2, [r1, #REG_DMA2SAD - MMIO_BASE]

    add r2, r1, #REG_FIFO_B - MMIO_BASE
    str r2, [r1, #REG_DMA2DAD - MMIO_BASE]

    @ store pointer to SoundInfo
    ldr r2, =#0x03007ff0
    str r0, [r2]

    mov r0, #0
    stmfd sp!, { r0 }       @ push 0 onto the stack as source address for CpuSet (cant use address from BIOS)
    sub r0, sp, #4          @ set source address

    mov r1, r4              @ &SoundInfo
    mov r2, #0x000003ec     @ 3ec words
    orr r2, #0x01000000     @ fill with fixed source

    bl swi_CpuSet           @ clear buffer
    ldmfd sp!, { r0 }       @ pop zero value off the stack
    
    @ set values in SoundInfo struct
    @ pointers to these values might not be aligned:
    mov r0, #8
    strb r0, [r4, #0x6]
    mov r0, #0xf
    strb r0, [r4, #0x7]

    ldrh r0, =#0x2425
    str r0, [r4, #0x38]

    @ callbacks
    ldr r0, =#swi_DoNothing
    str r0, [r4, #0x28]
    str r0, [r4, #0x2c]
    str r0, [r4, #0x30]
    str r0, [r4, #0x3c]

    ldr r0, =#.sound_init_function_table
    str r0, [r4, #0x34]

    @ todo: figure out what FUN_0000170a(0x40000) does
    @ set SoundInfo->ident to Smsh: 6873'6d53
    ldr r0, =#0x68736d53
    str r0, [r4]

    ldmfd sp!, { r4, lr }
    bx lr

.pool

swi_SoundDriverVSyncOn:
    @ very short SWI, basically just sets the audio DMA channel control registers
    mov r1, #0xb600
    mov r0, #MMIO_BASE
    strh r1, [r0, #REG_DMA1CNT_H - MMIO_BASE]    @ set DMA1CNT_H
    strh r1, [r0, #REG_DMA2CNT_H - MMIO_BASE]    @ set DMA2CNT_H
    bx lr


swi_SoundDriverVSyncOff:
    @ loads a flag from the location specified at 03007ff0
    @ if this flag is equal to 6873'6d53 or 6873'6d54, it stores increments it by one and stores it back,
    @ this locks the SoundInfo struct described earlier
    @ the ident should be Smsh or Tmsh (locked)
    @ it also sets the pcmDmaCounter field to 0

    @ it clears the audio DMA channel control regs (sets to 0)
    @ sets some stuff up, does a DMA (without using DMA channels to clear the pcm buffer in that struct),
    @ decrements and stores the flag again. Sets the byte at 03007ff4 to 0

    stmfd sp!, { r4, lr }

    @ load address of flag
    ldr r4, =#0x03007ff0    @ SoundInfo**
    ldr r4, [r4]            @ SoundInfo*
    ldr r1, [r4]            @ SoundInfo->ident
    ldr r0, =#0x68736d54    @ SoundInfo identifier expected value + 1

    sub r0, r1
    cmp r0, #1              @ check if ident is 0x68736d53 or 0x68736d54
    bhi .sound_vsync_off_return

    @ lock SoundInfo struct
    add r1, #1
    str r1, [r4]

    mov r1, #MMIO_BASE

    strh r1, [r1, #REG_DMA1CNT_H - MMIO_BASE]    @ disable DMA1
    strh r1, [r1, #REG_DMA2CNT_H - MMIO_BASE]    @ disable DMA2
    strb r1, [r4, #4]       @ set pcmDmaCounter to 0

    mov r0, #0
    stmfd sp!, { r0 }       @ push 0 onto the stack as source address for CpuSet (cant use address from BIOS)
    sub r0, sp, #4          @ set source address

    add r1, r4, #0x350      @ &SoundInfo->pcmBuffer
    mov r2, #0x00000318     @ 318 words
    orr r2, #0x01000000     @ fill with fixed source

    bl swi_CpuSet           @ clear buffer
    ldmfd sp!, { r0 }       @ pop zero value off the stack
    
    ldr r1, [r4]            @ SoundInfo->ident
    sub r1, #1
    str r1, [r4]            @ decrement identifier again

    .sound_vsync_off_return:
    ldmfd sp!, { r4, lr }
    bx lr

swi_SoundDriverVSync:
    @ acts on the same struct as above
    @ loads the identifier, checks if it is correct
    @     if it is, decrements pcmDmaCounter
    @         if it remains positive, return, otherwise:
    @
    @     load "c15" field (byte, offs 0xb)
    @     store it in pcmDmaCounter
    @     disable DMA channels and set them to 0xb600 again

    @ load address of flag
    ldr r0, =#0x03007ff0    @ SoundInfo**
    ldr r0, [r0]            @ SoundInfo*
    ldr r1, [r0]            @ SoundInfo->ident
    ldr r2, =#0x68736d53    @ SoundInfo identifier expected value

    cmp r1, r2
    bne .sound_vsync_return

    ldrb r1, [r0, #0x4]     @ SoundInfo->pcmDmaCounter
    subs r1, #1
    strb r1, [r0, #0x4]     @ SoundInfo->pcmDmaCounter--

    bgt .sound_vsync_return

    ldrb r1, [r0, #0xb]     @ SoundInfo->c15
    strb r1, [r0, #0x4]     @ SoundInfo->pcmDmaCounter = SoundInfo->c15

    mov r0, #0
    mov r1, #0xb600
    mov r2, #MMIO_BASE

    strh r0, [r2, #REG_DMA1CNT_H - MMIO_BASE]   @ disable DMA1
    strh r0, [r2, #REG_DMA2CNT_H - MMIO_BASE]   @ disable DMA2
    strh r1, [r2, #REG_DMA1CNT_H - MMIO_BASE]   @ enable DMA1
    strh r1, [r2, #REG_DMA2CNT_H - MMIO_BASE]   @ enable DMA2

    .sound_vsync_return:

    bx lr

.pool

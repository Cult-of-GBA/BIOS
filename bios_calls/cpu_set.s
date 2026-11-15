@ TODO: check if source address is valid (>= 0x02000000)

swi_CpuSet:
    stmfd sp!, {r3, r4}

    @ r3 = word count
    lsl r3, r2, #11
    lsrs r3, r3, #11
    beq .swi_CpuSet_done

    @ r2 = fn table index, bit0=fill, bit1=32-bit
    and r2, r2, #0x05000000     @ keep only bit24 (fill) and bit26 (32-bit)
    adr r4, .fn_table
    ldr pc, [r4, r2, lsr #22]   @ bit24 -> +4 bytes, bit26 -> +16 bytes
.fn_table:
    .word .copy16               @ +0   (neither bit)
    .word .fill16               @ +4   (fill)
    .word 0                     @ +8   unused
    .word 0                     @ +12  unused
    .word .copy32               @ +16  (32-bit)
    .word .fill32               @ +20  (32-bit + fill)
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

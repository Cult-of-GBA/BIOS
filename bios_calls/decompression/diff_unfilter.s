swi_Diff8bitUnfilterWrite8bit:
    stmfd sp!, { r2-r4 }
    
    ldr r2, [r0], #4        @ load data header
    @ original BIOS ignores data size/type flags as well
    lsr r2, #8              @ size after decompression
    
    @ check for invalid decompression parameters
    check_invalid_decomp r2, r3, r0, .diff_8bit_unfilter_write_8bit_return
    
    ldrb r3, [r0], #1       @ original data
    
    .diff_8bit_unfilter_write_8bit_loop:
        strb r3, [r1], #1   @ store current data
        ldrb r4, [r0], #1   @ next offset
        add r3, r4          @ calculate next data
        subs r2, #1
        bgt .diff_8bit_unfilter_write_8bit_loop
    
    .diff_8bit_unfilter_write_8bit_return:
        ldmfd sp!, { r2-r4 }
        bx lr
    
swi_Diff8bitUnfilterWrite16bit:
    @ almost the same as above, except we write in units of 16 bits instead of 8 bits
    
    stmfd sp!, { r2-r5 }
    
    ldr r2, [r0], #4        @ load data header
    @ original BIOS ignores data size/type flags as well
    lsr r2, #8              @ size after decompression
    
    @ check for invalid decompression parameters
    check_invalid_decomp r2, r3, r0, .diff_8bit_unfilter_write_16bit_return
    
    ldrb r3, [r0], #1       @ original data
    ldrb r4, [r0], #1
    
    .diff_8bit_unfilter_write_16bit_loop:
        orr r4, r3, r4, lsl #8      @ [MSB: diff] [LSB: original]
        add r4, r3, lsl #8          @ [MSB: original + diff] [LSB: original]
        
        strh r4, [r1], #2
        
        ldrb r3, [r0], #1           @ next diff
        add r3, r4, lsr #8          @ next "original" data (might have overflown into the next byte)
        and r3, #0xff
        ldrb r4, [r0], #1           @ next diff
        
        subs r2, #2
        bgt .diff_8bit_unfilter_write_16bit_loop
    
    .diff_8bit_unfilter_write_16bit_return:
        ldmfd sp!, { r2-r5 }
        bx lr

swi_Diff16bitUnfilter:
    @ basically the exact same as Diff8bitUnfilterWrite8bit, except all ldrb/strb's are replaced by ldrh/strh's
    stmfd sp!, { r2-r4 }
    
    ldr r2, [r0], #4        @ load data header
    @ original BIOS ignores data size/type flags as well
    lsr r2, #8              @ size after decompression
    
    @ check for invalid decompression parameters
    check_invalid_decomp r2, r3, r0, .diff_16bit_unfilter_return
    
    ldrh r3, [r0], #2       @ original data
    
    .diff_16bit_unfilter_loop:
        strh r3, [r1], #2   @ store current data
        ldrh r4, [r0], #2   @ next offset
        add r3, r4          @ calculate next data
        subs r2, #2
        bgt .diff_16bit_unfilter_loop
    
    .diff_16bit_unfilter_return:
        ldmfd sp!, { r2-r4 }
        bx lr

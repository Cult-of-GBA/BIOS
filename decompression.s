@ I decompiled this from the original BIOS:

@ function BitUnpack(src_addr, dest_addr, src_len, src_width, dest_width, data_offset):
@   if (src_len == 0 || src_addr < 0x02000000)
@       return;
@
@   bool zero_flag = ((int)data_offset) < 0;
@   uint data_offset &= 0x7fff_ffff;
@   uint data_buffer = 0;
@   dest_bit_count = 0;
@   
@   while (src_len-- > 0)
@   {
@       data_mask = 0xff >> (8 - src_width);
@       data = byte_at[src_addr++];
@       src_bit_count = 0;
@       
@       while (src_bit_count < 8) 
@       {
@           masked_data = (data & data_mask) >> src_bit_count;
@           if (masked_data != 0 || zero_flag)
@               masked_data += data_offset;
@           
@           data_buffer |= masked_data << dest_bit_count;
@           dest_bit_count += dest_width;
@
@           if (dest_bit_count >= 32)
@           {
@               word_at[dest_addr] = data_buffer;
@               dest_addr += 4;
@               dest_bit_count = 0;
@               data_buffer = 0;
@           }
@           data_mask <<= src_width;
@           src_bit_count += src_width;
@       }
@   }

swi_BitUnpack:
    stmfd sp!, { r2-r12 }
    
    @ load bitunpack data
    ldrh r3, [r2]           @ src_len
    
    @ check if src_len == 0 || src_addr < 0x02000000
    cmp r3, #0
    movnes r4, r0, lsr #25  @ == 0 if and only if src_addr < 0x02000000
    beq .bit_unpack_return
    
    ldrb r4, [r2, #2]       @ src_width
    ldrb r5, [r2, #3]       @ dest_width
    ldr r2, [r2, #4]        @ data_offset and zero flag (we no longer need r2 after this)
    mov r6, r2, lsr #31     @ zero flag
    bic r2, #0x80000000     @ data_offset
    
    mov r12, #1
    rsb r12, r12, lsl r4    @ base bit mask for source data ((1 << src_width) - 1)
    mov r7, #0              @ data_buffer
    mov r9, #0              @ dest_bit_count
    
    @ while (src_len-- > 0)
    .bit_unpack_byte_loop:
        subs r3, #1
        bmi .bit_unpack_return
    
        ldrb r11, [r0], #1  @ data
        mov r8, #0          @ src_bit_count
        
        @ while (src_bit_count < 8)
        .bit_unpack_bit_loop:
            cmp r8, #8
            bge .bit_unpack_byte_loop
            
            ands r10, r12, r11, lsr r8   @ masked_data = (data >> src_bit_count) & data_mask
                                         @ omits use of shifted data mask
            cmpeq r6, #0                 @ if (masked_data != 0 || zero_flag)
            addne r10, r2                @     masked_data += data_offset
            
            orr r7, r10, lsl r9          @ data_buffer |= masked_data << dest_bit_count
            add r9, r5                   @ dest_bit_count += dest_width
            
            ands r9, #31                 @ if ((dest_bit_count %= 32) == 0) (use the fact that only powers of 2 are allowed for dest_width)  
            streq r7, [r1], #4           @     word_at[dest_addr] = data_buffer; dest_addr += 4;
            moveq r7, #0                 @     data_buffer = 0
            
            add r8, r4                   @ src_bit_count += src_width
            b .bit_unpack_bit_loop
    
    .bit_unpack_return:
        ldmfd sp!, { r2-r12 }
        bx lr


swi_Diff8bitUnfilterWrite8bit:
    stmfd sp!, { r2-r4 }
    
    ldr r2, [r0], #4        @ load data header
    @ original BIOS ignores data size/type flags as well
    lsr r2, #8              @ size after decompression
    
    @ check if src_len == 0 || src_addr < 0x02000000
    cmp r2, #0
    movnes r3, r0, lsr #25  @ == 0 if and only if src_addr < 0x02000000
    beq .diff_8bit_unfilter_write_8bit_return
    
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
    
    @ check if src_len == 0 || src_addr < 0x02000000
    cmp r2, #0
    movnes r3, r0, lsr #25  @ == 0 if and only if src_addr < 0x02000000
    beq .diff_8bit_unfilter_write_16bit_return
    
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
    
    @ check if src_len == 0 || src_addr < 0x02000000
    cmp r2, #0
    movnes r3, r0, lsr #25  @ == 0 if and only if src_addr < 0x02000000
    beq .diff_16bit_unfilter_return
    
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
 
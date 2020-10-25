.macro check_invalid_decomp src_len, unused_reg, src_addr, return_branch
    @ check if src_len == 0 || src_addr < 0x02000000
    cmp \src_len, #0
    movnes \unused_reg, \src_addr, lsr #25  @ == 0 if and only if src_addr < 0x02000000
    beq \return_branch
.endm

@ TODO: check for invalid addresses < 0x02000000!
swi_LZ77UnCompWrite8bit:
    stmfd sp!, {r3 - r6}

    @ Read header word:
    @ bit0-3:  reserved
    @ bit4-7:  compressed type (1 for LZ77)
    @ bit8-31: size of compressed data
    ldr r2, [r0], #4
    lsrs r2, r2, #8
    @ ignore zero-length decompression requests
    beq .lz77_8bit_done

.lz77_8bit_loop:
    @ read encoder byte, shift to MSB for easier access.
    ldrb r3, [r0], #1
    orr r3, #0x01000000
.lz77_8bit_encoder_loop:
    tst r3, #0x80
    bne .lz77_8bit_copy_window
.lz77_8bit_copy_byte:
    @ copy byte from current source to current destination
    ldrb r4, [r0], #1
    strb r4, [r1], #1

    @ check if decompressed length has been reached.
    subs r2, #1
    beq .lz77_8bit_done

    @ read next encoder or process next block
    lsls r3, #1
    bcc .lz77_8bit_encoder_loop
    b .lz77_8bit_loop
.lz77_8bit_copy_window:
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
.lz77_8bit_copy_window_loop:
    @ copy byte from window to current destination
    ldrb r6, [r1, -r5]
    strb r6, [r1], #1

    @ check if decompressed length has been reached
    subs r2, #1
    beq .lz77_8bit_done

    @ check if window has been fully copied
    subs r4, #1
    bne .lz77_8bit_copy_window_loop

    @ read next encoder or process next block
    lsls r3, #1
    bcc .lz77_8bit_encoder_loop
    b .lz77_8bit_loop

.lz77_8bit_done:
    ldmfd sp!, {r3 - r6}
    bx lr

@ TODO: check for invalid addresses < 0x02000000!
swi_LZ77UnCompWrite16bit:
    stmfd sp!, {r3 - r7}

    @ TODO: this might not be necessary.
    @ mov r7, #0

    @ Read header word:
    @ bit0-3:  reserved
    @ bit4-7:  compressed type (1 for LZ77)
    @ bit8-31: size of compressed data
    ldr r2, [r0], #4
    lsrs r2, r2, #8
    @ ignore zero-length decompression requests
    beq .lz77_16bit_done

.lz77_16bit_loop:
    @ read encoder byte, shift to MSB for easier access.
    ldrb r3, [r0], #1
    orr r3, #0x01000000
.lz77_16bit_encoder_loop:
    tst r3, #0x80
    bne .lz77_16bit_copy_window
.lz77_16bit_copy_byte:
    @ copy byte from current source to current destination
    ldrb r4, [r0], #1
    tst r1, #1
    moveq r7, r4
    orrne r7, r4, lsl #8
    strneh r7, [r1]
    add r1, #1

    @ check if decompressed length has been reached.
    subs r2, #1
    beq .lz77_16bit_done

    @ read next encoder or process next block
    lsls r3, #1
    bcc .lz77_16bit_encoder_loop
    b .lz77_16bit_loop
.lz77_16bit_copy_window:
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
.lz77_16bit_copy_window_loop:
    @ copy byte from window to current destination
    ldrb r6, [r1, -r5]
    tst r1, #1
    moveq r7, r6
    orrne r7, r6, lsl #8
    strneh r7, [r1]
    add r1, #1

    @ check if decompressed length has been reached
    subs r2, #1
    beq .lz77_16bit_done

    @ check if window has been fully copied
    subs r4, #1
    bne .lz77_16bit_copy_window_loop

    @ read next encoder or process next block
    lsls r3, #1
    bcc .lz77_16bit_encoder_loop
    b .lz77_16bit_loop

.lz77_16bit_done:
    ldmfd sp!, {r3 - r7}
    bx lr

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
    
    @ check for invalid decompression parameters
    check_invalid_decomp r3, r4, r0, .bit_unpack_return
    
    .bit_unpack_check_skip:
    
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

@ I decompiled this from the original BIOS:

@ HuffUnCompReadNormal(src_addr: r0, dest_addr: r1) 
@ {
@     // return if attempted BIOS read or zero length transfer
@
@     uint[]* data_stream_ptr           // r0 (src_addr + 5 + tree_size)
@     byte[]* tree_ptr                  // r7 ([src_addr + 5])
@     byte[]* current_addr = tree_ptr   // r2 = r7
@     byte data_size                    // r4 ([src_addr] & 0xf)
@     uint decomp_len                   // r12 ([src_addr] >> 4, in bytes)
@     
@     // @ sp + 4:
@     // note: this algorithm WON'T work with data_size other than 4/8
@     uint units_per_word = (data_size & 7) + 4   // (= 4 if data_size = 8 or 8 if data_size = 4)
@     uint unit_counter = 0      // lr
@     uint buffer = 0            // r3
@     
@     // LAB_00001064
@     while (decomp_len > 0) 
@     {
@         bit_counter = 32       // r8
@         data = [data_stream_ptr];
@         data_stream_ptr += 4;
@         
@         // LAB_00001074
@         while (bit_counter-- > 0)  // or --bit_counter >= 0
@         {
@             data_bit = (data >> 31) & 1                  // r9
@             node_shifted = [current_addr] << data_bit    // r6
@             
@             node = [current_addr]                        // r11
@             next_node_offset = (node & 0x3f) + 1         // r11
@             
@             // r2 (using r10):
@             next_node_ptr = (current_addr & ~1) + (next_node_offset << 1) + data_bit
@             
@             // check if next node is data
@             if ((node_shifted & 0x80) != 0)
@             {
@                 buffer >>= data_size
@                 next_node = [next_node_ptr]               // r10
@                 
@                 buffer |= next_node << (32 - data_size)   // using r11
@                 current_addr = tree_ptr
@                 
@                 if (++unit_counter == units_per_word)
@                 {
@                     [dest_addr] = buffer; dest_addr += 4;
@                     decomp_len -= 4
@                     unit_counter = 0
@                 }
@             }
@             
@             if (decomp_len > 0) 
@             {
@                 data <<= 1
@             }
@             else
@             {
@                 break;
@             }
@         }
@     }
@ }

swi_HuffUnCompReadNormal:
    stmfd sp!, { r2-r11 }
    
    ldr r3, [r0], #4         @ src_len << 8
    
    @ check for invalid decompression parameters (slightly different from others)
    movs r2, r3, lsr #8
    movnes r2, r0, lsr #25   @ == 0 if and only if src_addr < 0x02000000
    beq .huff_uncomp_return
     
    and r2, r3, #0xf         @ data_size
    lsr r3, #8               @ decomp_len
    
    ldrb r4, [r0], #1        @ (tree_length / 2) - 1; r0 now contains tree_ptr
    add r4, r0, r4, lsl #1   @ data_stream_ptr
    add r4, #1
    
    mov r5, #0               @ buffer
    mov r6, #0               @ unit_counter; instead of adding 1 and comparing to units_per_word, we just add data_size and compare to 32
    mov r7, r0               @ working copy of tree_ptr (current address)
    
    .huff_uncomp_word_loop:
    
        mov r8, #32          @ bit counter
        ldr r9, [r4], #4     @ data
        
        .huff_uncomp_node_loop:
            subs r8, #1
            blt .huff_uncomp_word_loop
            
            ldrb r10, [r7]              @ node
            and r11, r10, #0x3f
            add r11, #1                 @ next_node_offset
            
            bic r7, #1
            lsls r9, #1                 @ data_bit in carry flag
            adc r7, r11, lsl #1         @ next_node_ptr
            lslcs r10, #1               @ node_shifted
            
            tst r10, #0x80
            beq .huff_uncomp_node_loop  @ we did not change src_len here, so we don't need to check it
            
            @ next node is data
            ldrb r7, [r7]               @ we have to reset r7 (node_ptr) to tree_ptr after this anyway
            
            orr r5, r7, lsl r6          @ buffer |= next_node << unit_counter
            mov r7, r0
            
            add r6, r2                  @ unit_counter += data_size
            ands r6, #31                @ the original algorithm would go wrong if the unit_counter is 4 or 8 anyway
            bne .huff_uncomp_node_loop
            
            str r5, [r1], #4            @ store buffer
            mov r5, #0
            subs r3, #4                 @ decomp_len -= 4
            
            bgt .huff_uncomp_node_loop
            
    .huff_uncomp_return:
        ldmfd sp!, { r2-r11 }
        bx lr


@ RLUnCompReadNormalWrite8bit(src_addr: r0, dest_addr: r1):
@ {
@     // return if zero length / BIOS read
@     uint decomp_len             // r7 (@[src_addr])
@     src_addr += 4               // skip header
@     
@     while (decomp_len > 0)
@     {
@         byte flags = [src_addr++]
@         expand_length = flags & 0x7f  // r2 (N - 1 or N - 3 depending on compression flag)
@         if ((flags & 0x80) == 0)   // check uncomp/comp flag
@         {
@             // uncompressed
@             expand_length++
@             decomp_len -= expand_length
@             
@             while (decomp_len > 0)
@             {
@                 byte data = [src_addr++]
@                 [dest_addr++] = data
@                 
@                 decomp_len--
@             }
@         }
@         else
@         {
@             // compressed
@             expand_length += 3
@             decomp_len -= expand_length
@             
@             byte data = [src_addr++]
@             
@             while (decomp_len > 0) 
@             {
@                 [dest_addr++] = data
@                 expand_length--
@             }
@         }
@     }
@ }

swi_RLUnCompReadNormalWrite8bit:
    stmfd sp!, { r2-r4 }
    
    ldr r2, [r0], #4
    lsr r2, #8                  @ decomp_len
    
    @ check for invalid decompression parameters
    check_invalid_decomp r2, r3, r0, .rl_uncomp_read_normal_write_8bit_return
    
    .rl_uncomp_read_normal_write_8bit_check_skip:       @ used in boot_screen
    
    .rl_uncomp_read_normal_write_8bit_loop:
        ldrb r3, [r0], #1
        lsls r3, #0x19          @ carry flag = uncomp/comp flag
        lsr r3, #0x19
        
        bcc .rl_uncomp_read_normal_write_8bit_uncompressed
        
        .rl_uncomp_read_normal_write_8bit_compressed:
            ldrb r4, [r0], #1   @ data
            add r3, #3          @ expand_length += 3
            sub r2, r3          @ decomp_len -= expand_length
            
            .rl_uncomp_read_normal_write_8bit_compressed_loop:
                strb r4, [r1], #1
                subs r3, #1
                bgt .rl_uncomp_read_normal_write_8bit_compressed_loop
            
            b .rl_uncomp_read_normal_write_8bit_loop_end
            
        .rl_uncomp_read_normal_write_8bit_uncompressed:
            add r3, #1          @ expand_length += 1
            sub r2, r3          @ decomp_len -= expand_length
            
            .rl_uncomp_read_normal_write_8bit_uncompressed_loop:
                ldrb r4, [r0], #1
                strb r4, [r1], #1
                subs r3, #1
                bgt .rl_uncomp_read_normal_write_8bit_uncompressed_loop
                
        .rl_uncomp_read_normal_write_8bit_loop_end:
            cmp r2, #0
            bgt .rl_uncomp_read_normal_write_8bit_loop
    
    .rl_uncomp_read_normal_write_8bit_return:
        ldmfd sp!, { r2-r4 }
        bx lr
 
 
 swi_RLUnCompReadNormalWrite16bit:
    @ basically the same thing as above, except we buffer the bytes and write them 2 at a time
    @ in the original BIOS, any leftover byte (if the uncompressed length is not divisible by 2) is NOT written
    
    stmfd sp!, { r2-r6 }
    
    ldr r2, [r0], #4
    lsr r2, #8                  @ decomp_len
    
    @ check for invalid decompression parameters
    check_invalid_decomp r2, r3, r0, .rl_uncomp_read_normal_write_16bit_return
    
    mov r5, #0                  @ keep track of upper/lower byte
    mov r6, #0                  @ write buffer
    
    .rl_uncomp_read_normal_write_16bit_loop:
        ldrb r3, [r0], #1
        lsls r3, #0x19          @ carry flag = uncomp/comp flag
        lsr r3, #0x19
        
        bcc .rl_uncomp_read_normal_write_16bit_uncompressed
        
        .rl_uncomp_read_normal_write_16bit_compressed:
            ldrb r4, [r0], #1   @ data
            add r3, #3          @ expand_length += 3
            sub r2, r3          @ decomp_len -= expand_length
            
            .rl_uncomp_read_normal_write_16bit_compressed_loop:
                subs r3, #1
                blt .rl_uncomp_read_normal_write_16bit_loop_end
                
                orr r6, r4, lsl r5
                eors r5, #8
                @ store only if it's an even byte we are checking
                bne .rl_uncomp_read_normal_write_16bit_compressed_loop
                
                strh r6, [r1], #2
                mov r6, #0              @ clear buffer
                b .rl_uncomp_read_normal_write_16bit_compressed_loop
            
        .rl_uncomp_read_normal_write_16bit_uncompressed:
            add r3, #1          @ expand_length += 1
            sub r2, r3          @ decomp_len -= expand_length
            
            .rl_uncomp_read_normal_write_16bit_uncompressed_loop:
                subs r3, #1
                blt .rl_uncomp_read_normal_write_16bit_loop_end
                
                ldrb r4, [r0], #1
                orr r6, r4, lsl r5
                eors r5, #8
                @ store only if it's an even byte we are checking
                bne .rl_uncomp_read_normal_write_16bit_uncompressed_loop
                
                strh r6, [r1], #2     @ last byte is not stored for misaligned decomp_len
                mov r6, #0            @ clear buffer
                
                b .rl_uncomp_read_normal_write_16bit_uncompressed_loop
                
        .rl_uncomp_read_normal_write_16bit_loop_end:
            cmp r2, #0
            bgt .rl_uncomp_read_normal_write_16bit_loop
    
    .rl_uncomp_read_normal_write_16bit_return:
        ldmfd sp!, { r2-r6 }
        bx lr
 
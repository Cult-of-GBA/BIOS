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

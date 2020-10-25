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

.align 4
.pool
    
glyphs:
    .incbin "glyphs.dat"

.align 4
glyph_bit_unpack_info:
    @ offset per glyph: 16 tiles * 8 bytes per tile = 0x80 bytes
    .hword 0x0080       @ source length (16 tiles * 8 lines per tile * 2 bytes per line)
    .byte  0x01         @ width of source unit
    .byte  0x04         @ width of destination
    .word  0x00000000   @ data offset (we do not need this)
    
.align 4
glyph_metrics:
    @ contains data for glyph metrics in the following format:
    @ byte: width
    @ signed byte: lsb (Left Side Bbox offset)
    .incbin "glyph_metrics.dat"
    
.align 4
boot_screen_text_data:
    @ length of boot screen text
    .byte 8
    @ y coordinate
    .byte 60
    @ actual text:
    .ascii "CULT-GBA"

@ todo: shine sprite (put in top 8 tiles of last character,
@             with different palette base, fill rest of first palette bank with white (backdrop) color)

.align 4
.arm
BootScreen:
    stmfd sp!, { lr }
    
    @ decompress glyphs into WRAM
    ldr r0, =#glyphs
    mov r1, #eWRAM_START
    
    @ ------------------------------ Cheese to skip RLDecompress BIOS read check ---------------------------------
    stmfd sp!, { r2-r4 }
    ldr r2, [r0], #4
    lsr r2, #8                  @ decomp_len
    bl .rl_uncomp_read_normal_write_8bit_check_skip
    @ ------------------------------------------------ /Cheese ---------------------------------------------------
    
    @ load white backdrop
    mov r0, #PAL_START
    ldrh r1, =#0x7fff
    strh r1, [r0]
    ldrh r1, =#0x7c00
    
    mov r0, #MMIO_BASE      @ DISPCNT
    mov r1, #0x1140         @ 1D OBJ mapping; Enable BG0; Enable OBJ
    strh r1, [r0]
    
    ldr r12, =#glyph_metrics
    ldr r11, =#boot_screen_text_data
    mov r10, #' ' << 1      @ offset with first character * 2
    
    ldrb r4, [r11], #2      @ text_len (chars); add 2 because we are not interested in the y-coordinate here
    mov r0, #0              @ to hold width
    mov r3, #0              @ length counter
    
    .calc_screen_text_width_loop:
        ldrb r1, [r11, r3]              @ load character
        rsb r1, r10, r1, lsl #1         @ offset by first glyph (' ')
        ldrsh r1, [r12, r1]             @ load metrics (signed for lsb)
        add r0, r1, asr #8              @ add lsb
        and r1, #0xff
        add r0, r1                      @ add width
        
        add r3, #1
        cmp r3, r4
        blt .calc_screen_text_width_loop
        
    lsr r0, #1                  @ width / 2
    rsb r0, #SCREEN_WIDTH  / 2  @ (screen_width - width) / 2
    
    @ r12 still contains glyph_metrics
    @ r11 still contains boot_screen_text_data + 2 (text pointer)
    @ r10 still holds ' ' << 1 (offset to first character * 2)
    @ r4 still contains text_len
    @ r0 now holds the start x for centering the string
    ldrb r1, [r11, #-1]         @ load y coordinate
    mov r3, #0                  @ load letter counter
    
    .blit_screen_text:
        ldrb r2, [r11, r3]          @ load next character
        bl draw_GB_letter           @ draw at current location
        rsb r5, r10, r2, lsl #1     @ calculate offset into metrics
        ldrsh r5, [r12, r5]
        add r0, r5, asr #8          @ add lsb
        and r5, #0xff
        add r0, r5
        
        add r3, #1
        cmp r3, r4
        blt .blit_screen_text
        
    @ freeze:
    @     b freeze

    ldmfd sp!, { lr }
    bx lr
    
draw_GB_letter:
    @ draw GameBoy font character r2 OBJ at (x, y) = (r0, r1), after character is transferred into OBJ with "number" r3
    stmfd sp!, { r0-r3, lr }
    
    @ LOAD SPRITE
    stmfd sp!, { r0, r1 }
    
    mov r0, #eWRAM_START        @ source address
    sub r2, #' '                @ offset with first character
    add r0, r2, lsl #7          @ char number * 0x80 (length of one compressed 32x32 OBJ sprite)
    ldr r1, =#OBJ_START         @ destination address
    add r1, r3, lsl #9          @ length of one 4bpp 32x32 OBJ sprite (0x200 bytes) * letter number
    ldr r2, =#glyph_bit_unpack_info
    bl swi_BitUnpack
    
    ldmfd sp!, { r0, r1 }
    
    @ STORE OBJ INFO IN OAM
    mov r2, #OAM_START          @ we do not need r3 anymore from here on out
    add r2, r3, lsl #3          @ 8 bytes per object, this is object number r3
    
    @ OBJ_ATTR0
    strh r1, [r2], #2           @ square; 4bpp; GFXMode normal; (all 0)
    
    @ OBJ_ATTR1
    orr r0, #0x8000             @ 32x32 size
    strh r0, [r2], #2
    
    @ OBJ_ATTR2
    lsl r3, #4                  @ TID = (letter number) * 16 = (letter number) << 4
    strh r3, [r2], #2
    
    @ OBJ_ATTR3
    @ not needed
    
    ldmfd sp!, { r0-r3, lr }
    bx lr

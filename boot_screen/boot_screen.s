.equ NAME_TILES_START, VRAM_START + (14 << 6) + (7 << 1)       @ Tx = 7, Ty = 14
.equ ONE_LINE_TID_OFFSET, 30 << 1
.equ GLOW_SPRITE_BASE, OAM_START + 0x400 - 32
.equ SPEED, 4

.align 4
.pool
    
glyphs:
    .incbin "boot_screen/glyphs.dat"

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
    .incbin "boot_screen/glyph_metrics.dat"
    
.align 4
glow_pal_data:
    .incbin "boot_screen/glow_palette.dat"
glow_pal_data_end:

glow_sprite_data:
    .incbin "boot_screen/glow.dat"
glow_sprite_data_end:

.align 4
names_data:
    .incbin "boot_screen/names.dat"
names_data_end:

.align 4
flero_data_unpack_info:
    .hword (names_data_end - names_data) * 2 / 5        @ top 2 lines 
    .byte 0x01
    .byte 0x04
    .word 0x80000001    @ increase all data by 1 to use third palette entry for "Fleroviux", and the white palette entry for the background

.align 4
densinh_data_unpack_info:
    .hword (names_data_end - names_data) * 3 / 5        @ bottom 3 lines
    .byte 0x01
    .byte 0x04
    .word 0x80000003    @ increase all data by 3 to use third palette entry for "DenSinH", and the white palette entry for the background
   

.align 4
boot_screen_text_data:
    @ length of boot screen text
    .byte 8
    @ y coordinate
    .byte 32
    @ actual text:
    .ascii "CULT-GBA"

.align 4
.arm
BootScreen:
    stmfd sp!, { lr }
    
    @ decompress glyphs into WRAM
    ldr r0, =#glyphs
    mov r1, #eWRAM_START
    
    @                       -------- Cheese to skip RLDecompress BIOS read check --------
    stmfd sp!, { r2-r4 }
    ldr r2, [r0], #4
    lsr r2, #8                  @ decomp_len
    bl .rl_uncomp_read_normal_write_8bit_check_skip
    @                       ------------------------- /Cheese ---------------------------
    
    @ -------------------------------------- load base palette entries--------------------------------------------
    mov r0, #PAL_START
    @ blue: BGR (254, 5, 21) /8 ~~ (32, 1, 3)
    ldrh r1, =((31 << 10) | (1 << 5) | 3)
    strh r1, [r0]           @ backdrop
    ldrh r1, =#0x7fff
    strh r1, [r0, #2]       @ PAL entry 1 (white BG on "Fleroviux")
    strh r1, [r0, #6]       @ PAL entry 3 (white BG on "DenSinH")
    @ pink: BGR (218, 12, 208) /8 ~~ (27, 2, 26)
    ldrh r1, =#((27 << 10) | (2 << 5) | 26)
    strh r1, [r0, #4]       @ PAL entry 2 ("Fleroviux")
    strh r1, [r0, #8]       @ PAL entry 4 ("DenSinH")
    
    @ ------------------------------------------- init LCD registers ---------------------------------------------
    mov r0, #MMIO_BASE                                @ DISPCNT
    ldrh r1, =#0x9140                                 @ 1D OBJ mapping; Enable BG0; Enable OBJ; OBJ Window display
    strh r1, [r0]                                     @ store to DISPCNT
    mov r1, #0x08                                     @ V-Blank IRQ enable, for swi_Halt
    strh r1, [r0, #(REG_DISPSTAT - MMIO_BASE)]        @ store to DISPSTAT
    ldrh r1, =#0x3001                                 @ display BG0 outside WinOBJ, display OBJ within WinOBJ
    strh r1, [r0, #(REG_WINOUT - MMIO_BASE)]
    
    mov r1, #0x07                                     @ Prio 3; CharBaseBlock 1; 4bpp
    strh r1, [r0, #(REG_BG0CNT - MMIO_BASE)]          @ store to BG0CNT
    
    @ --------------------------------------- load glow sprite data -----------------------------------------------
    @ assume palette data length is a multiple of 4
    ldr r0, =#glow_pal_data
    ldr r1, =#PAL_START + 0x220
    mov r2, #(glow_pal_data_end - glow_pal_data) / 4
    .boot_screen_glow_pal_transfer:
        ldr r3, [r0], #4
        str r3, [r1], #4
        subs r2, #1
        bgt .boot_screen_glow_pal_transfer
    
    ldr r1, =#VRAM_START + 0x18000 - (glow_sprite_data_end - glow_sprite_data)
    mov r2, #(glow_sprite_data_end - glow_sprite_data) / 4
    .boot_screen_glow_sprite_transfer:
        ldr r3, [r0], #4
        str r3, [r1], #4
        subs r2, #1
        bgt .boot_screen_glow_sprite_transfer
    
    @ ----------------------------------------- load tiles for BG0 ------------------------------------------------
    @ white tile:
    ldr r0, =#VRAM_START + CHAR_BLOCK_LENGTH
    ldr r1, =#0x11111111    @ 8 pixels holding first palette entry
    mov r2, #8
    .boot_screen_tile_fill:
        str r1, [r0], #4
        subs r2, #1
        bgt .boot_screen_tile_fill
        
    @ r0 now contains the address for the second tile in charblock 1
    mov r1, r0              @ destination address
    ldr r0, =#names_data    @ source address
    ldr r2, =#flero_data_unpack_info
    mov r3, #1
    
    .boot_screen_names_decompress_loop:
        @ USE THE FACT THAT r0 and r1 point to right after the data, so we can keep looping this
        @                     ------- Cheese to skip BitUnpack BIOS read check -------
        stmfd sp!, { r2-r12 }
        ldrh r3, [r2]
        bl .bit_unpack_check_skip
        @                     ------------------------ /Cheese -----------------------
        subs r3, #1
        ldreq r2, =#densinh_data_unpack_info
        beq .boot_screen_names_decompress_loop
        

    
    @ ----------------------------------------- calculate text width ----------------------------------------------
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
    b BootScreen_draw           @ we need more pools...
    
.pool

BootScreen_draw:
    @ -------------------------------------------- draw text centered ---------------------------------------------
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
        
    @ ------------------------------------------ initialize glow sprite--------------------------------------------
    @ r11 still contains boot_screen_text_data + 2 (text pointer)
    @ r1 still contains text y coordinate
    
    ldr r3, =#GLOW_SPRITE_BASE              @ load address of 4-th last OAM entry (8 bytes per object, 4 objects back)
    mov r4, #0                              @ flip data/corner counter (tl, tr, bl, br)
    mov r5, #1020                           @ base tile ID
    mov r6, #0x4000                         @ 16x16 tile size
    .boot_screen_glow_oam_init:
        mov r2, r1
        tst r4, #2
        addne r2, #16
        strh r2, [r3], #2                   @ y coordinate, other flags are all 0; todo: alpha blending
        orr r0, r6, r4, lsl #12             @ x = 0, flipping data is in r4; tile size 32x32
        tst r4, #1
        addne r0, #16                       @ add offset for rightmost sprites for odd tile counts
        
        strh r0, [r3], #2
        ldrh r0, =#0x1400 | 1020            @ palette bank 1, priority 1, TID 1020
        strh r0, [r3], #4                   @ skip OBJ_ATTR3
        add r4, #1
        cmp r4, #4
        blt .boot_screen_glow_oam_init
    
    @ ------------------------------------------------ draw names -------------------------------------------------
    @ names.bmp is 128px (16 tiles) wide, and 40px (5 tiles) high
    @ tile ID for the top left tile is 1, and keeps incrementing
    @ max tile ID is then 1 + 10 * 4 = 41
    ldr r0, =#NAME_TILES_START
    mov r1, #1
    mov r3, #5                              @ y counter
    
    .boot_screen_names_y_loop:
        mov r2, #16                         @ x counter
        .boot_screen_names_x_loop:
            strh r1, [r0], #2
            add r1, #1
            subs r2, #1
            bgt .boot_screen_names_x_loop
        add r0, #ONE_LINE_TID_OFFSET - (14 << 1) @ go to the left side of the next line
        subs r3, #1
        bgt .boot_screen_names_y_loop
        
    
    b BootScreen_animate

.pool

BootScreen_animate:
    @ I have to use registers that are not altered by swi_Halt for this:
    mov r8, #SCREEN_WIDTH       @ keep track of x-coordinate
    ldr r10, =#REG_IE
    mov r11, #1
    strh r11, [r10], #2         @ enable VBlank IRQs in IE (IME is still off); r11 now holds REG_IF

    .boot_screen_animation_loop:
        bl swi_Halt             @ wait until VBlank (IE still has VBlank IRQ enabled, IME is off)
        strh r11, [r10]         @ acknowledge VBlank IRQ
        
        ldr r3, =#GLOW_SPRITE_BASE + 2   @ load address of first glow sprite + 2 (OBJ_ATTR1)
        mov r4, #4
        
        .boot_screen_animation_glow_loop:
            @ load all glow sprites, increment their x coordinate, and store them again
            
            ldrh r1, [r3]
            add r1, #SPEED
            strh r1, [r3], #8   @ go to next sprite
            subs r4, #1
            bgt .boot_screen_animation_glow_loop
            
        subs r8, #SPEED
        bgt .boot_screen_animation_loop
    
    ldmfd sp!, { lr }
    bx lr

.pool

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
    orr r1, #0x0800
    strh r1, [r2], #2           @ square; 4bpp; GFXMode: OBJ window;
    
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

@ Useful info from GBATek:
@
@ The following parameters are required for Rotation/Scaling
@     Rotation Center X and Y Coordinates (x0,y0)
@     Rotation Angle                      (alpha)
@     Magnification X and Y Values        (xMag,yMag)
@   The display is rotated by 'alpha' degrees around the center.
@   The displayed picture is magnified by 'xMag' along x-Axis (Y=y0) and 'yMag' along y-Axis (X=x0).
@
@ Calculating Rotation/Scaling Parameters A-D
@   A = Cos (alpha) / xMag    ;distance moved in direction x, same line
@   B = Sin (alpha) / xMag    ;distance moved in direction x, next line
@   C = Sin (alpha) / yMag    ;distance moved in direction y, same line
@   D = Cos (alpha) / yMag    ;distance moved in direction y, next line
@
@ Calculating the position of a rotated/scaled dot
@ Using the following expressions,
@   x0,y0    Rotation Center
@   x1,y1    Old Position of a pixel (before rotation/scaling)
@   x2,y2    New position of above pixel (after rotation scaling)
@   A,B,C,D  BG2PA-BG2PD Parameters (as calculated above)
@ the following formula can be used to calculate x2,y2:
@   x2 = A(x1-x0) + B(y1-y0) + x0
@   y2 = C(x1-x0) + D(y1-y0) + y0

.sin_LUT:
    @ sin in range 0 - 2pi (0x00 - 0xff)
    @ this is the LUT the original BIOS uses
    .hword 0x0000, 0x0192, 0x0323, 0x04B5, 0x0645, 0x07D5, 0x0964, 0x0AF1
    .hword 0x0C7C, 0x0E05, 0x0F8C, 0x1111, 0x1294, 0x1413, 0x158F, 0x1708
    .hword 0x187D, 0x19EF, 0x1B5D, 0x1CC6, 0x1E2B, 0x1F8B, 0x20E7, 0x223D
    .hword 0x238E, 0x24DA, 0x261F, 0x275F, 0x2899, 0x29CD, 0x2AFA, 0x2C21
    .hword 0x2D41, 0x2E5A, 0x2F6B, 0x3076, 0x3179, 0x3274, 0x3367, 0x3453
    .hword 0x3536, 0x3612, 0x36E5, 0x37AF, 0x3871, 0x392A, 0x39DA, 0x3A82
    .hword 0x3B20, 0x3BB6, 0x3C42, 0x3CC5, 0x3D3E, 0x3DAE, 0x3E14, 0x3E71
    .hword 0x3EC5, 0x3F0E, 0x3F4E, 0x3F84, 0x3FB1, 0x3FD3, 0x3FEC, 0x3FFB
    .hword 0x4000, 0x3FFB, 0x3FEC, 0x3FD3, 0x3FB1, 0x3F84, 0x3F4E, 0x3F0E
    .hword 0x3EC5, 0x3E71, 0x3E14, 0x3DAE, 0x3D3E, 0x3CC5, 0x3C42, 0x3BB6
    .hword 0x3B20, 0x3A82, 0x39DA, 0x392A, 0x3871, 0x37AF, 0x36E5, 0x3612
    .hword 0x3536, 0x3453, 0x3367, 0x3274, 0x3179, 0x3076, 0x2F6B, 0x2E5A
    .hword 0x2D41, 0x2C21, 0x2AFA, 0x29CD, 0x2899, 0x275F, 0x261F, 0x24DA
    .hword 0x238E, 0x223D, 0x20E7, 0x1F8B, 0x1E2B, 0x1CC6, 0x1B5D, 0x19EF
    .hword 0x187D, 0x1708, 0x158F, 0x1413, 0x1294, 0x1111, 0x0F8C, 0x0E05
    .hword 0x0C7C, 0x0AF1, 0x0964, 0x07D5, 0x0645, 0x04B5, 0x0323, 0x0192
    .hword 0x0000, 0xFE6E, 0xFCDD, 0xFB4B, 0xF9BB, 0xF82B, 0xF69C, 0xF50F
    .hword 0xF384, 0xF1FB, 0xF074, 0xEEEF, 0xED6C, 0xEBED, 0xEA71, 0xE8F8
    .hword 0xE783, 0xE611, 0xE4A3, 0xE33A, 0xE1D5, 0xE075, 0xDF19, 0xDDC3
    .hword 0xDC72, 0xDB26, 0xD9E1, 0xD8A1, 0xD767, 0xD633, 0xD506, 0xD3DF
    .hword 0xD2BF, 0xD1A6, 0xD095, 0xCF8A, 0xCE87, 0xCD8C, 0xCC99, 0xCBAD
    .hword 0xCACA, 0xC9EE, 0xC91B, 0xC851, 0xC78F, 0xC6D6, 0xC626, 0xC57E
    .hword 0xC4E0, 0xC44A, 0xC3BE, 0xC33B, 0xC2C2, 0xC252, 0xC1EC, 0xC18F
    .hword 0xC13B, 0xC0F2, 0xC0B2, 0xC07C, 0xC04F, 0xC02D, 0xC014, 0xC005
    .hword 0xC000, 0xC005, 0xC014, 0xC02D, 0xC04F, 0xC07C, 0xC0B2, 0xC0F2
    .hword 0xC13B, 0xC18F, 0xC1EC, 0xC252, 0xC2C2, 0xC33B, 0xC3BE, 0xC44A
    .hword 0xC4E0, 0xC57E, 0xC626, 0xC6D6, 0xC78F, 0xC851, 0xC91B, 0xC9EE
    .hword 0xCACA, 0xCBAD, 0xCC99, 0xCD8C, 0xCE87, 0xCF8A, 0xD095, 0xD1A6
    .hword 0xD2BF, 0xD3DF, 0xD506, 0xD633, 0xD767, 0xD8A1, 0xD9E1, 0xDB26
    .hword 0xDC72, 0xDDC3, 0xDF19, 0xE075, 0xE1D5, 0xE33A, 0xE4A3, 0xE611
    .hword 0xE783, 0xE8F8, 0xEA71, 0xEBED, 0xED6C, 0xEEEF, 0xF074, 0xF1FB
    .hword 0xF384, 0xF50F, 0xF69C, 0xF82B, 0xF9BB, 0xFB4B, 0xFCDD, 0xFE6E

swi_ObjAffineSet:
    
    @ r0   Source Address, pointing to data structure as such:
    @       s16  Scaling ratio in X direction (8bit fractional portion)
    @       s16  Scaling ratio in Y direction (8bit fractional portion)
    @       u16  Angle of rotation (8bit fractional portion) Effective Range 0-FFFF
    @ r1   Destination Address, pointing to data structure as such:
    @       s16  Difference in X coordinate along same line
    @       s16  Difference in X coordinate along next line
    @       s16  Difference in Y coordinate along same line
    @       s16  Difference in Y coordinate along next line
    @ r2   Number of calculations
    @ r3   Offset in bytes for parameter addresses (2=continuous, 8=OAM)
    
    stmfd sp!, { r4-r9, r11, r12 }
    ldr r12, =#.sin_LUT
    mov r11, #0
    
    @ calculations done
    .obj_affine_set_loop:
        subs r2, #1
        bmi .obj_affine_set_return
        
        ldrsh r4, [r0], #2    @ x scaling (8 bit fractional)
        ldrsh r6, [r0], #2    @ y scaling (8 bit fractional)
        ldrh r7, [r0], #2     @ angle of rotation (8 bit fractional, ignored by original BIOS)
        lsr r7, #8
        
        lsl r8, r7, #1
        add r9, r7, #0x40     @ cos(phi) = sin(phi + pi/2), 0x80 because r8 was already shifted
        and r9, #0xff         @ mod 2pi
        lsl r9, #1
        
        ldrsh r8, [r12, r8]   @ sin(phi)
        ldrsh r9, [r12, r9]   @ cos(phi)
        
        @ calculate the actual rotate/scale parameters
        mul r5, r4, r8            @ B = sin(alpha) / xMag
        sub r5, r11, r5, asr #14  @ needs negative sign (done in original BIOS as well)
        mul r4, r9                @ A = cos(alpha) / xMag
        asr r4, #14
        
        mul r7, r6, r9            @ D = cos(alpha) / yMag
        asr r7, #14
        mul r6, r8                @ C = sin(alpha) / yMag
        asr r6, #14
        
        @ store them
        strh r4, [r1], r3
        strh r5, [r1], r3
        strh r6, [r1], r3
        strh r7, [r1], r3
        b .obj_affine_set_loop
            
    .obj_affine_set_return:
        ldmfd sp!, { r4-r9, r11, r12 }
        bx lr
        
swi_BGAffineSet:
    @   r0   Pointer to Source Data Field with entries as follows:
    @         s32  Original data's center X coordinate (8bit fractional portion)
    @         s32  Original data's center Y coordinate (8bit fractional portion)
    @         s16  Display's center X coordinate
    @         s16  Display's center Y coordinate
    
    @         s16  Scaling ratio in X direction (8bit fractional portion)
    @         s16  Scaling ratio in Y direction (8bit fractional portion)
    @         u16  Angle of rotation (8bit fractional portion) Effective Range 0-FFFF
    @   r1   Pointer to Destination Data Field with entries as follows:
    @         s16  Difference in X coordinate along same line
    @         s16  Difference in X coordinate along next line
    @         s16  Difference in Y coordinate along same line
    @         s16  Difference in Y coordinate along next line
    
    @         s32  Start X coordinate
    @         s32  Start Y coordinate
    @   r2   Number of Calculations
    
    stmfd sp!, { r3-r12 }
    ldr r12, =#.sin_LUT
    
    @ calculations done
    .bg_affine_set_loop:
        subs r2, #1
        bmi .bg_affine_set_return
        
        ldmia r0!, { r9, r10, r11 }
        @ r9:  Original data center x (O_x)
        @ r10: Original data center y (O_y)
        @ r11: MSBs: [Display center y] LSBs: [Display center x]
        
        ldrsh r3, [r0], #2    @ x scaling (8 bit fractional)
        ldrsh r5, [r0], #2    @ y scaling (8 bit fractional)
        ldrh r6, [r0], #4     @ angle of rotation (8 bit fractional, ignored by original BIOS)
        lsr r6, #8            @       post index by 4 because we want to stay word aligned for the next loop
        
        lsl r7, r6, #1
        add r8, r6, #0x40     @ cos(phi) = sin(phi + pi/2)
        and r8, #0xff         @ mod 2pi
        lsl r8, #1
        
        ldrsh r7, [r12, r7]   @ sin(phi)
        ldrsh r8, [r12, r8]   @ cos(phi)
        
        @ calculate the actual rotate/scale parameters
        mul r4, r3, r7        @ B = sin(alpha) / xMag
        asr r4, #14
        mul r3, r8            @ A = cos(alpha) / xMag
        asr r3, #14
        
        mul r6, r5, r8        @ D = cos(alpha) / yMag
        asr r6, #14
        mul r5, r7            @ C = sin(alpha) / yMag
        asr r5, #14
        
        mov r7, r11, lsl #16   
        asr r7, #16           @ Display center x (D_x)
        rsb r7, #0            @ -D_x, after all, this is all we will be using
        mov r8, r11, asr #16  @ Display center y (D_y)
        
        @ looking at the original BIOS, the formula for "Start X" and "Start Y" is
        @   StartX = (-D_x * A + O_x) + D_y * B
        @   StartY = (-D_x * C + O_y) + -D_y * D
        @ so they would mean the texture coordinate for the top left corner of the screen
        
        @ You can think of it like this for StartX for example (by inverting the operation):
        @ O_x = StartX + A * D_x - B * D_y
        @ A * D_x is the scaling + rotation moving along the scanline
        @ - B * D_y is the scaling moving along the y direction, with a negative sign because y = 0 is the top left corner
        
        mla r9, r7, r3, r9    @ O_x - D_x * A
        mla r9, r8, r4, r9    @ O_x - D_x * A + D_y * B
        mla r10, r7, r5, r10  @ O_y - D_x * C
        rsb r8, #0
        mla r10, r8, r6, r10  @ O_y - D_x * C - D_y * D
        
        strh r3, [r1], #2
        @ B needs to be negative (wrong in GBATek)
        rsb r4, #0
        strh r4, [r1], #2
        strh r5, [r1], #2
        strh r6, [r1], #2
        stmia r1!, { r9, r10 }
        
        b .bg_affine_set_loop
            
    .bg_affine_set_return:
        ldmfd sp!, { r3-r12 }
        bx lr
        
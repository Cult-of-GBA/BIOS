.octant_offset_LUT:
    .hword 0x0000, 0x0040, 0x0040, 0x0080
    .hword 0x0080, 0x00c0, 0x00c0, 0x0100

swi_ArcTan2:
    @ should calculate the arctan with correction processing
    @ the ArcTan implementation of the original BIOS is pretty bad (very very inaccurate for higher angles)
    @ so I had to come up with a different way of calculating this than a simple formula you would find on wikipedia
    @ ArcTan basically _needs_ the input angles to be < pi/4 in absolute value, so I had to split a 2d grid into octants and
    @ figure out the offset based on those octants, and flip x and y in certain ones. It looks as follows:
    @
    @         \   -x/y| -x/y  /
    @           \ oct2|oct1 /
    @       y/x   \1/2|1/2/  y/x
    @       oct3 1  \ | /   oct0  0
    @    ---------------------------
    @       oct4 1  / | \   oct7  2
    @       y/x   /3/2|3/2\  y/x
    @           / oct5|oct6 \
    @         /   -x/y|-x/y   \
    @
    @ in every octant, the formula would be ArcTan2(x, y) = ArcTan(operand) + offset * pi
    @     operand is y/x (if |x| > |y|, so the "normal") or -x/y (if |x| < |y|)
    @         we add the sign because we would otherwise need to subtract it from the offset
    @     the offset is a fraction times pi, so for oct3 or oct4 it would be 1 pi, and for oct5 it's 3/2pi
    @ These things are needed so that the resulting angle for the ArcTan call is always less than pi/4 in absolute value
    @
    @ return value is in [0x0000, 0xffff] for (0, 2pi)
    @ this means that pi = 0x8000 and pi / 2 = 0x4000 (this is correct looking at the official BIOS)
    
    stmfd sp!, { r2, r4, r5, lr }
    
    @ copy r0, r1 into r2, r3
    mov r2, r0
    mov r3, r1
    
    @ we calculate the offset into the offset LUT using r4
    @ I cannot shift the offset register in a ldrh instruction, so I need to calculate it with offset immediately
    mov r4, #0
    
    @ bottom 4 octants (y < 0)
    cmp r1, #0
    addlt r4, #8
    rsblt r3, #0        @ r3 = |y|
    
    @ diagonal octants (+2) (x * y < 0)
    @ r1    r0      flags after tst r1, r0, asr #32:
    @ < 0   < 0     N clear, C set
    @ < 0   >= 0    N set, C clear
    @ >= 0  < 0     N set, C set,
    @ >= 0  >= 0    N clear, C clear
    @ this saves one comparison
    @ eors r5 because we need this information after anyway
    
    eors r5, r1, r0, asr #32    
    addmi r4, #4
    rsbcs r2, #0        @ r2 = |x|
    
    @ to determine the offset for the odd octants (oct1/3/5/7), I came up with the following formula:
    @       an octant is odd if and only if (x * y > 0 AND |x| < |y|)
    @                                    OR (x * y < 0 AND |x| > |y|)
    @       so it is odd if and only if
    @           x * y * |x| < x * y * |y|
    @       so it is odd if and only if
    @           x ^ y ^ (|x| - |y|) < 0 
    
    @ eor r5, r0, r1, we do this before
    subs r2, r3            @ flip operands if |x| > |y| ("normal" case)
    movpl r3, r1
    movpl r1, r0
    movpl r0, r3
    
    eors r5, r2
    addmi r4, #2           @ add sign bit to r4 (odd or even)
    
    @ load arctan offset based on octant we're in
    ldr r3, =#.octant_offset_LUT
    ldrh r4, [r3, r4]
    
    @ x / y or y / x (based on octant)
    lsl r0, #14
    bl swi_Div
    
    ldr lr, =#.add_arctan2_offset
    
swi_ArcTan:
    @ TODO: can this one we turned into THUMB? should be about the same...

    @ this is the algorithm used by the original BIOS
    @ in the end, we want ROM's to run as if the normal BIOS was in the emulator
    @ this algorithm is insanely fast, but is highly inaccurate for higher angles
    @ return value is in (0xc000, 0x4000) for (-pi/2, pi/2)
    mul r1, r0, r0
    mov r1, r1, asr #0xe
    rsb r1, r1, #0x0
    
    mov r3, #0xa9
    mul r3, r1,r3
    mov r3, r3, asr #0xe
    add r3, r3, #0x390
    
    mul r3, r1, r3
    mov r3, r3, asr #0xe
    add r3, r3, #0x900
    add r3, r3, #0x1c
    
    mul r3, r1, r3
    mov r3, r3, asr #0xe
    add r3, r3, #0xf00
    add r3, r3, #0xb6
    
    mul r3, r1, r3
    mov r3, r3, asr #0xe
    add r3, r3, #0x1600
    add r3, r3, #0xaa
    
    mul r3, r1,r3
    mov r3, r3, asr #0xe
    add r3, r3, #0x2000
    add r3, r3, #0x81
    
    mul r3, r1, r3
    mov r3, r3, asr #0xe
    add r3, r3, #0x3600
    add r3, r3, #0x51
    
    mul r3, r1, r3
    mov r3, r3, asr #0xe
    add r3, r3, #0xa200
    add r3, r3, #0xf9
    
    mul r0,r3,r0
    mov r0,r0, asr #0x10
    bx lr
    
.add_arctan2_offset:
    @ r2 still contains info on whether the operands were flipped
    @ r2 < 0 means the result should also be negative
    eors r0, r2, asr #32
    adc r0, #0
    
    @ add the offset we calculated
    add r0, r4, lsl #8
    mov r3, #0x170     @ (this is always the resulting value in r3 in the original BIOS)
    
    ldmfd sp!, { r2, r4, r5, lr }
    bx lr
        

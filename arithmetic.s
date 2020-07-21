swi_DivArm:
    @ parameters r0 and r1 swapped for div (r3 is output anyway)
    mov r3, r1
    mov r1, r0
    mov r0, r3

swi_Div:
    @ NOTE: differs from the official BIOS for division by 0 cases or int.MinValue / -1

    @ idea: basic division strategy: keep subtracting 2 ** n * Denom (r1) from Number (r0) until we can't anymore
    @        add these values up in r3 to find the div, add r0 will result in the mod
    @        store power of 2 in r2
    @        store signs in r4 (double negative is positive: eor)

    stmfd sp!, { r2, r4 }

    @ make operands positive
    movs r4, r1
    rsbmis r1, r1, #0        @ r1 was negative
    beq .div_by_zero         @ prevent freezes on division by 0
    eors r4, r0, asr #32     @ bit 31 of r4 are now sign(r1) ^ sign(r0)
    rsbcs r0, r0, #0         @ r0 was negative

    @ find maximum power of 2 (in r2) such that (r1 * r2) < r0
    mov r2, #1
    .div_max_pow_of_2_loop:
        cmp r1, r0, lsl #1
        lslle r2, #1
        lslle r1, #1
        ble .div_max_pow_of_2_loop
        
    mov r3, #0
    
    .div_loop:
        cmp r1, r0
        suble r0, r1
        addle r3, r2
        @ if eq then we have already found the divisor (perfect divisor)
        lsrne r1, #1
        lsrnes r2, #1
        
        @ keep going until r2 is 0
        bne .div_loop
        
    @ at this point, r0 contains Number % Denom (unsigned)
    @                r3 contains Number / Denom (unsigned)
    
    eor r1, r0, r4, asr #32        @ Number % Denom (signed)
    eor r0, r3, r4, asr #32        @ Number / Denom (signed)

    .div_done:
        ldmfd sp!, { r2, r4 } 
        bx lr
    
    .div_by_zero:
        @ todo: add some specific result?
        b .div_done


swi_Sqrt:
    @ idea: binary search with a power of 2 as initial guess
    
    stmfd sp!, { r1, r2, r3 }
    
    @ find power of 2 as initial guess
    mov r1, #1
    mov r2, r0                    @ copy r0 because we need it later
    .sqrt_initial_guess_loop:
        cmp r1, r2, lsr #2
        lslls r1, #1
        lsrls r2, #1
        bls .sqrt_initial_guess_loop
    @ at this point: r1 ** 2 <= r0    
    
    mov r2, r1, lsr #1
    
    .sqrt_binary_search_loop:
        add r3, r1, r2
        mul r3, r3, r3
        cmp r3, r0
        addle r1, r2
        
        @ break off early if we have already found the square (eq)
        lsrnes r2, #1
        bne .sqrt_binary_search_loop
        
    mov r0, r1
    
    ldmfd sp!, { r1, r2, r3 }
    bx lr
    
swi_ArcTan2:
    @ should calculate the arctan with correction processing, that is (from wikipedia):
    @                 / arctan(y / x)       if x > 0
    @                |  arctan(y / x) + pi  if x < 0 and y >= 0
    @ atan2(y, x) = <   arctan(y / x) - pi  if x < 0 and y < 0
    @                |   pi / 2             if x == 0 and y > 0
    @                |  -pi / 2             if x == 0 and y < 0
    @                 \  undefined          if x == y == 0
    @ the original BIOS returns r0 = 0 for x = y = 0 (undefined)
    @ return value is in [0x0000, 0xffff] for (0, 2pi)
    @ this means that pi = 0x8000 and pi / 2 = 0x4000 (this is correct looking at the official BIOS)
    
    @ NOTE: I'm not sure if r1 and r3 should be saved yet, r2 and lr definitely should!
    stmfd sp!, { r1-r3, lr }
    mov r2, #0
    
    cmp r2, r0, lsl #16           @ so that we can properly check the sign of r0 we shift it
    blt .arctan2_div_arctan       @ 0 < x
    bgt .arctan2_x_lt_0           @ 0 > x
                                  @ 0 == x
    
    .arctan2_x_eq_0:
        mov r0, #0x4000
        cmp r2, r1, lsl #16       @ r2 still contains 0, compare with r1 with sign bit in bit 31
        rsbgt r0, #0x10000        @ -pi/2 if 0 > y (note: that is the order of the comparison)
        moveq r0, #0              @ 0 if 0 == y
        
        ldmfd sp!, { r1-r3, lr }  @ no arctan necessary anymore in these cases
        bx lr
        
    .arctan2_x_lt_0:
        @ store "extra offset" in r2
        mov r2, #0x8000
        tst r1, #0x8000 
        rsbmi r2, #0x10000        @ -pi if y < 0

    .arctan2_div_arctan:
        @ r0 = r1 / r0
        @ shift r1 (numerator) 16 bits so that the result will be 16 bit again (otherwise it will always be either 0 or 1)
        mov r3, r0, lsl #16
        mov r0, r1, lsl #16
        mov r1, r3, asr #16
        swi 0x060000
        
        @ mov r0, r2
        @ ldmfd sp!, { r1-r3, lr }
        @ bx lr
        @ different return routine for arctan2
        ldr lr, =.add_arctan2_offset

swi_ArcTan:
    @ this is the algorithm used by the original BIOS
    @ in the end, we want ROM's to run as if the normal BIOS was in the emulator
    @ this algorithm is insanely fast, but does have some inaccuracies for higher angles
    @ return value is in (0xc000, 0x4000) for (-pi/2, pi/2)
    mul r1,r0,r0
    mov r1,r1, asr #0xe
    rsb r1,r1,#0x0
    
    mov r3,#0xa9
    mul r3,r1,r3
    mov r3,r3, asr #0xe
    add r3,r3,#0x390
    
    mul r3,r1,r3
    mov r3,r3, asr #0xe
    add r3,r3,#0x900
    add r3,r3,#0x1c
    
    mul r3,r1,r3
    mov r3,r3, asr #0xe
    add r3,r3,#0xf00
    add r3,r3,#0xb6
    
    mul r3,r1,r3
    mov r3,r3, asr #0xe
    add r3,r3,#0x1600
    add r3,r3,#0xaa
    
    mul r3,r1,r3
    mov r3,r3, asr #0xe
    add r3,r3,#0x2000
    add r3,r3,#0x81
    
    mul r3,r1,r3
    mov r3,r3, asr #0xe
    add r3,r3,#0x3600
    add r3,r3,#0x51
    
    mul r3,r1,r3
    mov r3,r3, asr #0xe
    add r3,r3,#0xa200
    add r3,r3,#0xf9
    
    mul r0,r3,r0
    mov r0,r0, asr #0x10
    bx lr
    
    .add_arctan2_offset:
        ldmfd sp!, { r1-r3, lr }
        bx lr
        

swi_Sqrt:
    @ idea: binary search with a power of 2 as initial guess
    
    stmfd sp!, { r1, r2, r3, r4 }
    
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
        mul r4, r3, r3
        cmp r4, r0
        addls r1, r2
        
        @ break off early if we have already found the square (eq)
        lsrnes r2, #1
        bne .sqrt_binary_search_loop
        
    mov r0, r1
    
    ldmfd sp!, { r1, r2, r3, r4 }
    bx lr

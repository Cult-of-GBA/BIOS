swi_GetBiosChecksum:
    @ GBATek says this should be the value resulting in r0 for a proper ROM's checksum
    @ In the end, this BIOS is directed more towards emulators, and it wouldn't matter much 
    @ if "not properly checksummed" ROMs can't run with it
    ldr r0, =#0xBAAE187F
    bx lr

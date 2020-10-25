.macro check_invalid_decomp src_len, unused_reg, src_addr, return_branch
    @ check if src_len == 0 || src_addr < 0x02000000
    cmp \src_len, #0
    movnes \unused_reg, \src_addr, lsr #25  @ == 0 if and only if src_addr < 0x02000000
    beq \return_branch
.endm

.include "bios_calls/decompression/lz77.s"
.include "bios_calls/decompression/bitunpack.s"
.include "bios_calls/decompression/diff_unfilter.s"
.include "bios_calls/decompression/huffman.s"
.include "bios_calls/decompression/running_length.s"

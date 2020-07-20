%DEVKITARM%/arm-none-eabi/bin/as.exe entrypoint.s -mcpu=arm7tdmi -o entrypoint.o
%DEVKITARM%/arm-none-eabi/bin/objcopy.exe entrypoint.o bios.bin -O binary

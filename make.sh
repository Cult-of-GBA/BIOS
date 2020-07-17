#!/bin/sh

${DEVKITARM}/bin/arm-none-eabi-as entrypoint.s -mcpu=arm7tdmi -o entrypoint.o
${DEVKITARM}/bin/arm-none-eabi-objcopy entrypoint.o bios.bin -O binary

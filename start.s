.arm
.align 4

b exception_reset
b exception_undefined
b exception_swi
b exception_unused
b exception_unused
b exception_unused
b exception_irq
b exception_unused

exception_reset:
    b $

exception_undefined:
    b $

exception_swi:
	b $

@ prefetch abort, data abort, reserved, fast IRQ
exception_unused:
	b $

exception_irq:
	b $

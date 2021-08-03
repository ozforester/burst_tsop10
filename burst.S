#include <avr/io.h>
#undef __SFR_OFFSET
#define __SFR_OFFSET 0

.global main                    ;

.section .text			; code section

main:				;
	rcall led_port_init	; D7 out,low
	rcall led_on
	l1:
	rjmp l1
ret

led_on:				;
        sbi PORTD, 7            ; D7 high
ret				;

led_port_init:                  ;
        sbi DDRD, 7             ; D7 output
        cbi PORTD, 7            ; D7 low
ret                             ;


.end


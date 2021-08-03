
; Copyright (c) 2021 ozforester. All rights reserved.
; Use of this source code is goverened by a MIT license
; that can be found in the LICENSE file.

; ATmega8 @4MHz internal osc. (H:D9, L:23)
; feeds si5351a with clockbuilder data portion
; bonus: scans twi bus for any si5351a address
; bonus: LED on D7 port will blink in case of TWI error or scan fail.

#include <avr/io.h>

#undef  __SFR_OFFSET
#define __SFR_OFFSET 0
#define START 	  0x08
#define REP_START 0x10
#define SLAW_ACK  0x18
#define SLAW_NACK 0x20
#define DATA_ACK  0x28
#define DATA_NACK 0x30

.global main                    ;
.global TIMER0_OVF_vect         ; doc
.global __vector_default        ; Note [10] nongnu.org assembly

temp    = 16			; common reg
counter = 17			; delay counter reg
code    = 18			; blink code reg
address = 19			; twi address reg
data    = 20			; twi data reg

.section .text

regs:
.byte 0x00,0x00,0x12,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.byte 0x00,0x04,0x00,0x50,0x50,0x50,0x00,0x50,0x00,0x00,0x00,0x01,0x00,0x0a,0x00,0x00
.byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x5e,0x00,0x00
.byte 0x00,0x00,0x00,0x01,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x00
.byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x07,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.byte 0x00,0x00,0x00,0x00,0x00,0x1e,0x00,0x00,0x3c,0x3c,0x00,0x00,0x00,0x00,0x00,0x00
.byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
.byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; clockbuilder cooked 233 regs

main:				;
	rcall led_port_init	; D7 out,low
	rcall timer_init	; timer0
	rcall twi_init		; 100kHz
	rcall twi_scan		; downwards 127..0 (0 = none answered)
        cpi address, 0          ; there was no answer?
        brne m1			;
	rcall error_blink	; error blink
	m1: rcall led_on	;
	rcall prepare		; disable outputs etc.
	rcall burst		; load registers
	rcall polish		; soft reset and enable outputs
	rcall sleep		; power safe
	rcall led_off		;
	ldi counter, 20		; easy oscilloscope twi mesurement
	rcall delay		;
	rjmp m1			;
ret				;

prepare:			;
	rcall twi_start		;
	rcall twi_sla_w		;
	ldi data, 3		; disable outputs
	rcall twi_data_w	;
        ldi data, 0xff          ;
        rcall twi_data_w        ;
        rcall twi_stop          ;

        rcall twi_start         ;
        rcall twi_sla_w         ;
	ldi temp, 16		; powerdown dividers (16-23 regs)
	mov data, temp		;
        rcall twi_data_w        ;
	prepare1:		; burst
	ldi data, 0x80		;
        rcall twi_data_w        ;
	inc temp		;
	cpi temp, 24		;
	brne prepare1		;
        rcall twi_stop          ;

        rcall twi_start         ;
        rcall twi_sla_w         ;
        ldi data, 2             ; set interrupt masks (w/o reading)
        rcall twi_data_w        ;
        ldi data, 0x00          ;
        rcall twi_data_w        ;
        rcall twi_stop          ;
ret				;

burst:				;
        rcall twi_start         ;
        rcall twi_sla_w         ;

	ldi temp, 0		; send register number
	mov data, temp		;
        rcall twi_data_w        ;

        rcall twi_start         ;
        rcall twi_sla_w         ;
        ldi ZL, lo8(regs)   ; set pm the first
        ldi ZH, hi8(regs)   ; burst address
        burst1:                 ;
        lpm data, Z             ; send data bytes
        rcall twi_data_w        ;
	adiw Z, 1
	inc temp		;
	cpi temp, 233		; registers 0..232 (burst)
	brne burst1		; r31 > 6 cause error

        rcall twi_stop          ;
ret				;

polish:				;
        rcall twi_start         ;
        rcall twi_sla_w         ;
        ldi data, 177           ; plla and pllb soft reset
        rcall twi_data_w        ;
        ldi data, 0xac          ;
        rcall twi_data_w        ;
        rcall twi_stop          ;
        rcall twi_start         ;
        rcall twi_sla_w         ;
	ldi data, 3		; output control
        rcall twi_data_w        ;
        ldi data, 0x07          ; enable clk 0,1,2
        rcall twi_data_w        ;
        rcall twi_stop          ;
ret				;

sleep:                          ;
        nop                     ;
ret                             ;

twi_scan:			;
	ldi address, 127	; will step backward
	twscan1:		;
	rcall twi_start		; start/rep_start
	rcall twi_sla_w		; slave addres + w
	cpi temp, 0xFF		; touched?
	brne twscan2		; if not cleared
	clr temp		; (temp=0x00)
	subi address, 1		; else next address
	cpi address, 0		; last address
	breq twscan2		; exit with zero address
	rjmp twscan1		; rep start
	twscan2:		;
	rcall twi_stop		;
ret				;

twi_data_w:					;
        push temp                               ;
	tdw1:					;
        in temp, TWCR                           ;
        sbrs temp, TWINT                        ; ready?
        rjmp tdw1                               ; not yet, repeat
	mov temp, data				;
	out TWDR, temp				; data
	ldi temp, ((1<<TWINT)|(1<<TWEN))	;
	out TWCR, temp				; go
	tdw2:					;
	in temp, TWCR				;
	sbrs temp, TWINT			; sent?
	rjmp tdw2				; not yet, repeat
	in temp, TWSR				; ok, read status
	andi temp, 0xF8				;
	cpi temp, DATA_ACK			;
	breq tdw3				; ok
        rcall error_blink                       ; error (blinking loop)
	tdw3:					;
	pop temp				;
ret						;

twi_sla_w:					;
	mov temp, address			; slave address (e.g. 0x3F as pcf of mine)
	lsl temp				; address<<  + 0, R/W = W
	out TWDR, temp				;
	ldi temp, ((1<<TWINT)|(1<<TWEN))	;
	out TWCR, temp				; go
	slaw1:					;
        in temp, TWCR                           ;
        sbrs temp, TWINT                        ; sent
        rjmp slaw1                              ;
        in temp, TWSR                           ; read status
        andi temp, 0xF8                         ;
        cpi temp, SLAW_ACK                      ;
	breq slaw2				; acked (stay temp untouched)
	;rcall error_blink			; unused w/ autodetect
	ser temp				; else (temp=0xFF)
	slaw2:					;
ret						;

twi_start:						;
	ldi temp, ((1<<TWINT)|(1<<TWSTA)|(1<<TWEN))	;
	out TWCR, temp					; go
	start1:						;
	in temp, TWCR					;
	sbrs temp, TWINT				; sent
        rjmp start1                                     ;
	in temp, TWSR					; read status
	andi temp, 0xF8					;
	cpi temp, START					;
	breq start2					;
        cpi temp, REP_START                             ;
        breq start2                                     ;
	rcall error_blink				; error (blinking loop)
	start2:						;
ret							; acked

twi_stop:						;
	push temp					;
	ldi temp, ((1<<TWINT)|(1<<TWEN)|(1<<TWSTO))	;
        out TWCR, temp                                  ;
	pop temp					;
ret							;

led_on:				;
        sbi PORTD, 7            ; D7 high
ret				;

led_off:                        ;
        cbi PORTD, 7            ; D7 low
ret                             ;

led_port_init:                  ;
        sbi DDRD, 7             ; D7 output
        cbi PORTD, 7            ; D7 low
ret                             ;

error_blink:			;
        sbi PORTD, 7            ; D7 high
        ldi counter, 1          ; delay on
        rcall delay             ;
        cbi PORTD, 7            ; D7 low
        ldi counter, 1          ; delay off
        rcall delay             ;
        rjmp error_blink        ;
ret				;

delay:                          ; counter itself decrements by t0 isr
        cpi counter, 0          ; just wait 0
        brne delay              ;
ret               		; voila

twi_init:			; 100 kHz @4MHz clock
	ldi temp, 0b00001100	; 4000000 / ( 16 + 2*TWBR * 4^TWPS )
	out TWBR, temp		; 12
        in temp, TWSR	        ;
	ori temp, 0b00000011	; 64
	out TWSR, temp		;
ret				;

timer_init:			; TIMER0 (65 ms @4MHz)
        ldi temp, (1<<CS00)     ;
        ori temp, (1<<CS02)     ;
        out TCCR0, temp         ;
        ldi temp, (1<<TOIE0)    ;
        out TIMSK, temp         ;
        sei                     ;
ret				;

TIMER0_OVF_vect:		; counter--
	push temp		;
	in temp, SREG		; z in main loop
	subi counter, 1		;
	out SREG, temp		;
	pop temp		;
reti				;

__vector_default:		;
reti				;

.end

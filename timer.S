;------------------------
; Assembly Code
;------------------------
#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global main
;===============================================================
main:
LDI R16, 0b00100000 ;to toggle PB5 (D13)
LDI R17, 0b00000000
;--------------------------------------------
SBI DDRB, 5 ;set PB5 for o/p
OUT PORTB, R17 ;PB5 = 0
;--------------------------------------------
LDI R18, 61 ;set loop counter
l1: RCALL delay_timer0 ;apply delay via timer0
DEC R18
BRNE l1 ;& go back & repeat
;--------------------------------------------
EOR R17, R16 ;R17 = R17 XOR R16
OUT PORTB, R17 ;toggle PB5
LDI R18, 61 ;re-set loop counter
RJMP l1 ;go back & repeat toggle
;===============================================================
delay_timer0: ;0.64 ms delay via Timer0
;---------------------------------------------------------
CLR R20
OUT TCNT0, R20 ;initialize timer0 with count=0
LDI R20, 9
OUT OCR0A, R20 ;OCR0 = 9
LDI R20, 0b00001101
OUT TCCR0B, R20 ;timer0: CTC mode, prescaler 1024
;---------------------------------------------------------
l2: IN R20, TIFR0 ;get TIFR0 byte & check
SBRS R20, OCF0A ;if OCF0=1, skip next instruction
RJMP l2 ;else, loop back & check OCF0 flag
;---------------------------------------------------------
CLR R20
OUT TCCR0B, R20 ;stop timer0
;---------------------------------------------------------
LDI R20, (1<<OCF0A)
OUT TIFR0, R20 ;clear OCF0 flag
RET
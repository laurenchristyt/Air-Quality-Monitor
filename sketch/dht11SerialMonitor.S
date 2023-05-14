;------------------------
; Assembly Code
;------------------------
#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global DHT11_sensor
;=================================================================
DHT11_sensor:
;-----------------------------------------------------------------
agn:RCALL delay_2s      ;wait 2s for DHT11 to get ready
;-----------------------------------------------------------------
;start_signal
;------------
    SBI   DDRD, 7       ;pin PD7 as o/p
    CBI   PORTD, 7      ;first, send low pulse
    RCALL delay_20ms    ;for 20ms
    SBI   PORTD, 7      ;then send high pulse
;-----------------------------------------------------------------
;responce signal
;---------------
    CBI   DDRD, 7       ;pin PD7 as i/p
w1: SBIC  PIND, 7
    RJMP  w1            ;wait for DHT11 low pulse
w2: SBIS  PIND, 7
    RJMP  w2            ;wait for DHT11 high pulse
w3: SBIC  PIND, 7
    RJMP  w3            ;wait for DHT11 low pulse
;-----------------------------------------------------------------
    RCALL DHT11_reading ;read humidity (1st byte of 40-bit data)
    MOV   R25, R24
    RCALL DHT11_reading
    RCALL DHT11_reading ;read temp (3rd byte of 40-bit data)
;-----------------------------------------------------------------
;convert temp & humidity bytes to decimal & display on MAX7219
;-------------------------------------------------------------
    MOV   R28, R24
    LDI   R29, 0x07
    LDI   R30, 0x06
    ;-------------------
    RCALL binary2decimal  ;temp in decimal
    ;-------------------
    MOV   R28, R25
    LDI   R29, 0x02
    LDI   R30, 0x01
    ;-------------------
    RCALL binary2decimal  ;humidity in decimal
    ;-------------------
    RJMP  agn           ;go back & get another sensor reading
;=================================================================
DHT11_reading:
    LDI   R16, 8        ;set counter for receiving 8 bits
    CLR   R24           ;clear data register
    ;-------------------------------------------------------
w4: SBIS  PIND, 7
    RJMP  w4            ;detect data bit (high pulse)
    RCALL delay_timer0  ;wait 50us & then check bit value
    ;-------------------------------------------------------
    SBIS  PIND, 7       ;if received bit=1, skip next inst
    RJMP  skp           ;else, received bit=0, jump to skp
    SEC                 ;set carry flag (C=1)
    ROL   R24           ;shift in 1 into LSB data register
    RJMP  w5            ;jump & wait for low pulse
skp:LSL   R24           ;shift in 0 into LSB data register
    ;-------------------------------------------------------
w5: SBIC  PIND, 7
    RJMP  w5            ;wait for DHT11 low pulse
    ;-------------------------------------------------------
    DEC   R16           ;decrement counter
    BRNE  w4            ;go back & detect next bit
    RET                 ;return to calling subroutine
;=================================================================
;delay subroutines
;=================================================================
delay_20ms:             ;delay 20ms
    LDI   R21, 255
l3: LDI   R22, 210
l4: LDI   R23, 2
l5: DEC   R23
    BRNE  l5
    DEC   R22
    BRNE  l4
    DEC   R21
    BRNE  l3
    RET
;-----------------------------------------------------------------
delay_2s:               ;delay 2s
    LDI   R21, 255
l6: LDI   R22, 255
l7: LDI   R23, 164
l8: DEC   R23
    BRNE  l8
    DEC   R22
    BRNE  l7
    DEC   R21
    BRNE  l6
    RET
;===============================================================
delay_timer0:             ;50 usec delay via Timer 0
    ;---------------------------------------------------------
    CLR   R20
    OUT   TCNT0, R20      ;initialize timer0 with count=0
    LDI   R20, 100
    OUT   OCR0A, R20      ;OCR0 = 100
    LDI   R20, 0b00001010
    OUT   TCCR0B, R20     ;timer0: CTC mode, prescaler 64
    ;---------------------------------------------------------
l2: IN    R20, TIFR0      ;get TIFR0 byte & check
    SBRS  R20, OCF0A      ;if OCF0=1, skip next instruction
    RJMP  l2              ;else, loop back & check OCF0 flag
    ;---------------------------------------------------------
    CLR   R20
    OUT   TCCR0B, R20     ;stop timer0
    ;---------------------------------------------------------
    LDI   R20, (1<<OCF0A)
    OUT   TIFR0, R20      ;clear OCF0 flag
    RET
;===============================================================
;Serial monitor subroutines
;-----------------------------------------------------------
init_serial:
    CLR R24
    STS UCSR0A, R24 ;clear UCSR0A register
    STS UBRR0H, R24 ;clear UBRR0H register
    LDI R24, 8 ;& store in UBRR0L 8
    STS UBRR0L, R24 ;to set baud rate 115200
    LDI R24, 1<<RXEN0 | 1<<TXEN0
    STS UCSR0B, R24 ;enable RXB & TXB
    LDI R24, 1<<UCSZ00 | 1<<UCSZ01 | 1<<UPM01 | 1<<USBS0
    STS UCSR0C, R24 ;asynch, EVEN parity, 2 stop, 8 bits
;----------------------------------------------------------------
print_ADC:
    LDI R23, 48 ;constants used to get ASCII values
    LDI R24, 7 ;for chars 0-->9 & A-->F
;-------------------------------------------------------------------
    LDI R20, 0xC7 ;set ADSC in ADCSRA to start conversion
    STS ADCSRA, R20
;-------------------------------------------------------------------
wait_ADC:
    LDS R21, ADCSRA ;check ADIF flag in ADCSRA
    SBRS R21, 4 ;skip jump when conversion is done (flag set)
    RJMP wait_ADC ;loop until ADIF flag is set
;------------------------------------------------------------------
    LDI R17, 0xD7 ;set ADIF flag again
    STS ADCSRA, R17 ;so that controller clears ADIF
;------------------------------------------------------------------
    LDS R16, ADCL ;get low-byte result from ADCL
    LDS R25, ADCH ;get high-byte result from ADCH
;-----------------------------------------------------------------
    ADD R25, R23 ;add 48 to byte to get ASCII char 0 to 9
;-----------------------------------------------------------------
l1: LDS R17, UCSR0A
    SBRS R17, UDRE0 ;test data buffer if data can be sent
    RJMP l1
;-----------------------------------------------------------------
    STS UDR0, R25 ;print ADC MSD on serial monitor
;-----------------------------------------------------------------
    PUSH R16 ;store copy of ADCH in STACK register
    ANDI R16, 0xF0 ;mask & extract high-nibble
    SWAP R16 ;swap high-nibble with low-nibble
    ADD R16, R23 ;add 48 to byte to get ASCII char 0 to 9

    MOV R28, R16 ;store a copy of byte in R28
    SUBI R28, 58 ;subtract 58 from R28
    BRPL A_F_MSD ;jump if result is +ve
;-----------------------------------------------------------------
l9: LDS R17, UCSR0A
    SBRS R17, UDRE0 ;test data buffer if data can be sent
    RJMP l2
;-----------------------------------------------------------------
    STS UDR0, R16 ;print ADC mid digit on serial monitor
;-----------------------------------------------------------------
    POP R16 ;restore ADCH value from STACK register
    ANDI R16, 0x0F ;mask & extract low-nibble
    ADD R16, R23
    MOV R28, R16
    SUBI R28, 58
    BRPL A_F_LSD
;-----------------------------------------------------------------
l10: LDS R17, UCSR0A
    SBRS R17, UDRE0 ;test data buffer if data can be sent
    RJMP l3
;-----------------------------------------------------------------
    STS UDR0, R16 ;print ADC LSD on serial monitor
;-----------------------------------------------------------------
l11: LDS R17, UCSR0A
    SBRS R17, UDRE0 ;test data buffer if data can be sent
    RJMP l4
;-----------------------------------------------------------------
    LDI R18, 0x0A
    STS UDR0, R18 ;print newline on serial monitor
;-----------------------------------------------------------------
l12: LDS R17, UCSR0A
    SBRS R17, UDRE0 ;test data buffer if data can be sent
    RJMP l5
;-----------------------------------------------------------------
    LDI R18, 0x0D
    STS UDR0, R18 ;print carriage return on serial monitor
;-----------------------------------------------------------------
    RCALL delay_sec ;1 second delay
    RJMP print_ADC

;=====================================================================
A_F_MSD:
    ADD R16, R24 ;add 7 to byte to get ASCII chars A to F
    RJMP l2
;---------------------------------------------------------------------
A_F_LSD:
    ADD R16, R24 ;add 7 to byte to get ASCII chars A to F
    RJMP l3
;---------------------------------------------------------------------
;==============================================================
binary2decimal:
;--------------
    CLR   R26             ;set counter1, initial value 0
    CLR   R27             ;set counter2, initial value 0
    ;--------------------------------------------------------
l70:  CPI   R28, 100        ;compare R28 with 100
Ret:  BRMI  l80             ;jump when R28 < 100
    INC   R26             ;increment counter1 by 1
    SUBI  R28, 100        ;R28 = R28 - 100
    RJMP  l70
    ;--------------------------------------------------------
l80:  CPI   R28, 10         ;compare R28 with 10
    BRMI  dsp             ;jump when R28 < 10
    INC   R27             ;increment counter2 by 1
    SUBI  R28, 10         ;R28 = R28 - 10
    RJMP  l80
    ;--------------------------------------------------------  
dsp:  MOV   R18, R27
    MOV   R17, R29        ;select digit
    RCALL send_bytes      ;send command & data to MAX7219
    ;--------------------------------------------------------
    MOV   R18, R28
    MOV   R17, R30        ;select digit
    RCALL send_bytes      ;send command & data to MAX7219    
    ;--------------------------------------------------------
    RET
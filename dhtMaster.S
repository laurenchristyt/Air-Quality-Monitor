#define __SFR_OFFSET 0x00 
#include "avr/io.h" 
;------------------------ 
.global main .equ SCK, 5 
.equ MOSI, 3 
.equ SS, 2 
;================================================================= 
main: 
  CBI DDRD, 2 ;clear PD2 (pin D02 as i/p - green(addition) button) 
  RCALL I2C_init ;initialize TWI module 
main_loop: 
  RCALL DHT11_process   
  RCALL SPI_Code 
  LDI R31, 0b00000000 
  SBIC PIND, 2 ;skip next statement if red button not pressed 
  LDI R31, 0b11111111 ; send signal to turn on LED on slave 
  RCALL I2C_Code 
  RJMP main_loop 
 
;================================================================= 
DHT11_process: 
;send start signal 
;------------ 
SBI DDRB, 1 ;pin PB0 as o/p 
CBI PORTB, 1 ;first, send low pulse 
RCALL delay_20ms ;for 20ms 
SBI PORTB, 1 ;then send high pulse 
;----------------------------------------------------------------- 
;wait for response signal 
;--------------- 
CBI DDRB, 1 ;pin PB0 as i/p 
w1: SBIC PINB, 1 
RJMP w1 ;wait for DHT11 low pulse 
w2: SBIS PINB, 1 
RJMP w2 ;wait for DHT11 high pulse 
w3: SBIC PINB, 1 
RJMP w3 ;wait for DHT11 low pulse 
;----------------------------------------------------------------- 
RCALL DHT11_reading ;read humidity (1st byte of 40-bit data) 
MOV R19, R18 
RCALL DHT11_reading 
RCALL DHT11_reading ;read temp (3rd byte of 40-bit data) 
;----------------------------------------------------------------- 
;Nilai Temperature disimpan pada R18 dan akan di cek dibagi menjadi tiga kondisi 
CPI R18, 70 
BRSH first_condition ;Branch if same or higher 
CPI R18, 0 
BREQ second_condition; Branch if equal  
CPI R18, 5 
BRLO third_condition; Branch if lower  
; OUT PORTD, R19 ;o/p temp byte to port C 
; OUT PORTC, R18 ;o/p humidity byte to port D 
 
RCALL delay_2s 
RET ;go back & get another sensor reading 
;================================================================= 
DHT11_reading: 
LDI R17, 8 ;set counter for receiving 8 bits 
CLR R18 ;clear data register 
;------------------------------------------------------- 
w4: SBIS PINB, 1 
RJMP w4 ;detect data bit (high pulse) 
RCALL delay_timer0 ;wait 50us & then check bit value 
;------------------------------------------------------- 
SBIS PINB, 1 ;if received bit=1, skip next inst 
RJMP skp ;else, received bit=0, jump to skp 
SEC ;set carry flag (C=1) 
ROL R18 ;shift in 1 into LSB data register 
RJMP w5 ;jump & wait for low pulse skp:LSL R18 ;shift in 0 into LSB data register 
;------------------------------------------------------- 
w5: SBIC PINB, 1 
RJMP w5 ;wait for DHT11 low pulse 
;------------------------------------------------------- 
DEC R17 ;decrement counter 
BRNE w4 ;go back & detect next bit 
RET ;return to calling subroutine 
 
;================================================================= ;Condition 
;================================================================= 
 first_condition: 
LDI R20, 0b11000000 ;Menyalakan 2 LED 
OUT PORTD, R20 
RJMP main_loop ; Kembali ke agn second_condition: 
LDI R20, 0b10000000 ;Menyalakan 1 LED 
OUT PORTD, R20 
RJMP main_loop  ; Kembali ke agn third_condition: 
LDI R20, 0b00000000 ;Mematikan LED 
OUT PORTD, R20 
RJMP main_loop ; Kembali ke agn 
 
;================================================================= 
;delay subroutines 
;================================================================= 
delay_20ms: ;delay 20ms 
LDI R21, 255 
l3: 
LDI R22, 210 
l4: 
LDI R23, 2 
l5: 
DEC R23 
BRNE l5 
DEC R22 
BRNE l4 
DEC R21 
BRNE l3 
RET 
;----------------------------------------------------------------- 
delay_2s: ;delay 3s 
LDI R21, 255 
l6: 
LDI R22, 255 
l7: 
LDI R23, 210 
l8: 
DEC R23 
BRNE l8 
DEC R22 
BRNE l7 
DEC R21 
BRNE l6 
RET 
;=============================================================== 
delay_timer0: ;50 usec delay via Timer 0 
;--------------------------------------------------------- 
CLR R20 
OUT TCNT0, R20 ;initialize timer0 with count=0 
LDI R20, 100 
OUT OCR0A, R20 ;OCR0 = 100 
LDI R20, 0b00001010 
OUT TCCR0B, R20 ;timer0: CTC mode, prescaler 8 
;--------------------------------------------------------- 
l2: IN R20, TIFR0 ;get TIFR0 byte & check 
SBRS R20, OCF0A ;if OCF0=1, skip next instruction 
RJMP l2 ;else, loop back & check OCF0 flag 
;--------------------------------------------------------- 
CLR R20 
OUT TCCR0B, R20 ;stop timer0 
;--------------------------------------------------------- 
 \
LDI R20, (1<<OCF0A) 
OUT TIFR0, R20 ;clear OCF0 flag 
RET 
;------------------------ 
; Assembly Code SPI Master 
;------------------------ 
;============================================================== 
SPI_Code: 
;-------------------------------------------------------------- 
LDI R17, (1<<MOSI)|(1<<SCK)|(1<<SS) 
OUT DDRB, R17 ;set MOSI, SCK, SS as o/p 
;-------------------------------------------------------- 
LDI R17, (1<<SPE)|(1<<MSTR)|(1<<SPR1)|(1<<CPOL)|(1<<CPHA) 
OUT SPCR, R17 ;enable SPI as master, fsck=fosc/16 
;-------------------------------------------------------- 
MOV R16, R18 ;move humidity to temp R16 
LDI R18, 0   ; nullify R18 
MOV R17, R19 ;temperature data 
LDI R19, 0 
;-------------------------------------------------------- 
again:CBI PORTB, SS ;enable slave device 
 
;Send DHT11 Temp  
OUT SPDR, R17 ;transmit byte to slave 
;-------------------------------------------------------- 
loop: IN R18, SPSR 
SBRS R18, SPIF ;wait for byte transmission 
RJMP loop ;to complete 
;-------------------------------------------------------- 
SBI PORTB, SS ;disable slave device 
;-------------------------------------------------------- 
RCALL delay_2s ;delay 
;-------------------------------------------------------- 
LDI R17, 0 
MOV R17, R16 ;Humidity data 
LDI R16, 0 
;-------------------------------------------------------- 
CBI PORTB, SS ;enable slave device 

 
;Send DHT11 Humidity  
OUT SPDR, R17 ;transmit byte to slave 
;-------------------------------------------------------- 
loop2: IN R18, SPSR 
SBRS R18, SPIF ;wait for byte transmission 
RJMP loop2 ;to complete 
;-------------------------------------------------------- 
SBI PORTB, SS ;disable slave device 
;-------------------------------------------------------- 
RCALL delay_2s ;delay 
RET 
;============================================================== 
 
 
;-------------------------- 
; Assembly Code - I2C Master Tx 
;-------------------------- 
;============================================================== 
I2C_Code: 
;---------------------------------------------------------- ; 
RCALL I2C_init ;initialize TWI module 
;---------------------------------------------------------- 
;---------------------------------------------------------- 
RCALL I2C_start ;transmit START condition 
LDI R27, 0b10010000 ;SLA(1001000) + W(0) slave address 
RCALL I2C_write ;write slave address SLA+W 
;Send Button data 
MOV R27, R31 ;data byte to be transmitted 
RCALL I2C_write ;write data byte 
RCALL I2C_stop ;transmit STOP condition 
;---------------------------------------------------------- 
; RJMP l1 ;go back for another transmit 
RET ;go back for another transmit 
;============================================================== 
I2C_init: 
LDI R21, 2 
STS TWSR, R21 ;prescaler = 2 
LDI R21, 83 ;division factor = 83 
STS TWBR, R21 ;SCK freq = 400kHz 
LDI R21, (1<<TWEN) 
STS TWCR, R21 ;enable TWI 
RET 
;============================================================== 
2C_start: 
LDI R21, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN) 
STS TWCR, R21 ;transmit START condition 
;---------------------------------------------------------- 
wt1:LDS R21, TWCR 
SBRS R21, TWINT ;TWI interrupt = 1? 
RJMP wt1 ;no, wait for end of transmission 
;---------------------------------------------------------- 
RET 
;============================================================== 
I2C_write: 
STS TWDR, R27 ;copy SLA+W into data register 
LDI R21, (1<<TWINT)|(1<<TWEN) 
STS TWCR, R21 ;transmit SLA+W 
;---------------------------------------------------------- 
wt2:LDS R21, TWCR 
SBRS R21, TWINT 
RJMP wt2 ;wait for end of transmission 
;---------------------------------------------------------- 
RET 
;============================================================== 
I2C_stop: 
LDI R21, (1<<TWINT)|(1<<TWSTO)|(1<<TWEN) 
STS TWCR, R21 ;transmit STOP condition 
RET 

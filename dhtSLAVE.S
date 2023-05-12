#define __SFR_OFFSET 0x00 
#include "avr/io.h" 
;------------------------ 
.global main 
;============================================================== 
main: 
SBI DDRD, 2 ; LED output 
LDI R17, (1<<SPE) 
OUT SPCR, R17 ;enable SPI as slave 
RCALL init_serial 
main_loop: 
RCALL I2CLOOP 
RCALL SPILOOP 
RCALL print_msg 
RCALL print_DHT 
RJMP main 
;-------------------------------------------------------------- 
SPILOOP: 
IN R18, SPSR 
SBRS R18, SPIF ;wait for byte reception 
RJMP l1 ;to complete 
;------------------------------------------------------ 
IN R18, SPDR ;i/p byte from data register TEMPERATURE 
RCALL delay_2s ;delay 
IN R19, SPSR 
SBRS R19, SPIF ;wait for byte reception 
RJMP l1 ;to complete 
;------------------------------------------------------ 
IN R19, SPDR ;i/p byte from data register HUMIDITY 
RET 
;============================================================== 
I2CLOOP:RCALL I2C_init ;initialize TWI module 
RCALL I2C_listen ;listen to bus to be addressed 
RCALL I2C_read ;read data byte 
SBRS R27, 2 
SBI PORTD, 2 
SBRC R27, 2 
CBI PORTD, 2 ;and o/p to port D 
RET 
;-------------------------------------------------------------- 
l1: 
SBIS PINC, 3 
RJMP l1 ;wait for "listen" button press 
;-------------------------------------------------------------- 
LDI R26, 0 
OUT PORTD, R26 ;clear port D 
RJMP I2CLOOP ;& go back & listen to bus 
;============================================================== 
I2C_init: 
LDI R21, 0b10010000 
STS TWAR, R21 ;store slave address 0b10010000 
LDI R21, (1<<TWEN) 
STS TWCR, R21 ;enable TWI 
LDI R21, (1<<TWINT)|(1<<TWEN)|(1<<TWEA) 
STS TWCR, R21 ;enable TWI & ACK 
RET 
;============================================================== 
I2C_listen: 
LDS R21, TWCR 
SBRS R21, TWINT 
RJMP I2C_listen ;wait for slave to be addressed RET 
;============================================================== 
I2C_read: 
LDI R21, (1<<TWINT)|(1<<TWEA)|(1<<TWEN) 
STS TWCR, R21 ;enable TWI & ACK 
;---------------------------------------------------------- 
wt: LDS R21, TWCR 
SBRS R21, TWINT 
RJMP wt ;wait for data byte to be read 
;---------------------------------------------------------- 
LDS R27, TWDR ;store received byte 
RET 
 
init_serial: 
  CLR R24 ; Meng-clear R24 untuk meng-clear UCSR0A dan UBRR0H 
  STS UCSR0A, R24 ; Menyimpan isi dari R24 yang sudah di-clear ke UCSR04 
  STS UBRR0H, R24 ; Menyimpan isi dari R24 yang sudah di-clear ke UBRR0H 
  LDI R24, 103 ; Mengisi R24 untuk mengisi UBRR0L 
  STS UBRR0L, R24 ; Menetapkan baud rate dengan menyimpan isi dari R24 
  LDI R24, 1<<RXEN0 | 1<<TXEN0 ; Meng-enable RXB dan TXB 
  STS UCSR0B, R24 ; Menyimpan isi dari R24 
  LDI R24, 1<<UCSZ00 | 1<<UCSZ01 ; Async, no parity, 1 stop, 8 bits   
  STS UCSR0C, R24; Menyimpan isi dari R24 
  RET 
LCD_buffer: 
  LDS R17, UCSR0A 
  SBRS R17, UDRE0 ;test data buffer if data can be sent 
  RJMP LCD_buffer   RET print_msg: 
  LDI R30, lo8(message) ; Me-load low-byte dari pesan yang diinginkan ke Z   
  LDI R31, hi8(message) ; Me-load high-byte dari pesan yang diinginkan ke Z agn: 
  LPM R19, Z+ ; Me-load satu char dari strings yang disimpan di program memory Z 
  CPI R19, 0 ; Meng-compare apakah R19 berisi 0 
  BREQ ext ; Jika nol, program akan branch ke ext 
  RCALL LCD_buffer 
  STS UDR0, R19 ; Menyimpan char ke  UDR0 yang akan ditampilkan di serial monitor   
  RJMP agn ; kembali ke agn sampai R19 bernilai 0 ext: 
  RET ; Lanjut ke mengeprint DHT11 message: 
  .ascii " Pembacaan sensor: " ; Pesan yang diinginkan 
  .byte 0 print_DHT: 
  MOV R16, R18 ;Print TEMPERATURE 
  RCALL ASCII_MSD ; Mendapatkan ASCII dari MSD 
  RCALL LCD_buffer ; Subroutine untuk mengecek FLAG UDRE0 
  STS UDR0, R16 ; Menampilkan MSD (yang sudah diubah ke ASCII) di serial monitor   
  RCALL ASCII_LSD ; Menampilkan MSD (yang sudah diubah ke ASCII) di serial monitor 
  RCALL LCD_buffer ;Subroutine untuk mengecek Flag UDRE0 
  STS UDR0, R16 ;print LSD of result on serial monitor 
   
  MOV R16, R19 ;Print HUMIDITY 
  RCALL ASCII_MSD ;Mendapatkan ASCII dari MSD 
  RCALL LCD_buffer ;Subroutine untuk mengecek Flag UDRE0 
  STS UDR0, R16 ;Menampilkan MSD (yang sudah diubah ke ASCII) di serial monitor 
  RCALL ASCII_LSD ; Mendapatkan ASCII dari MSD 
  RCALL LCD_buffer ;Subroutine untuk mengecek Flag UDRE0 
  STS UDR0, R16 ;Menampilkan LSD (yang sudah diubah ke ASCII) di serial monitor   
  RCALL LCD_buffer ;Subroutine untuk mengecek Flag UDRE0   
  LDI R26, 0x0A 
  STS UDR0, R26 ;print newline 
  RCALL LCD_buffer ;Subroutine untuk mengecek Flag UDRE0   
  LDI R26, 0x0D 
  STS UDR0, R26 ;print carriage return 
   
   
  RCALL delay_2s ;wait 2s for DHT11 to get ready 
  RET;return to loop() 
ASCII_MSD: ; Proses mendapatkan ASCII dari MSD 
  MOV R23, R16 ;save copy of result 
  ANDI R16, 0xF0 ; extract & swap high-nibble 
  SWAP R16 
  SUBI R16, -48 ;R16 = R16 - (48) = R16 + 48 
  MOV R28, R16 ;save a copy of high-byte result 
  SUBI R28, 58 ;if +ve 
  BRPL A_F_D1 ;branch & add 7 to get ASCII A to F 
  loopMSD: 
  RET 
 
ASCII_LSD: ; Proses mendapatkan ASCII dari LSD 
MOV R16, R23 ;restore copy of result 
ANDI R16, 0x0F ;extract low-nibble 
SUBI R16, -48 ;R16 = R16 - (48) = R16 + 48 
MOV R28, R16 ;save a copy of high-byte result 
SUBI R28, 58 ;if +ve 
BRPL A_F_D0 ;branch & add 7 to get ASCII A to F 
LOOPLSD: 
RET 
A_F_D1: 
SUBI R16, -7 ;R16 = R16 - (7) = R16 + 7 RJMP loopMSD 
A_F_D0: 
SUBI R16, -7 ;R16 = R16 - (7) = R16 + 7 
RJMP LOOPLSD 
 
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

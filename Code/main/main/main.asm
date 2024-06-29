.include "m328pdef.inc" 

.def ASCII = R8

.org 0x0000					; starts from 0x000
	rjmp main

;------------------------------------------------------------------------------------------------------------------------------------------main start
main:
	CLI					  ; Clear globle interruplts
	CBI   PORTB, 3
	LDI   R16,0
	MOV   R14, R16
	MOV   R15, R16

	;pin configuration======================================================================
	
    LDI   R21, 0xF2       
    OUT   DDRD, R21       ; O/P (row lines R1,R2,R3,R4, LCD data )  
	LDI   R21, 0xF8       
    OUT   DDRB, R21       ; (column lines C1,C2,C3 as i/p AND RS,E,PWM (Timer2) O/P)
	ldi   R21, 0b01111111
	out   DDRC, R21
;===========================================================================================

; ADC configuration=========================================================================
    LDI   R21, 0x00		; AREF, right-justified data, ADC0
    STS   ADMUX, R21
    LDI   R21, 0x87		; 0b01010111 enable ADC, ADC prescaler CLK/128
    STS   ADCSRA, R21
;===========================================================================================

; ASCII configuration=======================================================================
	ldi   R21, 48
	mov   ASCII, R21		; store ascii constant to get character
;===========================================================================================
	
; Initialize display========================================================================
	CALL LCD_init
;===========================================================================================

;Initial run of ADC=========================================================================
	call  ADC_start
	call  map
	call  val_to_digit
	mov   R13, R18
	mov   R12, R19
	call  lcd_write
	call  comp
	mov   R7,R11
;===========================================================================================
;--------------------------------------------------------------------------------------------------------------------------------------------main end


;------------------------------------------------------------------------------------------------------------------------------------------loop start
loop:
	call delay_long
	call  ADC_start
	call  map
	mov   R24, R11
	CPSE  R7, R24
	call  ADC_display
	in    R21, pind
	;andi   R21, 8
	sbrc  R21,2			; ISR check
	call  Enter_key 
	rjmp  loop
;--------------------------------------------------------------------------------------------------------------------------------------------loop end

;-----------------------------------------------------------------------------------------------------------------------------------ADC_display start
ADC_display:
	call  ADC_start
	call  map
	call  comp
	call  val_to_digit 
	call  digit_to_val
	call  comp
	mov   R13, R18
	mov   R12, R19
	call  lcd_write
	mov   R7, R11
	ret
;-------------------------------------------------------------------------------------------------------------------------------------ADC_display end

;-------------------------------------------------------------------------------------------------------------------------------------Enter_key start
Enter_key:	
	sbi   portd, 1
	call  init_keypad
	mov   R14, R16
	call  lcd_write
	sbi   portd, 1
	call  init_keypad
	mov   R15, R16
	call  lcd_write
	call  digit_to_val
	ldi   R21,0
	mov   R2, R21
	CBI   PORTC,2
	CBI   PORTC,3
	CBI   PORTC,4
	CBI   PORTC,5
	CBI   PORTB,0
	CBI   PORTB,1
	CBI   PORTB,2
	call  comp
	ret
;--------------------------------------------------------------------------------------------------------------------------------------Enter_key end

;===========================================================================================
;-----------------------
; LCD dispaly functions
;-----------------------
LCD_write:
	LDI   R25, 0x01			;clear LCD
    RCALL command_wrt
	CBI   PORTB, 4			;EN = 0
    RCALL delay_ms			;wait for LCD power on
    ;--------------------------------------------------
	;display Reference on LCD
	ldi   R25,82				
    RCALL data_wrt			
	ldi   R25,101
    RCALL data_wrt	
	ldi   R25,102
    RCALL data_wrt	
	ldi   R25,101
    RCALL data_wrt	
	ldi   R25,114
    RCALL data_wrt	
	ldi   R25,101
    RCALL data_wrt	
	ldi   R25,110
    RCALL data_wrt	
	ldi   R25,99
    RCALL data_wrt	
	ldi   R25,101
    RCALL data_wrt	
	ldi   R25,32
    RCALL data_wrt	
	MOV   R25, R14			; MSD of reference
	add   R25, ASCII
    RCALL data_wrt	
	MOV   R25, R15			; LSD of referencr
	add   R25, ASCII
    RCALL data_wrt
	ldi   R25,223
    RCALL data_wrt
	ldi   R25,67
    RCALL data_wrt			
	;----------------------------------------------------
    LDI   R25, 0xC0			;cursor beginning of 2nd line
    RCALL command_wrt
    RCALL delay_ms
    ;----------------------------------------------------
	;display Current on LCD
	ldi   R25, 67
    RCALL data_wrt	
	ldi   R25,117
    RCALL data_wrt	
	ldi   R25,114
    RCALL data_wrt	
	ldi   R25,114
    RCALL data_wrt	
	ldi   R25,101
    RCALL data_wrt	
	ldi   R25,110
    RCALL data_wrt	
	ldi   R25,116
    RCALL data_wrt	
	ldi   R25,32
    RCALL data_wrt	
	MOV   R25, R13
	add   R25, ASCII
    RCALL data_wrt	
	MOV   R25, R12
	add   R25, ASCII
    RCALL data_wrt
	ldi   R25,223
    RCALL data_wrt
	ldi   R25,67
    RCALL data_wrt		
	ret

;==============================================================
LCD_init:
    LDI   R25, 0x33			;init LCD for 4-bit data
    RCALL command_wrt		;send to command register
    RCALL delay_ms
    LDI   R25, 0x32			;init LCD for 4-bit data
    RCALL command_wrt
    RCALL delay_ms
    LDI   R25, 0x28			;LCD 2 lines, 5x7 matrix
    RCALL command_wrt
    RCALL delay_ms
    LDI   R25, 0x0C			;disp ON, cursor OFF
    RCALL command_wrt
    LDI   R25, 0x01			;clear LCD
    RCALL command_wrt
    RCALL delay_ms
    ;LDI   R25, 0x06		;shift cursor right
    ;RCALL command_wrt
    RET  

;====================================================================
command_wrt:
    MOV   R26, R25
    ANDI  R26, 0xF0		;mask low nibble & keep high nibble
    OUT   PORTD, R26	;o/p high nibble to port D
    CBI   PORTB, 5		;RS = 0 for command
    SBI   PORTB, 4		;EN = 1
    RCALL delay_short   ;widen EN pulse
    CBI   PORTB, 4		;EN = 0 for H-to-L pulse
    RCALL delay_us      ;delay 100us
    ;-------------------------------------------------------
    MOV   R26, R25
    SWAP  R26			;swap nibbles
    ANDI  R26, 0xF0		;mask low nibble & keep high nibble
    OUT   PORTD, R26	;o/p high nibble to port D
    SBI   PORTB, 4		;EN = 1
    RCALL delay_short   ;widen EN pulse
    CBI   PORTB, 4		;EN = 0 for H-to-L pulse
    RCALL delay_us      ;delay 100us
    RET

;====================================================================
data_wrt:
    MOV   R26, R25
    ANDI  R26, 0xF0		;mask low nibble & keep high nibble
    OUT   PORTD, R26	;o/p high nibble to port D
    SBI   PORTB, 5		;RS = 1 for data
    SBI   PORTB, 4		;EN = 1
    RCALL delay_short   ;make wide EN pulse
    CBI   PORTB, 4		;EN = 0 for H-to-L pulse
    RCALL delay_us      ;delay 100us
    ;-------------------------------------------------------
    MOV   R26, R25
    SWAP  R26			;swap nibbles
    ANDI  R26, 0xF0		;mask low nibble & keep high nibble
    OUT   PORTD, R26	;o/p high nibble to port D
    SBI   PORTB, 4		;EN = 1
    RCALL delay_short   ;widen EN pulse
    CBI   PORTB, 4		;EN = 0 for H-to-L pulse
    RCALL delay_us      ;delay in micro seconds
    RET

;===========================================================================================
;-----------------------
; time delay functions!!!
;-----------------------
delay_short:            ;short delay, 3 cycles
	NOP
    NOP
    RET
;--------------------------------------------------
delay_us:               ;delay in us
    LDI   R20, 90
l1: RCALL delay_short
    DEC   R20
    BRNE  l1
    RET

;--------------------------------------------------
delay_ms:               ;delay in ms
    LDI   R21, 40
l2: RCALL delay_us
    DEC   R21
    BRNE  l2
    RET

delay_long:
	LDI R31, 50
l3: RCALL delay_ms
    DEC   R31
    BRNE  l3
    RET
	

;===========================================================================================
;-----------------------
; Keypad function
;-----------------------
init_keypad: 
	CBI   PORTC,2
	CBI   PORTC,3
	CBI   PORTC,4
	CBI   PORTC,5
	SBI   PORTB,0
	SBI   PORTB,1
	SBI   PORTB,2
    ;-----------------------------------------------------------
wait_release:
	NOP                     ; delay
	NOP
	NOP
	NOP
	IN    R17, PINB         ;read key pins 
	ANDI  R17, 0x07         ;mask unsed bits
	CPI   R17, 0x07         ;equal if no keypress
	BRNE  wait_release      ;do again until keys released
	;-----------------------------------------------------------
wait_keypress:
    NOP                     ; delay
	NOP
	NOP
	NOP
	NOP
	NOP
    IN    R17, PINB         ;read key pins
    ANDI  R17, 0x07         ;mask unsed bits
    CPI   R17, 0x07         ;equal if no keypress
    BREQ  wait_keypress     ;keypress? no, go back & check
;------------------------------------------------------------------colunm 1 check
	CBI   PORTC,2
	SBI   PORTC,3
	SBI   PORTC,4
	SBI   PORTC,5
    NOP						; delay 
	NOP
	NOP
	NOP
	NOP
	NOP
    IN    R17, PINB         ;read all columns
    ANDI  R17, 0x07         ;mask unsed bits
    CPI   R17, 0x07         ;equal if no key
    BRNE  row1_col          ;row 1, find column // new function
;------------------------------------------------------------------colunm 2 check
	SBI   PORTC,2
	CBI   PORTC,3
	SBI   PORTC,4
	SBI   PORTC,5
    NOP
	NOP
	NOP
	NOP
	NOP
	NOP
    IN    R17, PINB         ;read all columns
    ANDI  R17, 0x07			;mask unsed bits
    CPI   R17, 0x07			;equal if no key
    BRNE  row2_col          ;row 2, find column // nf 2
;------------------------------------------------------------------colunm 3 check
	SBI   PORTC,2
	SBI   PORTC,3
	CBI   PORTC,4
	SBI   PORTC,5
    NOP 
	NOP
	NOP
	NOP
	NOP
	NOP
    IN    R17, PINB			;read all columns
    ANDI  R17, 0x07			;mask unsed bits
    CPI   R17, 0x07			;equal if no key
    BRNE  row3_col			;row 3, find column // nf 3
;------------------------------------------------------------------colunm 4 check
    SBI   PORTC,2
	SBI   PORTC,3
	SBI   PORTC,4
	CBI   PORTC,5
    NOP
	NOP
	NOP
	NOP
	NOP
	NOP
    IN    R17, PINB			;read all columns
    ANDI  R17, 0x07			;mask unsed bits
    CPI   R17, 0x07			;equal if no key
    BRNE  row4_col			;row 4, find column // nf 4 
;------------------------------------------------------------------row 1 check
row1_col:
    CPI   R17, 0b00000110    
	BREQ  Load_1
	CPI   R17, 0b00000101   
	BREQ  Load_2
	CPI   R17, 0b00000011    
	BREQ  Load_3
;------------------------------------------------------------------row 2 check
row2_col:
    CPI   R17, 0b00000110    
	BREQ  Load_4
	CPI   R17, 0b00000101   
	BREQ  Load_5
	CPI   R17, 0b00000011    
	BREQ  Load_6
;------------------------------------------------------------------row 3 check
row3_col:
    CPI   R17, 0b00000110    
	BREQ  Load_7
	CPI   R17, 0b00000101   
	BREQ  Load_8
	CPI   R17, 0b00000011    
	BREQ  Load_9
;------------------------------------------------------------------row 4 check
row4_col:
    CPI   R17, 0b00000110    
	BREQ  Load_10
	CPI   R17, 0b00000101   
	BREQ  Load_0
	CPI   R17, 0b00000011   
	BREQ  Load_11
;------------------------------------------------------------------value load to R16
Load_1:
	LDI   R16,1
	ret
Load_2:
	LDI   R16,2
	ret
Load_3:
	LDI   R16,3
	ret
Load_4:
	LDI   R16,4
	ret
Load_5:
	LDI   R16,5
	ret
Load_6:
	LDI   R16,6
	ret
Load_7:
	LDI   R16,7
	ret 
Load_8:
	LDI   R16,8
	ret
Load_9:
	LDI   R16,9
	ret   
Load_10:
	;LDI   R16,10
	ret 
Load_0:
	LDI   R16,0
	ret   
Load_11:
	;LDI   R16,11
	ret

;===========================================================================================
;-----------------------
; ADC function
;-----------------------
ADC_start:
    LDI   R21, 0xC7		    ;set ADSC in ADCSRA to start conversion
    STS   ADCSRA, R21
	;----------------------------------------------------------------
wait_ADC:
    LDS   R21, ADCSRA		;check ADIF flag in ADCSRA
    SBRS  R21, 4			;skip jump when conversion is done (flag set)
    RJMP  wait_ADC		    ;loop until ADIF flag is set
    ;----------------------------------------------------------------
    LDI   R21, 0xD7		    ;set ADIF flag again
    STS   ADCSRA, R21		;so that controller clears ADIF
    ;----------------------------------------------------------------
	LDS   R10, ADCL		    ;get low-byte result from ADCL
	LDS   R9, ADCH		    ;get high-byte result from ADCH
	ret

;===========================================================================================
;-----------------------
; Map function
;-----------------------
map:
	mov   R30, R10         
	lsr   R30
	mov   R11, R30
	ret


;===========================================================================================
;-----------------------
; Compare function
;-----------------------
comp:
	CLR   R22
	CLR   R21
	mov   R22, R11
	;ldi   R21, 1
	;add   R27, R21
	sub   R22, R27
	BRMI  ON
	jmp   OFF

ON:
	CBI   PORTB, 3
	ret

OFF:
	SBI   PORTB, 3
	ret

;===========================================================================================
;-----------------------
; Value to digit function
;-----------------------
val_to_digit:
	CLR R28
	mov R19, R11
	ldi R18, 0
	ldi R28, 10
div:
	sub R19, R28
	BRMI return_digit
	inc  R18
	rjmp div
return_digit:
	add R19, R28
	ret

;===========================================================================================
;-----------------------
; Digit to value function
;-----------------------
digit_to_val:
	CLR R23
	mov R26, R14
	mov R27, R15
	ldi R23, 10
multi:
	dec R26
	BRMI return_val
	add  R27, R23
	rjmp multi
return_val:
	ret

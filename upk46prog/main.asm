;
; upk46prog.asm
;
; Created: 01.10.2018 15:58:21
; Author : i_guzak
;

			.include "m8def.inc"
			.include "macro.inc"

			.equ		I2CBSF = 0x00
			.equ		I2CSTT = 0x80
			.equ		I2CRST = 0x10
			.equ		I2CAWA = 0x18
			.equ		I2CAWN = 0x20
			.equ		I2CBTA = 0x28
			.equ		I2CBTN = 0x30
			.equ		I2CCLN = 0x38
			.equ		I2CARA = 0x40
			.equ		I2CARN = 0x48
			.equ		I2CRBA = 0x50
			.equ		I2CRBN = 0x58

;====================================================================
;			RAM
;====================================================================

			.DSEG

			.equ	MAXBUFF_IN	 =	10	
			.equ	MAXBUFF_OUT = 	10
	
IN_BUFF:	.byte	MAXBUFF_IN
IN_PTR_S:	.byte	1
IN_PTR_E:	.byte	1
IN_FULL:	.byte	1	

OUT_BUFF:	.byte	MAXBUFF_OUT
OUT_PTR_S:	.byte	1
OUT_PTR_E:	.byte	1
OUT_FULL:	.byte	1

			.equ	DL_ERR_MSK = 0x80
			.equ	DL_CLT_MSK = 0x01
			.equ	DL_BZY_MSK = 0x02
			.equ	DL_ERR_CLT = DL_ERR_MSK + DL_CLT_MSK + DL_BZY_MSK
DELAY_FL:	.byte	1
DELAY_CNT:	.byte	1

;====================================================================
;			FLASH
;====================================================================

			.CSEG
			.ORG	$000	 
			RJMP	RESET	; (RESET)
			.ORG	$001
			RETI			; (INT0) External Interrupt Request 0
			.ORG	$002
			RETI 			; (INT1) External Interrupt Request 1
			.ORG	$003
			RETI 			; (TIMER2 COMPB) Timer/Counter2 Compare Match
			.ORG	$004
			RETI 			; (TIMER2 OVF) Timer/Counter2 Overflow
			.ORG	$005
			RETI 			; (TIMER1 CAPT) Timer/Counter1 Capture Event
			.ORG	$006
			RETI 			; (TIMER1 COMPA) Timer/Counter1 Compare Match A
			.ORG	$007
			RETI 			; (TIMER2 COMPB) Timer/Counter2 Compare Match B
			.ORG	$008
			RETI 			; (TIMER1 OVF) Timer/Counter1 Overflow
			.ORG	$009
			RJMP TOV0_F		; (TIMER0 OVF) Timer/Counter0 Overflow
			.ORG	$00A
			RETI 			; (SPI,STC) Serial Transfer Complete
			.ORG	$00B
			RJMP RX_U0		; (USART0,RXC) USART0 Rx Complete
			.ORG	$00C
			RJMP DR_U0		; (USART0,UDRE) USART0 Data Register Empty
			.ORG	$00D
			RJMP TX_U0		; (USART0,TXC) USART0 Tx Complete
			.ORG	$00E
			RETI			; (ADC) ADC Conversion Complete
			.ORG	$00F
			RETI 			; (EE_RDY) EEPROM Ready
			.ORG	$010
			RETI			; (ANALOG COMP) Analog Comparator
			.ORG	$011 
            RJMP I2C_EVENT	; (TWI) 2-wire Serial Interface
			.ORG	$012
			RETI			; (SPM_RDY) Store Program Memory Ready
			
			.ORG   INT_VECTORS_SIZE      	; Конец таблицы прерываний

;==========================================================
;	I2C INTERRUPT
;==========================================================

			.def	STATI2C = R18

			CLI

			PUSHF
			PUSH	R17
			PUSH	STATI2C

			OUT		STATI2C, TWSR
			ANDI	STATI2C, PRESC

			CPI		STATI2C, I2CBSF
			BRNE	CASE1
			
			RCALL	DELAY_MS	

CASE1:		NOP

OUT_I2C:	POP		STATI2C
			POP		R17
			POPF
			SEI

;==========================================================
;	DELAY FUNCTION
;==========================================================

; range from 2 to 500 ms (64)
; range from 40 to 2000 ms (256)
; range from 160 to 8000 ms (1024)
; IN - R19 (Time set)
; OUT - R19 (FLAG mask)

			.equ	PRESC_MASK = 0x07
			.equ	T0_STOP = 0x00
			.equ	T0_RUN_64 = 0x03
			.equ	T0_RUN_256 = 0x04
			.equ	T0_RUN_1024 = 0x05
			.equ	T0_STEP_CNT = 0.002048

DELAY_MS:	PUSHF
			PUSH	R17
	
			LDS		R16, DELAY_FL
			LDI		R17, DL_ERR_CLT
			AND		R17, R16

			CPI		R17, 0x00
			BREQ	QUERY_PROC

			LDS		R16, DELAY_FL
			ORI		R16, DL_ERR_MSK
			STS		DELAY_FL, R16
			RJMP	DELAY_OUT

QUERY_PROC: CLR		R16
			LDI		R16, (0 << TOV0)
			OUT		TIMSK, R16

			STS		DELAY_CNT, R19
			
			LDI		R16, DR_CLT_MSK
			LDI		R17, DL_ERR_MSK
			ORI		R17, R16
			COM		R17
			
			LDS		R16, DELAY_FL
			AND		R16, R17
			STS		DELAY_FL, R16

			LDI		R16, (1 << TOV0)
			OUT		TIMSK, R16

			LDI		R16, T0_RUN_256
			OUT		TCCR0, R16
			
DELAY_OUT:	POP		R17
			POPF
			RET

;==========================================================
;	RX INTERRUPT
;==========================================================

RX_U0:		PUSHF
			PUSH	R17
			PUSH	R18
			PUSH	XL
			PUSH	XH

			LDI		XL, low(IN_BUFF)	; Берем адрес начала буффера
			LDI		XH, high(IN_BUFF)
			LDS		R16, IN_PTR_E		; Берем смещение точки записи
			LDS		R18, IN_PTR_S		; Берем смещение точки чтения

			ADD		XL, R16				; Сложением адреса со смещением
			CLR		R17					; получаем адрес точки записи
			ADC		XH, R17
			
			IN		R17, UDR			; Забираем данные
			ST		X, R17				; сохраняем их в кольцо

			INC		R16					; Увеличиваем смещение

			CPI		R16, MAXBUFF_IN		; Если достигли конца 
			BRNE	NO_END
			CLR		R16					; переставляем на начало

NO_END:		CP		R16, R18			; Дошли до непрочитанных данных?
			BRNE	RX_OUT				; Если нет, то просто выходим


RX_FULL:	LDI		R18, 0x01				; Если да, то буффер переполнен.
			STS		IN_FULL, R18			; Записываем флаг наполненности
			
RX_OUT:		STS		IN_PTR_E, R16		; Сохраняем смещение. Выходим

			POP		XH
			POP		XL
			POP		R18
			POP		R17
			POPF						; Достаем SREG и R16
			RETI

;==========================================================
;	TX INTERRUPT
;==========================================================

TX_U0:		PUSHF						; Выключаем прерывание UDRE
			LDI 	R16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(1<<TXCIE)|(0<<UDRIE)
			OUT 	UCSRB, R16
			POPF
			RETI

;==========================================================
;	UDRE INTERRUPT
;==========================================================

DR_U0:		PUSHF						
			PUSH	R17
			PUSH	R18
			PUSH	R19
			PUSH	XL
			PUSH	XH


			LDI		XL, low(OUT_BUFF)	; Берем адрес начала буффера
			LDI		XH, high(OUT_BUFF)
			LDS		R16, OUT_PTR_E		; Берем смещение точки записи
			LDS		R18, OUT_PTR_S		; Берем смещение точки чтения			
			LDS		R19, OUT_FULL		; Берм флаг переполнения

			CPI		R19, 0x01			; Если буффер переполнен, то указатель начала
			BREQ	NEED_SND			; Равер указателю конца. Это надо учесть.

			CP		R18, R16			; Указатель чтения достиг указателя записи?
			BRNE	NEED_SND			; Нет! Буффер не пуст. Надо слать дальше

			LDI 	R16, 1<<RXEN|1<<TXEN|1<<RXCIE|1<<TXCIE|0<<UDRIE	; Запрет прерывания
			OUT 	UCSRB, R16										; По пустому UDR
			RJMP	TX_OUT				; Выходим

NEED_SND:	CLR		R17					; Получаем ноль
			STS		OUT_FULL, R17		; Сбрасываем флаг переполнения

			ADD		XL, R18				; Сложением адреса со смещением
			ADC		XH, R17				; получаем адрес точки чтения

			LD		R17, X				; Берем байт из буффера
			OUT		UDR, R17			; Отправляем его в USART

			INC		R18					; Увеличиваем смещение указателя чтения

			CPI		R18, MAXBUFF_OUT	; Достигли конца кольца?
			BRNE	TX_OUT				; Нет? 
			
			CLR		R18					; Да? Сбрасываем, переставляя на 0

TX_OUT:		STS		OUT_PTR_S, R18		; Сохраняем указатель
			
			POP		XH
			POP		XL
			POP		R19
			POP		R18
			POP		R17
			POPF						; Выходим, достав все из стека
			RETI

;==========================================================
;	TOV0 INTERRUPT
;==========================================================

TOV0_F:		PUSHF
			
			LDI		R16, (0 << TOV0)
			OUT		TIMSK, R16
			
			LDS		R16, DELAY_CNT

			CPI		R16, 0x00
			BRNE	STEP_UP

			LDS		R16, DELAY_FL
			ORI		R16, DL_CLT_MSK
			STS		DELAY_FL, R16

			LDI		R16, T0_STOP
			OUT		TCCR0, R16

			RJMP	OUT_TOV0

STEP_UP:	DEC		R16
			STS		DELAY_CNT, R16			

OUT_TOV0:	POPF
			RETI

;==========================================================
;	BUFFER PUSH FUNCTION
;==========================================================

; Load Loop Buffer 
; IN R19 	- DATA
; OUT R19 	- ERROR CODE 
BUFF_PUSH:	LDI		XL, low(OUT_BUFF)	; Берем адрес начала буффера
			LDI		XH, high(OUT_BUFF)
			LDS		R16, OUT_PTR_E		; Берем смещение точки записи
			LDS		R18, OUT_PTR_S		; Берем смещение точки чтения

			ADD		XL, R16				; Сложением адреса со смещением
			CLR		R17					; получаем адрес точки записи
			ADC		XH, R17
			

			ST		X, R19				; сохраняем их в кольцо
			CLR		R19					; Очищаем R19, теперь там код ошибки
										; Который вернет подпрограмма

			INC		R16					; Увеличиваем смещение

			CPI		R16, MAXBUFF_OUT		; Если достигли конца 
			BRNE	_NoEnd
			CLR		R16					; переставляем на начало

_NoEnd:		CP		R16,R18				; Дошли до непрочитанных данных?
			BRNE	_RX_OUT				; Если нет, то просто выходим


_RX_FULL:	LDI		R19,1				; Если да, то буффер переполнен.
			STS		OUT_FULL,R19		; Записываем флаг наполненности
										; В R19 остается 1 - код ошибки переполнения
			
_RX_OUT:	STS		OUT_PTR_E,R16		; Сохраняем смещение. Выходим
			RET

;==========================================================
;	BUFFER POP FUNCTION
;==========================================================

; Read from loop Buffer
; IN: NONE
; OUT: 	R17 - Data,
;		R19 - ERROR CODE

BUFF_POP: 	LDI		XL,low(IN_BUFF)		; Берем адрес начала буффера
			LDI		XH,high(IN_BUFF)
			LDS		R16,IN_PTR_E		; Берем смещение точки записи
			LDS		R18,IN_PTR_S		; Берем смещение точки чтения			
			LDS		R19,IN_FULL			; Берм флаг переполнения

			CPI		R19,1				; Если буффер переполнен, то указатель начала
			BREQ	NeedPop				; Равен указателю конца. Это надо учесть.

			CP		R18,R16				; Указатель чтения достиг указателя записи?
			BRNE	NeedPop				; Нет! Буффер не пуст. Работаем дальше

			LDI		R19,1				; Код ошибки - пустой буффер!
												
			RJMP	_TX_OUT				; Выходим

NeedPop:	CLR		R17					; Получаем ноль
			STS		IN_FULL,R17			; Сбрасываем флаг переполнения

			ADD		XL,R18				; Сложением адреса со смещением
			ADC		XH,R17				; получаем адрес точки чтения

			LD		R17,X				; Берем байт из буффера
			CLR		R19					; Сброс кода ошибки

			INC		R18					; Увеличиваем смещение указателя чтения

			CPI		R18,MAXBUFF_OUT		; Достигли конца кольца?
			BRNE	_TX_OUT				; Нет? 
			
			CLR		R18					; Да? Сбрасываем, переставляя на 0

_TX_OUT:	STS		IN_PTR_S,R18		; Сохраняем указатель
			RET

;==========================================================
;	RUN
;==========================================================

RESET:   	STACKINIT			
			RAMFLUSH			

			ldi   R16,low(RAMEND)    
			out   SPL,R16            
			ldi   R17,high(RAMEND)   
			out   SPH,R17            

			CLI

;==========================================================
;	VARIABLE INIT
;==========================================================

;==========================================================
;	USART0 INIT
;==========================================================

			.equ 	XTAL = 8000000 	
			.equ 	baudrate = 9600  
			.equ 	bauddivider = XTAL/(16*baudrate)-1

			LDI 	R16, low(bauddivider)
			OUT 	UBRRL, R16
			LDI 	R16, high(bauddivider)
			OUT 	UBRRH, R16

			LDI 	R16, 0x00
			OUT 	UCSRA, R16

			LDI 	R16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(1<<TXCIE)|(0<<UDRIE)
			OUT 	UCSRB, R16

			LDI 	R16, (1<<URSEL)|(1<<UCSZ0)|(1<<UCSZ1)
			OUT 	UCSRC, R16

;==========================================================
;	BUFFER USART INIT
;==========================================================

			CLR		R16

			STS		IN_PTR_S,R16				
			STS		IN_PTR_E,R16
			STS		OUT_PTR_S,R16
			STS		OUT_PTR_E,R16

;==========================================================
;	I2C INIT
;==========================================================

			LDI		R16, 0x80
			OUT		TWBR, R16

			//0b01000101
			LDI		R16, 0x45
			OUT		TWCR, R16

			//0b00000001
			.equ	PRESC = 0x01

			LDI		R16, PRESC
			OUT		TWSR, R16

;==========================================================
;	TIMER0 INIT
;==========================================================

			CLR		R16
			OUT		TCCR0, R16
			LDI		R16, (1 << TOV0)
			OUT		TIMSK, R16

;==========================================================
;	MAIN LOOP
;==========================================================

			SEI

LOOP:		NOP
			NOP
			
			
	LDS		R16, DELAY_FL
LOOP_DL:	LDI		R19, 5
			CPI		R19, 0x01
			BREQ	LOOP_DL

			RJMP	LOOP


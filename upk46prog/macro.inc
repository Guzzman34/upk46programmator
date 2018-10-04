;= Start 	macro.inc ========================================
   .macro    OUTI           ; Это описание макроса. Везде где outi встретится в коде, то заменяется на
      ldi    R16,@1
   .if @0 < 0x40
      out    @0,R16         ; макроса. Данный макрос тупо копирует введенное число сначала в регистр R16, а из него
   .else
      sts      @0,R16
   .endif
   .endm

   	.macro    OUTU        
   	.if	@0 < 0x40
      	out	@0,@1         
	.else
      	sts	@0,@1
   	.endif
   	.endm

;.............................................................
;SET BIT with stack
	.MACRO	SETBM 
		.if @0 < 0x20
		SBI		@0,@1
		.else
			.if	@0<0x40
		PUSH	R17
		IN		R17,@1
		ORI		R17,1<<@1
		OUT		@0,R17
		POP		R17
			.else
		PUSH	R17
		LDS		R17,@1
		ORI		R17,1<<@1
		STS		@0,R17
		POP		R17
			.endif
		.endif
	.ENDM

;SET BIT with REG
	.MACRO	SETB
		.if @0 < 0x20		; Low IO
		SBI		@0,@1
		.else
			.if	@0<0x40		; High IO
		IN		@2,@0
		ORI		@2,1<<@1
		OUT		@0,@2
			.else			; Memory
		LDS		@2,@0
		ORI		@2,1<<@1
		STS		@0,@2
			.endif
		.endif
	.ENDM
;.............................................................
;Clear BIT with REG
	.MACRO	CLRB
		.if @0 < 0x20		; Low IO
		CBI		@0,@1
		.else
			.if	@0<0x40		; High IO
		IN		@2,@0
		ANDI	@2,~(1<<@1)
		OUT		@0,@2
			.else			; Memory
		LDS		@2,@0
		ANDI	@2,~(1<<@1)
		STS		@0,@2
			.endif
		.endif
	.ENDM

;Clear BIT with STACK
	.MACRO	CLRBM 
		.if @0 < 0x20
		CBI		@0,@1
		.else
			.if	@0<0x40
		PUSH	R17
		IN		R17,@1
		ANDI	R17,~(1<<@1)
		OUT		@0,R17
		POP		R17
			.else
		PUSH	R17
		LDS		R17,@1
		ANDI	R17,~(1<<@1)
		STS		@0,R17
		POP		R17
			.endif
		.endif
	.ENDM
;.............................................................

	.MACRO	INVB
	.if	@0 < 0x40
	IN		@2,@0
	LDI		@3,1<<@1
	EOR		@3,@2
	OUT		@0,@3
	.else
	LDS		@2,@0
	LDI		@3,1<<@1
	EOR		@2,@3
	STS		@0,@2
	.endif
	.ENDM

	.MACRO	INVBM
	.if	@0 < 0x40
	PUSH	R16
	PUSH	R17
	IN		R16,@0
	LDI		R17,1<<@1
	EOR		R17,R16
	OUT		@0,R17
	POP		R17
	POP		R16
	.else
	PUSH	R16
	PUSH	R17
	LDS		R16,@0
	LDI		R17,1<<@1
	EOR		R17,R16
	STS		@0,R17
	POP		R17
	POP		R16
	.endif
	.ENDM

;...............................................................
	.MACRO	INCM
	LDS	R16,@0
	LDS	R17,@0+1
	LDS	R18,@0+2
	LDS	R19,@0+3

	SUBI	R16,(-1)
	SBCI	R17,(-1)
	SBCI	R18,(-1)
	SBCI	R19,(-1)

	STS	@0,R16
	STS	@0+1,R17
	STS	@0+2,R18
	STS	@0+3,R19
	.ENDM
;.............................................................
	.MACRO PUSHF
	PUSH	R16
	IN	R16,SREG
	PUSH	R16
	.ENDM


	.MACRO POPF
	POP	R16
	OUT	SREG,R16
	POP	R16
	.ENDM

;= End 		macro.inc ========================================

	.MACRO RAMFLUSH
RAM_Flush:	LDI		ZL,Low(SRAM_START)	; Адрес начала ОЗУ в индекс
			LDI		ZH,High(SRAM_START)
			CLR		R16
										; Очищаем R16
Flush:		ST 		Z+,R16				; Сохраняем 0 в ячейку памяти
			CPI		ZH,High(RAMEND+1)	; Достигли конца оперативки?
			BRNE	Flush				; Нет? Крутимся дальше!
 
			CPI		ZL,Low(RAMEND+1)	; А младший байт достиг конца?
			BRNE	Flush
 
			LDI	ZL, 30		; +-----------------------	+
			CLR	ZH			; |			  				|
			DEC	ZL			; | Очистка РОН (R00-R31) 	|
			ST	Z, ZH		; |	[10 байт кода]	  		|
			BRNE	PC-2	; +-----------------------	+
	.ENDM

	.MACRO 	STACKINIT
   			LDI 	R16,Low(RAMEND)	; Инициализация стека
		    OUT 	SPL,R16			; Обязательно!!!

		 	LDI 	R16,High(RAMEND)
		 	OUT 	SPH,R16
	.ENDM


	.MACRO	CLRTCNT
			CLR		R16				; Нам нужен ноль
			OUT		TCNT0,R16		; Ноль в счетный регистр таймера
			STS		TCNT,R16		; Ноль в первый байт счетчика в RAM
			STS		TCNT+1,R16		; Ноль в второй байт счетчика в RAM
			STS		TCNT+2,R16		; Ноль в третий байт счетчика в RAM
			STS		TCNT+3,R16		; Ноль в первый байт счетчика в RAM
	.ENDM



	.MACRO	DEB_CMD
			PUSH	R16		; Сохраняем регистр и флаги в стек
			IN		R16,SREG
			PUSH	R16

			SBIS	UCSRA,RXC
			RJMP	PC-1
			IN		R16,UDR	; Читаем UDR, чтобы сбросить RXC флаг

						; Определяем что там пришло
			CPI		R16,'R'
			BREQ	PC+0x07	; BREQ REGISTER

			CPI		R16,'M'
			BREQ	PC+0x07	; BREQ	MEMORY

			CPI		R16,'I'
			BREQ	PC+0x09 	; BREQ	IO

			CPI		R16,'G'
			BREQ	PC+0x0A	; BREQ GONEXT


			OUT		UDR,@0		;REGISTER
			RJMP	PC+0x0008

			LDS		R16,@1		;MEMORY
			OUT		UDR,R16
			RJMP	PC+0x0004

			IN		R16,@2		;IO
			OUT		UDR,R16

			POP		R16		;GONEXT - достаем все сохраненное из стека и идем дальше
			OUT		SREG,R16
			POP		R16
	.ENDM

	.MACRO	BUFF_SEND 
			LDI		R19,@0
			RCALL	Buff_Push
	.ENDM

	.MACRO	TX_RUN
			LDI 	R16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(1<<TXCIE)|(1<<UDRIE)
			OUT 	UCSRB, R16	
	.ENDM

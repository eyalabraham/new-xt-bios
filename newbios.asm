;********************************************************************
; newbios.asm
;
;  BIOS rewrite for PC/XT
;
;  BIOS replacement for PC/XT clone
;  Hardware includes USART to replace CRT and keyboard
;  Initial systems with no display card, not parallel port, no RS232
;  IDE-8255 HDD interface, no display adapter
;  BIOS with required POST and services to boot MS-DOS, MINIX, ELKS
;  With no boot code, BIOS will provide basic monitor functions.
;
; resources:
;	general resource: http://stanislavs.org/helppc/
;   INT 13 info     : http://stanislavs.org/helppc/int_13.html
;	Peter Norton    : http://www.ousob.com/ng/peter_norton/index.php
;					: http://www.ousob.com/ng/peter_norton/ng76349.php
;
;********************************************************************
;
; change log
;------------
; created       02/02/2013              file structure and Makefile
;
CPU 8086
;
;======================================
; includes
;======================================
;
%include        "memdef.asm"                			; memory segment and data structures
%include        "iodef.asm"                 			; io port definitions
;
;======================================
; BIOS code
;======================================
;
segment         .text       start=0         			; start at top of EEPROM
;
COLD:           mov         ax,BIOSDATASEG  			; entered by POWER_ON/RESET or forced cold restart
                mov         ds,ax
                mov         word [ds:bdBOOTFLAG],0  	; show data areas not initialized to foce memory check

WARM:           cli										; clear interrupt flag -> disabled
				mov			al,NMIDIS
				out			NMIMASK,al					; mask NMI
;
;-----	begin FLAG and register test of CPU
;
                xor         ax,ax						; flag test
                jb          HALT
                jo          HALT
                js          HALT
                jnz         HALT
                jpo         HALT
                add         ax,1
                jz          HALT
                jpe         HALT
                sub         ax,8002h
                js          HALT
                inc         ax
                jno         HALT
                shl         ax,1
                jnb         HALT
                jnz         HALT
                shl         ax,1
                jb          HALT
                mov         bx,0101010101010101b  		; register test
CPUTST:         mov         bp,bx
                mov         cx,bp
                mov         sp,cx
                mov         dx,sp
                mov         ss,dx
                mov         si,ss
                mov         es,si
                mov         di,es
                mov         ds,di
                mov         ax,ds
                cmp         ax,0101010101010101b
                jnz         CPU1
                not         ax
                mov         bx,ax
                jmp         CPUTST
CPU1:           xor         ax,1010101010101010b
                jz          CPU_OK
;
HALT:           mcr7SEG		SEGH						; display 'H'
				hlt
;
CPU_OK:         cld
;
;-----	setup defaults for segment registers
;
				mov			ax,ROMSEG
				mov			ss,ax						; SS - this will also allow fake return from 'call's
				mov			ax,BIOSDATASEG
				mov			ds,ax						; DS initialized to BIOS data structure
				xor			ax,ax
				mov			es,ax						; ES to zero
;
;--------------------------------------
; peripheral setup
;--------------------------------------
;
;	********************
;	***   8255 PPI   ***
;	********************
;
;-----	setup PPI to read DIP swithes and to drive 7447 7-seg instead of keyboard
;
				mov			al,PPIINIT
				out			PPICTRL,al					; setup 8255 PPI
				mov			al,PPIPAINIT
				out			PPIPA,al					; zero and blank 7-segment
				mov			al,PPIPBINIT
				out			PPIPB,al					; initialize speaker, RAM parity check, config switches
;
;-----	CHECK POINT 0
;
				mcr7SEG		0							; display '0' on 7-seg
;
;	********************
;	***    UART      ***
;	********************
;
;-----	initialize URAT, 82C50 or 16550 with FIFO disabled
;
				mov			dx,IER
				mov			al,INTRINIT
				out			dx,al						; Rx enabled all other interrupts disabled
;
				inc			dx
				inc			dx							; point to LCR
				mov			al,LCRINIT
				out			dx,al						; 8-bit, 1 stop bit, no parity
;
				inc			dx							; point to MCR
				mov			al,MCRINIT
				out			dx,al						; all mode controls disabled
;
				dec			dx							; point to LCR
				mov			al,LCRINIT
				or			al,DLABSET
				out			dx,al						; enable access to BAUD rate divisor reg.
				mov			ah,al
				mov			cx,dx
;
				mov			dx,BAUDGENLO				; setup BAUD rate divisor
				mov			al,BAUDDIVLO
				out			dx,al						; low 8 bit divisor
				inc			dx
				mov			al,BAUDDIVHI
				out			dx,al						; high 8 bit divisor
;
				mov			al,ah
				mov			dx,cx
				and			al,DLABCLR
				out			dx,al						; disable access to BAUD rate divisor
;
;-----	CHECK POINT 'A'
;
				mcr7SEG		10							; intermediate check point before UART loopback test
;
;-----	UART loopback test
;
				mov			dx,MCR
				in			al,dx
				or			al,MCRLOOP
				out			dx,al						; set UART to loop-back test mode
;
				mov			cl,0ffh						; transmit 0ffh through 00h
TESTLOOP:		mov			al,cl						; test byte to transmit
				mov			sp,(UARTTESTRET+ROMOFF)		; fake stack for return
				jmp			TXBYTE						; transmit test byte
;
WAITBYTE:		mov			dx,LSR
				in			al,dx						; read LSR
				and			al,00000001b				; check if a byte was received
				jz			WAITBYTE					; wait until byte is received
;
				mov			dx,RBR
				in			al,dx						; read byte from receiver register
				cmp			cl,al						; compare received byte to transmitted byte
				jne			HALT						; fail if they are not equal
				dec			cl
				jnz			TESTLOOP					; loop to next test byte
;
				mov			dx,MCR
				in			al,dx
				and			al,11101111b
				out			dx,al						; set UART back to notmal Rx/Tx mode
;
;-----	print banner, build date and time
;
				mov			ax,cs
				mov			ds,ax						; establish DS for string source
				mov			si,(BANNER+ROMOFF)			; get banner string offset
PRINTBANNER:	lodsb									; get character
				cmp			al,0						; is it '0' ('0' is end of string)?
				je			DONEBANNER
				mov			sp,(BANNERPRRET+ROMOFF) 	; fake stack for return
				jmp			TXBYTE						; transmit character
;
;-----	CHECK POINT 1
;
DONEBANNER:		mcr7SEG		1							; display '1' on 7-seg
				mov			si,(CHECKPOINT1+ROMOFF)		; get string offset
PRINTCP1:		lodsb									; get character
				cmp			al,0						; is it '0' ('0' is end of string)?
				je			TIMERSETUP
				mov			sp,(CP1PRRET+ROMOFF)		; fake stack for return
				jmp			TXBYTE						; transmit character
;
;	********************
;	***  8253 TIMER  ***
;	********************
;
;-----	disable DMA controller
;
TIMERSETUP:		mov			al,DMACMDINIT
				out			DMACMD,al					; make sure DMA is disabled
;
;-----	initialize timer-0
;
				mov			al,TIMER0INIT
				out			TIMERCTRL,al				; initilize timer-0, LSB/MSB, mode 3
				mov			al,0
				out			TIMER0,al					; set count to 0ffffh
				nop
				nop
				out			TIMER0,al					; for 18.2 ticks/sec @@- check this!
;
;-----	initialize and test timer-1
;
				mov			al,TIMER1INIT
				out			TIMERCTRL,al				; initialize timer-1, LSB, Mode 2
;
TESTTIMER:		mov			al,0
				out			TIMER1,al					; initial count to 0
;
				mov			bl,0
				mov			cx,0
BITSON:			mov			al,01000000b
				out			TIMERCTRL,al				; latch timer-1 count
				cmp			bl,0ffh						; timer LSB bits all '1'?
				je			CHECKBITSOFF
				in			al,TIMER1					; read timer-1 count
				or			bl,al
				loop		BITSON						; keep looping to poll timer count
				jmp			TIMERFAIL					; timer count never reached all '1', it is probably stuck
;
CHECKBITSOFF:	mov			cx,0
				mov			al,0ffh
				out			TIMER1,al					; set initial count to 'ff'
BITSOFF:		mov			al,01000000b
				out			TIMERCTRL,al				; latch timer-1 count
				nop
				nop
				in			al,TIMER1					; read timer-1 count
				and			bl,al
				jz			TIMERGOOD
				loop		BITSOFF						; keep looping to poll timer count
				jmp			TIMERFAIL					; timer count never reached all '0', it is probably stuck
;
TIMERGOOD:		mov			si,(TIMEROK+ROMOFF)			; get string offset
PRINTTIMEROK:	lodsb									; get character
				cmp			al,0						; is it '0' ('0' is end of string)?
				je			CP2
				mov			sp,(TIMEROKPRRET+ROMOFF)	; fake stack for return
				jmp			TXBYTE						; transmit character
;
;-----	CHECK POINT 2
;
CP2:			mcr7SEG		2							; display '2' on 7-seg
				mov			si,(CHECKPOINT2+ROMOFF)		; get string offset
PRINTCP2:		lodsb									; get character
				cmp			al,0						; is it '0' ('0' is end of string)?
				je			TESTDMA
				mov			sp,(CP2PRRET+ROMOFF)		; fake stack for return
				jmp			TXBYTE						; transmit character
;
;-----	print timer failure status and halt
;
TIMERFAIL:		mov			si,(TIMERERR+ROMOFF)		; get string offset
PRINTTIMERERR:	lodsb									; get character
				cmp			al,0						; is it '0' ('0' is end of string)?
				je			HALT
				mov			sp,(TIMERERRPRRET+ROMOFF)	; fake stack for return
				jmp			TXBYTE						; transmit character
;
;	***************************
;	*** 8237 DMA CONTROLLER ***
;	***************************
;
; @@-	IBM BIOS listing page 5-86, 234 / line 278
;
;-----	test DMA channels
;
TESTDMA:		out			DMAMCLR,al					; initiate master clear to DMA controller
				mov			al,0ffh						; test pattern
NEXTDMAPATT:	mov			bl,al
				mov			bh,al
				mov			cx,8						; cycle through 8 registers
				mov			dx,CBAR0					; point to first register
DMAWRPATT:		out			DMACLRFF,al					; clear LSB/MSB FF
				out			dx,al						; write pattern to LSB
				push		ax							; does nothing, only for timing
				out			dx,al						; write pattern to MSB
				mov			al,01h						; change pattern before comparing
				out			DMACLRFF,al					; clear LSB/MSB FF
				in			al,dx						; read LSB
				mov			ah,al
				in			al,dx						; read MSB
				cmp			bx,ax						; compare written to read pattern
				je			NEXTDMAREG					; ok, so next register
				jmp			DMAFAIL
NEXTDMAREG:		inc			dx							; point to next channel register
				loop		DMAWRPATT					; loop to test next channel register
				inc			al							; if all ok so far, this will set test pattern to '0'
				jz			NEXTDMAPATT
				jmp			SETREFRESH					; all DMA controller address and counts are '0' here
;
;-----	print DMA failure status and halt
;
DMAFAIL:		mov			si,(DMAERR+ROMOFF)			; get string offset
PRINTDMAERR:	lodsb									; get character
				cmp			al,0						; is it '0' ('0' is end of string)?
				je			HALT
				mov			sp,(DMAERRPRRET+ROMOFF) 	; fake stack for return
				jmp			TXBYTE						; transmit character
;
;-----	begin DMA setup for DRAM refresh
;
SETREFRESH:		mov			al,0
				out			DMAPAGE1,al					; clear DMA page registers
				out			DMAPAGE2,al
				out			DMAPAGE3,al
;
;-----	configure DMA channel-0 for memory refresh
;
				out			DMACLRFF,al					; clear LSB/MSB FF
				mov			al,0ffh						; refresh byte count of 64K
				out			CBWC0,al					; write LSB
				push		ax							; delay
				out			CBWC0,al					; write MSB
				mov			al,DMACH0MODE				; set channel-0 for read and auto init
				out			DMAMODE,al
				mov			al,0
				out			DMACMD,al					; enable DMA controller
				out			DMAMASK,al					; unmask channel-0
;
;-----	start refresh timer-1 at refresh rate
;
; @@-	signal once every 72 cycles, or once every 15.08µs
; @@-	http://www.phatcode.net/res/224/files/html/ch04/04-06.html
; @@-	http://books.google.com/books?id=C3JBC7yUJ8IC&pg=PA488&lpg=PA488&dq=8237+dram+refresh&source=bl&ots=EUTzgByna7&sig=Mzqm08V5Wnqd6Y0J9yzqCLNW-PI&hl=en&sa=X&ei=IAzPUZexM8br0gHt0YGwDQ&ved=0CEkQ6AEwBA#v=onepage&q=8237%20dram%20refresh&f=true
;
				mov			al,12h						; DMA refresh every 12h (18) clock cycles about 15.3uSec
				out			TIMER1,al					; start timer
;
;-----	setup other DMA channels
;
				mov			al,DMACH1MODE				; setup channel-1 block verify
				out			DMAMODE,al
;
; @@- IBM BIOS has a check for ch-1 (pg. 5-86 / 234 line 330)
				mov			al,DMACH2MODE				; setup channel-2 block verify
				out			DMAMODE,al
				mov			al,DMACH3MODE				; setup channel-3 block verify
				out			DMAMODE,al
;
				mov			si,(DMAOK+ROMOFF)			; get string offset
PRINTDMAOK:		lodsb									; get character
				cmp			al,0						; is it '0' ('0' is end of string)?
				je			CP3
				mov			sp,(DMAOKPRRET+ROMOFF)		; fake stack for return
				jmp			TXBYTE						; transmit character
;
;-----	CHECK POINT 3
;
CP3:			mcr7SEG		3							; display '3' on 7-seg
				mov			si,(CHECKPOINT3+ROMOFF)		; get string offset
PRINTCP3:		lodsb									; get character
				cmp			al,0						; is it '0' ('0' is end of string)?
				je			MEMORYTEST
				mov			sp,(CP3PRRET+ROMOFF)		; fake stack for return
				jmp			TXBYTE						; transmit character
;
;	*********************************
;	***    RAM test and init      ***
;	*********************************
;
;-----	determine momory size
;
MEMORYTEST:		mov			ax,BIOSDATASEG				; point to BIOS data
				mov			ds,ax
;
				mov			si,[ds:bdBOOTFLAG]			; save BIOS boot flag, just in case this is a warm boot
				xor			ax,ax
				mov			bp,ax
				mov			bx,ax
;
MEMSIZE:		mov			dx,55aah					; set a data pattern
				cld										; set to auto increment
				xor			di,di						; start at address 0000:0000
				mov			es,bx
				mov			[es:di],dx					; write pattern
				cmp			dx,[es:di]					; read and compare
				jnz			MEMEND						; if compare failed then memory end
				mov			cx,2000h
				repz		stosw						; zero out 16KB ( ax -> [es:di] )
				add			bh,4						; get next 16KB
				cmp			bh,(MAX_MEMORY / 4)			; found max legal user ram?
				jnz			MEMSIZE						; check more
;
MEMEND:			mov			dx,bx						; BX has memory size, save it (for 640KB BX='A000'h)
				xor			ax,ax
				mov			es,ax
				mov			sp,(MEMTESTRET1+ROMOFF)		; SP points to fake stack for return from MEMTST
				jmp			MEMTST						; memory check ES:0000 to ES:0400 first 1K
MEM1KCHECK:		jc			MEMFAIL						; print memory failure
				mov			sp,(MEMTESTRET2+ROMOFF)		; SP points to fake stack for return from MEMTST
				jmp			MEMTST						; memory check ES:0400 to ES:0800 second 1K
MEM2KCHECK:		jnc			MEM2KOK						; MEMTST 'ret' here. check if no error in first 1KB
;
;-----	print memory failure status
;
MEMFAIL:		mov			si,(MEMTEST2KERR+ROMOFF)	; get string offset
				mov			ax,ROMSEG
				mov			ds,ax						; set string segment
PRINTMEM2KERR:	lodsb									; get character
				cmp			al,0						; is it '0' ('0' is end of string)?
				je			HALT						; first 2KB has bad memory, halt
				mov			sp,(MEM2KERRPRRET+ROMOFF)	; fake stack for return
				jmp			TXBYTE						; transmit character
;
;-----	save memory size and setup stack
;
MEM2KOK:		mov			ax,BIOSDATASEG				; point to BIOS data
				mov			ds,ax
				mov			cl,6
				mov			ax,dx
				shr			ax,cl						; adjust memory size value to be in KB
				mov			[ds:bdMEMSIZE],ax			; store in BIOS data area
				mov			byte [ds:bdIPLERR],0		; clear IPL error flags
				mov			[ds:bdBOOTFLAG],si			; restor BIOS boot flag
;
				mov			ax,STACKSEG					; set up IBM-compatible stack
				mov			ss,ax						; segment 0030h
				mov			sp,STACKTOP					; offset  0100h
;
				mcrPRINT	MEMTEST2KOK					; print 2K memory good message
;
;-----	CHECK POINT 4
;
				mcr7SEG		4							; display '4' on 7-seg
				mcrPRINT	CHECKPOINT4
;
;	*********************************
;	*** 8259 INTERRUPT CONTROLLER ***
;	*********************************
;
;-----	setup interrupt device
;
; @@-	page 235/5-87 line 409 IBM BIOS listing
;
				mov			al,INIT1					; setup ICW1 w/ ICW4, single 8259, endge triggered interrupt
				out			ICW1,al
				mov			al,INIT2					; setup ICW1 a8..a15 of vector address
				out			ICW2,al
				mov			al,INIT4					; setup ICW4 buffered 8086 mode
				out			ICW4,al
				mov			al,11111111b				; mask all interrupts
				out			IMR,al
				mov			byte [ds:bdINRTFLAG],0		; clear interrupt flags
;
;-----	setup interrupt vectors in RAM and copy vectors from ROM
;
				push		ds
				xor			ax,ax
				mov			es,ax						; establish destination in ES of RAM vector segment
				xor			di,di						; RAM destination vector table offset [ES:DI]
				mov			ax,cs
				mov			ds,ax						; establish source in DS of ROM vector table segment
				mov			si,(VECTORS+ROMOFF)			; ROM source offset of vector table [DS:SI]
				cld										; SI and DI will increment
				mov			cx,32						; handle all 32 vectors
VECCOPY:		movsw									; copy the vector offser component
				mov			ax,cs
				stosw									; add segment address
				loop		VECCOPY						; loop to copy all vectors
				pop			ds
;
;-----	clear special vector
;
				xor			ax,ax
				mov			es,ax
				mov			word [es:7Ch],0				; there are no special graphics chars in the system
				mov			word [es:7Eh],0				; so zero vector 1Fh
;
				mcrPRINT	INTVECOK					; print interrupts set message
;
;-----	CHECK POINT 5
;
				mcr7SEG		5							; display '5' on 7-seg
				mcrPRINT	CHECKPOINT5
;
;	*********************************
;	***   SYSTEM CONFIGURATION    ***
;	*********************************
;
;-----	read configuration switches and store settings
;
				in			al,PPIPC					; read configuration switches 1..4
				and			al,00001111b				; isolate switch bits
				mov			ah,al
				mov			al,PPIPBINIT
				or			al,00001000b				; enable other back of switches
				out			PPIPB,al
				nop
				in			al,PPIPC					; read switches 5..8
				mov			cl,4
				rol			al,cl						; shift switch bit to high nibble
				and			al,11110000b				; isolate switch bits
				or			al,ah						; merge switch bits
				sub			ah,ah
				mov			[ds:bdEQUIPMENT],ax			; save equipment flags
;
;-----	print configuration bits
;
				mcrPRINT	SYSCONFIG					; print system configuration message
				call		PRINTHEXW					; print config word as HEX
				mcrPRINT	CRLF						; print new line
;
; @@- (not implemented) scan for paralle ports, com ports, game ports etc. and store configuration
;
;-----	RAM test and capacity counter
;
RAMTEST:		mov			ax,[ds:bdBOOTFLAG]			; is this a warm restart?
				cmp			ax,1234h
				je			RAMTESTPASS					; skip memory test if this is a warm start
;
				mov			bx,[ds:bdMEMSIZE]			; get memory size
				sub			bx,2						; first 2KB already tested
				mov			cx,bx						; count of 1KB blocks to test
				mov			bx,0080h
				mov			es,bx						; RAM test start above first 2KB [0080:0000 equiv. 0000:0800]
				mov			bx,2						; counter for tested 1KB blocks
MEMTESTLOOP:	push		di
				push		cx							; save work registers
				push		bx
				push		ax
				call		MEMTST						; test memory, will also advance ES
				jc			RAMTESTFAIL					; if memory test failed, then abort
				pop			ax
				pop			bx
				pop			cx
				pop			di
				inc			bx							; next 1K
;
				mcrPRINT	RAMTESTMSG					; print RAM test in progress
				mov			ax,bx						; get tested KB number
				call		PRINTDEC					; print KB number
				mcrPRINT	KBMSG						; print "KB"
;
				loop		MEMTESTLOOP					; loop through count of 1KB blocks
;
				mcrPRINT	CRLF						; print new line
				jmp			RAMTESTPASS
;
RAMTESTFAIL:	mcrPRINT	RAMTESTERR					; print memory failure message
				jmp			HALT
;
;-----	setup UART receiver buffer in the keyboard buffer
;
RAMTESTPASS:	mov			ax,bdKEYBUF					; buffer start offset in BIOS data structure
				mov			[ds:bdKEYBUFHEAD],ax		; store as buffer head pointer
				mov			[ds:bdKEYBUFTAIL],ax		; buffer tail pointer is same as head (empty)
				mov			[ds:bdKEYBUFSTART],ax		; buffer start address
				add			ax,32
				mov			[ds:bdKEYBUFEND],ax			; buffer end address
;
;-----	initialize time of day
;
				xor			ax,ax
				mov			[ds:bdTIMELOW],ax
				mov			[ds:bdTIMEHI],ax
				mov			[ds:bdNEWDAY],al
;
;-----	enable timer=0 and UART interrupts
;
				in			al,IMR						; read IMR
				and			al,11111010b				; unmask/enable timer-0 (IRQ0) and UART (IRQ2) interrupt
				out			IMR,al
				sti										; enable processor interrupts
;
;-----	enable parity checking and NMI (IBM BIOS does this just before IPL pg.5-94/242 line 1158)
;
				mov			dx,PPIPB
				in			al,dx						; get current state
				or			al,00010000b				; disable parity checking and reset if any errors exist
				out			dx,al
				and			al,11101111b				; re-enable parity checking
				out			dx,al
				mov			al,NMIENA					; enable NMI
				out			NMIMASK,al
;
				mcrPRINT	INTENAMSG					; print interrupt enabled message
;
;-----	indicate cold start complete
;
				mov			word [ds:bdBOOTFLAG],1234h	; restart complete
;
;-----	CHECK POINT 6
;
				mcr7SEG		6							; display '6' on 7-seg
				mcrPRINT	CHECKPOINT6
;
;	*********************************
;	***      IDE DRIVE SETUP      ***
;	*********************************
;
;-----	configure IDE PPI
;
IDESETUP:		mcrPRINT	IDEINITMSG					; print IDE initializing message
;
				mov			dx,IDEPPI					; PPI control register
				mov			al,IDEPPIINIT				; PPI initialization PC=out, PA and PB=in
				out			dx,al						; set up 8255 PPI
				dec			dx							; point to IDE control register (IDE PPI PC)
				mov			al,IDEINIT					; initialize IDE control lines
				out			dx,al
;
;-----	initialize and test IDE drive
;
				mov			cx,2						; 2 retries on drive reset if not ready after power-on
IDESETUP01:		mov			ax,IDETOV					; time-out for ready check (~1sec = 55 x 18.2mSec)
				call		IDEREADY					; wait for drive to go ready
				jnc			IDESETUP02					; drive is ready so continue
				call		IDERESET					; drive not ready after power-on, try a hard reset
				mcrPRINT	IDERSTMSG					; notify print resent to drive
				loop		IDESETUP01
				mcrPRINT	IDENOTRDY					; print "not ready" error message
				jmp			IDEFAIL						; IDE failure, drive never got out of busy state after power-on
IDESETUP02:		mov			ah,IDEDEVCTLINIT			; IDE device control initialization disable intr req. from drive
				mov			al,IDEDEVCTL
				call		IDEREGWR					; write to device control register
;
				mcrPRINT	OKMSG						; print "Ok" message
;
;-----	** not using interrupts for IDE IO, only polling **
;		** if using IRQ5 for IDE then enable IDE interrupts here **
;
;
;-----	IDE identification using IDE IDENTITY command
;
				mcrPRINT	IDEIDENTITYMSG				; print identity section title
				mov			ax,BIOSDATASEG
				mov			ds,ax						; establish BIOS data segment
				xor			ax,ax
				mov			si,ax
				mov			cx,6
CLRCMDBLOCK:	mov			[ds:si+bdIDECMDBLOCK],al	; setup IDE command block
				inc			si
				loop		CLRCMDBLOCK					; loop to clear comand block
				mov			al,IDEIDENTIFY				; "identify" command
				mov			[ds:si+bdIDECMDBLOCK],al	; store in command block
				call		IDESENDCMD					; send command block to drive
				jc			IDEFAIL						; command could not be sent to drive
				mov			bx,STAGESEG					; setup destination buffer for command output
				mov			es,bx						;  establish pointer segment
				mov			bx,STAGEOFF					;  establish pointer offset
				mov			ax,1						; read 1 block of 512 bytes
				call		IDEREAD						; read command output
				jc			IDEFAIL						; output could not be read
				mcrPRINT	OKMSG						; print ok
;
;-----	print "identify" command output
;
				mov			ax,STAGESEG
				mov			es,ax
				mov			si,STAGEOFF
				mcrPRINT	CYLMSG						; print cylinder count
				mov			ax,[es:si+iiCYL]
				call		PRINTDEC
				mcrPRINT	CRLF
				mcrPRINT	HEADSMSG					; print head count
				mov			ax,[es:si+iiHEADS]
				call		PRINTDEC
				mcrPRINT	CRLF
				mcrPRINT	SECMSG						; print sector per track
				mov			ax,[es:si+iiSEC]
				call		PRINTDEC
				mcrPRINT	CRLF
;
				mcrPRINT	SERIALMSG					; print serial number string
				mov			cx,10
				xor			bx,bx
PRNTIDESERIAL:	mov			dx,[es:si+iiSERIANNUM+bx]
				mov			al,dh
				call		PRINTCHAR
				mov			al,dl
				call		PRINTCHAR
				add			bx,2
				loop		PRNTIDESERIAL
				mov			al,(']')
				call		PRINTCHAR
				mcrPRINT	CRLF
;
				mcrPRINT	MODELMSG					; print model number string
				mov			cx,20
				xor			bx,bx
PRNTIDEMODEL:	mov			dx,[es:si+iiMODEL+bx]
				mov			al,dh
				call		PRINTCHAR
				mov			al,dl
				call		PRINTCHAR
				add			bx,2
				loop		PRNTIDEMODEL
				mov			al,(']')
				call		PRINTCHAR
				mcrPRINT	CRLF
;
;-----	read drive parameter table(s) and print emulated drive list
;
				nop
;
;-----	CHECK POINT 7
;
				mcr7SEG		7							; display '7' on 7-seg
				mcrPRINT	CHECKPOINT7
;
;-----	check DIP switch setting and start monitor or try IPL
;
				mov			al,[ds:bdEQUIPMENT]			; get DIP switches
				test		al,00000001b				; is 'ROM Monitor' switch on?
				jnz			MONITOR						; yes, go directly to monitor mode
				jmp			IPLBOOT						; no, boot the OS
;
;-----	IDE drive failed initialization
;
IDEFAIL:		mcrPRINT	FAILMSG						; print "fail" message
				jmp			MONITOR						; without a drive jump to monitor mode
;
;	*********************************
;	***    BOOT OS FROM DRIVE 	  ***
;	*********************************
;
;-----	boot from HDD (IPL) or go into ROM monitor mode
;
IPLBOOT:		mov			cx,1502						; boot beep frequency 1KHz
				mov			bl,16						; boot beep 0.25 sec
				call		BEEP						; sound beep
				mcrPRINT	BOOTINGMSG					; print boot notification
;
;-----	CHECK POINT 8 and IPL
;
				mcr7SEG		8							; display '8' on 7-seg
				mcrPRINT	CHECKPOINT8
;
;-----	boot from disk
;
				mov			dl,0						; boot from floppy A:
				int			19h							; execute boot attempt
;
;	*********************************
;	***        MONITOR MODE       ***
;	*********************************
;
%include        "mon88.asm"
;
;	*********************************
;	***    INTERRUPT SERVICES     ***
;	*********************************
;
;-----------------------------------------------;
; this is a temporatry interrupt service		;
; routine.										;
; it will service unused interrupt vectors.		;
; location 'dbINRTFLAG' will contain either the	;
; level of HW interrupt or 'FF' for a SW		;
; interrupt that was requested					;
;												;
; entry:										;
;	NA											;
; exit:											;
;	'bdINRTFLAG' set with flag					;
;	all registers preserved						;
;-----------------------------------------------;
;
IGNORE:			push		ds							; unexpected/unused interrupts go here
				push		ax
				mov			ax,BIOSDATASEG				; establish segment of BIOS data
				mov			ds,ax
				mov			al,00001011b				; which IRQ caused this interrupt?
				out			OCW3,al
				nop
				in			al,ISR						; read IRQ level
				mov			ah,al
				or			al,ah						; test if any HW interrupt bit are set
				jnz			HWINT						; some bits set so this is a HW interrupt
				mov			ah,0ffh						; not HW so indicate with 0FFh IRQ
				jmp			SWINT
HWINT:			in			al,IMR						; clear the IRQ because this one has no handler routine
				or			al,ah
				out			IMR,al
				mov			al,EOI						; Send end-of-interrupt code
				out			OCW2,al
SWINT:			mov			byte [ds:bdINRTFLAG],ah		; Save last nonsense interrupt DS:6B
				pop			ax
				pop			ds
				iret
;
;----- NMI -------------------------------------;
; non-maskable interrupt service routine		;
; will print a parity check error.				;
; system will halt upon memory parity error.	;
; (IBM BIOS listing page 5-100/249, line 1914)	;
;												;
; entry:										;
;	NA											;
; exit:											;
;	system halt									;
;-----------------------------------------------;
;
INT02:			push		ax
				in			al,PPIPC					; read NMI source
				test		al,11000000b				; is it memory or IO channle parity error?
				jnz			NMIPARITYERR				; send error message
				jmp			INT02EXIT					; nothing here, exit
NMIPARITYERR:	mcrPRINT	PARITYERR					; print parity error message
				mcr7SEG		SEGP						; display 'P'
				hlt
;
INT02EXIT:		pop			ax
				iret
;
;----- INT 08 (IRQ0) ---------------------------;
; Hardware interrupt IRQ0 handler				;
; timer service interrupt service routine		;
; that is triggered 18.2 times per second.		;
; the handler maintains a count at (40:6c)		;
; of interrupts since power on.					;
; the handler also invokes a user defined		;
; interrupt handler at 1CH						;
;												;
; entry:										;
;	NA											;
; exit:											;
;	all work registers saved					;
;-----------------------------------------------;
;
INT08:			sti										; turn on interrupts
				push		ds
				push		ax
				mov			ax,BIOSDATASEG
				mov			ds,ax						; establish segment of BIOS data
				inc			word [ds:bdTIMELOW]			; increment time
				jnz			USERSERVICE					; counter rolls to '0000' every hour at the 18.2Hz interrupt rate
				inc			word [ds:bdTIMEHI]			; increment hour counter
				cmp			word [ds:bdTIMEHI],24		; reached 24 hour count?
				jnz			USERSERVICE					; no, continue to user int service hook
				mov			word [ds:bdTIMEHI],0		; reset day's hour counter
				mov			byte [ds:bdNEWDAY],1		; new day
USERSERVICE:	int			1ch							; invoke user interrupt service
;
				mov			al,byte [ds:bdTIMELOW]		; blink 7-seg's decimal point every 8 cycles, will yield about 1Hz blink rate
				and			al,00000111b				; count of 8 interrupts complete?
				jnz			DPNOCHANGE					; no, exit
				in			al,PPIPA					; yes, then toggle DP on 7-seg
				xor			al,10000000b
				out			PPIPA,al
;
DPNOCHANGE:		mov			al,EOI						; Send end-of-interrupt code
				out			OCW2,al
				pop			ax
				pop			ds
				iret
;
;----- INT 0A (IRQ2) ---------------------------;
; UART input (Rx) service interrupt routine		;
; this routine is hooked in place of the video	;
; IRQ2 just because it was available on the		;
; expansion slot and there is no video card		;
; installed. the routinve will accept a byte	;
; from the UART and place it in the keyboard	;
; buffer.										;
;												;
; entry:										;
;	NA											;
; exit:											;
;	All work registers are preserved			;
;-----------------------------------------------;
;
INT0A:			sti										; enable interrupts
				push		ax
				push		bx
				push		cx
				push		dx
				push		di
				push		ds							; save work registers
;
;-----	check UART receive buffer and read character if available
;
				mov			dx,IIR
				in			al,dx						; read IIR to determine interrupt type
				and			al,00000111b				; is there an interrupt waiting for service
				cmp			al,00000100b				; and is it for a received character?
				jnz			INT0AEXIT					; no, then exit
				mov			dx,RBR
				in			al,dx						; yes, read character from UART receiver buffer
;
;-----	store character in keyboard buffer
;
				mov			bx,BIOSDATASEG
				mov			ds,bx						; set DS to BIOS data structure segment
				mov			bx,[ds:bdKEYBUFTAIL]		; get buffer write pointer
				mov			di,bx						; save it
				inc			bx							; next position
				cmp			bx,[ds:bdKEYBUFEND]			; is this end of buffer?
				jne			NOTEND						;  no, skip
				mov			bx,[ds:bdKEYBUFSTART]		;  yes, reset write pointer (circular buffer)
NOTEND:			cmp			bx,[ds:bdKEYBUFHEAD]		; is write pointer same as read pointer?
				jne			NOOVERRUN					;  no, skip as there is no overrun
				mov			cx,2253						; 1.5KHz beep
				mov			bl,19						; 1/3 sec duration
				call		BEEP						; yes, beep speaker
				jmp			INT0AEXIT					; and exit
NOOVERRUN:		mov			[ds:di],al					; store in buffer
				mov			[ds:bdKEYBUFTAIL],bx		; update write pointer
;
;-----	epilog
;
INT0AEXIT:		mov			al,EOI						; Send end-of-interrupt code
				out			OCW2,al
				pop			ds							; restore work registers
				pop			di
				pop			dx
				pop			cx
				pop			bx
				pop			ax
				iret
;
;----- IND 0D (IRQ5) ---------------------------;
; IDE drive service interrupt routine			;
; is a place holder. IDE support will use		;
; polling and not interrupt.					;
;												;
; entry:										;
;	NA											;
; exit:											;
;	NA											;
;-----------------------------------------------;
;
INT0D:			push		ax
				mov			al,EOI						; Send end-of-interrupt code
				out			OCW2,al
				pop			ax
				iret
;
;----- INT 10 ----------------------------------;
; video service interrupt routine				;
; partial implementation of INT 10 functions	;
; as apropriate to use with a UART console.		;
; unused functions are ignored or return dummy	;
; data for compatibility						;
;												;
; entry:										;
;   AH = 00h                                    ;
;       AL video mode                           ;
;       40:49 will reflect the mode             ;
;       model will not change in implementation ;
;   AH = 05h                                    ;
;       AL = new page number                    ;
;	AH = 09h write attribute/char at cursor     ;
;	AH = 0ah write char at curson position      ;
;	AH = 0Eh write TTY to active page			;
;		AL character ASCII						;
;		(all other input ignored)               ;
;   AH = 0Fh                                    ;
;       AH = number of screen columns           ;
;       AL = mode currently set                 ;
;       BH = current display page               ;
;	AH = 13h write string						;
;		ES:BP pointer to string					;
;		CX    length of string					;
;		DX    cursor position (ignored)			;
;		BH    page number (ignored)				;
;		AL    00h write string					;
;			<char><char>...						;
;		BL attribute (ignored)				    ;
;			cursonr not moved (ignored)			;
;		AL    01h same as 00h move cursor		;
;		AL    02h write chat and attr.			;
;			<char><attr><char><attr>...			;
;			cursor not moved (ignored)			;
;		AL    03h same as 02h move cursor		;
;												;
; exit:											;
;	console output, all work registers saved	;
;                                               ;
; notes:                                        ;
;   '.' implemented as no-op function           ;
;   '*' function is implemented                 ;
;   ' ' function goes to IGNORE stub            ;
;-----------------------------------------------;
;
;														; function
INT10JUMPTBL:	dw			(INT10F00+ROMOFF)			; * 00h		- set CRT mode
				dw			(INT10F01+ROMOFF)			; .	01h		- set cursor type
				dw			(INT10F02+ROMOFF)			; .	02h		- set cursor position
				dw			(INT10F03+ROMOFF)			; *	03h		- read cursor position
				dw			(INT10IGNORE+ROMOFF)		;	04h		- read light pen position
				dw			(INT10F05+ROMOFF)           ; * 05h		- select active display
				dw			(INT10F06+ROMOFF)			; .	06h		- scroll active page up
				dw			(INT10IGNORE+ROMOFF)		;	07h		- scroll active page down
				dw			(INT10IGNORE+ROMOFF)		;   08h		- read attribute/character at cursor
				dw			(INT10F09+ROMOFF)			; *	09h		- write attribute/character at cursor
				dw			(INT10F0A+ROMOFF)			; *	0ah		- write character at curson position
				dw			(INT10F0B+ROMOFF)			; .	0bh		- set color palette
				dw			(INT10IGNORE+ROMOFF)		;	0ch		- write dot
				dw			(INT10IGNORE+ROMOFF)		;	0dh		- read dot
				dw			(INT10F0E+ROMOFF)			; *	0eh		- write character to page
				dw			(INT10F0F+ROMOFF)			; *	0fh		- return current video state
				dw			(INT10IGNORE+ROMOFF)		;	10h		- reserved
				dw			(INT10IGNORE+ROMOFF)		;	11h		- reserved
				dw			(INT10IGNORE+ROMOFF)		;	12h		- reserved
				dw			(INT10F13+ROMOFF)			; *	13h		- write string
;
INT10COUNT:		equ			($-INT10JUMPTBL)/2			; length of table for validation
;
INT10:			sti
				cmp			ah,INT10COUNT
				jb          INT10OK                     ; continue if function is in range
				call        INT10IGNORE                 ; call 'ignore' handler if out of range
				jmp         INT10EXIT
INT10OK:        push		si
				mov			si,ax						; save function and command in SI
				mov			al,ah
				cbw										; AX has function number
				sal			ax,1						; conert to jump table index
				xchg		si,ax						; restore function/command and move jump index to SI
				call		word [cs:(si+INT10JUMPTBL+ROMOFF)]	; call function using jump table
                pop			si
INT10EXIT:      iret
;
;-----------------------------------------------;
; INT10, 00h - Set Video Mode					;
;-----------------------------------------------;
;
INT10F00:       sti
				push		ds
                push        ax
				mov			ax,BIOSDATASEG
				mov			ds,ax						; establish segment of BIOS data structure
                pop         ax
				mov			byte [ds:bdVIDEOMODE],al	; save video more in 40:49
				pop			ds
				ret
;
;-----------------------------------------------;
; INT10, 01h - Set Cursor Type					;
; INT10, 02h - Set Cursor Position				;
;-----------------------------------------------;
;
INT10F01:
INT10F02:		ret
;
;-----------------------------------------------;
; INT10, 03h - return cursor position as 0,0	;
;-----------------------------------------------;
;
INT10F03:		xor			cx,cx
				xor			dx,dx
				ret
;
;-----------------------------------------------;
; INT10, 05h - select active display            ;
;-----------------------------------------------;
; @@- fix for bug #13
;
INT10F05:       sti
				push		ds
                push        ax
				mov			ax,BIOSDATASEG
				mov			ds,ax						; establish segment of BIOS data structure
                pop         ax
				mov			byte [ds:bdVIDEOPAGE],al	; save video page in 40:62
				pop			ds
				ret
;
;-----------------------------------------------;
; INT10, 06h - Scroll Window Up					;
;-----------------------------------------------;
;
INT10F06:		ret
;
;-----------------------------------------------;
; INT10, 09h and 0Ah - write ASCII at cursor	;
; INT10, 0eh - (AL) has ASCII of character		;
; (BL) has attribute that will be ignored		;
;-----------------------------------------------;
;
INT10F09:
INT10F0A:		nop										; fall through to function 0Eh
;
INT10F0E:		push		dx
				call		TXBYTE						; send character to UART console
				pop			dx
				ret
;
;-----------------------------------------------;
; INT10, 0bh Set color palette					;
;-----------------------------------------------;
;
INT10F0B:		ret										; called by COMMAND.COM and ignored
;
;-----------------------------------------------;
; INT 10, 0fh - get video state					;
;-----------------------------------------------;
;
INT10F0F:		mov			ah,CRTCOLUMNS				; screen columns
				mov			al,CRTMODE					; 80x25 Monochrome text (MDA,HERC,EGA,VGA)
				mov			bh,DEFVIDEOPAGE				; video page #1
				ret
;
;-----------------------------------------------;
; INT 10, 13h - write string					;
;-----------------------------------------------;
;
INT10F13:		cmp			al,4						; is the comand valid?
				jae			INT10F13EXIT				; exit if command not valid
				jcxz		INT10F13EXIT				; exit if string length is zero
				mov			dx,ax						; save AX
INT10CHRLOOP:	mov			al,[es:bp]					; get character
;				cmp			al,08h						; is it a back-space?
;				je			SPECIALCHAR					; skip special character
;				cmp			al,07h						; is it a BELL?
;				je			SPECIALCHAR					; skip special character
				push		dx
				call		TXBYTE						; send character to UART console
				pop			dx
SPECIALCHAR:	inc			bp							; point to next character
				cmp			dl,1						; does the string contain attributes?
				jle			NOATTR						; no atribute in string, continue
				inc			bp							; skip the attribute byte
NOATTR:			loop		INT10CHRLOOP				; loop through string
INT10F13EXIT:	ret
;
;-----------------------------------------------;
; INT 10, all unhandled functions				;
;-----------------------------------------------;
;
INT10IGNORE:	mcrPRINT	INT10DBG					; print unhandled function code
				xchg		al,ah
				call		PRINTHEXB
				xchg		ah,al
				mcrPRINT	CRLF
;
				ret
;
;----- INT 11 ----------------------------------;
; installed equipment service interrupt			;
; this routine return the bit field indicating	;
; installed equipment							;
;												;
; entry:										;
;	NA											;
; exit:											;
;	AX with bit fiels of installed equipment	;
;-----------------------------------------------;
;
INT11:			sti
				push		ds
				mov			ax,BIOSDATASEG
				mov			ds,ax						; establish segment of BIOS data structure
				mov			ax,[ds:bdEQUIPMENT]			; get equipment info from ds:10h
				pop			ds
				iret
;
;----- INT 12 ----------------------------------;
; RAM capacity on system returned in KB			;
;												;
; entry:										;
;	NA											;
; exit:											;
;	AX with system RAM in KB					;
;-----------------------------------------------;
;
INT12:			sti
				push		ds
				mov			ax,BIOSDATASEG				; establish segment of BIOS data structure
				mov			ds,ax
				mov			ax,[ds:bdMEMSIZE]			; get momory size in KB
				pop			ds
				iret
;
;----- INT 13 --------------------------------------------------------------;
; Disk IO service routine.													;
; source: http://stanislavs.org/helppc/int_13.html							;
; XTIDE:  http://xtideuniversalbios.googlecode.com/svn/trunk/				;
; IBM BIOS page.171 / 5-23                                                  ;
;																			;
; entry:																	;
;																			;
; AH = 00 - Reset Disk System												;
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)		;
;	on return:																;
;	AH = disk operation status (see INT 13,STATUS)							;
;	CF = 0 if successful													;
;	   = 1 if error															;
;																			;
;	NOTE: IBM BIOS does not need DL as drive ID. other BIOD documentation	;
;	does have DL as an input parameter. this implementation ignores DL		;
;																			;
; AH = 01 - Disk Status														;
;	on return:																;
;	AL = status:															;
;	Status in AL returns the status byte located at 40:41 in BIOS Data Area	;
;	   00  no error															;
;	   01  bad command passed to driver										;
;	   02  address mark not found or bad sector								;
;	   03  diskette write protect error										;
;	   04  sector not found													;
;	   05  fixed disk reset failed											;
;	   06  diskette changed or removed										;
;	   07  bad fixed disk parameter table									;
;	   08  DMA overrun														;
;	   09  DMA access across 64k boundary									;
;	   0A  bad fixed disk sector flag										;
;	   0B  bad fixed disk cylinder											;
;	   0C  unsupported track/invalid media									;
;	   0D  invalid number of sectors on fixed disk format					;
;	   0E  fixed disk controlled data address mark detected					;
;	   0F  fixed disk DMA arbitration level out of range					;
;	   10  ECC/CRC error on disk read										;
;	   11  recoverable fixed disk data error, data fixed by ECC				;
;	   20  controller error (NEC for floppies)								;
;	   40  seek failure														;
;	   80  time out, drive not ready										;
;	   AA  fixed disk drive not ready										;
;	   BB  fixed disk undefined error										;
;	   CC  fixed disk write fault on selected drive							;
;	   E0  fixed disk status error/Error reg = 0							;
;	   FF  sense operation failed											;
;																			;
; AH = 02 - Read Disk Sectors												;
;	AL = number of sectors to read	(1-128 dec.)							;
;	CH = track/cylinder number  (0-1023 dec., see below)					;
;	CL = sector number  (1-17 dec.)											;
;	DH = head number  (0-15 dec.)											;
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)		;
;	ES:BX = pointer to buffer												;
;	on return:																;
;	AH = status  (see INT 13,STATUS)										;
;	AL = number of sectors read												;
;	CF = 0 if successful													;
;	   = 1 if error															;
;	- BIOS disk reads should be retried at least three times and the		;
;	  controller should be reset upon error detection						;
;	- be sure ES:BX does not cross a 64K segment boundary or a				;
;	  DMA boundary error will occur											;
;	- many programming references list only floppy disk register values		;
;	- only the disk number is checked for validity							;
;	- the parameters in CX change depending on the number of cylinders;		;
;	  the track/cylinder number is a 10 bit value taken from the 2 high		;
;	  order bits of CL and the 8 bits in CH (low order 8 bits of track):	;
;																			;
;	  |F|E|D|C|B|A|9|8||7|6|5-0|  CX										;
;	   | | | | | | | |  | |	+-----	sector number							;
;	   | | | | | | | |  +-+-------  high order 2 bits of track/cylinder		;
;	   +-+-+-+-+-+-+-+------------  low order 8 bits of track/cyl number	;
;																			;
; AH = 03 - Write Disk Sectors												;
;	AL = number of sectors to write  (1-128 dec.)							;
;	CH = track/cylinder number  (0-1023 dec.)								;
;	CL = sector number  (1-17 dec., see below)								;
;	DH = head number  (0-15 dec.)											;
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)		;
;	ES:BX = pointer to buffer												;
;	on return:																;
;	AH = 0 if CF=0; otherwise disk status  (see INT 13,STATUS)				;
;	AL = number of sectors written											;
;	CF = 0 if successful													;
;	   = 1 if error															;
;	- BIOS disk write attempts should reset the controller on error			;
;	- be sure ES:BX does not cross a 64K segment boundary or a				;
;	  DMA boundary error will occur											;
;	- IBM PC XT 286 does not require a value in AL, though it is			;
;	  recommended that one be supplied for portability						;
;	- many programming references list only floppy disk register values		;
;	- only the disk number is checked for validity							;
;	- the parameters in CX change depending on the number of cylinders		;
;	  the track/cylinder number is a 10 bit value taken from the 2 high		;
;	  order bits of CL and the 8 bits in CH (low order 8 bits of track):	;
;																			;
;	  |F|E|D|C|B|A|9|8|7|6|5-0|  CX											;
;	   | | | | | | | | | |	`-----	sector number							;
;	   | | | | | | | | `---------  high order 2 bits of track/cylinder		;
;	   `------------------------  low order 8 bits of track/cyl number		;
;																			;
; AH = 04 - Verify Disk Sectors												;
;	AL = number of sectors to verify  (1-128 dec.)							;
;	CH = track/cylinder number  (0-1023 dec., see below)					;
;	CL = sector number  (1-17 dec.)											;
;	DH = head number  (0-15 dec.)											;
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)		;
;	ES:BX = pointer to buffer												;
;	on return:																;
;	AH = status  (see INT 13,STATUS)										;
;	AL = number of sectors verified											;
;	CF = 0 if successful													;
;	   = 1 if error															;
;	- BIOS disk reads should be retried at least three times and the		;
;	  controller should be reset upon error detection						;
;	- causes controller to calculate the CRC of the disk data and			;
;	  compare it against the CRC stored in the sector header				;
;	- BIOS before 11/15/85 required ES:BX point to a valid buffer			;
;	  that doesn't cross DMA boundaries.   More recent BIOS versions		;
;	  actually ignore the buffer and the DMA boundary requirement			;
;	- use this function to check for valid formatted diskette in a			;
;	  the specified drive and for drive ready for read						;
;	- only the disk number is checked for validity							;
;	- the parameters in CX change depending on the number of cylinders		;
;	  the track/cylinder number is a 10 bit value taken from the 2 high		;
;	  order bits of CL and the 8 bits in CH (low order 8 bits of track):	;
;																			;
;	  |F|E|D|C|B|A|9|8|7|6|5-0|  CX											;
;	   | | | | | | | | | |	`-----	sector number							;
;	   | | | | | | | | `---------  high order 2 bits of track/cylinder		;
;	   `------------------------  low order 8 bits of track/cyl number		;
;																			;
; AH = 05 - format disk														;
;	AL = interleave value (XT only)											;
;	CX = track/cylinder number (see below for format)						;
;	DH = head number  (0-15 dec.)											;
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)		;
;	ES:BX = pointer to block of "track address fields" containing			;
;		four byte fields for each sector to be formatted of the form:		;
;	       1 byte  track number												;
;	       1 byte  head number												;
;	       1 byte  sector number											;
;	       1 byte  sector size code											;
;						Size      #											;
;						Codes   Bytes										;
;						  0      128										;
;						  1      256										;
;						  2      512										;
;						  3     1024										;
;	on return:																;
;	AH = status  (see INT 13,STATUS)										;
;	CF = 0 if successful													;
;	   = 1 if error															;
;																			;
;	- BIOS disk write attempts should reset the controller on error			;
;	- INT 13,17 should be called to set the DASD type						;
;	- this function is capable of doing great damage if the parameters		;
;	  are incorrectly specified; only the drive number is checked			;
;	- initializes disk address fields and data sectors						;
;	- interleave is specified by ordering of track address fields			;
;	- after INT 13 disk format, if the disk is to be used with DOS the		;
;	  DOS data structure must be written									;
;	- only the disk number is checked for validity							;
;	- the parameters in CX change depending on the number of cylinders;		;
;	  the track/cylinder number is a 10 bit value taken from the 2 high		;
;	  order bits of CL and the 8 bits in CH (low order 8 bits of track):	;
;																			;
;	|F|E|D|C|B|A|9|8|7|6|5-0|  CX (cylinder value 0-1023 dec.)				;
;	 | | | | | | | | | |  `-----  unused									;
;	 | | | | | | | | `---------	high order 2 bits of track/cylinder			;
;	 `------------------------  low order 8 bits of track/cyl number		;
;																			;
; AH = 08 - Get Current Drive Parameters (floppy only?)						;
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)		;
; 	on return:																;
;	AH = status  (see INT 13,STATUS)										;
;	BL = CMOS drive type													;
;	     01 -   360K	     03 -   720K									;
;	     02 -   1.2Mb	     04 -  1.44Mb									;
;	CH = cylinders (0-1023 dec. see below)									;
;	CL = sectors per track	(see below)										;
;	DH = number of sides (0 based)											;
;	DL = number of drives attached											;
;	ES:DI = pointer to 11 byte Disk Base Table (DBT)						;
;	CF = 0 if successful													;
;	   = 1 if error															;
;																			;
;	Cylinder and Sectors Per Track Format									;
;	|F|E|D|C|B|A|9|8|7|6|5|4|3|2|1|0|  CX									;
;	 | | | | | | | | | | `------------  sectors per track					;
;	 | | | | | | | | `------------	high order 2 bits of cylinder count		;
;	 `------------------------  low order 8 bits of cylinder count			;
;																			;
;	- the track/cylinder number is a 10 bit value taken from the 2 high		;
;	  order bits of CL and the 8 bits in CH (low order 8 bits of track)		;
;	- many good programming references indicate this function is only		;
;	  available on the AT, PS/2 and later systems, but all hard disk		;
;	  systems since the XT have this function available						;
;	- only the disk number is checked for validity							;
;																			;
; AH = 15h - Read DASD Type													;
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)		;
;	on return:																;
;	AH = 00 drive not present												;
;	   = 01 diskette, no change detection present							;
;	   = 02 diskette, change detection present								;
;	   = 03 fixed disk present												;
;	CX:DX = number of fixed disk sectors; if 3 is returned in AH			;
;	CF = 0 if successful													;
;	   = 1 if error															;
;																			;
;	- XT's must have a BIOS date 1/10/86 or newer							;
;	- used to determine if INT 13,16 can detect disk change					;
;																			;
; AH = 16h - Change of Disk Status											;
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)		;
;	on return:																;
;	AH = 00 no disk change													;
;	   = 01 disk changed													;
;	CF = set if disk has been removed or an error occurred					;
;																			;
;	- used to detect if a disk change has occurred							;
;	- see	INT 13,STATUS    INT 13,15										;
;																			;
; AH = 17h - Set DASD Type for Format										;
;	AL = 00 no disk															;
;	   = 01  320k/360k diskette in 320k/360k drive							;
;	   = 02  320k/360k diskette in 1.2Mb drive								;
;	   = 03  1.2Mb diskette in 1.2Mb drive									;
;	   = 04  720k diskette in 720k drive  (BIOS 6/10/85 & newer)			;
;		 720K diskette in 1.44Mb drive (PS/2)								;
;		 1.44Mb diskette in 1.44Mb drive (PS/2)								;
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)		;
;																			;
;	returns nothing															;
;																			;
;	- only the disk number is checked for validity							;
;	- tells BIOS format routine about the disk type							;
;																			;
; AH = 18h - Set Media Type for Format										;
;	CH = lower 8 bits of number of tracks  (0-1023 dec., see below)			;
;	CL = sectors per track (1-17 dec., see below)							;
;	DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)		;
;																			;
;	on return:																;
;	ES:DI = pointer to 11-byte Disk Base Table (DBT)						;
;	AH = 00h if requested combination supported								;
;	   = 01h if function not available										;
;	   = 0Ch if not supported or drive type unknown							;
;	   = 80h if there is no media in the drive								;
;	CF = 0 if successful													;
;	   = 1 if error															;
;																			;
;	- valid only for XT BIOS dated after 1/10/86, AT after 11/15/86,		;
;	  XT 286 and the PS/2 line												;
;	- only disk number is checked for validity								;
;	- track number is a 10 bit value taken from the 2 high order			;
;	  bits of CL and the 8 bits in CH (low order 8 bits of track):			;
;																			;
;	  |F|E|D|C|B|A|9|8|7|6|5|4|3|2|1|0|  CX									;
;	   | | | | | | | | | | `--------------	sectors per track count			;
;	   | | | | | | | | `--------------  high order 2 bits track/cyl count	;
;	   `--------------------------	low order 8 bits of track/cyl count		;
;																			;
; DBT - Disk Base Table (BIOS INT 13)										;
;     Offset Size		Description											;
;	00   byte  specify byte 1; step-rate time, head unload time				;
;	01   byte  specify byte 2; head load time, DMA mode						;
;	02   byte  timer ticks to wait before disk motor shutoff				;
;	03   byte  bytes per sector code:										;
;			0 - 128 bytes	2 - 512 bytes									;
;			1 - 256 bytes	3 - 1024 bytes									;
;	04   byte  sectors per track (last sector number)						;
;	05   byte  inter-block gap length/gap between sectors					;
;	06   byte  data length, if sector length not specified					;
;	07   byte  gap length between sectors for format						;
;	08   byte  fill byte for formatted sectors								;
;	09   byte  head settle time in milliseconds								;
;	0A   byte  motor startup time in eighths of a second					;
;																			;
; Detecting Disk Ready														;
;	1.  use INT 13,4 (Verify Sector) to check ready for read				;
;	2.  check for error in AH of:											;
;	    80h  Time out, or Not Ready											;
;	    AAh  Drive not ready												;
;	    00h  drive is ready for reading										;
;	    other value indicates drive is ready, but an error occurred			;
;	3.  use INT 13,2 (Read Sector) followed by INT 13,3 (Write Sector)		;
;	    to check ready for read/write.  First read sector, test for			;
;	    ready;  write sector back, check for 03h (write protect) or			;
;	    any of the other BIOS disk errors									;
;																			;
; exit:																		;
;	see above, all other registers saved									;
;---------------------------------------------------------------------------;
;
; '*' function implemented
; '.' function not implemented but stubbed with 'no error' return status
; '?' not sure if this function is required
;
;														; function
INT13JUMPTBL:	dw			(INT13F00+ROMOFF)			;   00h	*	- Reset disk system
				dw			(INT13F01+ROMOFF)			;	01h	*	- Get disk status
				dw			(INT13F02+ROMOFF)			;	02h	*	- Read disk sectors
				dw			(INT13F03+ROMOFF)			;	03h	*	- Write disk sectors
				dw			(INT13F04+ROMOFF)           ;	04h .   - Verify disk sectors
				dw			(INT13F05+ROMOFF)           ;	05h *   - Format disk track
				dw			(INT13IGNORE+ROMOFF)		;	06h		- Format track and set bad sector flag (XT & portable)
				dw			(INT13IGNORE+ROMOFF)		;	07h		- Format the drive starting at track (XT & portable)
				dw			(INT13F08+ROMOFF)			;	08h	*	- Get current drive parameters (XT & newer)
				dw			(INT13IGNORE+ROMOFF)		;	09h     - Initialize fixed disk base tables (XT & newer)
				dw			(INT13F0A+ROMOFF)			;	0ah	.	- Read long sector (XT & newer)
				dw			(INT13F0B+ROMOFF)			;	0bh	.	- Write long sector (XT & newer)
				dw			(INT13IGNORE+ROMOFF)		;	0ch		- Seek to cylinder (XT & newer)
				dw			(INT13IGNORE+ROMOFF)		;	0dh		- Alternate disk reset (XT & newer)
				dw			(INT13IGNORE+ROMOFF)		;  	0eh		- Read sector buffer (XT & portable only)
				dw			(INT13IGNORE+ROMOFF)		;	0fh		- Write sector buffer (XT & portable only)
				dw			(INT13IGNORE+ROMOFF)		;	10h		- Test for drive ready (XT & newer)
				dw			(INT13IGNORE+ROMOFF)		;	11h		- Recalibrate drive (XT & newer)
				dw			(INT13IGNORE+ROMOFF)		;	12h		- Controller ram diagnostic (XT & portable only)
				dw			(INT13IGNORE+ROMOFF)		;  	13h		- Drive diagnostic (XT & portable only)
				dw			(INT13IGNORE+ROMOFF)		;  	14h		- Controller internal diagnostic (XT & newer)
				dw			(INT13F15+ROMOFF)			;  	15h	*	- Read disk type/DASD type (XT BIOS from 1/10/86 & newer)
				dw			(INT13IGNORE+ROMOFF)		;  	16h     - Disk change line status (XT BIOS from 1/10/86 & newer)
				dw			(INT13IGNORE+ROMOFF)		;  	17h     - Set dasd type for format (XT BIOS from 1/10/86 & newer)
				dw			(INT13F18+ROMOFF)			;  	18h	*	- Set media type for format (BIOS date specific)
				dw			(INT13IGNORE+ROMOFF)		;  	19h		- Park fixed disk heads (AT & newer)
				dw			(INT13IGNORE+ROMOFF)		;  	1ah		- Format ESDI drive unit (PS/2 50+)
;
INT13COUNT:		equ			($-INT13JUMPTBL)/2			; length of table for validation
;
;-----	check function and call through jump table
;
INT13:			sti										; enable interrupts
				cmp			ah,INT13COUNT
				jb			INT13OK                     ; continue if function is in range
				call        INT13IGNORE                 ; call 'ignore' handler if out of range
				mov         ah,INT13BADCMD              ; signal function error
				stc
				jmp         INT13EXIT
INT13OK:        push        si
                mov			si,ax						; save function and command in SI
				mov			al,ah
				cbw										; AX has function number
				sal			ax,1						; convert to jump table index
				xchg		si,ax						; restore function/command and move jump index to SI
				call		word [cs:(si+INT13JUMPTBL+ROMOFF)]	; call function using jump table
				pop         si
;
;-----	store function call status
;
INT13EXIT:      push		ds
				push		ax
				mov			ax,BIOSDATASEG				; establish pointer to BIOS data structure
				mov			ds,ax
				pop			ax
				mov			byte [ds:bdDRIVESTATUS],ah	; store last status
				pop			ds
;
				retf		2							; return and discard saved flags
;
;-----------------------------------------------;
;		INT 13, function 00h - disk reset		;
;-----------------------------------------------;
;
INT13F00:		call        IDERESET                    ; reset the host HDD
                mov			ah,INT13NOERR				; return with no error
				clc										; and successful completion
				ret
;
;-----------------------------------------------;
;		INT 13, function 01h - get status		;
;-----------------------------------------------;
;
INT13F01:		push		ds
				mov			ax,BIOSDATASEG
				mov			ds,ax						; set a pointer to BIOS data area
				mov			al,[ds:bdDRIVESTATUS]		; get status byte of last command
				mov			ah,INT13NOERR				; reset status byte to no error
				clc
F01EXIT:		pop			ds
				ret
;
;-----------------------------------------------;
;		INT 13, function 02h / 0Ah - read disk	;
;-----------------------------------------------;
;
INT13F02:
INT13F0A:		push		ds
;
;-----	check validity of drive ID
;
				push		es
				push		di							; save ES, DI becasue we only want to know if drive ID is OK
				call		CHECKDRV					; check if valid drive
				pop			di
				pop			es
				jnc			F02VALIDDRV					; drive is valid, continue
				mov			ah,INT13BADCMD				; signal error 'bad parameter'
				stc
				jmp			F02EXIT
;
;-----	convert CHS to LBA
;
F02VALIDDRV:	push		ax
				mov			ax,BIOSDATASEG				; establish pointer to BIOS data
				mov			ds,ax
				pop			ax
				mov			byte [ds:bdIDEFEATUREERR],0	; setup IDE command block, features not needed so '0'
				mov			[ds:bdIDESECTORS],al		; sector count to read
				push		ax
				push		dx							; save parameters in AX and DX
				call		CHS2LBA						; convert CHS address to LBA
				jnc			F02CMDSET					; no error continue with command setup
				mov			ah,INT13BADSEC				; bad CHS error 'address mark not found or bad sector'
				mov			al,0						; nothing read
				add			sp,4						; adjust SP for saved registers AX and DX
				stc										; signal error
				jmp			F02EXIT						; conversion error, CHS tuple out of range
;
;-----	 load and send IDE command to drive
;
F02CMDSET:		mov			[ds:bdIDELBALO],al			; low LBA byte (b0..b7)
				mov			[ds:bdIDELBAMID],ah			; mid LBA byte (b8..b15)
				mov			[ds:bdIDELBAHI],dl			; high LBA byte (b16..b23)
				and			dh,IDEDEVSELECT				; device #0
				or			dh,IDELBASELECT				; LBA addressing mode
				mov			[ds:bdIDEDEVLBATOP],dh		; device, addressing and high LBA nibble (b24..b27)
				mov			byte [ds:bdIDECMDSTATUS],IDEREADSEC	; read command
				call		IDESENDCMD					; send command block to drive
				jnc			F02GETRDDATA				; no error, get read data
				mov			ah,INT13BADCMD				; set 'bad command passed to driver'
				mov			al,0						; nothing read
				add			sp,4						; adjust SP for saved registers AX and DX
				stc
				jmp			F02EXIT						; command could not be sent to drive
;
;-----	read data from drive
;
F02GETRDDATA:	pop			dx
				pop			ax
				call		IDEREAD						; read data from drive
				jnc			F02READOK					; no read errors
				mov			ah,INT13TOVERR				; indicate 'time out, drive not ready' (could be something else, but all other causes elimnated before)
				mov			al,0						; nothing read
				stc
				jmp			F02EXIT						; read failed, exit with error
F02READOK:		mov			ah,INT13NOERR				; no error, AL contains sectors read
				clc
;
F02EXIT:		pop			ds							; restore DS and exit
				ret
;
;-----------------------------------------------;
;		INT 13, function 03h / 0Bh - write disk	;
;-----------------------------------------------;
;
INT13F03:
INT13F0B:		push		ds
;
;-----	check validity of drive ID
;
				push		es
				push		di							; save ES, DI becasue we only want to know if drive ID is OK
				call		CHECKDRV					; check if valid drive
				pop			di
				pop			es
				jnc			F03VALIDDRV					; drive is valid continue
				mov			ah,INT13BADCMD				; signal error 'bad parameter'
				stc
				jmp			F03EXIT
;
;-----	convert CHS to LBA
;
F03VALIDDRV:	push		ax
				mov			ax,BIOSDATASEG				; establish pointer to BIOS data
				mov			ds,ax
				pop			ax
				mov			byte [ds:bdIDEFEATUREERR],0	; setup IDE command block, features not needed so '0'
				mov			[ds:bdIDESECTORS],al		; sector count to read
				push		ax
				push		dx							; save parameters in AX and DX
				call		CHS2LBA						; convert CHS address to LBA
				jnc			F03CMDSET					; no error continue with command setup
				mov			ah,INT13BADSEC				; bad CHS error 'address mark not found or bad sector'
				mov			al,0						; nothing written
				add			sp,4						; adjust SP for saved registers AX and BX
				stc
				jmp			F03EXIT						; conversion error, CHS tuple out of range
;
;-----	 load and send IDE command to drive
;
F03CMDSET:		mov			[ds:bdIDELBALO],al			; low LBA byte (b0..b7)
				mov			[ds:bdIDELBAMID],ah			; mid LBA byte (b8..b15)
				mov			[ds:bdIDELBAHI],dl			; high LBA byte (b16..b23)
				and			dh,IDEDEVSELECT				; device #0
				or			dh,IDELBASELECT				; LBA addressing mode
				mov			[ds:bdIDEDEVLBATOP],dh		; device, addressing and high LBA nibble (b24..b27)
				mov			byte [ds:bdIDECMDSTATUS],IDEWRITESEC	; write command
				call		IDESENDCMD					; send command block to drive
				jnc			F03WRDATA					; no error, write data
				mov			ah,INT13BADCMD				; set 'bad command passed to driver'
				mov			al,0						; nothing written
				add			sp,4						; adjust SP for saved registers AX and DX
				stc
				jmp			F03EXIT						; command could not be sent to drive
;
;-----	write data to drive
;
F03WRDATA:		pop			dx
				pop			ax
				call		IDEWRITE					; write data to drive
				jnc			F03WRITEOK					; no write errors
				mov			ah,INT13TOVERR				; indicate 'time out, drive not ready' (could be something else, but all other causes elimnated before)
				mov			al,0						; nothing written
				stc
				jmp			F03EXIT						; read failed, exit with error
F03WRITEOK:		mov			ah,INT13NOERR				; no error, AL contains sectors writted
				clc
;
F03EXIT:		pop			ds							; restore DS and exit
				ret
;
;-----------------------------------------------;
;       INT 13, function 04h - verify track     ;
;-----------------------------------------------;
;
INT13F04:       mov         ah,INT13NOERR               ; return with no error
                clc                                     ; and successful completion
                ret
;
;-----------------------------------------------;
;		INT 13, function 05h - Format track     ;
;-----------------------------------------------;
; @@- fix for bug #5
;
INT13F05:       push        bx
                push        cx
                push        dx
                push        di
                push        es
;
                call        CHECKDRV                    ; check drive ID and point to drive data drive is valid
                jnc         F05VALIDDRV
                mov         ah,INT13BADCMD              ; signal 'bad parameter' error
                stc
                jmp         F05EXIT
;
F05VALIDDRV:    and         cl,11000000b                ; zero out lower track number bits in CL
                inc         cl                          ; CL index to track #1 on the cylinder
                mov         al,[es:di+ddDRVGEOSEC]      ; get sectors per track, [ES:DI] points to drive data table
                mov         ah,03h                      ; INT13/03h write sectors function
                mov         bx,cs
                mov         es,bx
                mov         bx,EMPTYSECTOR              ; setup [ES:BX] to point to dummy sector filled with 'format byte'
;
SECFORMATLOOP:  push        ax
                mov         al,1                        ; write 1 sector
                int         13h                         ; call function to write formatted sector
                jc          F05ERR                      ; if error exit the formatting loop
                pop         ax                          ; retrieve AX
                inc         cl                          ; increment sector number in CL
                dec         al                          ; decrement sector count
                jnz         SECFORMATLOOP               ; loop for remaining sectors
;
                mov         ah,INT13NOERR               ; 'no error' return code
                jmp         F05EXIT
;
F05ERR:         add         sp,2                        ; discard pushed AX
                stc                                     ; re-assert CY.f to indicate error
;
F05EXIT:        pop         es
                pop         di
                pop         dx
                pop         cx
                pop         bx
                ret
;
;-----------------------------------------------;
;		INT 13, function 08h - get drive param	;
;-----------------------------------------------;
;
INT13F08:		call		CHECKDRV					; check if drive exists
				jnc			F08VALIDDRV					; drive is valid, continue
				mov			ah,INT13BADPARAM			; drive parameter is not valid, signal error 'bad parameter'
				stc
				jmp			F08EXIT
;
;-----  set common parameters for fixed disk and diskette
;
F08VALIDDRV:	mov			ch,[es:di+ddDRVGEOCYL]		; ES:DI = top of drive table, get low byte of cylinder count
				mov			al,[es:di+ddDRVGEOCYL+1]	; get high byte of cylinder count
				mov			cl,6
				shl			al,cl						; move 2 high order cylinder count bits
				add			al,[es:di+ddDRVGEOSEC]		; add sectors per track
				mov			cl,al						; move to CL
				mov			dh,[es:di+ddDRVGEOHEAD]		; get head count
				dec         dh                          ; head count is zero based!
				call		COUNTDRV
                mov         dl,al                       ; get drive count
                xor         bx,bx
                mov         bl,[es:di+ddCMOSTYPE]       ; get drive type
                add			di,ddDBT					; point DI at the DBT offset
                xor         ax,ax
                mov			ah,INT13NOERR				; indicate no errors
				clc
F08EXIT:		ret
;
;-----------------------------------------------;
;		INT 13, function 15h - disk/DASD type	;
;-----------------------------------------------;
;
INT13F15:		push		di
				push		es
				call		CHECKDRV					; check if drive exists
				jnc			F15VALIDDRV					; drive is valid, [ES:DI] points to drive info in ROM, continue
				xor			ah,ah						; drive not present
				xor			cx,cx
				xor			dx,dx
				stc
				jmp			F15EXIT
F15VALIDDRV:    mov         ah,[es:di+ddDASDTYPE]      	; get disk type
                cmp         dl,80h                      ; is this a fixed disk?
                jb          F15FLOPPY                   ;  it is a floppy, so exit here
                mov         cx,[es:di+ddDRVMAXLBA]      ;  fixed disk, so get sector count (which is the LBA count)
                xor         dx,dx
F15FLOPPY:      clc
F15EXIT:		pop			es
				pop			di
				ret
;
;----------------------------------------------------;
;		INT 13, function 18h - media type for format ;
;----------------------------------------------------;
;
INT13F18:		push        bx
                call		CHECKDRV					; check if drive exists
				jnc			F18VALIDDRV					; drive is valid, [ES:DI] points to drive info in ROM, continue
				mov			ah,INT13UNSUPMED			; drive parameter is not valid, signal error 'bad parameter'
				stc
				jmp			F18EXIT
F18VALIDDRV:	mov			bx,cx						; save CX
				cmp			bh,[es:di+ddDRVGEOCYL]		; ES:DI = top of drive table, compare low byte of cylinder count
				jne			F18NOTSUP				    ; error if not equal
				mov			al,[es:di+ddDRVGEOCYL+1]	; get high byte of cylinder count
				mov			cl,6
				shl			al,cl						; move 2 high order cylinder count bits
				add			al,[es:di+ddDRVGEOSEC]		; add sectors per track
				cmp			bl,al						; compare high order cylinder bits + sectors per track
				jne			F18NOTSUP				    ; error if not equal
				add			di,ddDBT					; point DI at the DBT offset
				mov			ah,INT13NOERR				; indicate no errors
				clc
				jmp			F18EXIT
F18NOTSUP:      mov			ah,INT13UNSUPMED			; signal 'unsupported track/media'
				stc
F18EXIT:		pop         bx
                ret
;
;-----------------------------------------------;
;		all ignored function exit here          ;
;-----------------------------------------------;
;
INT13IGNORE:	mcrPRINT	INT13DBG					; print unhandled function code
				xchg		al,ah
				call		PRINTHEXB
				xchg		ah,al
				mcrPRINT	CRLF
;
				push		ds
				mov			ax,BIOSDATASEG				; set pointer to BIOS data area
				mov			ds,ax
				mov			byte [ds:bdIDECMDSTATUS],0	; clear drive errors by clearing
				mov			byte [ds:bdIDEFEATUREERR],0	; both command block registers
				pop			ds
;
				mov			ah,INT13BADCMD				; set error type to 'bad command passed to driver'
				stc										; indicate error condition for ignored function
				ret										; exit back to caller
;
;----- INT 15 ----------------------------------;
; cassette function								;
;												;
; entry:										;
;	NA											;
; exit:											;
;	always return not present failure			;
;	AH = 86h, CY.f = '1'						;
;-----------------------------------------------;
;
INT15:			stc										; set carry flag
				mov			ah,86h						; set return value
				retf		2							; return and discard saved flags
;
;----- INT 16 ----------------------------------;
; keyboard service interrupt routine			;
; partial implementation of INT 16 functions	;
; as apropriate to use with a UART console.		;
; unused functions are ignored or return dummy	;
; data for compatibility						;
;												;
; entry:										;
;	AH = 00h read character						;
;		AL character, AH scan code				;
;	AH = 01h is character in buffer?			;
;		Z.f = 1 no code available				;
;		Z.f = 0 code available returned in AX	;
;			character is left in the buffer		;
;	AH = 02h return shift status				;
;	AH = 05h place char/scan code in buffer		;
;		CL char, CH scan code to place			;
;		AL = 00h success, 01h fail/full			;
;	AH = 10h extended read (same as 00h)		;
;	AH = 11h extended status (same as 01h)		;
;	AH = 12h extended shift status (ignored)	;
; exit:											;
;	as listed above, AX and flags changes, all	;
;	other registers are preserved				;
;-----------------------------------------------;
;
INT16:			sti										; enable other interrupts
				push		ds
				push		bx
				mov			bx,BIOSDATASEG
				mov			ds,bx						; establish BIOS data segment
				cmp			ah,00h
				je			INT16READ					; func. 00h read keyboard buffer
				cmp			ah,01h
				je			INT16STATUS					; func. 01h get keyboard buffer status
				cmp			ah,02h
				je			INT16SHIFT					; func. 02h get shift key status
;				cmp			ah,05h
;				je			INT16WRITE					; func. 05h write to keyboard buffer
				cmp			ah,10h
				je			INT16READ					; func. 10h read keyboard buffer
				cmp			ah,11h
				je			INT16STATUS					; func. 11h same as function 01h
;
				mcrPRINT	INT16DBG					; print unhandled function code
				xchg		al,ah
				call		PRINTHEXB
				xchg		ah,al
				mcrPRINT	CRLF
;
INT16EXIT:		pop			bx
				pop			ds
				iret
;
;-----	read keyboard buffer
;
INT16READ:		cli										; disable interrupts while reading buffer pointers
				mov			bx,[ds:bdKEYBUFHEAD]		; get buffer head pointer
				cmp			bx,[ds:bdKEYBUFTAIL]		; compare to buffer tail pointer
				jne			READBUFFER					; character to read from buffer
				sti										; reenable interrupts
				jmp			INT16READ					; loop until something is typed
READBUFFER:		mov			al,[ds:bx]					; get the ASCII code into AL
				call		ASCII2SCANCODE				; get scan code from ASCII into AH
				inc			bx							; point to next buffer position
				mov			[ds:bdKEYBUFHEAD],bx		; save new buffer head position
				cmp			bx,[ds:bdKEYBUFEND]			; is buffer end/overflow?
				jne			INT16EXIT					; no, done and exit
				mov			bx,[ds:bdKEYBUFSTART]
				mov			[ds:bdKEYBUFHEAD],bx		; correct buffer head pointer
				jmp			INT16EXIT
;
;-----	check keyboard buffer for waiting characters
;
INT16STATUS:	cli										; disable interrupts while reading buffer pointers
				mov			bx,[ds:bdKEYBUFHEAD]		; get buffer head pointer
				cmp			bx,[ds:bdKEYBUFTAIL]		; compare to buffer tail pointer, if equal then nothing there (Z.f=1)
				pushf									; save the flags (Z.f)
				mov			al,[ds:bx]					; get the ASCII code of last character into AL
				sti										; reenable interrupts
				call		ASCII2SCANCODE				; get scan code from ASCII into AH
				popf									; restore flags (and Z.f)
				pop			bx							; restore
				pop			ds							; registers
				retf		2							; and exit here while preserving flags set in *this* function
;
;-----	return shift status, always '0 for this implementation
;
INT16SHIFT:		mov			al,[ds:bdSHIFT]
				jmp			INT16EXIT
;
;-----	write character into keyboard buffer
; @@- do we need this function?
INT16WRITE:		nop
				jmp			INT16EXIT
;
;----- INT 19 ----------------------------------;
; boot strap loader from track 0 sector 1 into	;
; boot location 0000:7C00.						;
; execution control is transferred there.		;
; if there is an error, control will transfer	;
; to monitor mode.								;
;												;
; entry:										;
;	DL	boot drive								;
; exit:											;
;	NA											;
;-----------------------------------------------;
; @@- boot: 5-94/242 line 1166
;
INT19:			sti										; enable interrupts
;
;-----	get DBT of boot drive
;
				call		CHECKDRV					; check boot drive passed in DL
				jc			INT19ERREXIT				; no drive or error with access
				add			di,ddDBT					; ES:DI returned, adjust DI to point to Disk Base Table (DBT)
				xor			ax,ax
				mov			ds,ax						; establish pointer segment
				mov			[ds:078h],di				; store DBT offset
				mov			[ds:07ah],es				; store DBT segment
;
;-----	attempt to read boot record, store it and jump to it
;
				mov			cx,4						; four boot retry
IPLRETRY:		push		cx
				mov			ah,02h						; read sector function
				mov			al,01h						; read 1 sector from:
				mov			cx,1						;   sector 1, cylinder 0
				mov			dh,0						;   head 0, DL already has drive ID
				mov			bx,IPLSEG					;   IPL record pointer segment
				mov			es,bx
				mov			bx,IPLOFF					;   IPL record pointer offset
				int			13h							; read sector 0 on drive 0
				pop			cx							; recover retry count
				jnc			INT19DOIPL					; CY.f=0 no error, so jump to IPL code
				loop		IPLRETRY					; retry
				jmp			INT19ERREXIT
;
INT19DOIPL:		jmp			word IPLSEG:IPLOFF
;
;-----	if INT 19 fails it will start monitor mode
;
INT19ERREXIT:	mcrPRINT	IPLFAILMSG					; print IPL fail message before going to MONITOR mode
				add			sp,6						; discard INT 19 stack frame
				int			18h							; invoke 'monitor' mode if there was an error in INT 19 execution,
;
;----- INT 1A ----------------------------------;
; system and real time clock service handler	;
; this service routine allows clocks to be set	;
; and read										;
;												;
; entry:										;
;	AH = 00h read current clock setting			;
;		CX high portion of count				;
;		DX low portion of count					;
;		AL '0' not passed 24hr since last read	;
;		   '1' passed 24hr, reaset after read	;
;	AH = 01h set clock							;
;		CX high count							;
;		DX low count							;
;	AH = 0Ah read day count	(not implemented)	;
;		CX day count							;
;	AH = 0Bh set day count (not implemented)	;
;		CX day count							;
;												;
; exit:											;
;	AX modified									;
;-----------------------------------------------;
;
INT1A:			sti										; enable interrupts
				push		ds
				push		ax
				mov			ax,BIOSDATASEG
				mov			ds,ax						; establish BIOS data segment
				pop			ax							; retrieve function
				cli										; disable interrupts
				cmp			ah,00h
				je			INT1A00						; function 00h
				cmp			ah,01h
				je			INT1A01						; function 01h
				stc										; invalid function set carry flag
				jmp			INT1ADONE
;
INT1A00:		mov			cx,[ds:bdTIMEHI]			; read time
				mov			dx,[ds:bdTIMELOW]
				mov			byte [ds:bdNEWDAY],0
				clc
				jmp			INT1ADONE
;
INT1A01:		mov			[ds:bdTIMEHI],cx			; set time
				mov			[ds:bdTIMELOW],dx
				mov			byte [ds:bdNEWDAY],0
				clc
;
INT1ADONE:		sti										; reenable interrupts and return
				pop			ds
				iret
;
;----- INT 1C ----------------------------------;
; place holder for a user interrupt service		;
; that is called periodically from the timer	;
; tick interrupt INT-08							;
;-----------------------------------------------;
;
INT1C:			iret
;
;
;	*********************************
;	***    SUPPORT ROUTINES       ***
;	*********************************
;
;-----------------------------------------------;
; this routing transmits a string to UART.		;
; The string must be '0' terminated.			;
;												;
; enrty:										;
;	SI offset to string							;
;	DS segment address of string				;
; exit:											;
;	all work registers preserved				;
;-----------------------------------------------;
;
PRINTSTZ:		push		dx
				push		ax
				push		si							; save work registers
CHARTXLOOP:		lodsb									; get character from string
				cmp			al,0						; is it '0' ('0' signals end of string)?
				je			STRINGEND					; yes, then done
				call		TXBYTE						; no, transmit the character byte
				jmp			CHARTXLOOP					; loop for next character
STRINGEND:		pop			si							; restore registers and return
				pop			ax
				pop			dx
				ret
;
;-----------------------------------------------;
; this routing transmits a single byte through	;
; the UART. The routine waits until the			;
; transmit buffer is clear/ready and then sends	;
; the byte										;
;												;
; enrty:										;
;	AL byte to transmit							;
; exit:											;
;	DX, AH used									;
;-----------------------------------------------;
;
TXBYTE:			mov			dx,LSR
				mov			ah,al						; save AL
WAITTHR:		in			al,dx						; read LSR
				and			al,00100000b				; check if transmit hold reg is empty
				jz			WAITTHR						; loop if not empty
				mov			dx,THR
				mov			al,ah						; restore AL
				out			dx,al						; output to serial console
				ret
;
;-----------------------------------------------;
; this routine prints to console the ASCII code	;
; passed to it in AL							;
;												;
; enrty:										;
;	AL ASCII code to transmit					;
; exit:											;
;	all work registers saved					;
;-----------------------------------------------;
;
PRINTCHAR:		push		ax
				push		dx							; save work registers
				call		TXBYTE						; print character from AL
				pop			dx
				pop			ax
				ret
;
;-----------------------------------------------;
; this routine converts a number stored in AX	;
; into ASCII and prints its decimal form to		;
; the console.									;
; the algorithm repeatedly divides by 10 and	;
; keeps the remainder as the 1's 10's 100's...	;
; digit											;
;												;
; enrty:										;
;	AX number to convert and print				;
; exit:											;
;	all work registers saved					;
;-----------------------------------------------;
;
PRINTDEC:		push		ax
				push		bx
				push		cx
				push		dx
				mov			bx,10						; divide by ten
				mov			cx,0						; initialize digit counter
DECIMALLOOP:	xor			dx,dx
				div			bx							; divide by 10, remainder is decimal digit
				add			dx,('0')					; conver remainder to ASCII
				push		dx							; save digit to print later
				inc			cx							; increment digit counter
				cmp			ax,0						; check if done if quotient is 0
				jne			DECIMALLOOP
PRINTLOOP:		pop			ax							; get the digits in reverse order
				call		TXBYTE						; output to console, ASCII will be in AL
				loop		PRINTLOOP
				pop			dx
				pop			cx
				pop			bx
				pop			ax
				ret
;
;-----------------------------------------------;
; this routing converts a number stored in AX	;
; into ASCII and prints its hex form to the		;
; console.										;
; There are three entry point in this utility:	;
;  (1) PRINTHEXW - print a word from AX			;
;  (2) PRINTHEXB - print a byte from AL			;
;  (3) HEXDIGIT - print low nibble from AL		;
;												;
; enrty:										;
;	AX number to convert and print				;
; exit:											;
;	all work registers saved					;
;-----------------------------------------------;
;
PRINTHEXW:		push		ax							; save word
				mov			al,ah						; setup AL for high byte
				call		PRINTHEXB					; print high byte
				pop			ax							; setup AL for low byte
				call		PRINTHEXB					; print low byte
				ret
;
PRINTHEXB:		push		cx							; save CX
				push		ax
				mov			cl,4
				shr			al,cl						; setup high nibble in AL
				call		HEXDIGIT					; pring high nibble
				pop			ax							; setup low nibble in AL
				call		HEXDIGIT					; print low nibble
				pop			cx
				ret
;
HEXDIGIT:		push		ax
				and			al,0fh						; isolate low nibble
				cmp			al,9						; check for '0'-'9' or 'a'-'f'
				jbe			NUMDIGIT					; if '0'-'9' treat as number
				add			al,('a'-10)					; if 'a'-'f' shift to lower case alpha ASCII
				jmp			PRINTDIGIT
NUMDIGIT:		add			al,('0')					; shift to numbers' ASCII
PRINTDIGIT:		push		dx
; @@- should use INT10 instead of direct call to 'TXBYTE'?
				call		TXBYTE						; transmit byte
				pop			dx
				pop			ax
				ret
;
;-----------------------------------------------;
; this subroutine performes a read/write test	;
; with four byte patterns: 55/AA/01/00.			;
; test 1KB (1024B) at a time.					;
;												;
; entry:										;
;	ES tested segment							;
; exit:											;
;	C.F is set if memory error, clear if ok		;
;	ES is advances to next segment by 1KB		;
;	memory block is zero'd						;
;	AL, BX, CX, DI, ES used						;
;-----------------------------------------------;
;
MEMTST:			mov			bx,0400h					; 1K bytes to test
;
PAT1:			mov			al,55h						; test pattern 1
				xor			di,di
				mov			cx,bx
				repz		stosb						; fill memory with pattern 1
				xor			di,di
				mov			cx,bx
				repz		scasb						; scan memory for NOT pattern 1
				jcxz		PAT2
				stc										; test failed
				ret
;
PAT2:			mov			al,0aah						; test pattern 2
				xor			di,di
				mov			cx,bx
				repz		stosb						; fill memory with pattern 2
				xor			di,di
				mov			cx,bx
				repz		scasb						; scan memory for NOT pattern 2
				jcxz		PAT3
				stc										; test failed
				ret
;
PAT3:			mov			al,01h						; test pattern 3
				xor			di,di
				mov			cx,bx
				repz		stosb						; fill memory with pattern 3
				xor			di,di
				mov			cx,bx
				repz		scasb						; scan memory for NOT pattern 3
				jcxz		PAT4
				stc										; test failed
				ret
;
PAT4:			mov			al,0						; test pattern 4
				xor			di,di
				mov			cx,bx
				repz		stosb						; fill memory with pattern 4
				xor			di,di
				mov			cx,bx
				repz		scasb						; scan memory for NOT pattern 4
				jcxz		EXTMEMTST
				stc										; test failed
				ret
;
EXTMEMTST:		mov			ax,es
				add			ax,40h						; add 40h to segment number, advance 1K
				mov			es,ax
				clc										; memory block test passed
				ret
;
;-----------------------------------------------;
; read blocks of 512 bytes from IDE drive		;
;												;
; entry:										;
;	ES:BX pointer to destination buffer			;
;	AL number of 512 block to read				;
; exit:											;
;	memory buffer containes read data and/or	;
;	CF = '1' drive timed out					;
;	CF = '0' read completed						;
;	all work registers saved					;
;-----------------------------------------------;
;
IDEREAD:		push		ax
				push		bx
				push		cx
				push		dx
				push		di
				push		ds
				push		es							; save work registers
;
				mov			cl,al						; make CL block counter
				mov			di,bx						; pointer to data buffer is not in [ES:DI]
				mov			ax,BIOSDATASEG
				mov			ds,ax						; segment pointer to BIOS data
;
				mov			ax,IDETOV					; 1sec time out to wait for not BSY
				call		IDEREADY					; first check if drive is not busy
				jc			READFAIL					; drive is stuck in busy, exit
				call		IDERECVCMD					; get command block with command status
				mov			al,[ds:bdIDECMDSTATUS]		; get status byte
				and			al,IDESTATERR				; test ERR bit
				jz			NOREADERR					; no error, continue
				stc										; there is an error, set CY.f
				jmp			READFAIL					; and exit
NOREADERR:		mov			ax,IDETOV					; 1sec time out for DRQ wait
				call		IDEDRQ						; is DRQ asserted?
				jc			READFAIL					; no, exit
				mov			dx,IDEPPI					; data is ready to read, PPI IDE control port
				mov			al,IDEDATARD				; IDE read mode
				out			dx,al						; set PPI for IDE read
				dec			dx							; set PPI PC IDE control lines
				mov			al,IDEDATA					; IDE data register address and CSx
				out			dx,al						; set the address
;
;-----	85 cycles @ 4.7MHz -> 53KBps / @ 8MH -> 91KBps
;
BLOCKREADLOOP:	xor			ch,ch						; 		CH=word count, CL=block count
READLOOP:		xor			al,IDERD					; 4
				out			dx,al						; 8		assert the RD line
				mov			bx,ax						; 2		save AX
				dec			dx							; 2
				dec			dx							; 2		PPI PA IDE data port lines
				in			ax,dx						; 12	read all 16 bits
				mov			[es:di],ax					; 14	store read value in buffer
				mov			ax,bx						; 2		restore AX
				inc			dx							; 2
				inc			dx							; 2		point to PPI PC IDE control lines
				xor			al,IDERD					; 4
				out			dx,al						; 8		negate the RD line
				inc			di							; 2		advance pointer to next word
				inc			di							; 2
				dec			ch							; 3
				jnz			READLOOP					; 16	read next word
				dec			cl
				jnz			BLOCKREADLOOP				; loop for next block of 512 bytes
;
READFAIL:		pop			es
				pop			ds
				pop			di
				pop			dx
				pop			cx
				pop			bx
				pop			ax
				ret
;
;-----------------------------------------------;
; write blocks of 512 bytes to IDE drive		;
;												;
; entry:										;
;	ES:BX pointer to source buffer				;
;	AL number of 512 block to write				;
; exit:											;
;	CF = '1' drive timed out					;
;	CF = '0' write completed					;
;	all work registers saved					;
;-----------------------------------------------;
;
IDEWRITE:		push		ax
				push		bx
				push		cx
				push		dx
				push		di
				push		ds							; save work registers
;
				mov			cl,al						; make CL block counter
				mov			di,bx						; pointer to data buffer is not in [ES:DI]
				mov			ax,BIOSDATASEG
				mov			ds,ax						; segment pointer to BIOS data
;
				mov			ax,IDETOV					; 1sec time out to wait for not BSY
				call		IDEREADY					; first check if drive is not busy
				jc			WRITEFAIL					; drive is stuck in busy, exit
				call		IDERECVCMD					; get command block with command status
				mov			al,[ds:bdIDECMDSTATUS]		; get status byte
				and			al,IDESTATERR				; test ERR bit
				jz			NOWRITEERR					; no error, continue
				stc										; there is an error, set CY.f
				jmp			WRITEFAIL					; and exit
NOWRITEERR:		mov			ax,IDETOV					; 1sec time out for DRQ wait
				call		IDEDRQ						; is DRQ asserted?
				jc			WRITEFAIL					; no, exit
				mov			dx,IDEPPI					; data is ready to write, PPI IDE control port
				mov			al,IDEDATAWR				; IDE write mode
				out			dx,al						; set PPI for IDE read
				dec			dx							; set PPI PC IDE control lines
				mov			al,IDEDATA					; IDE data register address and CSx
				out			dx,al						; set the address
;
;-----	85 cycles @ 4.7MHz -> 53KBps / @ 8MH -> 91KBps
;
BLOCKWRITELOOP:	xor			ch,ch						; 		CH=word count, CL=block count
WRITELOOP:		mov			bx,ax						; 2		save AX
				mov			ax,[es:di]					; 14	get word to write
				dec			dx							; 2
				dec			dx							; 2		PPI PA IDE data port lines
				out			dx,ax						; 12	write all 16 bits
				mov			ax,bx						; 2		restore AX
				inc			dx							; 2
				inc			dx							; 2		point to PPI PC IDE control lines
				xor			al,IDEWR					; 4
				out			dx,al						; 8		assert the WR line
				xor			al,IDEWR					; 4
				out			dx,al						; 8		negate the WR line
				inc			di							; 2		advance pointer to next word
				inc			di							; 2
				dec			ch							; 3
				jnz			WRITELOOP					; 16	read next word
				dec			cl
				jnz			BLOCKWRITELOOP				; loop for next block of 512 bytes
;
WRITEFAIL:		pop			ds
				pop			di
				pop			dx
				pop			cx
				pop			bx
				pop			ax
				ret
;
;-----------------------------------------------;
; write to an IDE register. the IDE register	;
; address to write + CS1 or CS3 are passed		;
; in AL. data to write in AH.					;
;												;
; entry:										;
;	AL IDE register + CSx						;
;	AH data to write							;
; exit:											;
;	all work registers saved					;
;-----------------------------------------------;
;
IDEREGWR:		push		dx
;
				push		ax
				mov			dx,IDEPPI
				mov			al,IDEDATAWR
				out			dx,al				; set PPI for IDE write
				pop			ax
;
				sub			dx,3				; PPI PA IDE data port lines
				xchg		al,ah
				out			dx,al				; write data
				xchg		al,ah
				add			dx,2				; PPI PC IDE control port
				and			al,00011111b
				out			dx,al				; set the address
				xor			al,IDEWR
				out			dx,al				; assert the WR line
				xor			al,IDEWR
				out			dx,al				; negate the WR line
				pop			dx
				ret
;
;-----------------------------------------------;
; read an IDE register. the IDE register		;
; address to read + CS1 or CS3 are passed		;
; in AL.										;
; returned value in AX							;
;												;
; entry:										;
;	AL IDE register + CSx						;
; exit:											;
;	AX IDE register contents					;
;	all work registers saved					;
;-----------------------------------------------;
;
IDEREGRD:		push		cx
				push		dx
;
				mov			cl,al				; save AL
				mov			dx,IDEPPI			; PPI IDE control port
				mov			al,IDEDATARD
				out			dx,al				; set PPI for IDE read
				mov			al,cl				; restore AL
;
				dec			dx					; PPI PC IDE control port
				and			al,00011111b
				out			dx,al				; set the address
				xor			al,IDERD
				out			dx,al				; assert the RD line
				mov			cx,ax				; save AX
				sub			dx,2				; PPI PA IDE data port lines
				in			ax,dx				; read all 16 bits
				xchg		ax,cx				; save data read and restore AX
				add			dx,2				; PPI PC IDE control port
				xor			al,IDERD
				out			dx,al				; negate the RD line
				mov			ax,cx				; restore read value
;
				pop			dx
				pop			cx
				ret
;
;-----------------------------------------------;
; perform and IDE device reset					;
; entry:										;
;	NA											;
; exit:											;
;	NA, all registers saved						;
;-----------------------------------------------;
;
IDERESET:		push		ax
				push		dx
				mov			dx,IDECNT
				mov			al,IDERST
				out			dx,al				; assert Reset line
				xor			al,IDERST
				out			dx,al				; negate Reset line
				pop			dx
				pop			ax
				ret
;
;-----------------------------------------------;
; write Command Block Registers from BIOS data	;
; location bdIDECMDBLOCK: 						;
; this will have the effect of loading and		;
; executing the IDE command						;
;												;
; entry:										;
;	IDE command in 7 byte block at [40h:42h]	;
; exit:											;
;	CF = '1' drive timed out					;
;	CF = '0' read ok							;
;	all work registers saved					;
;-----------------------------------------------;
;
IDESENDCMD:		push		ax
				mov			ax,IDETOV					; 1sec time out
				call		IDEREADY					; first check if drive is not busy
				jc			SENDFAIL					; drive is stuck in busy
				push		cx
				push		si
				push		ds							; save work registers
;
				mov			ax,BIOSDATASEG
				mov			ds,ax
				mov			si,bdIDECMDBLOCK			; [DS:SI] pointer to IDE command block
				xor			ah,ah
				mov			cx,7						; to loop through all 7 Command Block Registers
				mov			al,IDEFEATUREERR			; first register in the list
;
SENDLOOP:		mov			ah,[ds:si]					; get data to write
				call		IDEREGWR					; write a register, AL holds the IDE register address + CS1
				inc			al							; point to next register
				inc			si							; point to next location
				loop		SENDLOOP					; loop to write next register
;
				pop			ds							; restore work registers
				pop			si
				pop			cx
SENDFAIL:		pop			ax
				ret
;
;-----------------------------------------------;
; read Command Block Registers into BIOS data	;
; location bdIDECMDBLOCK: 						;
;												;
; entry:										;
;	NA											;
; exit:											;
;	IDE status in 7 byte block at [40h:42h]		;
;	all work registers saved					;
;-----------------------------------------------;
;
IDERECVCMD:		push		ax
				push		bx
				push		cx
				push		di
				push		ds							; save work registers
;
				mov			ax,BIOSDATASEG
				mov			ds,ax
				mov			di,bdIDECMDBLOCK			; [DS:DI] pointer to IDE command block
				mov			cx,7						; to loop through all 7 Command Block Registers
				mov			bl,IDEFEATUREERR			; first register in the list
;
RECVLOOP:		mov			al,bl
				call		IDEREGRD					; read a register
				mov			[ds:di],al					; store byte value
				inc			bl							; point to next register
				inc			di							; point to next location
				loop		RECVLOOP					; loop to read next register
;
				pop			ds							; restore work registers
				pop			di
				pop			cx
				pop			bx
RECVFAIL:		pop			ax
				ret
;
;-----------------------------------------------;
; poll IDE device and return when it is ready	;
; IDE bits BSY='0' and DRDY='1'					;
; routine will monitor time out counter			;
;												;
; entry:										;
;	AX time out in BIOS ticks					;
; exit:											;
;	CF = '1' waiting for ready timed out		;
;	CF = '0' device is ready					;
;	all work registers saved					;
;-----------------------------------------------;
;
IDEREADY:		push		bx
				push		cx
				push		ds							; save work registers
;
				mov			bx,BIOSDATASEG
				mov			ds,bx						; establish BIOS data structure pointer
;
				mov			bx,ax
				xor			cx,cx
				cli
				add			bx,[ds:bdTIMELOW]			; determine future tick count to wait in DX,AX
				adc			cx,[ds:bdTIMEHI]
				sti										; restore interrupts
;
IDEWAITLOOP:	mov			al,IDECMDSTATUS				; read the IDE status register
				call		IDEREGRD
				and			al,(IDESTATBSY+IDESTATRDY)	; check BSY='0' and DRDY='1'
				xor			al,IDESTATRDY
				jz			IDENOTBSY					; continue out if drive is ready
				cmp			cx,[ds:bdTIMEHI]			; have we reached end of time out high word?
				ja			IDEWAITLOOP					; no, loop back to keep waiting
				cmp			bx,[ds:bdTIMELOW]			; have we reached end of time out low word?
				ja			IDEWAITLOOP					;  no, continue to wait
;
				stc										;  yes, indicate time-out condition
				jmp			IDEREADYEXIT
;
IDENOTBSY:		clc										; IDE is ready, clear CY.f
;
IDEREADYEXIT:	pop			ds
				pop			cx
				pop			bx
				ret
;
;-----------------------------------------------;
; poll IDE device and return when DRQ='1'		;
; routine will monitor time out counter			;
;												;
; entry:										;
;	AX time out in BIOS ticks					;
; exit:											;
;	CF = '1' waiting for DRQ timed out			;
;	CF = '0' DRQ asserted						;
;	all work registers saved					;
;-----------------------------------------------;
;
IDEDRQ:			push		bx
				push		cx
				push		ds
;
				mov			bx,BIOSDATASEG
				mov			ds,bx						; establish BIOS data structure
;
				mov			bx,ax
				xor			cx,cx
				cli
				add			bx,[ds:bdTIMELOW]			; determine future tick count to wait in DX,AX
				adc			cx,[ds:bdTIMEHI]
				sti										; restore interrupts
;
IDEWAITDRQ:		mov			al,IDECMDSTATUS				; read the IDE status register
				call		IDEREGRD
				and			al,IDESTATDRQ				; check DRQ must be '1'
				jnz			IDEDRQ1						; if DRQ='1' continue out
				cmp			cx,[ds:bdTIMEHI]			; have we reached end of time out high word?
				ja			IDEWAITDRQ					; no, loop back to keep waiting
				cmp			bx,[ds:bdTIMELOW]			; have we reached end of time out low word?
				ja			IDEWAITDRQ					;  no, loop to wait for DRQ
;
				stc										;  yes, indicate time-out condition
				jmp			IDEDRQEXIT
;
IDEDRQ1:		clc										; clear CY.f (the AND will do this anyway...)
;
IDEDRQEXIT:		pop			ds
				pop			cx
				pop			bx
				ret
;
;-----------------------------------------------;
; this subroutine maps cylinder-head-sector		;
; to LBA. mapping is calculated for a given		;
; drive per drive parameters.					;
; LBA formula:									;
;   LBA=(c * H + h) * S + (s - 1)				;
;		c - cylinder/track in CH/ CL b6..7		;
;		s - sector CL b0..5						;
;		h - head DH								;
;		S - sectors per track					;
;		H - heads per drive						;
; IDE drive absolut LBA will be calculated by	;
; adding the 'ddDRVHOSTOFF' parameter from the	;
; drive data structure.							;
;												;
; entry:										;
;	CH track number								;
;	CL sector number & 2 high bits of track num	;
;	DH head number								;
;	DL drive									;
; exit:											;
;	AL low LBA byte b0..b7						;
;	AH mid LBA byte b8..b15						;
;	DL high LBA byte b16..b23					;
;	DH high LBA nible b24..b27					;
;	CY.f = 0 conversion ok						;
;	CY.f = 1 failed, CHS out of range			;
;	all other work registers preserved			;
;-----------------------------------------------;
;
CHS2LBA:		push		di
				push		es
				push		bp
				mov			bp,sp						; establish calculator stack
				call		CHECKDRV					; check for valid drive ID, should be valid here
				jc			CHS2LBAERR					; not valid (odd!) so exit with CY.f set
;
;-----	store formula parameters on stack
;
				mov			al,cl						; get sector number
				and			al,00111111b				; clear cylinder bits
				cbw										; convert to word
				dec			ax							; subtract 1
				push		ax							; save on stack (s - 1) @ [bp-2]
				mov			al,[es:di+ddDRVGEOSEC]		; get sectors per track
				cbw										; conver to word
				push		ax							; save on stack S @ [bp-4]
				mov			al,dh						; get head number
				cbw										; conver to word
				push		ax							; save on stack	h @ [bp-6]
				mov			al,[es:di+ddDRVGEOHEAD]		; get head count
				cbw										; conver to word
				push		ax							; save on stack H @ [bp-8]
				mov			al,ch						; low order cylinder number
				mov			ah,cl						; get high order cylinder bits
				rol			ah,1						; rotate into place
				rol			ah,1
				and			ah,00000011b				; zero out all bit except for b0 and b1
;
;-----	calculate/translate CHS to LBA
;
;														; this assumes that the multiplication result fits in AX
				mul			word [bp-8]					; ( s * H
				add			ax,word [bp-6]				;         + h )
				mul			word [bp-4]					;               * S
				add         ax,word [bp-2]				;                   + (s-1)
;
				add			ax,[es:di+ddDRVHOSTOFF]		; add LBA offset for virtual drive location
				adc			ax,0						; complete the 32 bit addition
;
;-----	exit
;
				mov			sp,bp						; restore SP
CHS2LBAERR:		pop			bp
				pop			es
				pop			di
				ret
;
;-----------------------------------------------;
; this subroutine checks the existance of the 	;
; drive number passed in DL, and returns a		;
; pointer to the drive's parameter table		;
;												;
; entry:										;
;	DL drive number/ID							;
; exit:											;
;	ES:DI drive parameter table					;
;	CY.f = 0 conversion ok						;
;	CY.f = 1 failed, CHS out of range			;
;	all other work registers preserved			;
;-----------------------------------------------;
;
CHECKDRV:		push		ax
				push		cx
				push		si
;
				mov			ax,cs						; make ES = CS
				mov			es,ax
				mov			si,(DRVPARAM+ROMOFF)		; establish pointer to ROM drive table
				mov			al,[es:si]					; get drive count
				cbw
				mov			cx,ax						; make CX into a counter
				inc			si							; point to drive-data tables pointer list
;
NEXTDRIVE:		mov			di,[es:si]					; DI = pointer offset to drive data table
				cmp			dl,[es:di]					; does this drive match requested drive ID in DL?
				jz			FOUNDDRIVE					;  yes, return drive parameters
				add			si,2						;  no, point to next drive on the list
				loop		NEXTDRIVE					; loop to handle all drives
				stc										; drive not found indicate function error
				jmp			CHKDRVEXIT					; exit
;
FOUNDDRIVE:		clc										; no error
CHKDRVEXIT:		pop			si
				pop			cx
				pop			ax
				ret
;
;-----------------------------------------------;
; this subroutine returns the drives attached	;
; to the system.								;
;												;
; entry:										;
;	NA											;
; exit:											;
;	AL number of drives							;
;	all other work registers preserved			;
;-----------------------------------------------;
;
COUNTDRV:		mov			al,[cs:(DRVPARAM+ROMOFF)]	; get drive count
				ret
;
;-----------------------------------------------;
; this subroutine drives the 7-segment display.	;
; display is connected to PPI PA replacing the	;
; keyboard hardware.							;
;												;
; entry:										;
;	AL number 00h to 0Fh to display, FFh blank	;
;	AH 00h D.P. off, 80h D.P. on				;
; exit:											;
;	all registers preserved						;
;-----------------------------------------------;
;
SEVENSEG:		cmp			al,0fh						; is number in range
				ja			SEVENSEGEXIT				; exit if out of range
				cmp			al,0ffh						; is this a blanking request
				jnz			SEVENSEGDISP				; no, go to a display routine
				out			PPIPA,al					; yes, blank the display
				jmp			SEVENSEGEXIT				; and exit
;
SEVENSEGDISP:	push		si							; save work registers
				mov			si,ax						; save command in SI
				cbw										; AX is index into 7-segment LED pattern table
				xchg		si,ax						; AX has original command, SI has index into table
				mov			al,[cs:si+SEGMENTTBL+ROMOFF]; convert number in AL to 7-seg pattern
				xor			al,ah						; turn D.P on or off
				out			PPIPA,al					; display digit
				pop			si
SEVENSEGEXIT:	ret
;
;-----------------------------------------------;
; this subroutine will sound the beeper using	;
; timer-2 to generate a tone.					;
;												;
; entry:										;
;	BL duration 1 = 1/64 of second				;
;	CX frequency (1193180/freq.) 1331 for 886Hz	;
; exit:											;
;	AX, BL, CX modified 						;
;-----------------------------------------------;
; @@- (5-96/244 line 1395)
;
BEEP:			push		ax
				push		cx
				pushf									; save interrupt state
				cli										; disable during updates
				mov			al,10110110b				; generate square wave
				out			TIMERCTRL,al				; on channel 2 (speaker)
				nop
				mov			al,cl						; divisor for Hz
				out			TIMER2,al					; low order count
				nop
				mov			al,ch
				out			TIMER2,al					; high order count
				in			al,PPIPB					; get timer control port state
				mov			ah,al						; save it
				or			al,00000011b				; ebale the timer/speaker
				out			PPIPB,al
				popf									; restore interrupts
;
BEEPLOOP:		mov			cx,4320						; delay to achieve 1/64 sec @ 4.7MHz clock (CX=7353 @ 8MHz)
WAITBEEP:		loop		WAITBEEP					; wait 1/64 of sec
				dec			bl
				jnz			BEEPLOOP					; repeate delay count
;
				pushf									; save interrupt state
				cli										; and disable during changes
				mov			al,ah
				out			PPIPB,al					; restore speaker control to off
				popf									; restore interrupts and registers
				pop			cx
				pop			ax
				ret
;
;-----------------------------------------------;
; fixed time wait that is not processor related	;
; uses time of day clock, but is not accurate	;									;
;												;
; entry:										;
;	AX count of 200mSec intervals to wait		;
; exit:											;
;	AX = 0, function blocks!					;
;-----------------------------------------------;
; @@- original BIOS function on page 5-96/244 line 1448
WAITFIX:		push		ax
				push		bx
				push		dx
				push		ds							; save work registers
				mov			bx,BIOSDATASEG
				mov			ds,bx						; establish BIOS data structure
;
				xor			dx,dx
				mov			bx,11
				mul			bx							; (11 x 18.2mSec per tick = 200mSec) x AX
				cli										; temporarily stop interrupts
				add			ax,[ds:bdTIMELOW]			; determine future tick count to wait in DX,AX
				adc			dx,[ds:bdTIMEHI]
				sti										; restore interrupts
;
WAITLOOP:		cmp			dx,[ds:bdTIMEHI]			; have we reached end of time out high word?
				ja			WAITLOOP					; no, loop back to keep waiting
				cmp			ax,[ds:bdTIMELOW]			; have we reached end of time out low word?
				ja			WAITLOOP
;
				pop			ds
				pop			dx
				pop			bx
				pop			ax
				ret

;
;-----------------------------------------------;
; this routine will use the ASCII code of a		;
; character in AL to look up and return its 	;
; keyboard scan code in AH.						;
; this is used by INT 16 to fake keyboard scan	;
; codes.										;
;												;
; entry:										;
;	AL ASCII code of character					;
; exit:											;
;	AH keyboard scan code, AL preserved			;
;	all other work registers saved				;
;-----------------------------------------------;
;
ASCII2SCANCODE:	xor			ah,ah
				cmp			al,ASCIILIST				; check if ASCII code is out of table range
				jae			NOSCANCODE					; yes, exit with scan code AH=0
				push		si
				cbw										; AX is index into scan code look up table
				mov			si,ax						; SI now has index too
				mov			ah,[cs:si+ASCII2SCAN+ROMOFF]; get scan code byte
				pop			si
NOSCANCODE:		ret
;
;	*********************************
;	***       STATIC DATA         ***
;	*********************************
;
;-----	dummy stack with return addresses for 'call's with no RAM
;
UARTTESTRET:	dw			(WAITBYTE+ROMOFF)			; UART test
BANNERPRRET:	dw			(PRINTBANNER+ROMOFF)		; banner print
CP1PRRET:		dw			(PRINTCP1+ROMOFF)			; check point 1
TIMEROKPRRET:	dw			(PRINTTIMEROK+ROMOFF)		; timer ok print
CP2PRRET:		dw			(PRINTCP2+ROMOFF)			; check point 2
TIMERERRPRRET:	dw			(PRINTTIMERERR+ROMOFF)		; timer error print
DMAOKPRRET:		dw			(PRINTDMAOK+ROMOFF)			; DMA ok print
CP3PRRET:		dw			(PRINTCP3+ROMOFF)			; check point 3
DMAERRPRRET:	dw			(PRINTDMAERR+ROMOFF)		; DMA error print
MEM2KERRPRRET:	dw			(PRINTMEM2KERR+ROMOFF)		; first 2K byte error print
MEMTESTRET1:	dw			(MEM1KCHECK+ROMOFF)			; first 1K memory test
MEMTESTRET2:	dw			(MEM2KCHECK+ROMOFF)			; second 1K memory test
;
;-----	implemented interrupt service routines:    ^^^
; @@- 5-107/255 line 2585
VECTORS:		dw			(IGNORE+ROMOFF)				;		00h Divide by zero
				dw			(IGNORE+ROMOFF)				;		01h Single step
				dw			(INT02+ROMOFF)				;	y	02h NMI
				dw			(IGNORE+ROMOFF)				;		03h Breakpoint
				dw			(IGNORE+ROMOFF)				;		04h Overflow
				dw			(IGNORE+ROMOFF)				;		05h print screen
				dw			(IGNORE+ROMOFF)				;		06h Reserved
				dw			(IGNORE+ROMOFF)				;		07h Reserved
				dw			(INT08+ROMOFF)				;	y	08h (IRQ0) Timer tick					[timer tick]
				dw			(IGNORE+ROMOFF)				;		09h (IRQ1) Keyboard attention			[masked]
				dw			(INT0A+ROMOFF)				;	y	0Ah (IRQ2) Video (5-49/197 line 278)	[UART console input]
				dw			(IGNORE+ROMOFF)				;		0Bh (IRQ3) COM2 serial i/o				[masked]
				dw			(IGNORE+ROMOFF)				;		0Ch (IRQ4) COM1 serial i/o				[masked]
				dw			(INT0D+ROMOFF)				;	n	0Dh (IRQ5) Hard disk attn. 				[IDE -> masked]
				dw			(IGNORE+ROMOFF)				;		0Eh (IRQ6) Floppy disk attention		[masked]
				dw			(IGNORE+ROMOFF)				;		0Fh (IRQ7) Parallel printer				[masked]
				dw			(INT10+ROMOFF)				;	y	10h Video bios services (5-62/210 line 52)
				dw			(INT11+ROMOFF)				;	y	11h Equipment present
				dw			(INT12+ROMOFF)				;	Y	12h Memories size services
				dw			(INT13+ROMOFF)				;	y	13h Disk bios services (5-23/171 line 4)
				dw			(IGNORE+ROMOFF)				;		14h Serial com. services
				dw			(INT15+ROMOFF)				;	y	15h Expansion bios services
				dw			(INT16+ROMOFF)				;	y	16h Keyboard bios services (5-46/194 line 4)
				dw			(IGNORE+ROMOFF)				;		17h Parallel printer services
				dw			(MONITOR+ROMOFF)			;	y	18h monitor mode entry point (ROM Basic)
				dw			(INT19+ROMOFF)				;	y	19h Bootstrap (5-94/242 line 1181)
				dw			(INT1A+ROMOFF)				;	y	1Ah Time/date services (5-95/243 line 1294)
				dw			(IGNORE+ROMOFF)				;		1Bh Keyboard break user service
				dw			(INT1C+ROMOFF)				;		1Ch System tick user service
				dw			0							;		1Dh Address of Video parameter table
				dw			0							;		1Eh Address of Disk parameter table
				dw			0							;		1Fh Graphic charactr table ptr
;
;-----	drive parameters
;
; using IDE drive model IC25N020ATCS04 as a host drive
; for emulated floppy and HDD.
; the table below enumerates the number of emulated
; floppy/HDD and their geometries.
; emulation will:
;  (1) calculate LBA number based on listed geometry
;  (2) add LBA offset that will position the emulated floppy/HDD
;      in the LBA list of the host drive.
;  (3) hosr drive has 39,070,000 addressable LBAs; resulting
;      LBA from #2 shall not exceed maximum addresable LBAs
;
DRVPARAM:		db			3							; attached drives (max of 3, 2 x floppy, 1 x HDD)
DRVTABLE:		dw			(DRV0+ROMOFF)				; parameter table for drive 0 (floppy A:)
				dw			(DRV1+ROMOFF)				; parameter table for drive 1 (floppy B:)
				dw			(DRV2+ROMOFF)				; parameter table for drive 2 (HDD C:)
;
DRV0:			db			00h							; [ddDRIVEID]    drive ID
				db			1							; [ddDASDTYPE]   diskette, no change detection present (see INT 13, 08h and 15h)
				db			4							; [ddCMOSTYPE]   1 = 5.25/360K, 2 = 5.25/1.2Mb, 3 = 3.5/720K, 4 = 3.5/1.44Mb
				dw			80							; [ddDRVGEOCYL]  # cylinders -> 3.5" floppy 1.44MB (0..79)
				db			2							; [ddDRVGEOHEAD] # heads (0..1)
				db			18							; [ddDRVGEOSEC]  # sectors/track (1..18)
				dw			2880						; [ddDRVMAXLBA]  Max LBAs (0..2879)
				dw			0							; [ddDRVHOSTOFF] LBA offset into IDE host drive
DRV0DBT:		db			0							; specify byte 1; step-rate time, head unload time
				db			0							; specify byte 2; head load time, DMA mode
				db			1							; timer ticks to wait before disk motor shutoff
				db			2							; bytes per sector code: 0 = 128, 1 = 256, 2 = 512, 3 = 1024
				db			18							; sectors per track (last sector number)
				db			0							; inter-block gap length/gap between sectors
				db			0ffh						; data length, if sector length not specified
				db			0							; gap length between sectors for format
				db			FORMATFILL					; fill byte for formatted sectors
				db			1							; head settle time in milliseconds
				db			1							; motor startup time in eighths of a second
;
DRV1:			db			01h							; drive ID
				db			1							; type = diskette, no change detection present (see INT 13, 08h and 15h)
				db			4							; CMOS drive type: 1 = 5.25/360K, 2 = 5.25/1.2Mb, 3 = 3.5/720K, 4 = 3.5/1.44Mb
				dw			80							; # cylinders -> 3.5" floppy 1.44MB (0..79)
				db			2							; # heads (0..1)
				db			18							; # sectors/track (1..18)
				dw			2880						; Max LBAs (0..2879)
				dw			3000						; LBA offset into IDE host drive
DRV1DBT:		db			0							; specify byte 1; step-rate time, head unload time
				db			0							; specify byte 2; head load time, DMA mode
				db			1							; timer ticks to wait before disk motor shutoff
				db			2							; bytes per sector code: 0 = 128, 1 = 256, 2 = 512, 3 = 1024
				db			18							; sectors per track (last sector number)
				db			0							; inter-block gap length/gap between sectors
				db			0ffh						; data length, if sector length not specified
				db			0							; gap length between sectors for format
				db			FORMATFILL					; fill byte for formatted sectors
				db			1							; head settle time in milliseconds
				db			1							; motor startup time in eighths of a second
;
DRV2:			db			80h							; drive ID
				db			3							; type = HDD, fixed disk (see INT 13, 15h)
				db			0							; CMOS drive type: 1 = 5.25/360K, 2 = 5.25/1.2Mb, 3 = 3.5/720K, 4 = 3.5/1.44Mb
				dw			612							; # cylinders -> HDD 20MB (0..611)
				db			4							; # heads (0..3)
				db			17							; # sectors/track (1..17)
				dw			41616 						; Max LBAs (0..41615)
				dw			6000						; LBA offset into IDE host drive
DRV2DBT:		db			0							; specify byte 1; step-rate time, head unload time
				db			0							; specify byte 2; head load time, DMA mode
				db			1							; timer ticks to wait before disk motor shutoff
				db			2							; bytes per sector code: 0 = 128, 1 = 256, 2 = 512, 3 = 1024
				db			17							; sectors per track (last sector number)
				db			0							; inter-block gap length/gap between sectors
				db			0ffh						; data length, if sector length not specified
				db			0							; gap length between sectors for format
				db			FORMATFILL					; fill byte for formatted sectors
				db			1							; head settle time in milliseconds
				db			1							; motor startup time in eighths of a second
;
;DRV2DBT:		dw			612							; maximum number of cylinders
;				db			4							; maximum number of heads
;				dw			0							; starting reduced write current cylinder
;				dw			0							; starting write pre-comp cylinder
;				db			128							; maximum ECC data burst length
;				db			0							; control byte:
;				db			0							;
;				db			0							; 3 bytes not used for PC/XT
;				db			0							;
;				dw			0							; landing zone
;				db			17							; sectors per track
;				db			0							; reserved
;
;-----	text strings
;
CRZ:			db			CR, 0
LFZ:			db			LF, 0
TABZ:			db			TAB, 0
;
CHECKPOINT1:	db			TAB, "=== CHECK POINT 1", CR, LF, 0
CHECKPOINT2:	db			TAB, "=== CHECK POINT 2", CR, LF, 0
CHECKPOINT3:	db			TAB, "=== CHECK POINT 3", CR, LF, 0
CHECKPOINT4:	db			TAB, "=== CHECK POINT 4", CR, LF, 0
CHECKPOINT5:	db			TAB, "=== CHECK POINT 5", CR, LF, 0
CHECKPOINT6:	db			TAB, "=== CHECK POINT 6", CR, LF, 0
CHECKPOINT7:	db			TAB, "=== CHECK POINT 7", CR, LF, 0
CHECKPOINT8:	db			TAB, "=== CHECK POINT 8", CR, LF, 0
CHECKPOINT9:	db			TAB, "=== CHECK POINT 9", CR, LF, CR, LF, 0
;
BANNER:         db          CR, LF
				db			"XT New Bios, 8088 cpu", CR, LF
				db			"Eyal Abraham, 2013 (c)", CR, LF
                db          "build: "
                db          __DATE__
                db          " "
                db          __TIME__, CR, LF, CR, LF
                db			"82C50/16550 UART ok"
;
CRLF:           db          CR, LF, 0					; this is still part of the BANNER: ...
;
OKMSG:			db			"ok", CR, LF, 0
FAILMSG:		db			"fail", CR, LF, 0
HALTMSG:		db			"halting.", 0
TIMEROK:		db			"8253 timer ok", CR, LF, 0
TIMERERR:		db			"8253 timer fail", CR, LF, "halting.", 0
DMAOK:			db			"8237 DMA controller ok", CR, LF, "RAM refresh active", CR, LF, 0
DMAERR:			db			"8237 DMA controller write/verify fail", CR, LF, "halting.", 0
MEMTEST2KOK:	db			"first 2K byte memory test ok", CR, LF, "stack set", CR, LF, 0
MEMTEST2KERR:	db			"first 2K byte memery test fail", CR, LF, "halting.", 0
INTVECOK:		db			"interrupt vectors and interrupt service set", CR, LF, 0
SYSCONFIG:		db			"system configuration switchs: 0x", 0
RAMTESTMSG:		db			CR, "RAM test: ", 0
KBMSG:			db			"KB", 0
RAMTESTERR:		db			CR, LF, "RAM test fail", CR, LF, "halting.", 0
INTENAMSG:		db			"IRQ0 (timer-0) and IRQ2 (UART) enabled", CR, LF, 0
PARITYERR:		db			CR, LF, "RAM parity error detected", CR, LF, "halting.", 0
IDEINITMSG:		db			"IDE init ", 0
IDERSTMSG:		db			"(reset) ", 0
IDENOTRDY:		db			"- not ready after power-on - ", 0
IDEDIAGMSG:		db			"IDE diagnostics ", 0
IDEIDENTITYMSG:	db			"IDE identity ", 0
DRIVEEMULMSG:	db			"emulated drive ", 0
CYLMSG:			db			"  cylinders  ", 0
HEADSMSG:		db			"  heads      ", 0
SECMSG:			db			"  sectors    ", 0
SERIALMSG:		db			"  serial     [", 0
MODELMSG:		db			"  model      [", 0
TYPE1MSG:		db			"  type       01 diskette, no change detection", CR, LF, 0
TYPE2MSG:		db			"  type       02 diskette, change detection", CR, LF, 0
TYPE3MSG:		db			"  type       03 fixed disk", CR, LF, 0
LBAOFFMSG:		db			"  LBA offset ", 0
BOOTINGMSG:		db			"booting OS", CR, LF, 0
IPLFAILMSG:		db			"OS boot (IPL) failed", CR, LF, 0
;
;-----	text strings for INT function debug
;
INT10DBG:		db			"=== int-10 unhandled function 0x", 0
INT13DBG:		db			"=== int-13 unhandled function 0x", 0
INT16DBG:		db			"=== int-16 unhandled function 0x", 0
;
;-----	7-seg bit table   dp gfedcba
;                           \|||||||
SEGMENTTBL:		db			11000000b					; '0' note: segment is on with '0'
				db			11111001b					; '1'
				db			10100100b					; '2'
				db			10110000b					; '3'
				db			10011001b					; '4'
				db			10010010b					; '5'
				db			10000010b					; '6'
				db			11111000b					; '7'
				db			10000000b					; '8'
				db			10010000b					; '9'
				db			10001000b					; 'A'
				db			10000011b					; 'b'
				db			10000110b					; 'C'
				db			11000001b					; 'd'
				db			10000110b					; 'E'
				db			10001110b					; 'F'
				db			10001001b					; 'H'
				db			10001100b					; 'P'
;
SEGH:			equ			16							; index for 7-segment 'H'
SEGP:			equ			17							; index for 7-segment 'P'
;
;-----	ASCII to SCAN CODE table
; source: http://stanislavs.org/helppc/scan_codes.html
;														; DEC	Symbol 	Description
ASCII2SCAN:		db			000h						; 0		NUL		Null char
				db			000h						; 1		SOH		Start of Heading
				db			000h						; 2		STX		Start of Text
				db			000h						; 3		ETX		End of Text
				db			000h						; 4		EOT		End of Transmission
				db			000h						; 5		ENQ		Enquiry
				db			000h						; 6		ACK		Acknowledgment
				db			000h						; 7		BEL		Bell
				db			00eh						; 8		BS		Back Space
				db			00fh						; 9		HT		Horizontal Tab
				db			000h						; 10	LF		Line Feed
				db			000h						; 11	VT		Vertical Tab
				db			000h						; 12	FF		Form Feed
				db			01ch						; 13	CR		Carriage Return
				db			000h						; 14	SO		Shift Out / X-On
				db			000h						; 15	SI		Shift In / X-Off
				db			000h						; 16	DLE		Data Line Escape
				db			000h						; 17	DC1		Device Control 1 (oft. XON)
				db			000h						; 18	DC2		Device Control 2
				db			000h						; 19	DC3		Device Control 3 (oft. XOFF)
				db			000h						; 20	DC4		Device Control 4
				db			000h						; 21	NAK		Negative Acknowledgement
				db			000h						; 22	SYN		Synchronous Idle
				db			000h						; 23	ETB		End of Transmit Block
				db			000h						; 24	CAN		Cancel
				db			000h						; 25	EM		End of Medium
				db			000h						; 26	SUB		Substitute
				db			001h						; 27	ESC		Escape
				db			000h						; 28	FS		File Separator
				db			000h						; 29	GS		Group Separator
				db			000h						; 30	RS		Record Separator
				db			000h						; 31	US		Unit Separator
				db			039h						; 32	 		Space
				db			002h						; 33	!		Exclamation mark
				db			028h						; 34	"		Double quotes (or speech marks)
				db			004h						; 35	#		Number
				db			005h						; 36	$		Dollar
				db			006h						; 37	%		Percent
				db			008h						; 38	&		Ampersand
				db			028h						; 39	'		Single quote
				db			00ah						; 40	(		Open parenthesis (or open bracket)
				db			00bh						; 41	)		Close parenthesis (or close bracket)
				db			009h						; 42	*		Asterisk
				db			00dh						; 43	+		Plus
				db			033h						; 44	,		Comma
				db			00ch						; 45	-		Hyphen
				db			034h						; 46	.		Period, dot or full stop
				db			035h						; 47	/		Slash or divide
				db			00bh						; 48	0		Zero
				db			002h						; 49	1		One
				db			003h						; 50	2		Two
				db			004h						; 51	3		Three
				db			005h						; 52	4		Four
				db			006h						; 53	5		Five
				db			007h						; 54	6		Six
				db			008h						; 55	7		Seven
				db			009h						; 56	8		Eight
				db			00ah						; 57	9		Nine
				db			027h						; 58	:		Colon
				db			027h						; 59	;		Semicolon
				db			033h						; 60	<		Less than (or open angled bracket)
				db			00dh						; 61	=		Equals
				db			034h						; 62	>		Greater than (or close angled bracket)
				db			035h						; 63	?		Question mark
				db			003h						; 64	@		At symbol
				db			01eh						; 65	A		Uppercase A
				db			030h						; 66	B		Uppercase B
				db			02eh						; 67	C		Uppercase C
				db			020h						; 68	D		Uppercase D
				db			012h						; 69	E		Uppercase E
				db			021h						; 70	F		Uppercase F
				db			022h						; 71	G		Uppercase G
				db			023h						; 72	H		Uppercase H
				db			017h						; 73	I		Uppercase I
				db			024h						; 74	J		Uppercase J
				db			025h						; 75	K		Uppercase K
				db			026h						; 76	L		Uppercase L
				db			032h						; 77	M		Uppercase M
				db			031h						; 78	N		Uppercase N
				db			018h						; 79	O		Uppercase O
				db			019h						; 80	P		Uppercase P
				db			010h						; 81	Q		Uppercase Q
				db			013h						; 82	R		Uppercase R
				db			01fh						; 83	S		Uppercase S
				db			014h						; 84	T		Uppercase T
				db			016h						; 85	U		Uppercase U
				db			02fh						; 86	V		Uppercase V
				db			011h						; 87	W		Uppercase W
				db			02dh						; 88	X		Uppercase X
				db			015h						; 89	Y		Uppercase Y
				db			02ch						; 90	Z		Uppercase Z
				db			01ah						; 91	[		Opening bracket
				db			02bh						; 92	\		Backslash
				db			01bh						; 93	]		Closing bracket
				db			007h						; 94	^		Caret - circumflex
				db			00ch						; 95	_		Underscore
				db			029h						; 96	`		Grave accent
				db			01eh						; 97	a		Lowercase a
				db			030h						; 98	b		Lowercase b
				db			02eh						; 99	c		Lowercase c
				db			020h						; 100	d		Lowercase d
				db			012h						; 101	e		Lowercase e
				db			021h						; 102	f		Lowercase f
				db			022h						; 103	g		Lowercase g
				db			023h						; 104	h		Lowercase h
				db			017h						; 105	i		Lowercase i
				db			024h						; 106	j		Lowercase j
				db			025h						; 107	k		Lowercase k
				db			026h						; 108	l		Lowercase l
				db			032h						; 109	m		Lowercase m
				db			031h						; 110	n		Lowercase n
				db			018h						; 111	o		Lowercase o
				db			019h						; 112	p		Lowercase p
				db			010h						; 113	q		Lowercase q
				db			013h						; 114	r		Lowercase r
				db			01fh						; 115	s		Lowercase s
				db			014h						; 116	t		Lowercase t
				db			016h						; 117	u		Lowercase u
				db			02fh						; 118	v		Lowercase v
				db			011h						; 119	w		Lowercase w
				db			02dh						; 120	x		Lowercase x
				db			015h						; 121	y		Lowercase y
				db			02ch						; 122	z		Lowercase z
				db			01ah						; 123	{		Opening brace
				db			02bh						; 124	|		Vertical bar
				db			01bh						; 125	}		Closing brace
				db			029h						; 126	~		Equivalency sign - tilde
				db			053h						; 127			Delete
;
ASCIILIST:		equ			($-ASCII2SCAN)							; ASCII table length for range checking
;
;-----  sector filled with formatting byte to use for INT13/05 format track
;
EMPTYSECTOR:    times 512 db FORMATFILL                             ; 512 bytes for sector formatting
;
;	*********************************
;	*** RESET VECTOR AND EPILOG   ***
;	*********************************
;
segment         resetvector start=(RSTVEC-ROMOFF) 
POWER:          jmp         word ROMSEG:(COLD+ROMOFF)	; Hardware power reset entry
;
segment         releasedate start=(RELDATE-ROMOFF)
                db          "11/23/13"          		; Release date MM/DD/YY
;
segment         checksum    start=(CHECKSUM-ROMOFF)
                db          0feh                		; Computer type (XT)
                db          0ffh               			; Checksum byte
;
; -- end of file --
;

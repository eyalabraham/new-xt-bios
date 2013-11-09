;********************************************************************
; iodef.asm
;
;  BIOS rewrite for PC/XT
;
;  BIOS replacement for PC/XT clone
;  io port definitions.
;
;********************************************************************
;
; change log
;------------
; created       02/02/2013              file structure
;
;
;======================================
; general equates
;======================================
;
LF:          	equ         0ah							; line feed
CR:          	equ         0dh							; carriage return
TAB:			equ			09h							; horizontal tab
BS:				equ			08h							; back space
SPACE:			equ			20h							; space
;
;======================================
; XMODEM equates
;======================================
;
FUNCDRIVEWR:	equ			1							; Rx from XMODEM and write to HDD
FUNCMEMWR:		equ			2							; Rx from XMODEM and write to memory
;
XSTART:			equ			43h							; "C" to start XMODEM connection
SOH:  			equ			01h							; start a 128B packet session
STX:  			equ			02h							; start a 1KB session
EOT:  			equ			04h							; end of session
ACK:  			equ			06h							; 'acknowledge'
NAK:  			equ			15h							; 'no acknowledge'
CAN:  			equ			18h							; cancel session
CTRLZ:  		equ			1ah
;
HOSTWAITTOV:	equ			15							; 15 seconds to wait for host connection after "C"
XMODEMTOV:		equ			55							; 1 sec time out (55 x 18.2 mSec)
XMODEMSEC:		equ			2							; number of sectors (512B) to write at once
XMODEMBUFFER:	equ			133							; XMODEM character buffer size
XMODEMPACKET:	equ			128							; XMODEM data packet size
XMODEMCANSEQ:	equ			3							; number of CAN chracters to send
;
;======================================
; general macros
;======================================
;
;-----	print a zero terminated string
;
%macro			mcrPRINT	1
				push		ax
				push		si
				push		ds
				mov			ax,cs
				mov			ds,ax
				mov			si,(%1+ROMOFF)		; get message string address
				call		PRINTSTZ			; and print
				pop			ds
				pop			si
				pop			ax
%endmacro
;
;-----	quick 7-segment display
;
%macro			mcr7SEG		1
				mov			al,[cs:SEGMENTTBL+ROMOFF+%1]
				out			PPIPA,al
%endmacro
;
;======================================
; CRT properties
;======================================
;
CRTCOLUMNS:		equ			80					; 80 columns
CRTMODE:		equ			7					; 80x25 Monochrome text (MDA,HERC,EGA,VGA)
DEFVIDEOPAGE:	equ			0					; page #1
;
;======================================
; IO port definitions
; PC/XT standard IO port range
;======================================
;
;--------------------------------------
; 8237 DMA controller
;--------------------------------------
;
CBAR0:			equ			000h				; ch-0 Current / Base Address Register
CBWC0:			equ			001h				; ch-0 Current  / Base Word Count Register
CBAR1:			equ			002h				; ch-1 Current / Base Address Register
CBWC1:			equ			003h				; ch-1 Current  / Base Word Count Register
CBAR2:			equ			004h				; ch-2 Current / Base Address Register
CBWC2:			equ			005h				; ch-2 Current  / Base Word Count Register
CBAR3:			equ			006h				; ch-3 Current / Base Address Register
CBWC3:			equ			007h				; ch-3 Current  / Base Word Count Register
;
DMACMD:			equ			008h				; Command Register (wr)
DMASTAT:		equ			008h				; Status Register (rd)
DMAREQ:			equ			009h				; Request Register (wr)
DMAMASK:		equ			00ah				; Mask Register (wr)
DMAMODE:		equ			00bh				; Mode Register (wr)
DMACLRFF:		equ			00ch				; Clear First/Last Flip-Flop (wr)
DMAMCLR:		equ			00dh				; Master Clear (wr)
DMAALLMASK:		equ			00fh				; All Mask Register (wr)
;
DMACMDINIT:		equ			00000100b
;							||||||||
;							|||||||+--- b0..Memory-Memory Transfer (dis=0)
;							||||||+----	b1..Channel 0 Address Hold (dis=0)
;							|||||+----- b2..Controller Disable     (dis=1)
;							||||+------	b3..Timing                 (normal=0)
;							|||+-------	b4..Priority               (fixed=0)
;							||+--------	b5..Write Pulse Width      (normal=0)
;							|+--------- b6..DREQ Sense             (active H=0)
;							+----------	b7..DACK Sense             (active L=0)
;
DMACH0MODE:		equ			01011000b
;							||||||||
;							||||||++--- b0,b1.. channle 0 ('00')
;							||||++----- b2,b3.. read transfer ('10')
;							|||+-------	b4..    auto init enabled
;							||+--------	b5..    address increment
;							++--------- b6,b7.. single mode ('01')
;
DMACH1MODE:		equ			01000001b
;							||||||||
;							||||||++--- b0,b1.. channle 1 ('01')
;							||||++----- b2,b3.. verify ('00')
;							|||+-------	b4..    auto init disable
;							||+--------	b5..    address increment
;							++--------- b6,b7.. single mode ('01')
;
DMACH2MODE:		equ			01000010b
;							||||||||
;							||||||++--- b0,b1.. channle 2 ('10')
;							||||++----- b2,b3.. verify ('00')
;							|||+-------	b4..    auto init disable
;							||+--------	b5..    address increment
;							++--------- b6,b7.. single mode ('01')
;
DMACH3MODE:		equ			01000011b
;							||||||||
;							||||||++--- b0,b1.. channle 3 ('11')
;							||||++----- b2,b3.. verify ('00')
;							|||+-------	b4..    auto init disable
;							||+--------	b5..    address increment
;							++--------- b6,b7.. single mode ('01')
;
;--------------------------------------
; 8259 Interrupt controller
;--------------------------------------
;
ICW1:			equ			020h				; initialization command (with D4=1)
ICW2:			equ			021h				; interrupt command words
ICW3:			equ			021h
ICW4:			equ			021h
;
OCW1:			equ			021h				; interrupt mask register
OCW2:			equ			020h				; end of interrupt mode (with D4=0, D3=0)
OCW3:			equ			020h				; read/write IRR and ISR (with D4=0, D3=1)
;
IRR:			equ			020h				; interrupt request register
ISR:			equ			020h				; interrupt in service register
IMR:			equ			021h				; interrupt mask register
;
INIT1:			equ			00010011b			; ICW1 initialization
;							||||||||
;							|||||||+---	ICW4 needed
;							||||||+----	single 8259
;							|||||+-----	8 byte interval vector (ignored for 8086)
;							||||+------	edge trigger
;							|||+-------	b.4='1'
;							+++--------	set to a5..a7 of vector address are '0' (ignored for 8086)
;
INIT2:			equ			00001000b			; ICW2 initialization
;							||||||||
;							|||||+++---	a8..a10 (ignored for 8086)
;							+++++------	set a8..a15 of vector address
;
INIT4:			equ			00001001b			; ICW4 initialization
;							||||||||
;							|||||||+---	8086 mode
;							||||||+----	normal EOI
;							||||++-----	buffered mode/slave
;							|||+-------	not special fully nested
;							+++--------	'0'
;
EOI:			equ			00100000b
;							||||||||
;							|||||+++---	active ITN level
;							|||++------	'0'
;							+++--------	'001' Non-specific EOI command
;
;--------------------------------------
; 8253 counter timer
;--------------------------------------
;
TIMER0:			equ			040h
TIMER1:			equ			041h
TIMER2:			equ			042h
TIMERCTRL:		equ			043h
;
TIMER0INIT:		equ			00110110b
;							||||||||
;							|||||||+---	b0..Binary '0' count
;							||||+++----	b1..counter mode 3
;							||++-------	b4..LSM+MSB '11'
;							++---------	b6..timer: #0 '00'
;
TIMER1INIT:		equ			01010100b
;							||||||||
;							|||||||+---	b0..Binary '0' count
;							||||+++----	b1..counter mode 2
;							||++-------	b4..LSB '01'
;							++---------	b6..timer: #1 '01'
;
TMCTRLBCD:		equ			00000001b	; BCD mode count
TMCTRLBIN:		equ			00000000b	; binary mode count
TMCTRLTM0:		equ			00000000b	; select timer 0
TMCTRLTM1:		equ			01000000b	; select timer 1
TMCTRLTM2:		equ			10000000b	; select timer 2
TMCTRLLATCH:	equ			00000000b	; counter latch
TMCTRLLSB:		equ			00010000b	; load LSB
TMCTRLMSB:		equ			00100000b	; load MSB
TMCTRLBOTH:		equ			00110000b	; load LSB then MSB
TMCTRLM0INT:	equ			00000000b	; mode 0 interrupt on TC
TMCTRLM1ONESHT:	equ			00000010b	; one shot
TMCTRLM2RATE:	equ			00000100b	; rate generator
TMCTRLM3SQRW:	equ			00000110b	; square wave generator
TMCTRLM4STRBS:	equ			00001000b	; software triggered strobe
TMCTRLM5STRBH:	equ			00001010b	; hardware triggered strobe
;
;--------------------------------------
; 8255 PPI
;--------------------------------------
;
PPIPA:			equ			060h
PPIPB:			equ			061h
PPIPC:			equ			062h
PPICTRL:		equ			063h
;
PPIINIT:		equ			10001001b			; PPI control register
;							||||||||
;							|||||||+--- b0..Port C lower input
;							||||||+----	b1..Port B output
;							|||||+----- b2..Mode 0
;							||||+------	b3..Port C upper input
;							|||+-------	b4..Port A output
;							|++--------	b5..Mode 0
;							+----------	b7..Mode-set active
;
PPIPAINIT:		equ			SEGBLANK			; blank 7-segment display
;
PPIPBINIT:		equ			10110001b			; PPI Port B initialization
;							||||||||
;							|||||||+--- b0..(+) Timer 2 Gate Speaker
;							||||||+----	b1..(+) Speaker Data
;							|||||+----- b2..(-) 4.77MHz (+) 8MHz [if not selected with jumper]
;							||||+------	b3..(-) Read High Switches (SW1..4) or (+) Read Low Switches (SW5..8)
;							|||+-------	b4..(-) Enable RAM Parity Check
;							||+--------	b5..(-) Enable I/O Channel Check
;							|+--------- b6..(free) (-) Hold Keyboard Clock Low
;							+----------	b7..(free) (-) Enable Keyboard or (+) Clear Keyboard
;
;						7.6.5.4.3.2.1.0			; PPI Port C equipment configuration switches
;						| | | | | | | |
;						| | | | | | | +- SW1: ROM Monitor  [on ], SW5: Display-0 [on ]
;						| | | | | | +--- SW2: Coprocessor  [off], SW6: Display-1 [on ]
;						| | | | | +----- SW3: RAM-0        [on ], SW7: Drive-0   [off]
;						| | | | +------- SW4: RAM-1        [on ], SW8: Drive-1   [off]
;						| | | +--------- spare
;						| | +----------- timer-2 out
;						| +------------- IO channel check
;						+--------------- RAM parity check
;
; RAM-1 RAM-0        Display-1 Display-0                Drive-1 Drive-0
;  0     0    64K       0         0      reserved         0       0     1 drive
;  0     1   128K       0         1      color 40x25      0       1     2 drives
;  1     0   192K       1         0      color 80x25      1       0     3 drives
;  1     1   256K       1         1      mono  80x25      1       1     4 drives
;
; 8255 PPI.PA 7-segment driver
; PA.0 segment 'a'
; PA.1 segment 'b'
; PA.2 segment 'c'
; PA.3 segment 'd'
; PA.4 segment 'e'
; PA.5 segment 'f'
; PA.6 segment 'g'
; PA.7 segment 'dp'
;
;		-- a --
;	   |       |
;      f       b
;	   |       |
;       -- g --
;	   |       |
;      e       c
;	   |       |
;       -- d --    (dp)
;
DPON:			equ			01111111b			; need to 'and' with this mask to turn the D.P 'on'
SEGBLANK:		equ			11111111b			; all segments are off
LAMPTEST:		equ			00000000b			; all segments are on
;
;--------------------------------------
; DMA page register
;
; 4 x 4bit registers (1 per DMA channel) that provide
; A16..A19 address for a memory DMA access
;
; ODD ADDRESS:
; Read address lines of 74LS670 IC used as the DMA page register
; are connected directly to the /DACK3 and /DACK2 lines.
; If channel 3 is active the resulting address is 10 binary or 2 hex,
; if channel 2 is active the resulting address is 01 binary or 1 hex,
; and if neither channel 3 nor channel 2 are active
; (meaning that either channel 0 or channel 1 are active)
; the address will be 11 binary or 3 hex.
; DMA page register for channel 0 is not required for DRAM refresh
;--------------------------------------
;
DMAPAGE1:		equ			083h
DMAPAGE2:		equ			081h
DMAPAGE3:		equ			082h
;
;--------------------------------------
; NMI mask register
;--------------------------------------
;
NMIMASK:		equ			0a0h
;
NMIENA:			equ			80h
NMIDIS:			equ			00h
;
;======================================
; new system IO port range
;======================================
;
;--------------------------------------
; 16550/82C50A UART ($300 - $307)
;--------------------------------------
;
RBR:			equ			300h				; Rx Buffer Reg. (RBR)
THR:			equ			300h				; Tx Holding Register. (THR)
RXTXREG:		equ			300h
;
IER:			equ			301h				; Interrupt Enable Reg.
;
INTRINIT:		equ			00000001b			; interrupt on byte receive only
;							76543210
;							||||||||
;							|||||||+--- b0.. Rx Data Available interrupt
;							||||||+----	b1.. Tx Holding Reg Empty interrupt
;							|||||+----- b2.. Rx Line Status int
;							||||+------	b3.. MODEM Status int.
;							|||+-------	b4.. '0'
;							||+--------	b5.. '0'
;							|+--------- b6.. '0'
;							+----------	b7.. '0'
;
IIR:			equ			302h				; Interrupt Identification Reg. (read only)
;
;							76543210
;							||||||||            16550                        82C50
;							|||||||+--- b0.. /interrupt pending            /interrupt pending
;							||||||+----	b1.. interrupt priority-0          interrupt priority-0
;							|||||+----- b2.. interrupt priority-1          interrupt priority-1
;							||||+------	b3.. '0' or '1' in FIFO mode       '0'
;							|||+-------	b4.. '0'                           '0'
;							||+--------	b5.. '0'                           '0'
;							|+--------- b6.. = FCR.b0                      '0'
;							+----------	b7.. = FCR.b0                      '0'
;
FCR:			equ			302h				; FIFO Control Reg. (write only) *** 16550 only ***
;
FCRINIT:		equ			00000000b			; initialize with no FIFO control
;							76543210
;							||||||||
;							|||||||+--- b0.. Rx and Tx FIFO enable
;							||||||+----	b1.. Rx FIFO clear/reset
;							|||||+----- b2.. Tx FIFO clear/reset
;							||||+------	b3.. RxRDY and TxRDY pins to mode 1
;							|||+-------	b4.. reserved
;							||+--------	b5.. reserved
;							|+--------- b6..
;							+----------	b7.. Rx FIFO trigger (1, 4, 8, 14 bytes)
;
LCR:			equ			303h				; Line Control Reg.
;
LCRINIT:		equ			00000011b			; 8-bit Rx/Tx, 1 stop bit, no parity
;							76543210
;							||||||||
;							|||||||+--- b0.. character length
;							||||||+----	b1.. character length
;							|||||+----- b2.. 1 stop bit
;							||||+------	b3.. parity disabled
;							|||+-------	b4.. odd parity
;							||+--------	b5.. "stick" parity disabled
;							|+--------- b6.. break control disabled
;							+----------	b7.. Divisor Latch Access Bit (DLAB)
;
MCR:			equ			304h				; MODEM Control Reg.
;
MCRINIT:		equ			00000000b			; all inactive
MCRLOOP:		equ			00010000b			; loop-back test
;							76543210
;							||||||||
;							|||||||+--- b0.. DTR
;							||||||+----	b1.. RTS
;							|||||+----- b2.. OUT-1 IO pin
;							||||+------	b3.. OUT-2 IO pin
;							|||+-------	b4.. Loopback mode
;							||+--------	b5.. '0'
;							|+--------- b6.. '0'
;							+----------	b7.. '0'
;
LSR:			equ			305h				; Line Status Reg.
;
;							76543210
;							||||||||
;							|||||||+--- b0.. Rx Register Ready
;							||||||+----	b1.. Overrun Error
;							|||||+----- b2.. Parity Error
;							||||+------	b3.. Framing Error
;							|||+-------	b4.. Break interrupt
;							||+--------	b5.. Tx Holding Register Ready / Tx FIFO empty
;							|+--------- b6.. Tx Empty (Tx shift reg. empty)
;							+----------	b7.. '0' or FIFO error in FIFO mode
;
MSR:			equ			306h				; MODEM Status Reg.
;
;							76543210
;							||||||||
;							|||||||+--- b0.. DCTS
;							||||||+----	b1.. DDSR
;							|||||+----- b2.. Trailing Edge RI
;							||||+------	b3.. DDCD
;							|||+-------	b4.. CTS
;							||+--------	b5.. DSR
;							|+--------- b6.. RI
;							+----------	b7.. DCD
;
SCRATCH:		equ			307h				; Scratchpad Reg. (temp read/write register)
;
BAUDGENLO:		equ			300h				; baud rate generator/div accessed when bit DLAB='1'
BAUDGERHI:		equ			301h
;
DLABSET:		equ			10000000b			; DLAB set (or) and clear (and) masks
DLABCLR:		equ			01111111b
;
BAUDDIVLO:		equ			10h					; BAUD rate divisor of 16 for 19200 BAUD
BAUDDIVHI:		equ			00h					; with 4.9152MHz crustal
;
;--------------------------------------
; 8255 IDE ($320 - $323)
;
; source: http://wiki.osdev.org/ATA_PIO_Mode
;         http://www.angelfire.com/de2/zel/
;--------------------------------------
;
IDETOV:			equ			55					; IDE drive time out value in BIOS ticks (approx. 1sec)
;
;-----	IDE PPI IO ports
;
IDEDATALO:		equ			320h				; IDE data bus low  D0..D7
IDEDATAHI:		equ			321h				; IDE data bus high D8..D15
IDECNT:			equ			322h				; IDE control
;
;-----	IDE control signals on PPI port C (IDECNT:)
;
IDEINIT:		equ			00000000b
IDECS1:			equ			00001000b
IDECS3:			equ			00010000b
IDERD:			equ			00100000b
IDEWR:			equ			01000000b
IDERST:			equ			10000000b
;							76543210
;							||||||||
;							|||||||+--- b0.. A0
;							||||||+----	b1.. A1
;							|||||+----- b2.. A2
;							||||+------	b3.. CS1
;							|||+-------	b4.. CS3
;							||+--------	b5.. RD
;							|+--------- b6.. WR
;							+----------	b7.. Reset
;
;-----	IDE Command Block Reisters: internal register addressed with PPI port C b0..b2 (IDECNT:)
;
IDEDATA:		equ			00001000b			; Read/write data (16 bit register accessed from PPI PA(low byte) and PB(high byte)
IDEFEATUREERR:	equ			00001001b			; Feature (wr) and error (rd) information
IDESECTORS:		equ			00001010b			; sector count to read/write
IDELBALO:		equ			00001011b			; Sector / low byte of LBA (b0..b7)
IDELBAMID:		equ			00001100b			; cylinder low / mid byte of LBA (b8..b15)
IDELBAHI:		equ			00001101b			; cylinder high / high byte of LBA (b16..b23)
IDEDEVLBATOP:	equ			00001110b			; drive select and/or head and top LBA address bits (b24..b27) - see below
IDECMDSTATUS:	equ			00001111b			; commad (wr) or regular status (rd) - see below
IDEALTSTATUS:	equ			00010110b			; Alternate Status (rd), used for software reset and to enable/disable interrupts
IDEDEVCTL:		equ			00010110b			; Device Control Register (wr)
;							   |||||
;							   ||||+--- b0.. A0
;							   |||+----	b1.. A1
;							   ||+----- b2.. A2
;							   |+------	b3.. CS1
;							   +-------	b4.. CS3
;
;-----	IDE drive select and top LBA bit register (IDEDEVLBATOP:)
;
IDEDEVSELECT:	equ			11101111b			; master device select 'AND' mask
IDELBASELECT:	equ			01000000b			; LBA addressing mode 'OR' mask
;							76543210
;							||||||||
;							|||||||+--- b0.. LBA b24
;							||||||+----	b1.. LBA b25
;							|||||+----- b2.. LBA b26
;							||||+------	b3.. LBA b27
;							|||+-------	b4.. DEV device select bit (dev#1='0', dev#2='1')
;							||+--------	b5..
;							|+--------- b6.. LBA/CHS mode select (LBA='1')
;							+----------	b7..
;
;-----	IDE status and alternate-status register bits (IDECMDSTATUS: and IDEALTSTATUS:)
;
IDESTATERR:		equ			00000001b			; IDE reports error condition if '1'
IDESTATDRQ:		equ			00001000b			; PIO data request ready for rd or wr
IDESTATRDY:		equ			01000000b			; Device is ready='1', not ready='0'
IDESTATBSY:		equ			10000000b			; Device busy='1', not busy (but check RDY)='0'
;							76543210
;							||||||||
;							|||||||+--- b0.. ERR Indicates an error occurred, read error register (IDEFEATUREERR:) or resend command or reset drive.
;							||||||+----	b1..
;							|||||+----- b2..
;							||||+------	b3.. DRQ Set when the drive has PIO data to transfer, or is ready to accept PIO data.
;							|||+-------	b4.. SRV Overlapped Mode Service Request.
;							||+--------	b5.. DF  Drive Fault Error (does not set ERR).
;							|+--------- b6.. DRDY bit is clear when drive is spun down, or after an error. Set otherwise.
;							+----------	b7.. BSY Indicates the drive is preparing to send/receive data (wait for it to clear). In case of 'hang' (it never clears), do a software reset.
;
;-----	IDE Device Control register bits (IDEDEVCTL:)
;
IDEDEVCTLINIT:	equ			00000010b			; device control register initialization
;							76543210
;							||||||||
;							|||||||+--- b0..
;							||||||+----	b1.. nIEN Set this to stop the current device from sending interrupts.
;							|||||+----- b2.. SRST Set this to do a "Software Reset" on all ATA drives on a bus, if one is misbehaving.
;							||||+------	b3..
;							|||+-------	b4..
;							||+--------	b5..
;							|+--------- b6..
;							+----------	b7.. HOB  Set this to read back the High Order Byte of the last LBA48 value sent to an IO port.
;
;-----	IDE commands
;
; source: ATA/ATAPI-5 'd1321r3-ATA-ATAPI-5.pdf'
IDECHKPWR:		equ			0e5h				;   8.6  CHECK POWER MODE (pg. 91)
IDEDEVRST:		equ			008h				;   8.7  DEVICE RESET (pg. 92)
IDEDEVDIAG:		equ			090h				;   8.9  EXECUTE DEVICE DIAGNOSTIC (pg. 96)
IDEFLUSHCACHE:	equ			0e7h				;   8.10 FLUSH CACHE (pg. 97)
IDEIDENTIFY:	equ			0ech				; > 8.12 IDENTIFY DEVICE (pg. 101)
IDEINITPARAM:	equ			091h				;   8.16 INITIALIZE DEVICE PARAMETERS (pg. 134)
IDEREADBUF:		equ			0e4h				;   8.22 READ BUFFER (pg. 149)
IDEREADSEC:		equ			020h				; > 8.27 READ SECTOR(S) (pg. 161)
IDESEEK:		equ			070h				;   8.35 SEEK (pg. 176)
IDEWRITEBUF:	equ			0e8h				;   8.44 WRITE BUFFER (pg. 227)
IDEWRITESEC:	equ			030h				; > 8.48 WRITE SECTOR(S) (pg. 237)
;
;-----	PPI control port
;
IDEPPI:			equ			323h				; IDE PPI 8255 control register
;
IDEPPIINIT:		equ			10010010b			; 8255 mode '0', PC output, PA and PB input
IDEDATARD:		equ			10010010b			; PC output, PA and PB input (IDE read)
IDEDATAWR:		equ			10000000b			; PC output, PA and PB output (IDE write)
;							76543210
;							||||||||
;							|||||||+--- b0.. PC lo in/out
;							||||||+----	b1.. PB in/out
;							|||||+----- b2.. mode
;							||||+------	b3.. PC hi in/out
;							|||+-------	b4.. PA in/out
;							||+--------	b5.. mode-0
;							|+--------- b6.. mode-1
;							+----------	b7.. mode set '1'
;
;--------------------------------------
; INDENTIFY command returned data structure
; page 103
;--------------------------------------
;
struc           IDEIDENTIFYSTRUCT
;
				resw		1
iiCYL:			resw		1					; logical cyliders
				resw		1
iiHEADS:		resw		1					; logical heads
				resw		2
iiSEC:			resw		1					; sectors per track
				resw		3
iiSERIANNUM:	resb		20					; serial number 20 ASCII characters
				resw		3
iiFIRMWARE:		resb		8					; firmware level 8 ASCII characters
iiMODEL:		resb		40					; model number 40 ASCII characters
				resw		13
iiLBA:			resw		2					; total number of LBAs
				resw		193
iiCHECKSUM:		resw		1					; block checksum
;
endstruc
;
;--------------------------------------
; INT 13 status codes
;--------------------------------------
;
INT13NOERR:		equ			000h					;  no error
INT13BADCMD:	equ			001h					;  bad command passed to driver
INT13BADSEC:	equ			002h					;  address mark not found or bad sector
INT13WRPROT:	equ			003h					;  diskette write protect error
INT13SECNF:		equ			004h					;  sector not found
INT13RSTFAIL:	equ			005h					;  fixed disk reset failed
INT13DSKCHG:	equ			006h					;  diskette changed or removed
INT13BADPARAM:	equ			007h					;  bad fixed disk parameter table
INT13DMAOVR:	equ			008h					;  DMA overrun
INT13DMA64K:	equ			009h					;  DMA access across 64k boundary
INT13HDDBADSEC:	equ			00Ah					;  bad fixed disk sector flag
INT13BADCYL:	equ			00Bh					;  bad fixed disk cylinder
INT13UNSUPMED:	equ			00Ch					;  unsupported track/invalid media
INT13INVSEC:	equ			00Dh					;  invalid number of sectors on fixed disk format
INT13HDDADDERR:	equ			00Eh					;  fixed disk controlled data address mark detected
INT13DMAERR:	equ			00Fh					;  fixed disk DMA arbitration level out of range
INT13CRCERR:	equ			010h					;  ECC/CRC error on disk read
INT13FIXCRC:	equ			011h					;  recoverable fixed disk data error, data fixed by ECC
INT13FLPERR:	equ			020h					;  controller error (NEC for floppies)
INT13SEELFAIL:	equ			040h					;  seek failure
INT13TOVERR:	equ			080h					;  time out, drive not ready
INT13DRVNRDY:	equ			0AAh					;  fixed disk drive not ready
INT13UNDEFERR:	equ			0BBh					;  fixed disk undefined error
INT13WRFAIL:	equ			0CCh					;  fixed disk write fault on selected drive
INT13HDDERR:	equ			0E0h					;  fixed disk status error/Error reg = 0
INT13SENSEFAIL:	equ			0FFh					;  sense operation failed
;
;======================================
; other IO addresses on PC/XT system
;======================================
;
;	200 - 20F Game port
;	210 - 217 Expansion Unit
;	2F8 - 2FF Serial port 2
;	300 - 31F Prototype card  |
;	320 - 32F Fixed disk      +- mod IO range, see below
;  		- 33F                 |   
; 	378 - 37F Parallel port 1
;	380 - 38F SDLC bisynchronous 2
;	3B0 - 3BF Monochrome adaptor/printer
;	3D0 - 3D7 CGA
;	3F0 - 3F7 Floppy disk
;	3F8 - 3FF Serial port
; 
; -- end of file --
;

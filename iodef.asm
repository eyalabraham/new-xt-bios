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
LF:             equ         0ah                         ; line feed
CR:             equ         0dh                         ; carriage return
TAB:            equ         09h                         ; horizontal tab
BS:             equ         08h                         ; back space
BELL:           equ         07h
SPACE:          equ         20h                         ; space
FORMATFILL:     equ         0f6h                        ; formatted sector fill byte
;
EQUIPMENTMASK:  equ         1111111000110011b           ; 'AND' mask for setting hard coded equipment bits
EQUIPMENT:      equ         0000000001001100b           ; hard coded 'OR' mask for equipment bits
;                           ||||||||||||||||
;                           |||||||||||||||+----------------- 9'off')1=auto-IPL or ('on')0=mon88 (was: IPL diskette installed)
;                           ||||||||||||||+------------------ no co-processor (get from DIP SW?)
;                           ||||||||||||++------------------- normal RAM board
;                           ||||||||||++--------------------- initial video mode (get from DIP SW5/6)
;                           ||||||||++----------------------- # of diskette drives less 1
;                           |||||||+------------------------- DMA installed
;                           ||||+++-------------------------- # of serial ports
;                           |||+----------------------------- game adapter
;                           ||+------------------------------ unused
;                           ++------------------------------- # of printer ports
;
ROMMONITOR:     equ         0000000000000001b
;
;======================================
; XMODEM equates
;======================================
;
FUNCDRIVEWR:    equ         1                           ; Rx from XMODEM and write to HDD
FUNCMEMWR:      equ         2                           ; Rx from XMODEM and write to memory
;
XSTART:         equ         43h                         ; "C" to start XMODEM connection
SOH:            equ         01h                         ; start a 128B packet session
STX:            equ         02h                         ; start a 1KB session
EOT:            equ         04h                         ; end of session
ACK:            equ         06h                         ; 'acknowledge'
NAK:            equ         15h                         ; 'no acknowledge'
CAN:            equ         18h                         ; cancel session
CTRLZ:          equ         1ah
;
HOSTWAITTOV:    equ         15                          ; 15 seconds to wait for host connection after "C"
XMODEMTOV:      equ         55                          ; 1 sec time out (55 x 18.2 mSec)
XMODEMWAITERR:  equ         10                          ; ~2sec wait before exiting XMODEM upon error
XMODEMBUFFER:   equ         133                         ; XMODEM character buffer size
XMODEMPACKET:   equ         128                         ; XMODEM data packet size
XMODEMCANSEQ:   equ         3                           ; number of CAN chracters to send
XMEMWRATONCE:   equ         1                           ; number of 512B blocks to write at once
XHDDWRATONCE:   equ         64                          ; number of 512B blocks to write at once (max. 127)
;
;======================================
; general macros
;======================================
;
;-----  print a zero terminated string
;
%macro          mcrPRINT    1
                push        ax
                push        si
                push        ds
                mov         ax,cs
                mov         ds,ax
                mov         si,(%1+ROMOFF)      ; get message string address
                call        PRINTSTZ            ; and print
                pop         ds
                pop         si
                pop         ax
%endmacro
;
;======================================
; default startup CRT properties
;======================================
;
DEFBAUDSIOA:    equ         BAUD9600
DEFBAUDSIOB:    equ         BAUD38400
DEFVIDEOMODE:   equ         9                   ; BIOS POST goes into special mode 9 for mon88
;                                                 for OS boot, video mode is set based on DIP SW.5 & 6 setting
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
CBAR0:          equ         000h                ; ch-0 Current / Base Address Register
CBWC0:          equ         001h                ; ch-0 Current  / Base Word Count Register
CBAR1:          equ         002h                ; ch-1 Current / Base Address Register
CBWC1:          equ         003h                ; ch-1 Current  / Base Word Count Register
CBAR2:          equ         004h                ; ch-2 Current / Base Address Register
CBWC2:          equ         005h                ; ch-2 Current  / Base Word Count Register
CBAR3:          equ         006h                ; ch-3 Current / Base Address Register
CBWC3:          equ         007h                ; ch-3 Current  / Base Word Count Register
;
DMACMD:         equ         008h                ; Command Register (wr)
DMASTAT:        equ         008h                ; Status Register (rd)
DMAREQ:         equ         009h                ; Request Register (wr)
DMAMASK:        equ         00ah                ; Mask Register (wr)
DMAMODE:        equ         00bh                ; Mode Register (wr)
DMACLRFF:       equ         00ch                ; Clear First/Last Flip-Flop (wr)
DMAMCLR:        equ         00dh                ; Master Clear (wr)
DMAALLMASK:     equ         00fh                ; All Mask Register (wr)
;
DMACMDINIT:     equ         00000100b
;                           ||||||||
;                           |||||||+--- b0..Memory-Memory Transfer (dis=0)
;                           ||||||+---- b1..Channel 0 Address Hold (dis=0)
;                           |||||+----- b2..Controller Disable     (dis=1)
;                           ||||+------ b3..Timing                 (normal=0)
;                           |||+------- b4..Priority               (fixed=0)
;                           ||+-------- b5..Write Pulse Width      (normal=0)
;                           |+--------- b6..DREQ Sense             (active H=0)
;                           +---------- b7..DACK Sense             (active L=0)
;
DMACH0MODE:     equ         01011000b
;                           ||||||||
;                           ||||||++--- b0,b1.. channle 0 ('00')
;                           ||||++----- b2,b3.. read transfer ('10')
;                           |||+------- b4..    auto init enabled
;                           ||+-------- b5..    address increment
;                           ++--------- b6,b7.. single mode ('01')
;
DMACH1MODE:     equ         01000001b
;                           ||||||||
;                           ||||||++--- b0,b1.. channle 1 ('01')
;                           ||||++----- b2,b3.. verify ('00')
;                           |||+------- b4..    auto init disable
;                           ||+-------- b5..    address increment
;                           ++--------- b6,b7.. single mode ('01')
;
DMACH2MODE:     equ         01000010b
;                           ||||||||
;                           ||||||++--- b0,b1.. channle 2 ('10')
;                           ||||++----- b2,b3.. verify ('00')
;                           |||+------- b4..    auto init disable
;                           ||+-------- b5..    address increment
;                           ++--------- b6,b7.. single mode ('01')
;
DMACH3MODE:     equ         01000011b
;                           ||||||||
;                           ||||||++--- b0,b1.. channle 3 ('11')
;                           ||||++----- b2,b3.. verify ('00')
;                           |||+------- b4..    auto init disable
;                           ||+-------- b5..    address increment
;                           ++--------- b6,b7.. single mode ('01')
;
;--------------------------------------
; 8259 Interrupt controller
;--------------------------------------
;
ICW1:           equ         020h                ; initialization command (with D4=1)
ICW2:           equ         021h                ; interrupt command words
ICW3:           equ         021h
ICW4:           equ         021h
;
OCW1:           equ         021h                ; interrupt mask register
OCW2:           equ         020h                ; end of interrupt mode (with D4=0, D3=0)
OCW3:           equ         020h                ; read/write IRR and ISR (with D4=0, D3=1)
;
IRR:            equ         020h                ; interrupt request register
ISR:            equ         020h                ; interrupt in service register
IMR:            equ         021h                ; interrupt mask register
;
IMRINIT:        equ         11101110b
;                           ||||||||
;                           |||||||+--- b0.. (IRQ0) Timer tick
;                           ||||||+---- b1.. (IRQ1) Keyboard attention
;                           |||||+----- b2.. (IRQ2) Video (5-49/197 line 278)
;                           ||||+------ b3.. (IRQ3) COM2 serial i/o
;                           |||+------- b4.. (IRQ4) COM1 serial i/o
;                           ||+-------- b5.. (IRQ5) Hard disk attn.
;                           |+--------- b6.. (IRQ6) Floppy disk attention
;                           +---------- b7.. (IRQ7) Parallel printer

;
INIT1:          equ         00010011b           ; ICW1 initialization
;                           ||||||||
;                           |||||||+--- ICW4 needed
;                           ||||||+---- single 8259
;                           |||||+----- 8 byte interval vector (ignored for 8086)
;                           ||||+------ edge trigger
;                           |||+------- b.4='1'
;                           +++-------- set to a5..a7 of vector address are '0' (ignored for 8086)
;
INIT2:          equ         00001000b           ; ICW2 initialization
;                           ||||||||
;                           |||||+++--- a8..a10 (ignored for 8086)
;                           +++++------ set a8..a15 of vector address
;
INIT4:          equ         00001001b           ; ICW4 initialization
;                           ||||||||
;                           |||||||+--- 8086 mode
;                           ||||||+---- normal EOI
;                           ||||++----- buffered mode/slave
;                           |||+------- not special fully nested
;                           +++-------- '0'
;
EOI:            equ         00100000b
;                           ||||||||
;                           |||||+++--- active ITN level
;                           |||++------ '0'
;                           +++-------- '001' Non-specific EOI command
;
;--------------------------------------
; 8253 counter timer
;--------------------------------------
;
TIMER0:         equ         040h
TIMER1:         equ         041h
TIMER2:         equ         042h
TIMERCTRL:      equ         043h
;
TIMER0INIT:     equ         00110110b
;                           ||||||||
;                           |||||||+--- b0..Binary '0' count
;                           ||||+++---- b1..counter mode 3
;                           ||++------- b4..LSM+MSB '11'
;                           ++--------- b6..timer: #0 '00'
;
TIMER1INIT:     equ         01010100b
;                           ||||||||
;                           |||||||+--- b0..Binary '0' count
;                           ||||+++---- b1..counter mode 2
;                           ||++------- b4..LSB '01'
;                           ++--------- b6..timer: #1 '01'
;
TMCTRLBCD:      equ         00000001b   ; BCD mode count
TMCTRLBIN:      equ         00000000b   ; binary mode count
TMCTRLTM0:      equ         00000000b   ; select timer 0
TMCTRLTM1:      equ         01000000b   ; select timer 1
TMCTRLTM2:      equ         10000000b   ; select timer 2
TMCTRLLATCH:    equ         00000000b   ; counter latch
TMCTRLLSB:      equ         00010000b   ; load LSB
TMCTRLMSB:      equ         00100000b   ; load MSB
TMCTRLBOTH:     equ         00110000b   ; load LSB then MSB
TMCTRLM0INT:    equ         00000000b   ; mode 0 interrupt on TC
TMCTRLM1ONESHT: equ         00000010b   ; one shot
TMCTRLM2RATE:   equ         00000100b   ; rate generator
TMCTRLM3SQRW:   equ         00000110b   ; square wave generator
TMCTRLM4STRBS:  equ         00001000b   ; software triggered strobe
TMCTRLM5STRBH:  equ         00001010b   ; hardware triggered strobe
;
;--------------------------------------
; 8255 PPI
;--------------------------------------
;
PPIPA:          equ         060h
PPIPB:          equ         061h
PPIPC:          equ         062h
PPICTRL:        equ         063h
;
PPIINIT:        equ         10011001b           ; PPI control register
;                           ||||||||
;                           |||||||+--- b0..Port C lower input
;                           ||||||+---- b1..Port B output
;                           |||||+----- b2..Mode 0
;                           ||||+------ b3..Port C upper input
;                           |||+------- b4..Port A input
;                           |++-------- b5..Mode 0
;                           +---------- b7..Mode-set active
;
PPIPBINIT:      equ         10110001b           ; PPI Port B initialization
;                           ||||||||
;                           |||||||+--- b0..(+) Timer 2 Gate Speaker
;                           ||||||+---- b1..(+) Speaker Data
;                           |||||+----- b2..(-) 4.77MHz (+) 8MHz [if not selected with jumper]
;                           ||||+------ b3..(-) Read High Switches (SW1..4) or (+) Read Low Switches (SW5..8)
;                           |||+------- b4..(-) Enable RAM Parity Check
;                           ||+-------- b5..(-) Enable I/O Channel Check
;                           |+--------- b6..(free) (-) Hold Keyboard Clock Low
;                           +---------- b7..(free) (-) Enable Keyboard or (+) Clear Keyboard
;
;                       7.6.5.4.3.2.1.0         ; PPI Port C equipment configuration switches
;                       | | | | | | | |
;                       | | | | | | | +- SW1: ROM Monitor  [on ], SW5: Display-0 [on ]
;                       | | | | | | +--- SW2: Coprocessor  [off], SW6: Display-1 [on ]
;                       | | | | | +----- SW3: RAM-0        [on ], SW7: Drive-0   [???]
;                       | | | | +------- SW4: RAM-1        [on ], SW8: Drive-1   [???]
;                       | | | +--------- spare
;                       | | +----------- timer-2 out
;                       | +------------- IO channel check
;                       +--------------- RAM parity check
;
;                                                       Floppy select
; RAM-1 RAM-0        Display-1 Display-0                Drive-1 Drive-0
;  0     0    64K       0         0      reserved         0       0     Floppy alt.0
;  0     1   128K       0         1      color 40x25      0       1     Floppy alt.1
;  1     0   192K       1         0      color 80x25      1       0     Floppy alt.2
;  1     1   256K       1         1      mono  80x25      1       1     Floppy alt.3
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
DMAPAGE1:       equ         083h
DMAPAGE2:       equ         081h
DMAPAGE3:       equ         082h
;
;--------------------------------------
; NMI mask register
;--------------------------------------
;
NMIMASK:        equ         0a0h
;
NMIENA:         equ         80h
NMIDIS:         equ         00h
;
;======================================
; new system IO port range
;======================================
;
;--------------------------------------
; 16550/82C50A UART ($300 - $307)
;--------------------------------------
;
RBR:            equ         300h                ; Rx Buffer Reg. (RBR)
THR:            equ         300h                ; Tx Holding Register. (THR)
RXTXREG:        equ         300h
;
IER:            equ         301h                ; Interrupt Enable Reg.
;
INTRINIT:       equ         00000001b           ; interrupt on byte receive only
;                           76543210
;                           ||||||||
;                           |||||||+--- b0.. Rx Data Available interrupt
;                           ||||||+---- b1.. Tx Holding Reg Empty interrupt
;                           |||||+----- b2.. Rx Line Status int
;                           ||||+------ b3.. MODEM Status int.
;                           |||+------- b4.. '0'
;                           ||+-------- b5.. '0'
;                           |+--------- b6.. '0'
;                           +---------- b7.. '0'
;
IIR:            equ         302h                ; Interrupt Identification Reg. (read only)
;
;                           76543210
;                           ||||||||            16550                        82C50
;                           |||||||+--- b0.. /interrupt pending            /interrupt pending
;                           ||||||+---- b1.. interrupt priority-0          interrupt priority-0
;                           |||||+----- b2.. interrupt priority-1          interrupt priority-1
;                           ||||+------ b3.. '0' or '1' in FIFO mode       '0'
;                           |||+------- b4.. '0'                           '0'
;                           ||+-------- b5.. '0'                           '0'
;                           |+--------- b6.. = FCR.b0                      '0'
;                           +---------- b7.. = FCR.b0                      '0'
;
FCR:            equ         302h                ; FIFO Control Reg. (write only) *** 16550 only ***
;
FCRINIT:        equ         00000000b           ; initialize with no FIFO control
;                           76543210
;                           ||||||||
;                           |||||||+--- b0.. Rx and Tx FIFO enable
;                           ||||||+---- b1.. Rx FIFO clear/reset
;                           |||||+----- b2.. Tx FIFO clear/reset
;                           ||||+------ b3.. RxRDY and TxRDY pins to mode 1
;                           |||+------- b4.. reserved
;                           ||+-------- b5.. reserved
;                           |+--------- b6..
;                           +---------- b7.. Rx FIFO trigger (1, 4, 8, 14 bytes)
;
LCR:            equ         303h                ; Line Control Reg.
;
LCRINIT:        equ         00000011b           ; 8-bit Rx/Tx, 1 stop bit, no parity
;                           76543210
;                           ||||||||
;                           |||||||+--- b0.. character length
;                           ||||||+---- b1.. character length
;                           |||||+----- b2.. 1 stop bit
;                           ||||+------ b3.. parity disabled
;                           |||+------- b4.. odd parity
;                           ||+-------- b5.. "stick" parity disabled
;                           |+--------- b6.. break control disabled
;                           +---------- b7.. Divisor Latch Access Bit (DLAB)
;
MCR:            equ         304h                ; MODEM Control Reg.
;
MCRINIT:        equ         00000000b           ; all inactive
MCRLOOP:        equ         00010000b           ; loop-back test
;                           76543210
;                           ||||||||
;                           |||||||+--- b0.. DTR
;                           ||||||+---- b1.. RTS
;                           |||||+----- b2.. OUT-1 IO pin
;                           ||||+------ b3.. OUT-2 IO pin
;                           |||+------- b4.. Loopback mode
;                           ||+-------- b5.. '0'
;                           |+--------- b6.. '0'
;                           +---------- b7.. '0'
;
LSR:            equ         305h                ; Line Status Reg.
;
;                           76543210
;                           ||||||||
;                           |||||||+--- b0.. Rx Register Ready
;                           ||||||+---- b1.. Overrun Error
;                           |||||+----- b2.. Parity Error
;                           ||||+------ b3.. Framing Error
;                           |||+------- b4.. Break interrupt
;                           ||+-------- b5.. Tx Holding Register Ready / Tx FIFO empty
;                           |+--------- b6.. Tx Empty (Tx shift reg. empty)
;                           +---------- b7.. '0' or FIFO error in FIFO mode
;
MSR:            equ         306h                ; MODEM Status Reg.
;
;                           76543210
;                           ||||||||
;                           |||||||+--- b0.. DCTS
;                           ||||||+---- b1.. DDSR
;                           |||||+----- b2.. Trailing Edge RI
;                           ||||+------ b3.. DDCD
;                           |||+------- b4.. CTS
;                           ||+-------- b5.. DSR
;                           |+--------- b6.. RI
;                           +---------- b7.. DCD
;
SCRATCH:        equ         307h                ; Scratchpad Reg. (temp read/write register)
;
BAUDGENLO:      equ         300h                ; baud rate generator/div accessed when bit DLAB='1'
BAUDGENHI:      equ         301h
;
DLABSET:        equ         10000000b           ; DLAB set (or) and clear (and) masks
DLABCLR:        equ         01111111b
;
BAUDDIVLO:      equ         10h                 ; BAUD rate divisor of 16 for 19200 BAUD
BAUDDIVHI:      equ         00h                 ; with 4.9152MHz crustal
;
;--------------------------------------
; 8255 IDE ($320 - $323)
;
; source: http://wiki.osdev.org/ATA_PIO_Mode
;         http://www.angelfire.com/de2/zel/
;--------------------------------------
;
FLOPPYCNT:      equ         2                   ; system floppy drive count. must match DIP switches!!
FIXEDCNT:       equ         1                   ; system fixed disk count
ALTFLPSPACING:  equ         3000                ; LBA spacing between alternate floppy drives
;
IDETOV:         equ         55                  ; IDE drive time out value in BIOS ticks (approx. 1sec)
IDEDRQWAIT:     equ         5                   ; wait for DRQ (approx 90mSec, perhaps too long)
;
;-----  IDE PPI IO ports
;
IDEDATALO:      equ         320h                ; IDE data bus low  D0..D7
IDEDATAHI:      equ         321h                ; IDE data bus high D8..D15
IDECNT:         equ         322h                ; IDE control
;
;-----  IDE control signals on PPI port C (IDECNT:)
;
IDEINIT:        equ         00000000b
IDECS1:         equ         00001000b
IDECS3:         equ         00010000b
IDERD:          equ         00100000b
IDEWR:          equ         01000000b
IDERST:         equ         10000000b
;                           76543210
;                           ||||||||
;                           |||||||+--- b0.. A0
;                           ||||||+---- b1.. A1
;                           |||||+----- b2.. A2
;                           ||||+------ b3.. CS1
;                           |||+------- b4.. CS3
;                           ||+-------- b5.. RD
;                           |+--------- b6.. WR
;                           +---------- b7.. Reset
;
;-----  IDE Command Block Reisters: internal register addressed with PPI port C b0..b2 (IDECNT:)
;
IDEDATA:        equ         00001000b           ; Read/write data (16 bit register accessed from PPI PA(low byte) and PB(high byte)
IDEFEATUREERR:  equ         00001001b           ; Feature (wr) and error (rd) information
IDESECTORS:     equ         00001010b           ; sector count to read/write
IDELBALO:       equ         00001011b           ; Sector / low byte of LBA (b0..b7)
IDELBAMID:      equ         00001100b           ; cylinder low / mid byte of LBA (b8..b15)
IDELBAHI:       equ         00001101b           ; cylinder high / high byte of LBA (b16..b23)
IDEDEVLBATOP:   equ         00001110b           ; drive select and/or head and top LBA address bits (b24..b27) - see below
IDECMDSTATUS:   equ         00001111b           ; commad (wr) or regular status (rd) - see below
IDEALTSTATUS:   equ         00010110b           ; Alternate Status (rd), used for software reset and to enable/disable interrupts
IDEDEVCTL:      equ         00010110b           ; Device Control Register (wr)
;                              |||||
;                              ||||+--- b0.. A0
;                              |||+---- b1.. A1
;                              ||+----- b2.. A2
;                              |+------ b3.. CS1
;                              +------- b4.. CS3
;
;-----  IDE drive select and top LBA bit register (IDEDEVLBATOP:)
;
IDEDEVSELECT:   equ         11101111b           ; master device select 'AND' mask
IDELBASELECT:   equ         01000000b           ; LBA addressing mode 'OR' mask
;                           76543210
;                           ||||||||
;                           |||||||+--- b0.. LBA b24
;                           ||||||+---- b1.. LBA b25
;                           |||||+----- b2.. LBA b26
;                           ||||+------ b3.. LBA b27
;                           |||+------- b4.. DEV device select bit (dev#1='0', dev#2='1')
;                           ||+-------- b5..
;                           |+--------- b6.. LBA/CHS mode select (LBA='1')
;                           +---------- b7..
;
;-----  IDE status and alternate-status register bits (IDECMDSTATUS: and IDEALTSTATUS:)
;
IDESTATERR:     equ         00000001b           ; IDE reports error condition if '1'
IDESTATDRQ:     equ         00001000b           ; PIO data request ready for rd or wr
IDESTATRDY:     equ         01000000b           ; Device is ready='1', not ready='0'
IDESTATBSY:     equ         10000000b           ; Device busy='1', not busy (but check RDY)='0'
;                           76543210
;                           ||||||||
;                           |||||||+--- b0.. ERR Indicates an error occurred, read error register (IDEFEATUREERR:) or resend command or reset drive.
;                           ||||||+---- b1..
;                           |||||+----- b2..
;                           ||||+------ b3.. DRQ Set when the drive has PIO data to transfer, or is ready to accept PIO data.
;                           |||+------- b4.. SRV Overlapped Mode Service Request.
;                           ||+-------- b5.. DF  Drive Fault Error (does not set ERR).
;                           |+--------- b6.. DRDY bit is clear when drive is spun down, or after an error. Set otherwise.
;                           +---------- b7.. BSY Indicates the drive is preparing to send/receive data (wait for it to clear). In case of 'hang' (it never clears), do a software reset.
;
;-----  IDE Device Control register bits (IDEDEVCTL:)
;
IDEDEVCTLINIT:  equ         00000010b           ; device control register initialization
;                           76543210
;                           ||||||||
;                           |||||||+--- b0..
;                           ||||||+---- b1.. nIEN Set this to stop the current device from sending interrupts.
;                           |||||+----- b2.. SRST Set this to do a "Software Reset" on all ATA drives on a bus, if one is misbehaving.
;                           ||||+------ b3..
;                           |||+------- b4..
;                           ||+-------- b5..
;                           |+--------- b6..
;                           +---------- b7.. HOB  Set this to read back the High Order Byte of the last LBA48 value sent to an IO port.
;
;-----  IDE commands
;
; source: ATA/ATAPI-5 'd1321r3-ATA-ATAPI-5.pdf'
IDECHKPWR:      equ         0e5h                ;   8.6  CHECK POWER MODE (pg. 91)
IDEDEVRST:      equ         008h                ;   8.7  DEVICE RESET (pg. 92)
IDEDEVDIAG:     equ         090h                ;   8.9  EXECUTE DEVICE DIAGNOSTIC (pg. 96)
IDEFLUSHCACHE:  equ         0e7h                ;   8.10 FLUSH CACHE (pg. 97)
IDEIDENTIFY:    equ         0ech                ; > 8.12 IDENTIFY DEVICE (pg. 101)
IDEINITPARAM:   equ         091h                ;   8.16 INITIALIZE DEVICE PARAMETERS (pg. 134)
IDEREADBUF:     equ         0e4h                ;   8.22 READ BUFFER (pg. 149)
IDEREADSEC:     equ         020h                ; > 8.27 READ SECTOR(S) (pg. 161)
IDESEEK:        equ         070h                ;   8.35 SEEK (pg. 176)
IDESETFEATURE:  equ         0efh                ; > 8.37 Set IDE feature (for CF card)
IDEWRITEBUF:    equ         0e8h                ;   8.44 WRITE BUFFER (pg. 227)
IDEWRITESEC:    equ         030h                ; > 8.48 WRITE SECTOR(S) (pg. 237)
;
;-----  PPI control port
;
IDEPPI:         equ         323h                ; IDE PPI 8255 control register
;
IDEPPIINIT:     equ         10010010b           ; 8255 mode '0', PC output, PA and PB input
IDEDATARD:      equ         10010010b           ; PC output, PA and PB input (IDE read)
IDEDATAWR:      equ         10000000b           ; PC output, PA and PB output (IDE write)
;                           76543210
;                           ||||||||
;                           |||||||+--- b0.. PC lo in/out
;                           ||||||+---- b1.. PB in/out
;                           |||||+----- b2.. mode
;                           ||||+------ b3.. PC hi in/out
;                           |||+------- b4.. PA in/out
;                           ||+-------- b5.. mode-0
;                           |+--------- b6.. mode-1
;                           +---------- b7.. mode set '1'
;
;--------------------------------------
; Z80 SIO USART ($390 - $393)
;--------------------------------------
;
SIOBASE:        equ         390h
;
SIODATAA:       equ         SIOBASE                 ; channel A data
SIODATAB:       equ         SIOBASE+1               ; channel B data
SIOCMDA:        equ         SIOBASE+2               ; channel A command
SIOCMDB:        equ         SIOBASE+3               ; channel B command
;
SIORR0RXC:      equ         00000001b               ; receive character ready
SIORR0INT:      equ         00000010b               ; inetrrupt pending (channel A)
SIORR0TXEMPYC:  equ         00000100b               ; transmit buffer empty
SIORR0CTS:      equ         00100000b               ; CTS state
SIORR0CTSTX:    equ         00100100b
;                           76543210
;                           ||||||||
;                           |||||||+--- b0.. Receive character available
;                           ||||||+---- b1.. Interrupt pending on channel A
;                           |||||+----- b2.. Transmit buffer empty
;                           ||||+------ b3.. DCD line state
;                           |||+------- b4.. SYNC/HUNT
;                           ||+-------- b5.. CTS line state
;                           |+--------- b6.. Transmit underrun
;                           +---------- b7.. Break/Abort
;
;--------------------------------------
; SIO Baud rate generator ($394 - $397)
;--------------------------------------
;
BAUDGEN:        equ         394h                    ; baud rate select register
;
;                           76543210
;                           ||||||||
;                           |||||+++--- b0,1,2.. SIO channel A
;                           ||+++------ b3,4,5.. SIO channel B
;                           |+--------- b6    .. Green status LED
;                           +---------- b7    .. Red status LED - HALT state
;
BAUD4800:       equ         0
BAUD9600:       equ         1
BAUD19200:      equ         2
BAUD38400:      equ         3
BAUD57600:      equ         4
BAUD115200:     equ         5
SYSSTATUS:      equ         10111111b
HALTSTATE:      equ         01111111b
;
;
;--------------------------------------
; SIO Ch.B RPi interface
;--------------------------------------
;
END:            equ         0c0h                    ; SLIP escame codes
ESC:            equ         0dbh                    ; https://en.wikipedia.org/wiki/Serial_Line_Internet_Protocol
ESCEND:         equ         0dch
ESCESC:         equ         0ddh
;
; | Command (5)(10)   | cmd    | byte.1       | byte.2          | byte.3        | byte.4    | byte.5     | byte.6     |
; |-------------------|--------|--------------|-----------------|---------------|-----------|------------|------------|
; | Set video mode    | 0      | Mode=0..9    | 0               | 0             | 0         | 0          | 0          |
; | Set display page  | 1      | Page         | 0               | 0             | 0         | 0          | 0          |
; | Cursor position   | 2      | Page         | 0               | col=0..79(39) | row=0..24 | 0          | 0          |
; | Cursor enable     | 3      | on=1 / off=0 | 0               | 0             | 0         | 0          | 0          |
; | Put character (1) | 4      | Page         | char code       | col=0..79(39) | row=0..24 | 0          | Attrib.(2) |
; | Get character (6) | 5      | Page         | 0               | col=0..79(39) | row=0..24 | 0          | 0          |
; | Put character (7) | 6      | Page         | char code       | col=0..79(39) | row=0..24 | 0          | 0          |
; | Scroll up (4)     | 7      | Rows         | T.L col         | T.L row       | B.R col   | B.R row    | Attrib.(2) |
; | Scroll down (4)   | 8      | Rows         | T.L col         | T.L row       | B.R col   | B.R row    | Attrib.(2) |
; | Put pixel         | 9      | Page         | Pixel color (3) |       16-bit column       |       16-bit row        |
; | Get pixel (8)     | 10     | Page         | 0               |       16-bit column       |       16-bit row        |
; | Clear screen      | 11     | Page         | 0               | 0             | 0         | 0          | Attrib.(2) |
; | Echo (9)          | 255    | 1            | 2               | 3             | 4         | 5          | 6          |
;
; (1) Character is written to cursor position
; (2) Attribute: Attribute byte will be decoded per video mode
; (3) XOR-ed with current pixel if bit.7=1
; (4) Act on active page
; (5) PC/XT can send partial command, any bytes not sent will be considered 0
; (6) Return data format: two bytes {character}{attribute}
; (7) same at command #4, but use existing attribute
; (8) Return data format: one byte {color_code}
; (9) Return data format: six bytes {6}{5}{4}{3}{2}{1}
; (10) Two high order bits are command queue: '00' VGA emulation, '01' tbd, '10' tbd, '11' system
;
RPIVGASETVID:   equ         0
RPIVGASETPAGE:  equ         1
RPIVGACURSPOS:  equ         2
RPIVGACURSENA:  equ         3
RPIVGAPUTCHATT: equ         4
RPIVGAGETCH:    equ         5
RPIVGAPUTCH:    equ         6
RPIVGASCRLUP:   equ         7
RPIVGASCRLDN:   equ         8
RPIVGAPUTPIX:   equ         9
RPIVGAGETPIX:   equ         10
RPIVGASCRCLR:   equ         11
;
RPISYSECHO:     equ         255
;
;--------------------------------------
; INT 13 status codes
;--------------------------------------
;
INT13NOERR:     equ         000h                    ;  no error
INT13BADCMD:    equ         001h                    ;  bad command passed to driver
INT13BADSEC:    equ         002h                    ;  address mark not found or bad sector
INT13WRPROT:    equ         003h                    ;  diskette write protect error
INT13SECNF:     equ         004h                    ;  sector not found
INT13RSTFAIL:   equ         005h                    ;  fixed disk reset failed
INT13DSKCHG:    equ         006h                    ;  diskette changed or removed
INT13BADPARAM:  equ         007h                    ;  bad fixed disk parameter table
INT13DMAOVR:    equ         008h                    ;  DMA overrun
INT13DMA64K:    equ         009h                    ;  DMA access across 64k boundary
INT13HDDBADSEC: equ         00Ah                    ;  bad fixed disk sector flag
INT13BADCYL:    equ         00Bh                    ;  bad fixed disk cylinder
INT13UNSUPMED:  equ         00Ch                    ;  unsupported track/invalid media
INT13INVSEC:    equ         00Dh                    ;  invalid number of sectors on fixed disk format
INT13HDDADDERR: equ         00Eh                    ;  fixed disk controlled data address mark detected
INT13DMAERR:    equ         00Fh                    ;  fixed disk DMA arbitration level out of range
INT13CRCERR:    equ         010h                    ;  ECC/CRC error on disk read
INT13FIXCRC:    equ         011h                    ;  recoverable fixed disk data error, data fixed by ECC
INT13FLPERR:    equ         020h                    ;  controller error (NEC for floppies)
INT13SEELFAIL:  equ         040h                    ;  seek failure
INT13TOVERR:    equ         080h                    ;  time out, drive not ready
INT13DRVNRDY:   equ         0AAh                    ;  fixed disk drive not ready
INT13UNDEFERR:  equ         0BBh                    ;  fixed disk undefined error
INT13WRFAIL:    equ         0CCh                    ;  fixed disk write fault on selected drive
INT13HDDERR:    equ         0E0h                    ;  fixed disk status error/Error reg = 0
INT13SENSEFAIL: equ         0FFh                    ;  sense operation failed
;
;======================================
; other IO addresses on PC/XT system
;======================================
;
;   200 - 20F Game port
;   210 - 217 Expansion Unit
;   2F8 - 2FF Serial port 2
;   300 - 31F Prototype card  |
;   320 - 32F Fixed disk      +- mod IO range, see below
;       - 33F                 |   
;   378 - 37F Parallel port 1
;   380 - 38F SDLC bisynchronous 2
;   3B0 - 3BF Monochrome adaptor/printer
;   3D0 - 3D7 CGA
;   3F0 - 3F7 Floppy disk
;   3F8 - 3FF Serial port
; 
; -- end of file --
;

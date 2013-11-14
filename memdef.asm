;********************************************************************
; memdef.asm
;
;  BIOS rewrite for PC/XT
;
;  BIOS replacement for PC/XT clone
;  memory segment and data structures.
;
;********************************************************************
;
; change log
;------------
; created       02/02/2013              file structure
;
;--------------------------------------
; memory map
;--------------------------------------
;
;					OS memry map (DOS)								Monitor mode
;				==========================						=====================
;
;									20bit physical									20bit physical
;									---------------									---------------
;	0000:0000	+--- vectors ---+	00000h			0000:0000	+--- vectors ---+	00000h
;				|	  |			|								|	  |			|
;				|	 \ /		|								|	 \ /		|
;				|				|								|				|
;				|				|								|				|
;				|	 / \		|								|	 / \		|
;				|	  |			|								|	  |			|
;	0030:0100	|    stack      |					0030:0100	|    stack      |
;	0040:0000	+-- BIOS data --+	00400h   		0040:0000	+-- BIOS data --+	00400h
;				|	  |			|								|	  |			|
;				|	 \ /		|								|	 \ /		|
;				|				|								|				|
;	0050:0000	+-- Boot data --+   00500h						|				|
;				|	  |			|					0060:0000	+--- MONITOR ---+   00600h
;				|	 \ /		|								|	  data		|
;				|				|								|	  |			|
;				|				|								|	 \ /		|
;	0070:0000	+--- DOS seg ---+   00700h			0070:0000	+--- XMODEM  ---+   00700h
;				|	  |			|								|	 & disk		|
;				|	 \ /		|								|	staging		|
;				|				|								|	  |			|
;				|				|								|	 \ /		|
;				|				|								|				|
;				|				|					00b0:0000	+---  free   ---+   00b00h
;				|				|								|	  |			|
;				|				|								|	 \ /		|
;				|				|								|				|
;	0000:7c00	+--- IPL seg ---+	07c00h						|				|
;				|   512 bytes	|								|				|
;				|	  |			|								|				|
;				|	 \ /		|								|				|
;				|				|								|				|
;				|				|								|				|
;	f000:8000	+-- ROM BIOS ---+	f8000h			f000:8000	+-- ROM BIOS ---+	f8000h
;				|	  |			|								|	  |			|
;				|	 \ /		|								|	 \ /		|
;				|				|								|				|
;				+---------------+	fffffh						+---------------+	fffffh
;
;--------------------------------------
; BIOS control data
;--------------------------------------
;
BIOSDATASEG:	equ         0040h
BIOSDATAOFF:	equ         0000h
;
;--------------------------------------
; Stack
;--------------------------------------
;
STACKSEG:		equ			0030h				; default stack segment
STACKTOP:		equ			0100h				; default top-of-stack
;
;--------------------------------------
; Boot disk directory from IPL
;--------------------------------------
; DOS system will use the 512 bytes of this segment
;
DOSDATASEG:     equ         0050h
DOSDATAOFF:     equ         0000h
;
;--------------------------------------
; "Kernel" of PC-DOS or sys
; @@- may not be needed
;--------------------------------------
;
DOSSEG:         equ         0070h
DOSOFF:         equ         0000h
;
;--------------------------------------
; ROM monitor RAM area
;--------------------------------------
;
MONSEG:         equ         0060h
MONOFF:         equ         0000h
;
;--------------------------------------
; XMODEM buffer area
; will use 1030 bytes starting atthis addres
;--------------------------------------
;
STAGESEG:		equ         0070h
STAGEOFF:		equ         0000h
;
;--------------------------------------
; Segment for boot block
;--------------------------------------
;
; The following boot block is loaded by BIOS with 512 bytes from
; the first sector of the bootable device.
; Control is transferred to the first word 0000:7C00 of the disk-resident bootstrap
; New BIOS will also use this block of 512 bytes as a temporary buffer for IDE setup
;
IPLSEG:         equ         0000h
IPLOFF:         equ         7C00h
;
;--------------------------------------
; BIOS and ROM MONITOR code
;--------------------------------------
;
ROMSEG:			equ         0f000h      		; using 28C256 32Kx8 EEPROM
ROMOFF:			equ         8000h       		;
;
;--------------------------------------
; general equates
;--------------------------------------
;
RSTVEC:			equ         0fff0h      		; CPU reset vector
RELDATE:		equ         0fff5h      		; BIOS release date stamp
CHECKSUM:		equ         0fffeh      		; BIOS checksum
MAX_MEMORY:		equ			704					; maximum kilobytes of memory allowed
DRIVEPARAMVEC:	equ			078h				; drive parameter table vector
;
;--------------------------------------
; BIOS control and status data structure
;--------------------------------------
;
struc           BIOSDATA
;
; Equipment
;
                resw        4                   ; 40:00 - RS232 com. ports - up to four
                resw        4                   ; 40:08 - Printer ports    - up to four
bdEQUIPMENT:	resw        1                   ; 40:10 + Equipment present word
                                                ;       |
                                                ;       - (1 if  floppies) *     1.
                                                ;       - (# 64K sys ram ) *     4.
                                                ;       - (init crt mode ) *    16.
                                                ;       - (# of floppies ) *    64.
                                                ;       - (# serial ports) *   512.
                                                ;       - (1 iff toy port) *  4096.
                                                ;       - (# parallel LPT) * 16384.
                resb        1                   ; 40:12 - MFG test flags, unused by us
bdMEMSIZE:		resw        1                   ; 40:13 - Memory size, kilobytes
bdIPLERR:		resb        1                   ; 40:15 - IPL errors<-table/scratchpad
                resb        1                   ;  ...unused
;
; Keyboard data area
;
bdSHIFT:		resw        1                   ; 40:17 - Shift/Alt/etc. keyboard flags
                resb        1                   ; 40:19 - Alt-KEYPAD char. goes here
bdKEYBUFHEAD:	resw        1                   ; 40:1A - --> keyboard buffer read poiter (head)
bdKEYBUFTAIL:	resw        1                   ; 40:1C - --> keyboard buffer write pointer (tail)
bdKEYBUF:		resw        16                  ; 40:1E - Keyboard Buffer (Scan,Value)
;
; Diskette data area @@- should I use this for the HDD controller to be compatible with BIOS calls?
;
                resb        1                   ; 40:3E - Drive Calibration bits 0 - 3
                resb        1                   ; 40:3F - Drive Motor(s) on 0-3,7=write
                resb        1                   ; 40:40 - Ticks (18/sec) til motor off
bdDRIVESTATUS:	resb        1                   ; 40:41 + Floppy return code stat byte
                                                ;       |
                                                ;       - 001h   1 = bad ic 765 command req.
                                                ;       - 002h   2 = address mark not found
                                                ;       - 003h   3 = write to protected disk
                                                ;       - 004h   4 = sector not found
                                                ;       - 008h   8 = data late (DMA overrun)
                                                ;       - 009h   9 = DMA failed 64K page end
                                                ;       - 010h  16 = bad CRC on floppy read
                                                ;       - 020h  32 = bad NEC 765 controller
                                                ;       - 040h  64 = seek operation failed
                                                ;       - 080h 128 = disk drive timed out
bdIDECMDBLOCK:					                ; 40:42 - IDE command block registers (was "7 status bytes from floppy controller")
bdIDEFEATUREERR:resb		1					;		IDEFEATUREERR: - Feature (wr) and error (rd) information
bdIDESECTORS:	resb		1					; 		IDESECTORS:	   - sector count to read/write
bdIDELBALO:		resb		1					; 		IDELBALO:	   - low byte of LBA (b0..b7)
bdIDELBAMID:	resb		1					; 		IDELBAMID:	   - mid byte of LBA (b8..b15)
bdIDELBAHI:		resb		1					; 		IDELBAHI:	   - high byte of LBA (b16..b23)
bdIDEDEVLBATOP:	resb		1					; 		IDEDEVLBATOP:  - drive select and/or head and top LBA address bits (b24..b27) - see below
bdIDECMDSTATUS:	resb		1					; 		IDECMDSTATUS:  - commad (wr) or regular status (rd) - see below
;
; Video display area
; ( defined but will not be used)
;
bdVIDEOMODE:    resb        1                   ; 40:49 + Current CRT mode  (software)
                                                ;       |
                                                ;       - 0 = 40 x 25 text (no color)
                                                ;       - 1 = 40 x 25 text (16 color)
                                                ;       - 2 = 80 x 25 text (no color)
                                                ;       - 3 = 80 x 25 text (16 color)
                                                ;       - 4 = 320 x 200 grafix 4 color
                                                ;       - 5 = 320 x 200 grafix 0 color
                                                ;       - 6 = 640 x 200 grafix 0 color
                                                ;       - 7 = 80 x 25 text (mono card)
                resw        1                   ; 40:4A - Columns on CRT screen
                resw        1                   ; 40:4C - Bytes in the regen region
                resw        1                   ; 40:4E - Byte offset in regen region
                resw        8                   ; 40:50 - Cursor pos for up to 8 pages
                resw        1                   ; 40:60 - Current cursor mode setting
bdVIDEOPAGE:    resb        1                   ; 40:62 - Current page on display
                resw        1                   ; 40:63 - Base addres (B000h or B800h)
                resb        1                   ; 40:65 - ic 6845 mode reg. (hardware)
                resb        1                   ; 40:66 - Current CGA palette
;
; Used to setup ROM
;
                resw        2                   ; 40:67 - Eprom base Offset,Segment
bdINRTFLAG:		resb        1                   ; 40:6B - Last spurious interrupt IRQ
;
; Timer data area
;
bdTIMELOW:      resw        1                   ; 40:6C - Ticks since midnight (lo)
bdTIMEHI:       resw        1                   ; 40:6E - Ticks since midnight (hi)
bdNEWDAY:       resb        1                   ; 40:70 - Non-zero if new day
;
; System data area
;
                resb        1                   ; 40:71 - Sign bit set if break
bdBOOTFLAG:		resw        1                   ; 40:72 - Warm boot if 1234h value
;
; Hard disk scratchpad
;
                resw        2                   ; 40:74 - Hard disk scratchpad
;
; Time-out areas COM/LPT
;
                resb        4                   ; 40:78 - Ticks for LPT 1-4 timeouts
                resb        4                   ; 40:7C - Ticks for COM 1-4 timeouts
;
; Keyboard buf start/end
;
bdKEYBUFSTART:  resw        1                   ; 40:80 - Contains 1Eh, buffer start
bdKEYBUFEND:    resw        1                   ; 40:82 - Contains 3Eh, buffer end
;
;--------------------------------------
; XMODEM data structure,
; only valid in monitor mode
;--------------------------------------
;
; temporary buffer for XMODEM
;
bdXMODEMBUFF:	resb		XMODEMBUFFER		; 40:84 - temporary buffer for XMODEM
bdLAST:			resb		1					; 40:109 - address of last byte in BIOS data area
;
endstruc
;
;--------------------------------------
; ROM monitor data structure
;--------------------------------------
;
MAXTOKENS:		equ			10
BUFFSIZE:		equ			80					; number of characters in input line buffer
BUFFEND:		equ			(BUFFSIZE-1)		; maximum input line buffer character count
;
struc           MONDATA
;
mdCMDBUFF:		resb		BUFFSIZE			; 70:00 - input line buffer
mdBUFFTERM:		resw		1					; 70:50 - buffer NULL terminator
mdTOKENCOUNT:	resw		1					; 70:52 - number of tokens in the list of indexes that follows (max. 10)
mdTOKENINDEX:	resw		MAXTOKENS			; 70:54 - list of 10 token indexes
mdCHARS:		resw		1					; 70:68 - characters in buffer
mdMONEXTENSION:	resw		2					; 70:6A - far pointer to monitor mode command extensions
;
endstruc
;
;--------------------------------------
; emulated drive geometry data structure
;--------------------------------------
;
struc           DRVDATA
;
ddDRIVEID:		resb		1					; drive ID
ddDASDTYPE:		resb		1					; type of drive (see INT13, 15)
ddTYPE:			resb		1					; CMOS drive type: 0 = HDD, 1 = 5.25/360K, 2 = 5.25/1.2Mb, 3 = 3.5/720K, 4 = 3.3/1.44Mb
ddDRVGEOCYL:	resw		1					; cylinders
ddDRVGEOHEAD:	resb		1					; heads
ddDRVGEOSEC:	resb		1					; sectors per track
ddDRVMAXLBA:	resw		1					; Max LBAs
ddDRVHOSTOFF:	resw		1					; LBA offset into IDE host drive
ddDBT:			resb		11					; Disk Base Table (DBT)
;
endstruc
;
; -- end of file --
;

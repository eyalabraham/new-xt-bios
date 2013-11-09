;********************************************************************
; mon88.asm
;
;	monitor mode source code include file
;	some strings and equates are defined in:
;	   newbios.asm ('static data'), memdef.asm, iodef.asm
;
;********************************************************************
;
;---------------------------------------------------;
; monitor mode command:							   	;
; ipl .......................... attempt an IPL		;
; cold ......................... cold start			;
; warm ......................... warm start			;
; memwr <seg> <off> ............ download to mem	;
; drvwr <lbaH> <lbaL> .......... download to disk	;
; memrd <seg> <off> <cnt> ...... upload from mem	;
; drvrd <lbaH> <lbaL> <cnt> .... upload from disk	;
; go <seg> <off>' .............. run code			;
; iord <port>' ................. input from port	;
; iowr <port> <byte>' .......... output to port		;
; memdump <seg> <off>' ......... read and disp mem	;
; drvdump <lbaH> <lbaL>' ....... display sector		;
; help' ........................ print help text	;
;												   	;
; numeric parameters can be:					   	;
;	decimal 0 - 65535							   	;
;	hex     0000h - ffffh						   	;
;	binary  00000000b - 11111111b				   	;
;---------------------------------------------------;
;
;-----	CHECK POINT 9 and entery to monitor mode
;
MONITOR:		mov			sp,STACKTOP					; reset stack pointer
				mov			ax,MONSEG					; establish monitor data segments
				mov			ds,ax						; initialize segments
				mov			es,ax
				mov			si,MONOFF					; data offset pointer [DS:SI] to command buffer
				mov			di,0
				cld										; auto incrementing string pointers
;
				mov			ax,(MONSTUB+ROMOFF)
				mov			[ds:si+mdMONEXTENSION],ax	; initialize far pointer to monitor extensions stub
				mov			ax,cs
				mov			[ds:si+(mdMONEXTENSION+2)],ax
				xor			ax,ax
				mov			[ds:si+mdBUFFTERM],ax		; initialize buffer NULL terminator
;
				mcrPRINT	MONITORMSG					; entering monitor mode notification
				mcr7SEG		9							; display '9' on 7-seg
				mcrPRINT	CHECKPOINT9
;
;-----	get console input and process characters
;
PROMPTLOOP:		mcrPRINT	MONPROMPT					; print prompt
;
				mov			si,MONOFF					; reset pointers [DS:SI] to command buffer -- code below changes SI!! --
				mov			di,MONOFF					; and [ES:DI] -- code changes them below!! --
				mov			ax,MONSEG
				mov			es,ax
;
				mov			word [ds:si+mdCHARS],0		; initialize index and buffer
				mov			word [ds:si+mdTOKENCOUNT],0	; initialize token count
				mov			cx,BUFFSIZE
				mov			al,0
				push		di
				mov			di,MONOFF
				rep stosb
				pop			di
;
INPUTLOOP:		mov			ah,00h
				int			16h							; wait for keyboard input
;
				cmp			al,CR						; is it a carriage return?
				je			PROCCMD						; yes, don't store it in the buffer, just process it
;
				mov			bx,[ds:si+mdCHARS]			; get charater index/count
				cmp			bx,BUFFSIZE					; do we have room in the line buffer for this character?
				jl			NOBUFFOVR					; yes, accept character
				cmp			al,BS						; no, but is this a backspace key?
				jne			NOTBS						; not backspace, error beep
				jmp			ISBS						; it is a backspace
;
NOTBS:			mov			cx,1202						; beep frequency 800Hz
				mov			bl,8						; beep 0.1 sec
				call		BEEP						; sound beep
				jmp			INPUTLOOP					; wait for another character
;
NOBUFFOVR:		cmp			al,BS						; is this a backspace key?
				jne			STORECHAR					; no, this is a printable character, continue
				cmp			bx,0						; it is a backspace, first check if there are any characters in the line buffer
				je			INPUTLOOP					; no characters left to backspace through, nothing to do
ISBS:			dec			bx							; decrement character count
				mov			byte [ds:si+bx],0			; store a '0' terminating character
				mcrPRINT	MONCLRCHAR					; clear backspaced character
				jmp			CONOUTPUT					; output the backspace to the console
;
STORECHAR:		mov			[ds:si+bx],al				; store character in input buffer
				inc			bx							; increment buffer input index
;
CONOUTPUT:		mov			[ds:si+mdCHARS],bx			; store input index
				mov			ah,0eh						; echo character to console
				int			10h
				jmp			INPUTLOOP					; get more characters
;
PROCCMD:		mcrPRINT	CRLF						; advance one line with CR, LF sequence
;
;-----	tokenize command line buffer by replacing all space charactar with '0' delimiters
;
				xor			bx,bx						; initialize character index
				mov			cx,BUFFSIZE					; initialize character counter
;
MORECHARS:		mov			al,[ds:si+bx]				; get chracter
				cmp			al,0						; is this a NULL character?
				je			GOCOUNT						; yes, we're done. go to count tokens
				cmp			al,(' ')					; is it a SPACE character?
				jne			SCANCONT					; no, continue character scan
				xor			al,al
				mov			[ds:si+bx],al				; yes, replace the 'space' with '0'
SCANCONT:		inc			bx							; next character index
				loop		MORECHARS					; loop to process command string buffer characters
;
;-----	scan buffer, count and save indexes of delimiter-to-character transitions
;
GOCOUNT:		xor			bx,bx						; reset character counter
				xor			dx,dx						; initialize token counter
				mov			cx,(BUFFSIZE+1)				; initialize character counter to go over into buffer delimiter area
				mov			ah,1						; initialize flag to 'on delimiter'
;
COUNTLOOP:		mov			al,[ds:si+bx]				; get chracter
				cmp			al,0						; is this a token delimiter?
				je			ISDELIM						;  yes, continue scanning
				cmp			ah,0						;  not delimiter, was the previous chractaer a character or delimiter?
				je			NEXTCHAR					;
;
				push		ax
				push		bx							; save registers
				mov			al,2
				mul			dl							; multiply token count by 2 to generate index into token-index table
				pop			bx							; AX=index into table, BX=character count (the index to save)
				xchg		ax,bx						; swap them
				mov			[ds:si+mdTOKENINDEX+bx],ax	; save index in table
				xchg		ax,bx						; swap back
				pop			ax
;
				inc			dx							;  no, we got a character after a delimiter so increment token count
				cmp			dx,MAXTOKENS				; check against max. token count
				jae			TOOMANYTOKENS				; too many tokens, flag error
				xor			ah,ah						; we are on a character, so clear flag
				jmp			NEXTCHAR					; continue to loop through characters in buffer
ISDELIM:		inc			ah							; not a character, so raise ''on delimiter' flag
NEXTCHAR:		inc			bx							; next character index
				loop		COUNTLOOP					; loop for next character
;
				mov			[ds:si+mdTOKENCOUNT],dx		; store token count
				cmp			dx,0
				jz			PROMPTLOOP					; if no tokens found it is an empty line, go back to prompt
				jmp			EXECCMD
;
TOOMANYTOKENS:	mcrPRINT	MONTOKENERR					; too many parameters (tokens) error
				jmp			PROMPTLOOP
;
;-----	try to call command extensions first
;
;EXECCMD:		call		far [ds:si+mdMONEXTENSION]	; first call extensions
;				jnc			PROMPTLOOP					; if CY.f=0 then extensions processed the command, we're done, go to prompts
;
;-----	set up pointers to command line token and command table
;
EXECCMD:		mov			di,(MONJUMPTBL+ROMOFF)
				mov			ax,cs
				mov			es,ax						; [ES:DI] is pointer to jump table strings
				mov			si,MONOFF					; data offset pointer [DS:SI] to command buffer
				mov			cx,MONFUNCCOUNT				; counter of available functions
;
				mov			ax,0						; get first token
				call		GETTOKEN
				jc			MONCMDERROR					; exit here if error
				add			si,ax						; adjust token start pointer
;
;-----	compare command line tokens and invoke command function
;
TOKENCMP:		xor			bx,bx
STRINGCMP:		mov			ah,[ds:si+bx]				; get character from token and keep in AH
				mov			al,ah
				or			al,[es:di+bx]				; have we reached end of both strings?
				jz			CMDFOUND					;  yes, found a matching command
;
				cmp			ah,[es:di+bx]				; do the characters match?
				jne			NEXTTOKEN					;  no, exit to get next token
				inc			bx							;  yes, increment string character pointer
				jmp			STRINGCMP					; continue to compare the string
;
CMDFOUND:		mov			ax,[es:di+8]				; get call address offset from jump table
				call		ax							; call function
				jc			MONCMDERROR					; if CY.f=1 there was an error
				jmp			PROMPTLOOP					; go back to prompt
;
NEXTTOKEN:		add			di,10						; next token on jump table
				loop		TOKENCMP					; loop for next command comparison
;
;-----	not a reognized command
;
MONCMDERROR:	mcrPRINT	MONCMDERR					; print command not recognized
				jmp			PROMPTLOOP
;
;-----	monitor command jump table
;
MONJUMPTBL:		db			"ipl",0,0,0,0,0
				dw			(MONIPL+ROMOFF)
				db			"cold",0,0,0,0
				dw			(COLDSTART+ROMOFF)
				db			"warm",0,0,0,0
				dw			(WARMSTART+ROMOFF)
				db			"memwr",0,0,0
				dw			(MEMORYWR+ROMOFF)
				db			"drvwr",0,0,0
				dw			(DRIVEWR+ROMOFF)
				db			"memrd",0,0,0
				dw			(MONNONE+ROMOFF)
				db			"drvrd",0,0,0
				dw			(MONNONE+ROMOFF)
				db			"go",0,0,0,0,0,0
				dw			(MONNONE+ROMOFF)
				db			"iord",0,0,0,0
				dw			(IORD+ROMOFF)
				db			"iowr",0,0,0,0
				dw			(IOWR+ROMOFF)
				db			"memdump",0
				dw			(MEMORYDUMP+ROMOFF)
				db			"drvdump",0
				dw			(DRVDUMP+ROMOFF)
				db			"help",0,0,0,0
				dw			(MONHELP+ROMOFF)
;
MONFUNCCOUNT:	equ			($-MONJUMPTBL)/10				; length of table for validation
;
;-----------------------------------------------;
; this routine is a stub for unimplemented		;
; monitor mode commandds						;
;												;
; entry:										;
;	NA											;
; exit:											;
;	CY.f=0 no error								;
;-----------------------------------------------;
;
MONNONE:		mcrPRINT	MONCMDNONE					; print command not implemented
				clc
				ret
;
;-----------------------------------------------;
; attempt an IPL								;
;												;
; entry:										;
;	NA											;
; exit:											;
;	NA											;
;-----------------------------------------------;
;
MONIPL:			add			sp,2						; discard 'call' return address
				jmp			IPLBOOT						; jump to IPL boot
;
;-----------------------------------------------;
; invoke a cold start from monitor mode			;
;												;
; entry:										;
;	NA											;
; exit:											;
;	NA											;
;-----------------------------------------------;
;
COLDSTART:		jmp			COLD						; jump to cold start
;
;-----------------------------------------------;
; invoke a warm start from monitor mode			;
;												;
; entry:										;
;	NA											;
; exit:											;
;	NA											;
;-----------------------------------------------;
;
WARMSTART:		jmp			WARM						; jump to warm start
;
;-----------------------------------------------;
; get data from UART using XMODEM and write to	;
; momory location specified on command line		;
; as '<segment> <offset>'						;
;												;
; entry:										;
;	NA											;
; exit:											;
;	CY.f=0 no error								;
;	CY.f=1 error								;
;-----------------------------------------------;
;
MEMORYWR:		push		ax
				push		cx
				push		si
				push		ds
				push		bp							; save work registers
				mov			bp,sp
				sub			sp,6						; make room for 3 parameters to pass on call to XMODEMRX
;
				mov			ax,MONSEG
				mov			ds,ax						; establish pointer to monitor data
;
;-----	get segment and offset address tokens
;
				mov			cx,2						; setup to get 2 word tokens in a loop
GETSEGOFF:		mov			si,MONOFF
				mov			ax,cx
				call		GETTOKEN					; get the token that holds the address starting with <lbaL>
				jc			DRIVEWREXIT					; exit here if error
				add			si,ax						; adjust token start pointer
				call		ASCII2NUM					; convert the token into a number
				jc			DRIVEWREXIT					; if error, then exit
				sub			bp,2
				mov			[bp],ax						; save segment and offset address token
				loop		GETSEGOFF
;
				sub			bp,2
				mov			word [bp],FUNCMEMWR			; flag the function to write to the HDD
				call		XMODEMRX
;
;-----	exit command function
;
MEMORYWREXIT:	add			sp,6						; discard parameters from stack
				pop			bp							; restore registers
				pop			ds
				pop			si
				pop			cx
				pop			ax
				ret
;
;-----------------------------------------------;
; get data from UART using XMODEM and write to	;
; drive location specified on command line		;
; as '<lbaH> <lbaL>'							;
;												;
; entry:										;
;	NA											;
; exit:											;
;	CY.f=0 no error								;
;	CY.f=1 error								;
;-----------------------------------------------;
;
DRIVEWR:		push		ax
				push		cx
				push		si
				push		ds
				push		bp							; save work registers
				mov			bp,sp
				sub			sp,6						; make room for 3 parameters to pass on call to XMODEMRX
;
				mov			ax,MONSEG
				mov			ds,ax						; establish pointer to monitor data
;
;-----	get LBA address tokens
;
				mov			cx,2						; setup to get 2 word tokens in a loop
GETWRITELBA:	mov			si,MONOFF
				mov			ax,cx
				call		GETTOKEN					; get the token that holds the address starting with <lbaL>
				jc			DRIVEWREXIT					; exit here if error
				add			si,ax						; adjust token start pointer
				call		ASCII2NUM					; convert the token into a number
				jc			DRIVEWREXIT					; if error, then exit
				sub			bp,2
				mov			[bp],ax						; save LBA address token
				loop		GETWRITELBA					; loop through LBA address tokens
;
				sub			bp,2
				mov			word [bp],FUNCDRIVEWR		; flag the function to write to the HDD
				call		XMODEMRX
;
;-----	exit command function
;
DRIVEWREXIT:	add			sp,6						; discard parameters from stack
				pop			bp							; restore registers
				pop			ds
				pop			si
				pop			cx
				pop			ax
				ret
;
;-----------------------------------------------;
; read data from momory location				;
; '<seg> <off> <cnt>' and send to UART using	;
; XMODEM  										;
;												;
; entry:										;
;	NA											;
; exit:											;
;	CY.f=0 no error								;
;	CY.f=1 error								;
;-----------------------------------------------;
;
MEMORYRD:		nop										; any errors from above set CY.f, return it
MEMORYRDEXIT:	ret
;
;-----------------------------------------------;
; read data from drive location					;
; '<lbaH> <lbaL> <cnt>' and send to UART using	;
; XMODEM  										;
;												;
; entry:										;
;	NA											;
; exit:											;
;	CY.f=0 no error								;
;	CY.f=1 error								;
;-----------------------------------------------;
;
DRIVERD:		nop										; any errors from above set CY.f, return it
DRIVERDEXIT:	ret
;
;-----------------------------------------------;
; run code addressed by '<seg> <off>'			;
; code executed with far call needs to return	;
; control to this routine with a far return		;
;												;
; entry:										;
;	NA											;
; exit:											;
;	CY.f=0 no error								;
;	CY.f=1 error								;
;-----------------------------------------------;
;
CODEEXEC:		nop
CODEEXECEXIT:	ret
;
;-----------------------------------------------;
; read IO port '<port>' and display byte result	;
; on colsole in HEX, Decimal formats			;
;												;
; entry:										;
;	NA											;
; exit:											;
;	CY.f=0 no error								;
;	CY.f=1 error								;
;	all work registers are saved				;
;-----------------------------------------------;
;
IORD:			push		ax
				push		bx
				push		dx
				push		si
				push		ds							; save work registers
				mov			si,MONOFF
				mov			ax,MONSEG
				mov			ds,ax						; establish pointer to monitor data
;
				mov			ax,1						; get second token which is the port address
				call		GETTOKEN
				jc			IORDEXIT					; exit here if error
				add			si,ax						; adjust token start pointer
;
				call		ASCII2NUM					; convert the token into a number
				jc			IORDEXIT					; if error, then exit
				mov			dx,ax
				in			al,dx						; read IO port
				mov			bx,ax						; save AX
				mcrPRINT	MONPORTRD1					; print data read from port
				mov			ax,dx						; get port IO address
				call		PRINTHEXW					; print IO address
				mcrPRINT	MONPORTRD2					; print closing text
				mov			ax,bx						; restore data read
				call		PRINTHEXB					; print data byte from AL
				mcrPRINT	CRLF						; print new line
				clc										; no errors
;
IORDEXIT:		pop			ds
				pop			si
				pop			dx
				pop			bx
				pop			ax
				ret
;
;-----------------------------------------------;
; write '<byte>' to IO port '<port>'			;
;												;
; entry:										;
;	NA											;
; exit:											;
;	CY.f=0 no error								;
;	CY.f=1 error								;
;	all work registers are saved				;
;-----------------------------------------------;
;
IOWR:			push		ax
				push		dx
				push		si
				push		ds							; save work registers
				mov			ax,MONSEG
				mov			ds,ax						; establish pointer to monitor data
;
				mov			si,MONOFF
				mov			ax,1						; get second token which is the port address
				call		GETTOKEN
				jc			IOWREXIT					; exit here if error
				add			si,ax						; adjust token start pointer
				call		ASCII2NUM					; convert the token into a number
				jc			IOWREXIT					; if error, then exit
				mov			dx,ax						; save IO port address
;
				mov			si,MONOFF
				mov			ax,2						; get third token which is the data byte to write
				call		GETTOKEN
				jc			IOWREXIT					; exit here if error
				add			si,ax						; adjust token start pointer
				call		ASCII2NUM					; convert the token into a number
				jc			IOWREXIT					; if error, then exit
;
				out			dx,al						; write to IO port
;
IOWREXIT:		pop			ds
				pop			si
				pop			dx
				pop			ax
				ret
;
;-----------------------------------------------;
; read memory from '<seg> <off>' and			;
; 256B dump contents to console screen.			;
; format will be:								;
; <seg>:<off> <b0> ... <b15> <ascii chars>		;
;												;
; entry:										;
;	NA											;
; exit:											;
;	CY.f=0 no error								;
;	CY.f=1 error								;
;	all work registers are saved				;
;-----------------------------------------------;
;
MEMORYDUMP:		push		ax
				push		dx
				push		si
				push		di
				push		es
				push		ds							; save work registers
				mov			ax,MONSEG
				mov			ds,ax						; establish pointer to monitor data
;
				mov			si,MONOFF
				mov			ax,1						; get second token which is the address segment
				call		GETTOKEN
				jc			MEMORYDUMPEXIT				; exit here if error
				add			si,ax						; adjust token start pointer
				call		ASCII2NUM					; convert the token into a number
				jc			MEMORYDUMPEXIT				; if error, then exit
				mov			dx,ax						; save IO port address
;
				mov			si,MONOFF
				mov			ax,2						; get third token which is the address offset
				call		GETTOKEN
				jc			MEMORYDUMPEXIT				; exit here if error
				add			si,ax						; adjust token start pointer
				call		ASCII2NUM					; convert the token into a number
				jc			MEMORYDUMPEXIT				; if error, then exit
;
				mov			di,ax						; setup pointer [ES:DI] for memory dump routine
				mov			es,dx
				mov			ax,16						; 16 paragraphs or 256B
				call		MEMDUMP						; call memory dump display
;
MEMORYDUMPEXIT:	pop			ds
				pop			es
				pop			di
				pop			si
				pop			dx
				pop			ax
				ret
;
;-----------------------------------------------;
; read a sector from the drive and dump content	;
; to console. sector read from LBA address		;
; given by <lbaH> <lbaL>' to form the 28 bit	;
; LBA address.					;
; the routine prints only 1 sector of 512 bytes	;
;												;
; entry:										;
;	NA											;
; exit:											;
;	CY.f=0 no error								;
;	CY.f=1 error								;
;	all work registers are saved				;
;-----------------------------------------------;
;
DRVDUMP:		push		ax
				push		bx
				push		cx
				push		dx
				push		si
				push		di
				push		es
				push		ds							; save work registers
				mov			ax,MONSEG
				mov			ds,ax						; establish pointer to monitor data
;
;-----	get LBA address part tokens
;
				mov			cx,2						; setup to get 2 word tokens in a loop
GETLBATOKENS:	mov			si,MONOFF
				mov			ax,cx
				call		GETTOKEN					; get the token that holds the address starting with <lbaL>
				jc			DRVDUMPEXIT					; exit here if error
				add			si,ax						; adjust token start pointer
				call		ASCII2NUM					; convert the token into a number
				jc			DRVDUMPEXIT					; if error, then exit
				push		ax							; save LBA address token
				loop		GETLBATOKENS				; loop through all four LBA address tokens
;
;-----	setup IDE command block for read
;
				mov			ax,BIOSDATASEG				; establish pointer to BIOS data
				mov			ds,ax
				mov			byte [ds:bdIDEFEATUREERR],0	; setup IDE command block, features not needed so '0'
				mov			byte [ds:bdIDESECTORS],1	; one (1) sector count to read
;
				pop			ax
				and			ah,IDEDEVSELECT				; device #0
				or			ah,IDELBASELECT				; LBA addressing mode
				mov			[ds:bdIDEDEVLBATOP],ah		; device, addressing and high LBA nibble (b24..b27)
				mov			[ds:bdIDELBAHI],al			; high LBA byte (b16..b23)
;
				pop			ax
				mov			[ds:bdIDELBAMID],ah			; mid LBA byte (b8..b15)
				mov			[ds:bdIDELBALO],al			; low LBA byte (b0..b7)
;
				mov			byte [ds:bdIDECMDSTATUS],IDEREADSEC	; read command
				call		IDESENDCMD					; send command block to drive
				jnc			DRVDUMPGETDATA
				jmp			DRVRDERROR
;
;-----	read a sector of data from the drive
;
DRVDUMPGETDATA:	mov			bx,STAGESEG
				mov			es,bx
				mov			bx,STAGEOFF					; pointer to data block destination
				mov			al,1						; one (1) sector
				call		IDEREAD						; read data from drive
				jnc			DRVSECTORPRINT				; no read errors go to print sector
;
DRVRDERROR:		mcrPRINT	DRVREADERROR				; print drive read error
				clc										; not really a function problem
				jmp			DRVDUMPEXIT
;
DRVSECTORPRINT:	mov			di,bx						; [ES:DI] point to data block read from drive
				mov			ax,32						; 32 paragraphs (512 bytes)
				call		MEMDUMP						; dump buffer contents to console
;
DRVDUMPEXIT:	pop			ds
				pop			es
				pop			di
				pop			si
				pop			dx
				pop			cx
				pop			bx
				pop			ax
				ret
;
;-----------------------------------------------;
; print help text								;
;												;
; entry:										;
;	NA											;
; exit:											;
;	CY.f=0 no error								;
;-----------------------------------------------;
;
MONHELP:		mcrPRINT	MONCMDHELP
				clc
				ret
;
;-----------------------------------------------;
; command extensions stub						;
; extensions preserve all registers and return 	;
; CY.f = 0 if command was processed or CY.f = 1	;
; if comand not processed						;
; this stub only returns CY.f = 1				;
;												;
; entry:										;
;	NA											;
; exit:											;
;	CY.f=1 stub did not process any commands	;
;-----------------------------------------------;
;
MONSTUB:		stc										; set CY.f=1 to indicate stub did not handle function
				retf									; must be a FAR return
;
;-----------------------------------------------;
; this routine returns a pointer to a token		;
; index passed to it in AX						;
; index is 0 base (0=1st token, 1=2nd etc.)		;
; the tokens must be in a tokenized string		;
; the tokens need to be '0' terminated			;
; the routine returns the string start index	;
; of the requested token in AX and CF.f=0		;
; if no tokens CY.f=1 and AX is not valid		;
;												;
; entry:										;
;	AX token index to retrieve					;
; exit:											;
;	AX string buffer start index of token		;
;	CY.f=1 no more tokens/bad index error		;
;	CY.f=0 token pointer is valid				;
;	all work registers are saved				;
;-----------------------------------------------;
;
GETTOKEN:		push		bx
				push		si
				push		ds							; save work registers
;
				mov			si,MONOFF
				mov			bx,MONSEG
				mov			ds,bx						; initialize pointer [DS:SI]
;
;-----	check for index validity (index < token count)
;
				cmp			ax,[ds:si+mdTOKENCOUNT]		; check index in range
				jb			INDEXOK						; index in range
				stc										; signal error
				jmp			GETTOKENEXIT				; and exit
;
;-----	get index from table
;
INDEXOK:		mov			bx,2
				mul			bl							; generate index to index-table
				mov			bx,ax
				mov			ax,[ds:si+mdTOKENINDEX+bx]	; get token index value
				clc										; signal index is valid
;
GETTOKENEXIT:	pop			ds							; retore work registers and exit
				pop			si
				pop			bx
				ret
;
;-----------------------------------------------;
; conver a string pointed to by DS:SI to		;
; a number returned in AX						;
; number returned is 16 bit max					;
; hex noted with 'h' at right end				;
; hex noted with 'b' at right end				;
; decimal with no notation at end of number		;
;												;
; entry:										;
;	DS:SI pointer to NULL terminated string		;
; exit:											;
;	AX 16 bit number							;
;	CY.f=1 convertion error						;
;	CY.f=0 valid number in AX					;
;-----------------------------------------------;
;
ASCII2NUM:		push		bx
				push		cx
				push		dx
				push		si
				push		ds							; save work registers
;
;-----	start scanning the number string fromn the right
;
				cld										; make sure SI increments
MOVERIGHT:		lodsb									; load a character
				or			al,al						; is it '0' i.e. right end?
				jnz			MOVERIGHT					; no, loop to next character
				sub			si,2						; point back to right most character
				std										; set to auto decrement
				mov			al,[ds:si]					; get the right most character
				cmp			al,('h')					; is it a HEX string?
				je			HEX2NUM
				cmp			al,('b')					; is it a BINARY string?
				je			BIN2NUM
;
;-----	convert DECIMAL notation to number
;
DEC2NUM:		xor			bx,bx
				mov			cx,1
NEXTDECCHAR:	lodsb									; get character
				or			al,al						; check for left end of string
				jz			ASCII2NUMOK					; exit if done processing string
				call		CHAR2NUM					; convert character to number now in AL
				jc			ASCII2NUMERR				; exit if error in digit
				cbw
				mul			cx							; multiply the number by the power
				jo			ASCII2NUMERR				; if DX has sugnificant digits then we have an error
				add			bx,ax						; accumulate sums in BX
				mov			ax,10
				mul			cx							; multiply power
				mov			cx,ax
				jmp			NEXTDECCHAR
;
;-----	convert HEX notation to number
;
HEX2NUM:		xor			bx,bx
				mov			cx,1
				sub			si,1						; point to first HEX digit
NEXTHEXCHAR:	lodsb									; get character
				or			al,al						; check for left end of string
				jz			ASCII2NUMOK					; exit if done processing string
				call		CHAR2NUM					; convert character to number now in AL
				jc			ASCII2NUMERR				; exit if error in digit
				cbw
				mul			cx							; multiply the number by the power
				jo			ASCII2NUMERR				; if DX has sugnificant digits then we have an error
				add			bx,ax						; accumulate sums in BX
				mov			ax,16
				mul			cx							; multiply power
				mov			cx,ax
				jmp			NEXTHEXCHAR
;
;-----	convert BINARY notation to number
;
BIN2NUM:		xor			bx,bx
				mov			cx,1
				sub			si,1						; point to LSB binary digit
NEXTBINCHAR:	lodsb									; get character
				or			al,al						; check for left end of string
				jz			ASCII2NUMOK					; exit if done processing string
				cmp			al,('1')					; is it a '1'?
				je			BINARY1						; yes, jump to accumulate sum
				cmp			al,('0')					; is it a '0'?
				je			BINARY0						; yes, jump to multiply power without accumulating sum
				jmp			ASCII2NUMERR				; not '1' not '0' so a bad digit type
BINARY1:		add			bx,cx						; accumulate sums in BX
BINARY0:		mov			ax,2
				mul			cx							; multiply power
				mov			cx,ax
				jmp			NEXTBINCHAR
;
;-----	conversion routine epilogs
;
ASCII2NUMOK:	mov			ax,bx						; load AX with number
				clc										; signal conversion ok
				jmp			ASCII2NUMDONE
;
ASCII2NUMERR:	xor			ax,ax
				stc										; signal conversion error
;
ASCII2NUMDONE:	cld										; set back to auto increment
				pop			ds							; restore work registers
				pop			si
				pop			dx
				pop			cx
				pop			bx
				ret
;
;-----------------------------------------------;
; this routine gets an ASCII character in AL	;
; and converts it to a number returned in AL	;
; the routine will set CY.f if the character	;
; cannot be converted to a number and clear		;
; the CY.f if the conversion is ok				;
;												;
; entry:										;
;	AL ASCII character code of a number			;
; exit:											;
;	AL the number represented by the ASCII code	;
;	CY.f=1 conversion error						;
;	CY.f=0 no error								;
;	all work registers are preserved			;
;-----------------------------------------------;
;
CHAR2NUM:		cmp			al,('0')					; is the character less than '0'?
				jb			CONVERR						; yes, then exit with error
				cmp			al,('9')					; is it less or equal to '9'?
				jbe			NUMERIC						; yes, conver a number character to a number
				or			al,00100000b				; only hex digits should be here, so convert to lower case
				cmp			al,('a')					; is it less that 'a'?
				jb			CONVERR						; yes, then exit with error
				cmp			al,('f')					; is it more that 'f'
				ja			CONVERR						; yes, then exit with error
;
;-----	convert a hex digit between 'a' and 'f'
;
				sub			al,('a')					; conver to number
				add			al,10
				clc										; signal good conversion
				jmp			CHAR2NUMEXIT
;
;-----	conver a numeric digit between '0' and '9'
;
NUMERIC:		sub			al,('0')					; conve to number
				clc										; signal good conversion
				jmp			CHAR2NUMEXIT
;
;-----	error exit or exit
;
CONVERR:		xor			al,al
				stc
;
CHAR2NUMEXIT:	ret
;
;-----------------------------------------------;
; this routine dumps memory contents to console	;
;												;
; entry:										;
;	ES:DI pointer to memory area				;
;	AX    number of paragraphs to dump			;
; exit:											;
;	NA											;
;   all work registers are saved				;
;-----------------------------------------------;
;
MEMDUMP:		push		ax
				push		bx
				push		cx
				push		di
				push		es							; save work register
;
				mcrPRINT	CRLF
;
				mov			cx,ax						; count of rows of 16 bytes for 512B block
				and			di,0fff0h					; reset DI to start at a 16 byte boundry
NEXTROW:		mov			ax,es						; print [ES:DI]
				call		PRINTHEXW
				mov			al,(':')
				call		PRINTCHAR
				mov			ax,di
				call		PRINTHEXW
				mov			al,(' ')
				call		PRINTCHAR
;
;-----	print HEX bytes
;
				xor			bx,bx						; reset byte counter before starting new row of bytes
NEXTBYTEHEX:	mov			al,[es:di+bx]				; get byte to print
				call		PRINTHEXB					; print byte as HEX
				mov			al,(' ')
				call		PRINTCHAR					; print space
				inc			bx
				cmp			bx,16						; check if 16 bytes were printed
				jb			NEXTBYTEHEX					; print next byte if not done
;
;-----	print ASCII characters
;
				mov			al,(' ')
				call		PRINTCHAR
;
				xor			bx,bx						; reset byte counter before starting new row of bytes
NEXTBYTEASCII:	mov			al,[es:di+bx]				; get byte to print
				cmp			al,32
				jb			PRINTPERIOD
				cmp			al,126
				ja			PRINTPERIOD					; if less that ASCII 32 or more than ASCII 126 print a period
				call		PRINTCHAR					; otherwise print the character
				jmp			NEXTASCII
PRINTPERIOD:	mov			al,('.')
				call		PRINTCHAR					; print a period character for non-printable ASCII
NEXTASCII:		inc			bx
				cmp			bx,16						; check if 16 bytes were printed
				jb			NEXTBYTEASCII				; print next byte if not done
;
;-----	finish a 16 byte row and repeat
;
				mcrPRINT	CRLF						; advance one line
				add			di,16						; advance DI to the next 16 bytes
				loop		NEXTROW
;
				mcrPRINT	CRLF
;
				pop			es
				pop			di
				pop			cx
				pop			bx
				pop			ax
				ret
;
;-----------------------------------------------;
; poll UART for XMODEM host reply				;
; return CY.f=1 if host timed out, or CY.f=0	;
; and received character in AL if not			;
;												;
; entry:										;
;	NA											;
; exit:											;
;	AL received character						;
;	AH not preserved!							;
;	CY.f=1 receive time out						;
;	CY.f=0 no error								;
;-----------------------------------------------;
;
WAITHOST:		push		cx
				push		dx
				push		ds
;
				mov			ax,BIOSDATASEG
				mov			ds,ax						; pointer to BIOS area
;
				mov			cx,XMODEMTOV				; for a 1sec TOV (see 'iodef.asm')
				xor			dx,dx
				cli
				add			cx,[ds:bdTIMELOW]			; determine future tick count to wait
				adc			dx,[ds:bdTIMEHI]
				sti										; restore interrupts
;
WAITRPLY:		mov			ah,01h
				int			16h							; did the host reply?
				jnz			GETHOSTCHAR					;  yes, continue and go get reply
				cmp			dx,[ds:bdTIMEHI]			; have we reached end of time out high word?
				ja			WAITRPLY					; no, loop back to keep waiting
				cmp			cx,[ds:bdTIMELOW]			; have we reached end of time out low word?
				ja			WAITRPLY
;
				stc										; timed out so flag and exit
				jmp			WAITHOSTEXIT
;
GETHOSTCHAR:	mov			ah,00h
				int			16h							; read received character
				clc
;
WAITHOSTEXIT:	pop			ds
				pop			dx
				pop			cx
				ret
;
;-----------------------------------------------;
; XMODEM receive routine						;
; raceived data through UART in XMODEM protocol	;
;												;
; entry:										;
;	LBA or SEG:OFF passed on stack				;
; exit:											;
;	NA											;
;	all registers saved							;
;-----------------------------------------------;
;
%macro			mcrXMODEMRESP	1						; macro to send response to host
				mov			ah,0eh						; output byte to console
				mov			al,%1						; byte to send with
				xor			bl,bl						; bogus page
				int			10h							; send response
%endmacro
;
LOCALVARIABLES:	equ			3
LOCALVARSPACE:	equ			(LOCALVARIABLES*2)			; stack space for local variables
;
;-----	local variables BP offsets
;
XBYTECOUNT:		equ			-6							; bytes in HDD write buffer
XEOT:			equ			-4							; flag to signal that EOT was sent by host
XCRC:			equ			-2							; XMODEM packet CRC
;
;-----	function parameter BP offsets
;
XHDDMEM:		equ			2
XLBAH:			equ			4							; high LBA word
XLBAL:			equ			6							; low LBA word
XMEMSEG:		equ			4							; memory segment and offset to write
XMEMOFF:		equ			6
;
;		.. registers ..
;		HDD bytes count		[BP-6]
;		host EOT flag		[BP-4]
;		CRC					[BP-2]
;		return address		[BP]
;		HDD/mem.			[BP+2]
;		LBA.H /SEGMENT		[BP+4]
;		LBA.L /OFFSET		[BP+6]
;		...
;
XMODEMRX:		mov			bp,sp						; setup BP as variable/parameter pointer
				sub			sp,LOCALVARSPACE			; move SP to make room for temp variable
;
				push		ax
				push		bx
				push		cx
				push		dx
				push		si
				push		di
				push		es
				push		ds							; save work registers
;
;-----	establish new temporay UART input buffer
;
				mov			ax,BIOSDATASEG				; establish pointer to BIOS data
				mov			ds,ax
				mov			ax,bdXMODEMBUFF				; buffer start offset in BIOS data structure
				cli
				mov			[ds:bdKEYBUFHEAD],ax		; store as buffer head pointer
				mov			[ds:bdKEYBUFTAIL],ax		; buffer tail pointer is same as head (empty)
				mov			[ds:bdKEYBUFSTART],ax		; buffer start address
				add			ax,XMODEMBUFFER
				mov			[ds:bdKEYBUFEND],ax			; buffer end address
				sti
;
;-----	establish data buffer pointers
;
				mov			ax,STAGESEG
				mov			es,ax						; set ES for disk write source
				mov			ds,ax
				mov			si,STAGEOFF					; [DS:SI] XMODEM temp buffer
;
;-----	establish XMODEM connection with host
;
				mov			word [ss:bp+XEOT],0			; clear EOT flag
				mov			word [ss:bp+XBYTECOUNT],0	; clear buffer byte count
				mov			dx,HOSTWAITTOV				; set max time to wait for host
;
CONNECTLOOP:	mcrXMODEMRESP	XSTART					; send "C" to start connection with host
WAITHOSTRPLY:	call		WAITHOST					; wait for host to reply, retun reply in AL
				jnc			GETFIRSTPACKET				; process packet is host did not time out
				dec			dx
				jnz			CONNECTLOOP					; loop to send another "C" becasue host did not reply yet
				mcrPRINT	XMODEMHOSTTOV				; print error message
				jmp			XMODEMRXEXIT
;
;-----	process data packets
;
GETMOREPACKETS:
RETRYPACKET:	call		WAITHOST					; on retry, wait for host byte
				jc			PACKETERR					; if time out go to error and see if we can try again
				mov			dh,5						; reset to 5 retry attempts
				jmp			RESUMEONRETRY				; byte received ok, check what it is
;
GETFIRSTPACKET:	mov			dl,1						; initialize sequence number
				mov			dh,5						; 5 retry attempts
RESUMEONRETRY:	mov			bx,0						; zero XMODEM buffer index
				mov			word [ss:bp+XCRC],0			; xero out CRC
				cmp			al,SOH						; is it a 128B packet?
				je			RCVPACKET					;  yes, go to receive loop
				cmp			al,EOT						; did the host send an EOT?
				je			HOSTEOT						;  yes, flush buffers to HDD and exit !! is the the right way !!
				cmp			al,CAN						; did the host send a CAN?
				je			HOSTCANCEL					;  yes, cancel the session
;
;-----	bad host respons, cancel
;
BADHOSTRESP:	mov			cx,XMODEMCANSEQ
				mcrXMODEMRESP	CAN						; send CAN
				loop		BADHOSTRESP
				mov			ax,2
				call		WAITFIX						; wait a bit (~400mSec) to clear console
				mcrPRINT	XMODEMBADRESP				; print notification and exit
				jmp			XMODEMRXEXIT
;
;-----	host sent EOT
;
HOSTEOT:		mcrXMODEMRESP	ACK						; host sent EOT, send ACK
				cmp			word [ss:bp+XBYTECOUNT],0	; are there any bytes to write?
				je			XMODEMRXEXIT				;  no, buffer is empty so exit
				mov			word [ss:bp+XEOT],1			;  yes, set EOT flag and go write what's left
				jmp			WRITEDEST
;
;-----	host sent a CAN cancel
;
HOSTCANCEL:		mcrXMODEMRESP	ACK						; host canceled the connection, send ACK
				mov			ax,2
				call		WAITFIX						; wait a bit to clear console
				mcrPRINT	XMODEMCANCEL				; print notification and exit
				jmp			XMODEMRXEXIT
;
;-----	XMODEM data receive loop and CRC
;
RCVPACKET:		mov			cx,XMODEMPACKET				; set packet size
				call		WAITHOST					; wait for packet number byte
				jc			PACKETERR					; packet error if timed out
				cmp			al,dl						; check sequence number matches expected number
				jne			PACKETERR					; no match so packet error
				call		WAITHOST					; wait for packet number complement byte
				jc			PACKETERR					; packet error if time out
				not			al
				cmp			al,dl						; compare complement of sequence number
				jne			PACKETERR					; packet error if no match
;
				xor			cx,cx						; zero byte count, also index to XMODEM input buffer
				mov			bx,[ss:bp+XBYTECOUNT]		; set BX to index of HDD write buffer
FILLBUFFER:		call		WAITHOST					; get a byte
				jc			PACKETERR					; packet error if time out
				mov			[ds:si+bx],al				; store byte
				call		CALCCRC						; run AL through CRC accumulator
				inc			bx							; increment buffer index
				inc			cx							; increment byte count
				cmp			cx,XMODEMPACKET
				jne			FILLBUFFER
				add			[ss:bp+XBYTECOUNT],cx		; accumulate byte count
;
				mov			al,0						; flush CRC calculator
				call		CALCCRC						; with more bytes of '0'
				mov			al,0
				call		CALCCRC
;
				call		WAITHOST					; get CRC hi byte
				jc			PACKETERR					; packet error if time out
				cmp			al,[ss:bp+(XCRC+1)]			; check CRC high byte
				jne			PACKETERR
				call		WAITHOST					; get CRC lo byte
				jc			PACKETERR					; packet error if time out
				cmp			al,[ss:bp+XCRC]				; check CRC low byte
				jne			PACKETERR
;
				inc			dl							; increment sequence number
;
				cmp			word [ss:bp+XBYTECOUNT],(512*XMODEMSEC) ; is the buffer full?
				je			WRITEDEST					; transfer the XMODEM buffer to HDD or memory
;
				mcrXMODEMRESP	ACK						; send ACK
				jmp			GETMOREPACKETS
;
;-----	packet error handling and retry
;
PACKETERR:		dec			dh							; decrement retry count
				jz			TOOMANYRETRY				; too many retries so abort
LINECLEAR:		call		WAITHOST
				jnc			LINECLEAR					; loop here until no more characters waiting in read buffer
				sub			word [ss:bp+XBYTECOUNT],cx	; discard byte count that was received before the error
				mcrXMODEMRESP	NAK						; send NAK
				jmp			RETRYPACKET					; and try again
;
TOOMANYRETRY:	mov			cx,XMODEMCANSEQ
				mcrXMODEMRESP	CAN						; cancel the connection
				loop		TOOMANYRETRY				; send CAN characters
				mov			ax,10
				call		WAITFIX						; wait about 2 sec to clear console
				mcrPRINT	XMODEMRETRYERR
				jmp			XMODEMRXEXIT
;
;-----	arbitrate between write to memory and HDD
;
WRITEDEST:		cmp			byte [ss:bp+XHDDMEM],FUNCDRIVEWR
				je			XFRTOHDD
				cmp			byte [ss:bp+XHDDMEM],FUNCMEMWR
				je			XFRTOMEM
				stc
				jmp			XMODEMRXEXIT
;
;-----	memory writes
;
XFRTOMEM:		mov			ax,[ss:bp+XMEMSEG]
				mov			es,ax
				mov			di,[ss:bp+XMEMOFF]			; establish pointer to destination memory region in [ES:DI]
				mov			cx,[ss:bp+XBYTECOUNT]		; setup counter for byte count
				rep movsw								; copy the buffer
				mov			si,STAGEOFF					; reset SI to XMODEM temp buffer offset
				mov			[ss:bp+XMEMOFF],di			; save DI offset for next transfer
				jmp			XFREPILOG					; conclude data transfer
;
;-----	setup IDE command block for HDD writes
;
XFRTOHDD:		push		ds
				mov			ax,BIOSDATASEG				; establish pointer to BIOS data
				mov			ds,ax
				mov			byte [ds:bdIDEFEATUREERR],0	; setup IDE command block, features not needed so '0'
				mov			byte [ds:bdIDESECTORS],XMODEMSEC ; sectors to write at a time
;
				mov			ax,[ss:bp+XLBAL]
				mov			[ds:bdIDELBALO],al			; low LBA byte (b0..b7)
				mov			[ds:bdIDELBAMID],ah			; mid LBA byte (b8..b15)
;
				mov			ax,[ss:bp+XLBAH]
				mov			[ds:bdIDELBAHI],al			; high LBA byte (b16..b23)
				and			ah,IDEDEVSELECT				; device #0
				or			ah,IDELBASELECT				; LBA addressing mode
				mov			[ds:bdIDEDEVLBATOP],ah		; device, addressing and high LBA nibble (b24..b27)
;
				mov			byte [ds:bdIDECMDSTATUS],IDEWRITESEC ; write command
				pop			ds
;
				call		IDESENDCMD					; send command block to drive
				jc			HDDWRITEERR					; if no errors write data to disk
;
;-----	write sectors of data from memory buffer to the drive
;
				mov			bx,STAGEOFF					; [ES:BX] pointer to write buffer
				mov			al,XMODEMSEC				; sector count
				call		IDEWRITE					; write data to drive
				jc			HDDWRITEERR					; exit if HDD write error
;
				add			word [ss:bp+XLBAL],XMODEMSEC ; advance LBA address
				adc			word [ss:bp+XLBAH],0
;
;-----	write data epilog for both memory and HDD writes
;
XFREPILOG:		mov			word [ss:bp+XBYTECOUNT],0	; clear buffer count for next write cycle
				cmp			word [ss:bp+XEOT],1			; did host send EOT so we're done?
				je			XMODEMRXEXIT				; done so exit
				mcrXMODEMRESP	ACK						; send ACK
				jmp			GETMOREPACKETS				; no errors and not done, so get more packets
;
;-----	handle HDD write error
;
HDDWRITEERR:	mov			cx,XMODEMCANSEQ
				mcrXMODEMRESP	CAN						; cancel the connection
				loop		HDDWRITEERR					; send CAN characters
				mov			ax,2
				call		WAITFIX						; wait a bit to clear console
				mcrPRINT	XMODEMHDDERR				; print error message
;
;-----	restore keyboard input buffer
;
XMODEMRXEXIT:	mov			ax,BIOSDATASEG				; establish pointer to BIOS data
				mov			ds,ax
				mov			ax,bdKEYBUF					; buffer start offset in BIOS data structure
				cli
				mov			[ds:bdKEYBUFHEAD],ax		; store as buffer head pointer
				mov			[ds:bdKEYBUFTAIL],ax		; buffer tail pointer is same as head (empty)
				mov			[ds:bdKEYBUFSTART],ax		; buffer start address
				add			ax,32
				mov			[ds:bdKEYBUFEND],ax			; buffer end address
				sti
;
;-----	exit XMODEM processing
;
				pop			ds							; restore registers
				pop			es
				pop			di
				pop			si
				pop			dx
				pop			cx
				pop			bx
				pop			ax
				add			sp,LOCALVARSPACE			; discard local variables
				ret
;
;-----	CRC calculator accumulating byte CRC
;
CALCCRC:		push		cx
				mov			cx,8						; number of bits in byte
CRCLOOP1:		rcl			al,1						; shift the data byte
				rcl			word [ss:bp+XCRC],1			; shift the mask
				jnc			CRCLOOP2					; skip the xor if 0
				xor			word [ss:bp+XCRC],1021h		; do the xor
CRCLOOP2:		loop		CRCLOOP1
				pop			cx
				ret
;
;-----------------------------------------------;
; XMODEM transmit routine						;
; send data through UART in XMODEM protocol		;
; 64K maximum transfer size						;
;												;
; entry:										;
;	ES:DI pointer to source memory area			;
;	CX total bytes to transmit					;
; exit:											;
;	AX total bytes transmitted (64K max.)		;
;	CY.f=1 transmit error						;
;	CY.f=0 no error								;
;-----------------------------------------------;
;
XMODEMTX:		ret
;
;-----	MONITOR test strings
;
MONCLRCHAR:		db			BS, " ", 0
MONITORMSG:		db			"entering monitor mode ('help'<CR> for help)", CR, LF, 0
MONPROMPT:		db			"mon88>", 0
MONCMDERR:		db			" [mon88] command syntax error", CR, LF, 0
MONCMDNONE:		db			" [mon88] command not implemented", CR, LF, 0
MONTOKENERR:	db			" [mon88] too many parameters", CR, LF, 0
MONCMDHELP:		db			"monitor commands:", CR, LF
				db			"+ ipl ......................... attempt an IPL", CR, LF
				db			"+ cold ........................ cold start", CR, LF
				db			"+ warm ........................ warm start", CR, LF
				db			"+ memwr <seg> <off> ........... download to mem.", CR, LF
				db			"+ drvwr <lbaH> <lbaL> ......... download to disk", CR, LF
				db			"  memrd <seg> <off> <cnt> ..... upload from mem.", CR, LF
				db			"  drvrd <lbaH> <lbaL> <cnt> ... upload from disk", CR, LF
				db			"  go <seg> <off> .............. run code", CR, LF
				db			"+ iord <port> ................. input from port", CR, LF
				db			"+ iowr <port> <byte> .......... output to port", CR, LF
				db			"+ memdump <seg> <off> ......... read and disp mem.", CR, LF
				db			"+ drvdump <lbaH> <lbaL> ....... display sector", CR, LF
				db			"+ help ........................ print help text", CR, LF, 0
MONPORTRD1:		db			"port(0x", 0
MONPORTRD2:		db			"),0x", 0
DRVREADERROR:	db			" [DRV] read error", CR, LF, 0
XMODEMHOSTTOV:	db			CR, LF, " [XMODEM] host connection time-out", CR, LF, 0
XMODEMCANCEL:	db			CR, LF, " [XMODEM] session ended/cancelled by host", CR, LF, 0
XMODEMBADRESP:	db			CR, LF, " [XMODEM] bad response from host", CR, LF, 0
XMODEMRETRYERR:	db			CR, LF, " [XMODEM] retry count exceeded", CR, LF, 0
XMODEMHDDERR:	db			CR, LF, " [XMODEM] HDD write error", CR, LF, 0
;
; -- end of file --
;

; KRUSADER - An Assembly Language IDE for the Replica 1

; 6502 Version 1.3 - 23 December, 2007
; (c) Ken Wessen (ken.wessen@gmail.com)

; Notes:
;	- 11 bytes free (17 free if TABTOSPACE = 0)
;	- Entry points:
;		SHELL = $711C($F01C)
;		MOVEDN = $7304($F204)
;		DEBUG = -($FE14)
;		XBRK = -($FE1E) - debugger re-entry point
;		DSMBL = $7BCA($FACA)

APPLE1  =1
INROM	=1
TABTOSPACE = 1
UNK_ERR_CHECK = 0

MINIMONITOR = INROM & 1
DOTRACE = MINIMONITOR & 1 
BRKAS2 = 1		; if 1, BRK will assemble to two $00 bytes
			; if set, then minimonitor will work unchanged 
			; for both hardware and software interrupts

	.if INROM
	* = $F000
	.else
	* = $7100
	.endif

	.if INROM	
MONTOR	=ESCAPE
	.else
MONTOR	=$FF1F
GETLINE	=MONTOR		; doesn't work in RAM version because needs adjusted monitor code
	.endif

; Constants

BS	=$08		; backspace
SP	=$20		; space
CR	=$0D		; carriage return
LF	=$0A		; line feed
ESC	=$1B		; escape
INMASK  =$7F
	
LNMSZ	=$03
LBLSZ	=$06		; labels are up to 6 characters
MNESZ	=$03		; mnemonics are always 3 characters
ARGSZ	=$0E		; arguments are up to 14 characters
COMSZ	=$0A		; comments fill the rest - up to 10 characters

ENDLBL	=LNMSZ+LBLSZ+1
ENDMNE	=ENDLBL+MNESZ+1
ENDARG	=ENDMNE+ARGSZ+1
ENDLN	=ENDARG+COMSZ+1

SYMSZ	=$06		; size of labels

LINESZ	=$27		; size of a line
USESZ	=LINESZ-LNMSZ-1	; usable size of a line
CNTSZ	=COMM-LABEL-1	; size of content in a line
	
MAXSYM	=$20		; at most 32 local symbols (256B) and 
MAXFRF	=$55		; 85 forward references (896B)
			; globals are limited by 1 byte index => max of 256 (2K)
			; global symbol table grows downwards
			
; Symbols used in source code

IMV	='#'		; Indicates immediate mode value
HEX	='$'		; Indicates a hex value
OPEN	='('		; Open bracket for indirect addressing
CLOSE	=')'		; Close bracket for indirect addressing
PC	='*'		; Indicates PC relative addressing
LOBYTE	='<'		; Indicates lo-byte of following word
HIBYTE	='>'		; Indicates hi-byte of following word
PLUS	='+'		; Plus in simple expressions
MINUS	='-'		; Minus in simple expressions
DOT	='.'		; Indicates a local label
QUOTE	=''''		; delimits a string
COMMA	=','
CMNT	=';'		; indicates a full line comment

PROMPT	='?'

EOL	=$00		; end of line marker
EOFLD	=$01		; end of field in tokenised source line
BLANK	=$02		; used to mark a blank line

PRGEND	=$FE		; used to flag end of program parsing
FAIL	=$FF		; used to flag failure in various searches

; Zero page storage	
IOBUF	=$00		; I/O buffer for source code input and analysis
LABEL	=$04		; label starts here
MNE	=$0B		; mnemonic starts here
ARGS	=$0F		; arguments start here
COMM    =$1D		; comments start here
FREFTL	=$29		; address of forward reference table
FREFTH	=$2A
NFREF	=$2B		; number of forward symbols
RECNM	=$2C		; number of table entries
RECSZ	=$2D		; size of table entries
RECSIG	=$2E		; significant characters in table entries
XSAV	=$2F
YSAV	=$30
CURMNE	=$3C		; Holds the current mne index
CURADM	=$3D		; Holds the current addressing mode
LVALL	=$3E		; Storage for a label value
LVALH	=$3F	
TBLL	=$40		; address of search table
TBLH	=$41
STRL	=$42		; address of search string
STRH	=$43
SCRTCH	=$44		; scratch location
NPTCH	=$45		; counts frefs when patching
PTCHTL	=$46		; address of forward reference being patched
PTCHTH	=$47
FLGSAV	=$48

MISCL	=$50		; Miscellaneous address pointer
MISCH	=$51		
MISC2L	=$52		; And another
MISC2H	=$53	
TEMP1	=$54		; general purpose storage
TEMP2	=$55	
TEMP3	=$56	
TEMP4	=$57
LMNE	=TEMP3		; alias for compression and expansion routines
RMNE	=TEMP4
FRFLAG	=$58		; if nonzero, disallow forward references
ERFLAG	=$59		; if nonzero, do not report error line
HADFRF	=$5A		; if nonzero, handled a forward reference
PRFLAG	=$5B

; want these to persist if possible when going into the monitor
; to test code etc, so put them right up high
XQT	=$E0

; these 6 locations must be contiguous
GSYMTL	=$E9		; address of the global symbol table
GSYMTH	=$EA	
NGSYM	=$EB		; number of global symbols
LSYMTL	=$EC		; address of the local symbol table
LSYMTH	=$ED
NLSYM	=$EE		; number of local symbols

	.if MINIMONITOR
; these 7 locations must be contiguous
REGS	=$F0
SAVP	=REGS
SAVS	=$F1
SAVY	=$F2
SAVX	=$F3
SAVA	=$F4
	.endif
CURPCL	=$F5		; Current PC
CURPCH	=$F6

CODEH	=$F8		; hi byte of code storage area (low is $00)
TABLEH	=$F9		; hi byte of symbol table area

; these 4 locations must be contiguous
LINEL	=$FA		; Current source line number (starts at 0)
LINEH	=$FB		
CURLNL	=$FC		; Current source line address
CURLNH	=$FD
		
SRCSTL	=$FE		; source code start address
SRCSTH	=$FF	
	
; for disassembler
FORMAT	=FREFTL		; re-use spare locations
LENGTH	=FREFTH
COUNT	=NFREF
PCL	=CURPCL
PCH	=CURPCH

; ****************************************
; 	COMMAND SHELL/EDITOR CODE
; ****************************************

MAIN	
	.if INROM
	LDA #$03
	STA CODEH
	LDA #$20
	STA SRCSTH
	LDA #$7C
	STA TABLEH
	.else
	LDA #$03
	STA CODEH
	LDA #$1D
	STA SRCSTH
	LDA #$6D
	STA TABLEH
	.endif
	LDX #MSGSZ
_NEXT	LDA MSG-1,X
	JSR OUTCH
	DEX
	BNE _NEXT
	DEX
	TXS		; reset stack pointer on startup
	JSR SHINIT	; default source line and address data
;	JMP SHELL
; falls through to SHELL 
  		
; ****************************************
	
SHELL			; Loops forever
			; also the re-entry point
	CLD		; just incase
	LDA #$00
	STA PRFLAG
	JSR FILBUF
	LDX #ARGS
	STX FRFLAG	; set flags in SHELL
	STX ERFLAG
	JSR CRLF
	LDA #PROMPT
	JSR OUTCH	; prompt
	JSR OUTSP	; can drop this if desperate for 3 more bytes :-)
_KEY	JSR GETCH
	CMP #BS
	BEQ SHELL	; start again
	CMP #CR
	BEQ _RUN
	JSR OUTCH
	STA IOBUF,X
	INX
	BNE _KEY	; always branches
_RUN	LDA ARGS
	BEQ SHELL	; empty command line
	LDA ARGS+1	; ensure command is just a single letter
	BEQ _OK
	CMP #SP
	BNE _ERR;SHLERR
_OK	LDX #NUMCMD
_NEXT	LDA CMDS-1,X	; find the typed command
	CMP ARGS
	BEQ GOTCMD
	DEX
	BNE _NEXT
_ERR	PHA		; put dummy data on the stack
	PHA
SHLERR	
	LDY #SYNTAX
ERR2	PLA		; need to clean up the stack
	PLA
	JSR SHWERR
	BNE SHELL
GOTCMD	JSR RUNCMD
	JMP SHELL	; ready for next command

; ****************************************

SHINIT	
	LDA #$00
	TAY
	STA SRCSTL	; low byte zero for storage area
	STA (SRCSTL),Y	; and put a zero in it for EOP
TOSTRT			; set LINEL,H and CURLNL,H to the start
	LDA SRCSTH
	STA CURLNH
	LDA #$00
	STA LINEL
	STA LINEH	; 0 lines
	STA CURLNL
	RTS		; leaves $00 in A 
	
; ****************************************

PANIC
	JSR SHINIT
	LDA ARGS+2
	BNE _SKIP
	LDA #$01
_SKIP	STA (SRCSTL),Y	; Y is $00 from SHINIT
	RTS

; ****************************************

VALUE	
	JSR ADDARG
	BEQ SHLERR
	JSR CRLF
	LDA LVALH
	LDX LVALL
	JMP PRNTAX
	
; ****************************************

RUN	
	JSR ADDARG
	BEQ SHLERR
	JSR CRLF
	JMP (LVALL)	; jump to the address

; ****************************************

ADDARG			; convert argument to address
	LDX #$02
	LDA ARGS,X
	BEQ _NOARG
	PHA
	JSR EVAL
	PLA
	;CPX #FAIL
	INX
	BEQ ERR2;SHLERR
_NOARG	RTS

; ****************************************

PCTOLV
	LDA CURPCL
	STA LVALL
	LDA CURPCH
	STA LVALH
	RTS
	
; ****************************************

LVTOPC	
	LDA LVALL
	STA CURPCL
	LDA LVALH
	STA CURPCH
	RTS
		
; ****************************************

FILLSP
	LDA #SP
FILBUF			; fill the buffer with the contents of A
	LDX #LINESZ
_CLR	STA <(IOBUF-1),X
	DEX
	BNE _CLR
	RTS
	
; ****************************************

RUNCMD	
	LDA CMDH-1,X
  	PHA
  	LDA CMDL-1,X
  	PHA
  	RTS

; ****************************************

NEW	
	JSR SHINIT
	JMP INSERT
	
; ****************************************

LIST			; L 	- list all
			; L nnn - list from line nnn
	JSR TOSTRT
	JSR GETARG
	BEQ _NEXT	; no args, list from start
	JSR GOTOLN	; deal with arguments if necessary
_NEXT	LDY #$00
	LDA (CURLNL),Y
	BEQ _RET
	JSR PRNTLN
	JSR UPDTCL
	LDA KBDRDY
	.if APPLE1
	BPL _NEXT
	.else
	BEQ _NEXT
	.endif
	LDA KBD
_RET	RTS

; ****************************************

MEM	
	JSR TOEND	; set CURLNL,H to the end
	JSR CRLF	
	LDX #$04
_LOOP	LDA CURLNL-1,X
	JSR OUTHEX
	CPX #$03
	BNE _SKIP
	JSR PRDASH
_SKIP	DEX
	BNE _LOOP
RET	RTS

; ****************************************

GETARG			; get the one or two numeric arguments
			; to the list, edit, delete and insert commands
			; store them in TEMP1-4 as found
			; arg count in Y or X has FAIL
	LDY #$00
	STY YSAV
	LDX #$01
_NEXT	LDA ARGS,X
	BEQ _DONE	; null terminator
	CMP #SP		; find the space
	BEQ _CVT
	CMP #HEX	; or $ symbol
	BEQ _CVT
	INX
	BNE _NEXT
_CVT	INC YSAV	; count args
	LDA #HEX
	STA ARGS,X	; replace the space with '$' and convert
	JSR CONVRT
	;CPX #FAIL
	INX
	BEQ LCLERR
	;INX
	LDA LVALL
	STA TEMP1,Y
	INY
	LDA LVALH
	STA TEMP1,Y
	INY
	BNE _NEXT	; always branches
_DONE	LDY YSAV
	RTS		; m in TEMP1,2, n in TEMP3,4
	
; ****************************************

EDIT	
	JSR GETARG
	;CPY #$01
	DEY
	BNE LCLERR
	JSR DELETE	; must not overwrite the command input buffer
;	JMP INSERT
; falls through to INSERT

; ****************************************
	
INSERT	
	JSR GETARG	; deal with arguments if necessary
	;CPX #FAIL
	INX
	BEQ LCLERR
	;CPY #$00	; no args
	TYA
	BNE _ARGS
	JSR TOEND	; insert at the end
	CLC
	BCC _IN
_ARGS	JSR GOTOLN	; if no such line will insert at end
_IN	JSR INPUT	; Get one line
	CPX #FAIL	; Was there an error?
	BEQ RET;
	; Save the tokenised line and update pointers
	; tokenised line is in IOBUF, size X
	; move up from CURLNL,H to make space
	STX XSAV	; save X (data size)
	LDA CURLNH
	STA MISCH
	STA MISC2H
	LDA CURLNL
	STA MISCL	; src in MISCL,H now
	CLC
	ADC XSAV
	STA MISC2L
	BCC _READY
	INC MISC2H	; MISC2L,H is destination
_READY	JSR GETSZ
	JSR MOVEUP	; do the move
	LDY #$00
	; now move the line to the source storage area
	; Y bytes, from IOBUF to CURLN
_MOVE	LDA IOBUF,Y
	STA (CURLNL),Y
	INY
	CPY XSAV
	BNE _MOVE
	JSR UPDTCL	; update CURLNL,H
	BNE _IN		; always branches

; ****************************************

LCLERR			; local error wrapper
			; shared by the routines around it
	JMP SHLERR

; ****************************************

GETSZ			; SIZE = TEMP1,2 = lastlnL,H - MISCL,H + 1
	LDX #-$04
_LOOP	LDA CURLNH+1,X
	PHA		; save CURLN and LINEN on the stack
	INX
	BNE _LOOP
	JSR TOEND
	SEC
	LDA CURLNL
	SBC MISCL
	STA TEMP1
	LDA CURLNH
	SBC MISCH
	STA TEMP2
	INC TEMP1
	BNE _SKIP
	INC TEMP2
_SKIP	LDX #$04
_LOOP2	PLA		; get CURLN and LINEN from the stack
	STA LINEL-1,X
	DEX
	BNE _LOOP2
	RTS
	
; ****************************************

DELETE			; Delete the specified range
			; Moves from address of line arg2 (MISCL,H)
			; to address of line arg1 (MISC2L,H)
	JSR GETARG
;	CPY #$00
	BEQ LCLERR
	STY YSAV
_DOIT	JSR GOTOLN	; this leaves TEMP1 in Y and TEMP2 in X
	CPX #FAIL
	BEQ LCLERR
	LDA CURLNL
	STA MISC2L
	LDA CURLNH
	STA MISC2H	; destination address is set in MISC2L,H
	LDA YSAV
	;CMP #$01
	LSR
	BEQ _INC
	LDX TEMP4
	LDY TEMP3	; Validate the range arguments
	CPX TEMP2	; First compare high bytes
	BNE _CHK	; If TEMP4 != TEMP2, we just need to check carry
	CPY TEMP1	; Compare low bytes when needed
_CHK	BCC LCLERR	; If carry clear, 2nd argument is too low
_INC	INY		; Now increment the second argument
	BNE _CONT
	INX
_CONT	STX TEMP2
	STY TEMP1
	JSR GOTOLN
	LDA CURLNL
	STA MISCL
	LDA CURLNH
	STA MISCH
	JSR GETSZ
;	JMP MOVEDN
; falls through
	
; ****************************************
;	Memory moving routines
;  From http://www.6502.org/source/general/memory_move.html
; ****************************************

; Some aliases for the following two memory move routines

FROM	=MISCL		; move from MISCL,H
TO	=MISC2L		; to MISCL2,H
SIZEL	=TEMP1
SIZEH	=TEMP2

MOVEDN			; Move memory down
	LDY #$00
	LDX SIZEH
	BEQ _MD2
_MD1	LDA (FROM),Y ; move a page at a time
	STA (TO),Y
	INY
	BNE _MD1
	INC FROM+1
	INC TO+1
	DEX
	BNE _MD1
_MD2	LDX SIZEL
	BEQ _MD4
_MD3	LDA (FROM),Y ; move the remaining bytes
	STA (TO),Y
	INY
	DEX
	BNE _MD3
_MD4	RTS

MOVEUP			; Move memory up
	LDX SIZEH	; the last byte must be moved first
	CLC		; start at the final pages of FROM and TO
	TXA
	ADC FROM+1
	STA FROM+1
	CLC
	TXA
	ADC TO+1
	STA TO+1
	INX		; allows the use of BNE after the DEX below
	LDY SIZEL
	BEQ _MU3
	DEY		; move bytes on the last page first
	BEQ _MU2
_MU1	LDA (FROM),Y
	STA (TO),Y
	DEY
	BNE _MU1
_MU2	LDA (FROM),Y	; handle Y = 0 separately
	STA (TO),Y
_MU3	DEY
	DEC FROM+1	; move the next page (if any)
	DEC TO+1
	DEX
	BNE _MU1
	RTS

; ****************************************

TOEND	
	LDA #$FF
	STA TEMP2	; makes illegal line number
;	JMP GOTOLN	; so CURLNL,H will be set to the end
; falls through

; ****************************************
	
GOTOLN			; go to line number given in TEMP1,2
			; sets CURLNL,H to the appropriate address
			; and leaves TEMP1 in Y and TEMP2 in X
			; if not present, return #FAIL in X
			; and LINEL,H will be set to the next available line number
EOP	= LFAIL
GOTIT	= LRET
	JSR TOSTRT
_NXTLN			; is the current line number the same
			; as specified in TEMP1,2?
			; Z set if equal
			; C set if TEMP1,2 >= LINEL,H 
	LDY TEMP1
	CPY LINEL
	BNE _NO
	LDX TEMP2
	CPX LINEH
	BEQ GOTIT
_NO	LDY #$FF
_NXTBT	INY		; find EOL
	LDA (CURLNL),Y
	BNE _NXTBT
	TYA
	;CPY #$00
	BEQ EOP		; null at start of line => end of program
	INY
	JSR UPDTCL	; increment CURLNL,H by Y bytes
	BNE _NXTLN	; always branches
;_EOP	LDX #FAIL
;_GOTIT	RTS		; address is now in CURLNL,H

; ****************************************

PRNTLN			; print out the current line (preserve X)
	JSR CRLF
	STX XSAV
	JSR DETKN
	INY
	JSR PRLNNM
	LDX #$00
_PRINT	LDA LABEL,X
	BEQ _DONE	; null terminator
	JSR OUTCH
	INX
	;CPX #USESZ
	BNE _PRINT
_DONE	LDX XSAV
	RTS
		
; ****************************************

NEXTCH			; Check for valid character in A
			; Also allows direct entry to appropriate location
			; Flag success with C flag
	JSR GETCH
	.if TABTOSPACE
	CMP #$09	; is it a tab?
	BNE _SKIP
	LDA #SP
	.endif
_SKIP	CMP #SP		; valid ASCII range is $20 to $5D
	BPL CHANM	; check alpha numeric entries
	TAY
	PLA
	PLA
	PLA
	PLA		; wipe out return addresses
	CPY #BS
	BEQ INPUT	; just do it all again
_NOBS	CPY #CR
	BNE LFAIL
	CPX #LABEL	; CR at start of LABEL means a blank line
	BEQ DOBLNK
	LDA #EOL
	STA IOBUF,X
	BEQ GOTEOL
LFAIL	LDX #FAIL	; may flag error or just end
LRET	RTS
CHANM	CPX #LINESZ	; ignore any characters over the end of the line
	BPL CHNO
	CMP #']'+1	; is character is in range $20-$5D?
	BPL CHNO	; branch to NO...
CHOK	SEC		; C flag on indicates success
	RTS
CHKLBL	CMP #DOT	; here are more specific checks
	BEQ CHOK
CHKALN	CMP #'0'	; check alpha-numeric
	BMI CHNO	; less than 0
	CMP #'9'+1
	BMI CHOK	; between 0 and 9
CHKLET	CMP #'A'
	BMI CHNO	; less than A
	CMP #'Z'+1	
	BMI CHOK	; between A and Z
CHNO	CLC
	RTS		; C flag off indicates failure
	
; ****************************************

DOBLNK	
	LDA #BLANK
	TAX		; BLANK = #$02, and that is also the
	STA IOBUF	; tokenised size of a blank line
	LDA #EOL	; (and only a blank line)
	STA IOBUF+1
ENDIN	RTS	

INPUT	
	JSR FILLSP
	LDA #EOL	; need this marker at the start of the comments
	STA COMM	; for when return hit in args field
	JSR CRLF
	JSR PRLNNM
	LDX #LABEL	; point to LABEL area
	LDA #ENDLBL
	JSR ONEFLD
	JSR INSSPC	; Move to mnemonic field
	LDA LABEL
	CMP #CMNT
	BEQ _CMNT
	LDA #ENDMNE
	JSR ONEFLD
	JSR INSSPC	; Move to args field
	LDA #ENDARG
	JSR ONEFLD
_CMNT	LDA #EOL
	JSR ONEFLD
GOTEOL	;JMP TOTKN	
; falls through

; ****************************************

TOTKN			; tokenise to IOBUF to calc size
			; then move memory to make space
			; then copy from IOBUF into the space
	LDX #$00
	STX MISCH
	LDA #SP
	STA TEMP2
	LDA #LABEL
	STA MISCL
	LDA #EOFLD
	STA TEMP1
	JSR TKNISE
	LDY LABEL
	CPY #CMNT
	BNE _CONT
	LDA #MNE
	BNE ISCMNT	; always branches
_CONT	TXA		; save X
	PHA

;	JSR SRCHMN	; is it a mnemonic?

SRCHMN  		; Search the table of mnemonics	for the mnemonic in MNE
			; Return the index in A

CMPMNE			; compress the 3 char mnemonic
			; at MNE to MNE+2 into 2 chars
			; at LMNE and RMNE
	CLC
	ROR LMNE		
	LDX #$03
_NEXT2	SEC
	LDA MNE-1,X
	SBC #'A'-1
	LDY #$05
_LOOP2	LSR
	ROR LMNE
	ROR RMNE
	DEY
	BNE _LOOP2
	DEX
	BNE _NEXT2

	LDX #NUMMN	; Number of mnemonics
_LOOP	LDA LMNETB-1,X
	CMP LMNE
	BNE _NXT
	LDA RMNETB-1,X
	CMP RMNE
	BEQ _FND
_NXT	DEX
	BNE _LOOP
_FND	DEX		; X = $FF for failure
;	RTS
	
	TXA
	CMP #FAIL
	BNE _FOUND
	LDA MNE		; or a directive?
	CMP #DOT
	BNE _ERR
	LDX #NUMDIR
	LDA MNE+1
_NEXT	CMP DIRS-1,X
	BEQ _FDIR
	DEX
	BNE _NEXT
_ERR	PLA
	LDY #INVMNE
	JMP SHWERR
_FDIR	DEX
_FOUND	TAY		; put mnemonic/directive code in Y
	INY		; offset by 1 so no code $00
	PLA		; restore Y
	TAX
	STY IOBUF,X
	INX
	LDA #ARGS
	STA MISCL
;	LDA #EOFLD
;	STA TEMP1
	JSR TKNISE
	STX XSAV
	INC XSAV
	LDA #COMM
ISCMNT	STA MISCL
	LDA #EOL
	STA TEMP1
	STA TEMP2
	JSR TKNISE
	CPX XSAV
	BNE _RET
	DEX		; no args or comments, so stop early
	STA <(IOBUF-1),X	; A already holds $00
_RET 	RTS

ONEFLD			; do one entry field
			; A holds the end point for the field
	STA TEMP1	; last position
_NEXT	JSR NEXTCH	; catches ESC, CR and BS
	BCC _NEXT	; only allow legal keys
	JSR OUTCH	; echo
	STA IOBUF,X
	INX
	CMP #SP
	BEQ _FILL
	CPX TEMP1
	BNE _NEXT
_RET	RTS
_FILL	LDA TEMP1
	BEQ _NEXT	; just treat a space normally
	CPX TEMP1	; fill spaces
	BEQ _RET
	LDA #SP
	STA IOBUF,X
	JSR OUTCH
_CONT	INX
	BNE _FILL	; always branches

; ****************************************
	
INSSPC	
	LDA <(IOBUF-1),X	; was previous character a space?
	CMP #SP
	BEQ _JUMP
_GET	JSR NEXTCH	; handles BS, CR and ESC
	CMP #SP
	BNE _GET	; only let SP through
_JUMP	STA IOBUF,X	; insert the space
	INX
	JMP OUTCH

TKNISE	
	LDY #$00
_NEXT	LDA (MISCL),Y
	BEQ _EOF
	CMP TEMP2
	BEQ _EOF	; null terminator
	STA IOBUF,X
	INX
	INC MISCL
	BNE _NEXT
_EOF	LDA TEMP1
	STA IOBUF,X
	INX
	RTS

; ****************************************

DETKN			; Load a line to the IOBUF
			; (detokenising as necessary)
			; On return, Y holds tokenised size
	JSR FILLSP
	LDY #$00
	LDX #LABEL
_LBL	LDA (CURLNL),Y
	BEQ _EOP	; indicates end of program
	CMP #BLANK
	BNE _SKIP
	INY
	LDA #EOL
	BEQ _EOL
_SKIP	CMP #EOFLD
	BEQ _CHK
	STA IOBUF,X
	INX
	INY
	BNE _LBL
_CHK	LDA LABEL
	CMP #CMNT
	BNE _NEXT
	LDX #MNE
	BNE _CMNT	; always branches
_NEXT	INY
	LDA (CURLNL),Y	; get mnemonic code
	TAX
	DEX		; correct for offset in tokenise
	STX CURMNE	; store mnemonic for assembler
	CPX #NUMMN
	BPL _DIR
	TYA		; save Y
	PHA	
	JSR EXPMNE
	PLA		; restore Y
	TAY
	BNE _REST
_DIR	STX MNE+1
	LDA #DOT
	STA MNE
_REST	INY
	LDX #ARGS	; point to ARGS area
_LOOP	LDA (CURLNL),Y
	BEQ _EOL	; indicates end of line
	CMP #EOFLD
	BNE _CONT
	INY
	LDX #COMM	; point to COMM area
	BNE _LOOP
_CONT	STA IOBUF,X
	INX
_CMNT	INY
	BNE _LOOP
_EOP	LDX #PRGEND
_EOL	STA IOBUF,X
	RTS

; ****************************************
; 		ASSEMBLER CODE
; ****************************************

ASSEM			; Run an assembly
	JSR INIT	; Set the default values
	JSR CRLF
	JSR MYPRPC
_NEXT	JSR DO1LN	; line is in the buffer - parse it
	;CPX #FAIL
	INX
	BEQ SHWERR
	CPX #PRGEND+1	; +1 because of INX above
	BNE _NEXT
	INC FRFLAG	; have to resolve them all now - this ensures FRFLAG nonzero
	JSR PATCH	; back patch any remaining forward references
	;CPX #FAIL
	INX
	BEQ SHWERR
	JMP MYPRPC	; output finishing module end address
;_ERR	JMP SHWERR

; ****************************************

SHWERR			; Show message for error with id in Y
			; Also display line if appropriate
	JSR CRLF
	LDX #ERPRSZ
_NEXT	LDA ERRPRE-1,X
	JSR OUTCH
	DEX
	BNE _NEXT
	TYA
	.if UNK_ERR_CHECK
	BEQ _SKIP
	CPY #MAXERR+1
	BCC _SHOW	; If error code valid, show req'd string
_UNKWN	LDY #UNKERR	; else show unknown error
 	BEQ _SKIP
 	.endif
_SHOW	CLC
	TXA		; sets A to zero
_ADD	ADC #EMSGSZ
	DEY
	BNE _ADD
	TAY
_SKIP	LDX #EMSGSZ	
	.if UNK_ERR_CHECK
_LOOP	LDA ERRMSG,Y
	.else
_LOOP	LDA ERRMSG-EMSGSZ,Y
	.endif
	JSR OUTCH
	INY
	DEX
	BNE _LOOP
	;LDX #FAIL
	DEX		; sets X = #FAIL
	LDA ERFLAG
	BNE RET1
	JMP PRNTLN

; ****************************************
	
INIT
	JSR TOSTRT	; leaves $00 in A
	STA FRFLAG
	STA NGSYM
	STA GSYMTL
	STA CURPCL	; Initial value of PC for the assembled code
	LDA CODEH
	STA CURPCH
	JSR CLRLCL	; set local and FREF table pointers 
	STX GSYMTH	; global table high byte - in X from CLRLCL
;	JMP INITFR
; falls through

; ****************************************

INITFR			; initialise the FREF table and related pointers
	LDA #$00
	STA NFREF
	STA FREFTL
	STA PTCHTL
	LDY TABLEH
	INY
	STY FREFTH
	STY PTCHTH
RET1	RTS
		
; ****************************************

DO1LN	
	JSR DETKN
	CPX #PRGEND
	BEQ _ENDPR
	CPX #LABEL	; means we are still at the first field => blank line
	BEQ _DONE
	LDA #$00
	STA ERFLAG
	STA FRFLAG
	STA HADFRF
	JSR PARSE
	CPX #FAIL
	BEQ DORTS
_CONT	LDY #$00
_LOOP	LDA (CURLNL),Y
	BEQ _DONE
	INY
	BNE _LOOP
_DONE	INY		; one more to skip the null
_ENDPR	;JMP UPDTCL
; falls through

; ****************************************

UPDTCL			; update the current line pointer 
			; by the number of bytes in Y
	LDA CURLNL
	STY SCRTCH
	CLC
	ADC SCRTCH	; move the current line pointer forward by 'Y' bytes
	STA CURLNL
	BCC INCLN
	INC CURLNH	; increment the high byte if necessary
INCLN	
	INC LINEL
	BNE DORTS
	INC LINEH
DORTS	RTS		; global label so can be shared
	
; ****************************************

MKOBJC			; MNE is in CURMNE, addr mode is in CURADM
			; and the args are in LVALL,H
			; calculate the object code, and update PC
	LDY CURMNE	
	LDA BASE,Y	; get base value for current mnemonic
	LDX CURADM
	CLC
	ADC OFFSET,X	; add in the offset
	CPX #ABY	; handle exception
	BEQ _CHABY
	CPX #IMM
	BNE _CONT
	CPY #$28	; immediate mode need to adjust a range
	BMI _CONT
	CPY #$2F+1
	BCS _CONT
	ADC #ADJIMM	; carry is clear
;	BNE _CONT
_CHABY	CPY #$35
	BNE _CONT
	CLC
	ADC #ADJABY
_CONT	JSR DOBYTE	; we have the object code
	.if BRKAS2
	CMP #$00
	BNE _MKARG
	JSR DOBYTE
	.endif
_MKARG			; where appropriate, the arg value is in LVALL,H
			; copy to ARGS and null terminate
	TXA		; quick check for X=0
	BEQ DORTS	; IMP - no args
	DEX
	BEQ DORTS	; ACC - no args
	LDA LVALL	; needed for _BYT handling
	; word arg if X is greater than or equal to ABS
	CPX #ABS-1
	BMI DOBYTE	; X < #ABS	
DOWORD	JSR DOBYTE
	LDA LVALH
DOBYTE	LDY #$00
	STA (CURPCL),Y
;	JMP INCPC
; falls through

; ****************************************

INCPC			; increment the PC
	INC CURPCL
	BNE _DONE	; any carry?
	INC CURPCH	; yes
_DONE	RTS

; ****************************************
	
CALCAM			; work out the addressing mode
	JSR ADDMOD	
	CPX #FAIL
	BNE MKOBJC
	LDY #ILLADM	; Illegal address mode error
	RTS
	
PARSE			; Parse one line and validate
	LDA LABEL
	CMP #CMNT
	BEQ DORTS	; ignore comment lines
	LDX MNE		; first need to check for an equate
	CPX #DOT
	BNE _NOEQU
	LDX MNE+1
	CPX #MOD	; Do we have a new module?
	BNE _NOMOD
	JMP DOMOD
_NOMOD	CPX #EQU
	BEQ DOEQU
_NOEQU	CMP #SP		; Is there a label?
	BEQ _NOLABL	
	JSR PCSYM	; save the symbol value - in this case it is the PC
_NOLABL	LDA MNE		
	CMP #DOT	; do we have a directive?
	BNE CALCAM 	; no
	
; ****************************************
	
DODIR	
	LDX #$00	; handle directives (except equate and module)
	LDA MNE+1
	CMP #STR
	BEQ DOSTR
	STA FRFLAG	; Disallows forward references
	JSR QTEVAL
	;CPX #FAIL
	INX
	BEQ DIRERR
	LDA LVALL
	LDX MNE+1
	CPX #WORD
	BEQ DOWORD
	LDX LVALH
	BEQ DOBYTE
DIRERR	LDY #SYNTAX
	LDX #FAIL
	RTS
DOSTR	LDA ARGS,X
	CMP #QUOTE
	BNE DIRERR	; String invalid
_LOOP	INX
	LDA ARGS,X
	BEQ DIRERR	; end found before string closed - error
	CMP #QUOTE
	BEQ DIROK
	JSR DOBYTE	; just copy over the bytes
	CPX #ARGSZ	; can't go over the size limit
	BNE _LOOP
	BEQ DIRERR	; hit the limit without a closing quote - error
DIROK	RTS

; ****************************************

DOEQU	
	;LDA LABEL
	STA FRFLAG
	JSR CHKALN	; label must be global
	BCC DIRERR	; MUST have a label for an equate
	LDX #$00
	JSR QTEVAL	; work out the associated value
	;CPX #FAIL
	INX
	BEQ DIRERR
	JMP STRSYM
	
; ****************************************

DOMOD			; Do we have a new module?
	;LDA LABEL
	JSR CHKALN	; must have a global label
	BCC DIRERR
	LDY #$00
	LDA ARGS
	BEQ _STORE
	CMP #SP
	BEQ _STORE
_SETPC	JSR ATOFR	; output finishing module end address (+1)
	LDX #$00	; set a new value for the PC from the args
	LDA ARGS
	JSR CONVRT
	;CPX #FAIL
	INX
	BEQ DIRERR
	JSR LVTOPC
_STORE	JSR PCSYM
	CPX #FAIL
	BEQ DIROK
	JSR PATCH
	CPX #FAIL
	BEQ DIROK
	JSR SHWMOD
	LDA #$00	; reset patch flag
	JSR ATOFR	; output new module start address
;	JMP CLRLCL
; falls through

; ****************************************

CLRLCL			; clear the local symbol table
	LDX #$00	; this also clears any errors
	STX NLSYM	; to their starting values
	STX LSYMTL
	LDX TABLEH	; and then the high bytes
	STX LSYMTH
	RTS

; ****************************************

ATOFR	STA FRFLAG
;	JMP MYPRPC
; falls through
	
; ****************************************

MYPRPC	
	LDA CURPCH
	LDX CURPCL
	LDY FRFLAG	; flag set => print dash and minus 1
	BEQ _NODEC
	PHA
	JSR PRDASH
	PLA
	CPX #$00
	BNE _SKIP	; is X zero?
	SEC
	SBC #$01
_SKIP	DEX
_NODEC	JMP PRNTAX

; ****************************************

PATCH			; back patch in the forward reference symbols
			; all are words
	LDX NFREF
	BEQ _RET	; nothing to do
	STX ERFLAG	; set flag
_STRPC	STX NPTCH
	LDA CURPCL	; save the PC on the stack
	PHA
	LDA CURPCH
	PHA	
	JSR INITFR
_NEXT	LDY #$00
	LDA FRFLAG
	STA FLGSAV	; so I can restore the FREF flag
	STY HADFRF
	LDA (PTCHTL),Y
	CMP #DOT
	BNE _LOOP
	STA FRFLAG	; nonzero means must resolve local symbols
_LOOP	LDA (PTCHTL),Y	; copy symbol to COMM
	STA COMM,Y
	INY
	CPY #SYMSZ
	BNE _LOOP
	LDA (PTCHTL),Y	; get the PC for this symbol
	STA CURPCL
	INY
	LDA (PTCHTL),Y
	STA CURPCH
	INY 
	LDA (PTCHTL),Y
	STA TEMP1	; save any offset value
	JSR DOLVAL	; get the symbols true value
	CPX #FAIL	; value now in LVALL,H or error
	BEQ _ERR	
	LDA HADFRF	; if we have a persistent FREF
	BEQ _CONT	; need to copy its offset as well
	LDA TEMP1  
	STA (MISCL),Y	; falls through to some meaningless patching...
	;SEC		; unless I put these two in
	;BCS _MORE
_CONT	JSR ADD16X	
	LDY #$00
	LDA (CURPCL),Y	; get the opcode
	AND #$1F	; check for branch opcode - format XXY10000
	CMP #$10
	BEQ _BRA
	JSR INCPC	; skip the opcode
_SKIP	LDA LVALL
	JSR DOWORD
_MORE	CLC
	LDA PTCHTL	; move to the next symbol
	ADC #SYMSZ+3
	STA PTCHTL
	BCC _DECN
	INC PTCHTH
_DECN	LDA FLGSAV
	STA FRFLAG
	DEC NPTCH
	BNE _NEXT
_DONE	PLA
	STA CURPCH	; restore the PC from the stack
	PLA
	STA CURPCL
_RET	RTS
_BRA	JSR ADDOFF	; BRA instructions have a 1 byte offset argument only
	CPX #FAIL
	BEQ _ERR
	LDY #$01	; save the offset at PC + 1
	LDA LVALL
	STA (CURPCL),Y
	JMP _MORE
_ERR	LDY #$00
	JSR OUTSP
_LOOP2	LDA (PTCHTL),Y	; Show symbol that failed
	JSR OUTCH
	INY
	CPY #SYMSZ
	BNE _LOOP2
	DEY		; Since #UNKSYM = #SYMSZ - 1
	BNE _DONE	; always branches
	
; ****************************************

ADDMOD			; Check the arguments and work out the
			; addressing mode
			; return mode in X
	LDX #$FF	; default error value for mode
	STX CURADM	; save it
	LDA CURMNE
	LDX ARGS	; Start checking the format...
	BEQ _EOL
	CPX #SP
	BNE _NOTSP
_EOL	LDX #IMP	; implied mode - space
	JSR CHKMOD	; check command is ok with this mode
	CPX #FAIL	; not ok
	BNE _RET	; may still be accumulator mode though
	LDX #ACC	; accumulator mode - space
	JMP CHKMOD	; check command is ok with this mode
_NOTSP	CPX #IMV	; immediate mode - '#'
	BEQ _DOIMM
	LDX #REL
	JSR CHKMOD	; check if command is a branch
	CPX #FAIL
	BEQ _NOTREL
	LDA ARGS
	JMP DOREL
_DOIMM	CMP #$2C	; check exception first - STA
	BEQ BAD
	LDX #IMM
	CMP #$35	; check inclusion first - STX
	BEQ _IMMOK
	JSR CHKMOD	; check command is ok with this mode
	CPX #FAIL
	BEQ _RET
_IMMOK	STX CURADM	; handle immediate mode
	;LDX #01	; skip the '#'
	DEX		; X == IMM == 2
	JSR QTEVAL
	INX
	BEQ BAD
	LDA LVALH
	BNE BAD
	;LDX #IMM
_RET	RTS
_NOTREL LDX #0		; check the more complicated modes
	LDA ARGS
	CMP #OPEN	; indirection?
	BNE _CONT	; no
	INX		; skip the '('
_CONT	JSR EVAL
	CPX #FAIL
	BEQ _RET
	JSR FMT2AM	; calculate the addressing mode from the format
	CPX #FAIL
	BEQ _RET
	STX CURADM
;	JMP CHKEXS
; falls through

; ****************************************

CHKEXS			; Current addressing mode is in X
	CPX #ZPY	; for MNE indices 28 to 2F, ZPY is illegal
	BNE _CONT	; but ABY is ok, so promote byte argument to word
	LDA CURMNE
	CMP #$28
	BCC _CONT
	CMP #$2F+1
	BCS _CONT	
	LDX #ABY	; updated addressing mode
	BNE OK
_CONT	LDY #SPCNT	; check special includes
_LOOP	LDA SPINC1-1,Y	; load mnemonic code
	CMP CURMNE
	BNE _NEXT
	LDX SPINC2-1,Y	; load addressing mode
	CPX CURADM
	BEQ OK		; match - so ok
	LDX SPINC3-1,Y	; load addressing mode
	CPX CURADM
	BEQ OK		; match - so ok
_NEXT	DEY
	BNE _LOOP
	LDX CURADM
;	BNE CHKMOD	; wasn't in the exceptions table - check normally
; falls through

; ****************************************

CHKMOD	LDA CURMNE	; always > 0
	CMP MIN,X	; mode index in X
	BCC BAD		; mnemonic < MIN
	CMP MAX,X	; MAX,X holds actually MAX + 1
	BCS BAD		; mnemonic > MAX
OK	STX CURADM	; save mode
	RTS
	
; ****************************************

BAD	LDX #FAIL	; Illegal addressing mode error
	RTS
DOREL	
	LDX #$00
	STX LVALL
	STX LVALH
	CMP #PC		; PC relative mode - '*'
	BNE DOLBL
	JSR PCTOLV
	JSR XCONT	
;	JMP ADDOFF	; just do an unnecessary EVAL and save 3 bytes
DOLBL	JSR EVAL	; we have a label
ADDOFF	SEC		; calculate relative offset as LVALL,H - PC
	LDA LVALL
	SBC CURPCL
	STA LVALL
	LDA LVALH
	SBC CURPCH
	STA LVALH
	BEQ DECLV	; error if high byte nonzero
	INC LVALH	
	BNE BAD		; need either $00 or $FF
DECLV	DEC LVALL
	DEC LVALL
RELOK	RTS		; need to end up with offset value in LVALL	
;ERROFF	LDX #FAIL
;	RTS
	
; ****************************************
	
QTEVAL			; evaluate an expression possibly with a quote
	LDA ARGS,X
	BEQ BAD
	CMP #QUOTE
	BEQ QCHAR
	JMP EVAL
QCHAR	INX
	LDA #$0
	STA LVALH	; quoted char must be a single byte
	LDA ARGS,X	; get the character
	STA LVALL
	INX		; check and skip the closing quote
	LDA ARGS,X	
	CMP #QUOTE
	BNE BAD
	INX
	LDA ARGS,X
	BEQ XDONE
	CMP #SP
	BEQ XDONE
;	JMP DOPLMN
; falls through

; ****************************************

DOPLMN			; handle a plus/minus expression
			; on entry, A holds the operator, and X the location
			; store the result in LVALL,H
	PHA		; save the operator
	INX		; move forward
	LDA ARGS,X	; first calculate the value of the byte
	JSR BYT2HX
	CPX #FAIL
	BNE _CONT
	PLA
;	LDX #FAIL	; X is already $FF
_RET	RTS
_CONT	STA TEMP1	; store the value of the byte in TEMP1
	PLA
	CMP #PLUS
	BEQ _NONEG
	LDA TEMP1
	CLC		; for minus, need to negate it
	EOR #$FF
	ADC #$1
	STA TEMP1
_NONEG	LDA HADFRF
	BEQ _SKIP
	LDA TEMP1	; save the offset for use when patching
	STA (MISCL),Y	
_SKIP	;JMP ADD16X
; falls through

; ****************************************

ADD16X			; Add a signed 8 bit number in TEMP1
			; to a 16 bit number in LVALL,H
			; preserve X (thanks leeeeee, www.6502.org/forum)
	LDA TEMP1	; signed 8 bit number
	BPL _CONT
	DEC LVALH	; bit 7 was set, so it's a negative
_CONT	CLC	
	ADC LVALL
	STA LVALL	; update the stored number low byte
	BCC _EXIT
	INC LVALH	; update the stored number high byte
_EXIT	RTS

; ****************************************

EVAL			; Evaluate an argument expression
			; X points to offset from ARGS of the start
			; on exit we have the expression replaced 
			; by the required constant
	STX TEMP3	; store start of the expression
	LDA ARGS,X
	CMP #LOBYTE
	BEQ _HASOP
	CMP #HIBYTE
	BNE _DOLBL
_HASOP	STA FRFLAG	; disables forward references when there
	INX		; is a '<' or a '>' in the expression
	LDA ARGS,X
_DOLBL	JSR CHKLBL	; is there a label?
	BCS _LBL	; yes - get its value
	JSR CONVRT	; convert the ASCII
	CPX #FAIL
	BEQ XERR	
	BNE XCONT	
_LBL	STX XSAV	; move X to Y
	JSR LB2VAL	; yes - get its value
	CPX #FAIL
	BEQ XDONE
	LDX XSAV
XCONT	INX		; skip the '$'
	LDA ARGS,X	; Value now in LVALL,H for ASCII or LABEL
	JSR CHKLBL
	BCS XCONT	; Continue until end of label or digits
	;STX TEMP4	; Store end index
	CMP #PLUS
	BEQ _DOOP
	CMP #MINUS
	BNE XCHKOP
_DOOP	JSR DOPLMN
	CPX #FAIL
	BNE XCONT
XERR	LDY #SYNTAX	; argument syntax error
XDONE	RTS	
XCHKOP	LDY #$00
	LDA FRFLAG
	CMP #LOBYTE
	BEQ _GETLO
	CMP #HIBYTE
	BNE _STORE
	LDA LVALH	; move LVALH to LVALL
	STA LVALL
_GETLO	STY LVALH	; keep LVALL, and zero LVALH
_STORE	LDA ARGS,X	; copy rest of args to COMM
	STA COMM,Y
	BEQ _DOVAL	
	CMP #SP
	BEQ _DOVAL
	INX
	INY
	CPX #ARGSZ
	BNE _STORE
_DOVAL	LDA #$00
	STA COMM,Y
	LDY TEMP3	; get start index 
	LDA #HEX	; put the '$" back in so subsequent code 
	STA ARGS,Y	; manages the value properly
	INY
	LDA LVALH
	BEQ _DOLO
	JSR HX2ASC
_DOLO	LDA LVALL
	JSR HX2ASC
	LDX #$00	; bring back the rest from IOBUF
_COPY	LDA COMM,X
	STA ARGS,Y	; store at offset Y from ARGS
	BEQ XDONE
	INX
	INY
	BNE _COPY	
		
; ****************************************

LB2VAL			; label to be evaluated is in ARGS + X (X = 0 or 1)
	LDY #$00
_NEXT	CPY #LBLSZ	; all chars done
	BEQ DOLVAL
	JSR CHKLBL	; has the label finished early?
	BCC _STOP
	STA COMM,Y	; copy because we need exactly 6 chars for the search
	INX		; COMM isn't used in parsing, so it
	LDA ARGS,X	; can be treated as scratch space
	INY		
	BNE _NEXT
_STOP	LDA #SP		; label is in COMM - ensure filled with spaces
_LOOP	STA COMM,Y	; Y still points to next byte to process 
	INY
	CPY #LBLSZ
	BNE _LOOP
DOLVAL	LDA #<COMM	; now get value for the label
	STA STRL
	LDX #$00	; select global table (#>COMM)
	STX STRH
	LDA #SYMSZ
	STA RECSIG
	LDA #SYMSZ+2
	STA RECSZ	; size includes additional two bytes for value
	LDA COMM
	CMP #DOT
	BEQ _LOCAL	; local symbol
	JSR SYMSCH
	BEQ _FREF	; if not there, handle as a forward reference
_FOUND	LDY #SYMSZ
	LDA (TBLL),Y	; save value
	STA LVALL
	INY
	LDA (TBLL),Y
	STA LVALH
	RTS	
_LOCAL			; locals much the same
	LDX #$03	; select local table
	JSR SYMSCH
	BNE _FOUND	; if not there, handle as a forward reference
_FREF	LDA FRFLAG	; set when patching
	BNE SYMERR	; can't add FREFs when patching
	JSR PCTOLV	; default value	to PC
	LDA FREFTH	; store it in the table
	STA MISCH
	LDA FREFTL	; Calculate storage address
	LDX NFREF
	BEQ _CONT	; no symbols to skip
_LOOP	CLC		
	ADC #SYMSZ+3	; skip over existing symbols
	BCC _SKIP
	INC MISCH	; carry bit set - increase high pointer
_SKIP	DEX
	BNE _LOOP
_CONT	STA MISCL	; Reqd address is now in MISCL,H
	INC NFREF	; Update FREF count
	LDA NFREF
	CMP #MAXFRF	; Check for table full
	BPL OVFERR
	LDA #COMM
	STA HADFRF	; non-zero value tells that FREF was encountered
	STA MISC2L
	JSR STORE	; Store the symbol
	INY
	TXA		; X is zero after STORE
	STA (MISCL),Y	
	RTS		; No error		
	
; ****************************************
	
PCSYM
	JSR PCTOLV
;	JMP STRSYM
	
; ****************************************
	
STRSYM			; Store symbol - name at LABEL, value in MISC2L,H
	LDA #LABEL
	STA MISC2L
	STA STRL
	LDX #$00
	STX STRH
	LDA #SYMSZ
	STA RECSIG	
	LDA LABEL	; Global or local?
	CMP #DOT
	BNE _SRCH	; Starts with a dot, so local
	LDX #$03
_SRCH	JSR SYMSCH
	BEQ STCONT	; Not there yet, so ok
_ERR	PLA
	PLA
SYMERR	LDY #UNKSYM	; missing symbol error
	BNE SBAD
	;LDX #FAIL
	;RTS
OVFERR	LDY #OVRFLW	; Symbol table overflow	error
SBAD	LDX #FAIL
	RTS
STCONT	;LDA #LABEL
	LDX LABEL	; Global or local?
	CPX #DOT
	BEQ _LSYM	; Starts with a dot, so local
	SEC		; Store symbol in global symbol table	
	LDA GSYMTL	; Make space for next symbol
	SBC #SYMSZ+2	; skip over existing symbols
	BCS _CONTG	; Reqd address is now in GSYMTL,H
_DWNHI	DEC GSYMTH	; carry bit clear - decrease high pointer
_CONTG	STA GSYMTL
	INC NGSYM	; Update Symbol count - overflow on 256 symbols
	BEQ OVFERR	; Check for table full
	STA MISCL	; put addres into MISCH,L for saving
	LDA GSYMTH
	STA MISCH
	BNE STORE	; Always branches - symbol tables cannot be on page zero
_LSYM	LDA LSYMTH	; Store symbol in local symbol table	
	STA MISCH
	LDA LSYMTL	; Calculate storage address
	LDX NLSYM
	BEQ _CONTL	; no symbols to skip
_LOOP	CLC
	ADC #SYMSZ+2	; skip over existing symbols
	BCC _SKIP
	INC MISCH
_SKIP	DEX
	BNE _LOOP
_CONTL	STA MISCL	; Reqd address is now in MISCL,H
	INC NLSYM	; Update Symbol count
	LDA NLSYM
	CMP #MAXSYM	; Check for table full
	BPL OVFERR
STORE	LDY #0		; First store the symbol string
	STY MISC2H
   	LDX #SYMSZ
_MV     LDA (MISC2L),Y 	; move bytes
	STA (MISCL),Y
	INY
	DEX
	BNE _MV
	LDA LVALL	; Now store the value WORD
	STA (MISCL),Y
	INY
	LDA LVALH
	STA (MISCL),Y
	RTS		; No error	
	
	
; ****************************************

CONVRT	 		; convert an ASCII string at ARGS,X 
			; of the form $nnnn (1 to 4 digits)
			; return the result in LVALL,H, and preserves X and Y
			; uses COMM area for scratch space
	CMP #HEX	; syntax for hex constant
	BNE SBAD	; syntax error
	STY COMM+1
	JSR NBYTS
	CPX #FAIL
	BEQ SBAD
	STA COMM
	LDY #$00
	STY LVALH
_BACK	DEX
	DEX
	LDA ARGS,X
	CMP #HEX
	BEQ _1DIG
	JSR BYT2HX
	SEC
	BCS _SKIP
_1DIG	JSR AHARGS1	; one digit
_SKIP	STA LVALL,Y
	INY
	CPY COMM
	BNE _BACK
_RET	LDY COMM+1
	RTS
		
; ****************************************

SYMSCH			; X = 0 for globals
			; X = 3 for locals
	LDA GSYMTL,X	; get global symbol value
	STA TBLL
	LDA GSYMTH,X
	STA TBLH
	LDA NGSYM,X	; Number of global symbols
	STA RECNM
	JSR SEARCH
	CPX #FAIL	; Z set if search failed
	RTS		; caller to check

; ****************************************

FMT2AM			; calculate the addressing given
			; the format of the arguments; 
			; return format in X, and
			; location to CHKEXT from in A
			; $FF		invalid
			; #ZPG		$nn
			; #ZPX		$nn,X
			; #ZPY		$nn,Y
			; #ABS		$nnnn
			; #ABX		$nnnn,X
			; #ABY		$nnnn,Y
			; #IND		($nnnn)
			; #IDX		($nn,X)
			; #IDY		($nn),Y
			; #INZ		($nn)
			; #IAX		($nnnn,X)
;		
;	Addressing modes are organised as follows:
;
;	IMP (0)	ZPG (4) INZ (-) ABS (9) IND (C)
;	ACC (1) ZPX (5) INX (7) ABX (A) IAX (D)
;	IMM (2) ZPY (6) INY (8) ABY (B) ---
;	REL (3) ---	 ---	---	---
;
;	so algorithm below starts with 4, adds 3 if indirect
;	and adds 6 if absolute (i.e. 2 byte address), then adds 1 or 2
;	if ,X or ,Y format
;
	LDX #$00
	LDA #$04	; start with mode index of 4
	LDY ARGS,X
	CPY #OPEN
	BNE _SKIP
	CLC		; add 3 for indirect modes
	ADC #$03
	INX
_SKIP	PHA	
	JSR NBYTS	; count bytes (1 or 2 only)
	TAY		; byte count in Y 
	DEX
	LDA CURMNE
	CMP #$21	; is it JSR?
	BEQ _JSR
	CMP #$23	; is it JMP?
	BNE _NOJMP
_JSR	;LDY #$2		; force 2 bytes for these two situations
	INY		; following code treats Y = 3 the same as Y = 2
_NOJMP	PLA		; mode base back in A
	INX		; check for NBYTS failure
	BEQ FERR
	DEY
	BEQ _1BYT
_2BYT	CLC
	ADC #$06	; add 6 to base index for 2 byte modes
_1BYT	TAY		; mode index now in Y
_CHECK	LDA ARGS,X
	BEQ _DONE
	CMP #SP
	BNE _CONT
_DONE	LDA ARGS
	CMP #OPEN	; brackets must match
	BEQ FERR
_RET	CPY #$0F
	BPL FERR	; no indirect absolute Y mode
	CPY #$07
	BEQ FERR	; no indirect zero page mode
	BMI _1		; 6502 has no INZ mode, so reduce
	DEY		; so reduce by ifgreater than 7
_1	TYA
	TAX
	RTS
_CONT	CMP #CLOSE
	BNE _MORE
	LDA #SP
	STA ARGS	; erase brackets now they have
	INX
	LDA ARGS,X
	CMP #COMMA
	BNE _CHECK
_MORE	LDA ARGS,X
	CMP #COMMA
	BNE FERR
	INX
	LDA ARGS,X
	CMP #'X'
	BEQ _ISX
_ISY	CMP #'Y'
	BNE FERR
	LDA ARGS
	CMP #OPEN
	BEQ FERR
	STA ARGS-2,X	; to avoid ,X check below
	INY
_ISX	INY
	LDA ARGS-2,X
	CMP #CLOSE
	BEQ FERR
	INX
	BNE _CHECK	; always
FERR	LDX #FAIL	; error message generated upstream
FRET	RTS
NBYTS	LDY #$00	; count bytes using Y
_LOOP	INX
	INY
	JSR AHARGS
	CMP #FAIL
	BNE _LOOP
_NEXT	TYA
	LSR		; divide number by 2
	BEQ FERR	; zero is an error
	CMP #$03	; 3 or more is an error
	BCS FERR
_RET	RTS		
	
; ****************************************
; *          Utility Routines            *
; ****************************************
	
SEARCH			; TBLL,H has the address of the table to search
			; and address of record on successful return
			; STRL,H has the address of the search string
			; Search through RECNM records
			; Each of size RECSZ with RECSIG significant chars
	LDA RECNM
	BEQ FERR	; empty table
	LDX #$00	; Record number
_CHK1	LDY #$FF	; Index into entry
_CHMTCH	INY
	CPY RECSIG	; Have we checked all significant chars?
	BEQ FRET	; Yes
	LDA (TBLL),Y	; Load the bytes to compare
	CMP (STRL),Y
	BEQ _CHMTCH	; Check next if these match
	INX		; Else move to next record
	CPX RECNM
	BEQ FERR
	LDA TBLL	; Update address
	CLC
	ADC RECSZ
	STA TBLL
	BCC _CHK1
	INC TBLH	; Including high byte if necessary
	BCS _CHK1	; will always branch
;_FAIL	LDX #FAIL	; X = $FF indicates failure
;_MATCH	RTS		; got it - index is in X, address is in A and TBLL,H

; ****************************************

BYT2HX			; convert the ASCII byte (1 or 2 chars) at offset X in
			; the args field to Hex
			; result in A ($FF for fail)
	
	JSR AHARGS	
	CMP #FAIL	; indicates conversion error		
	BEQ FERR
	PHA	
	JSR AHARGS1
	DEX
	CMP #FAIL
	BNE _CONT
	PLA		; just ignore 2nd character
	RTS
_CONT	STA SCRTCH
	PLA
	ASL		; shift 
	ASL
	ASL
	ASL
	ADC SCRTCH
	RTS
	
; ****************************************

AHARGS1	INX		; caller needs to DEX
AHARGS	LDA ARGS,X
ASC2HX			; convert ASCII code in A to a HEX digit
    	EOR #$30  
	CMP #$0A  
	BCC _VALID  
	ADC #$88        ; $89 - CLC  
	CMP #$FA  
	BCC _ERR  
	AND #$0F   
_VALID	RTS
_ERR	LDA #FAIL	; this value can never be from a single digit, 
	RTS		; so ok to indicate error
	
; ****************************************

HX2ASC			; convert a byte in A into two ASCII characters
			; store in ARGS,Y and ARGS+1,Y
	PHA 		; 1st byte. 
	JSR LSR4	; slower, but saves a byte and not too crucial
	JSR DO1DIG
	PLA 
DO1DIG	AND #$0F	; Print 1 hex digit
	ORA #$30
	CMP #$3A
	BCC _DONE
	ADC #$06
_DONE	STA ARGS,Y
	INY
	RTS
	
; ****************************************
	
EXPMNE			; copy the 2 chars at R/LMNETB,X
			; into LMNE and RMNE, and expand 
			; into 3 chars at MNE to MNE+2
	LDA LMNETB,X
	STA LMNE
	LDA RMNETB,X
	STA RMNE
	LDX #$00
_NEXT	LDA #$00
	LDY #$05
_LOOP	ASL RMNE
	ROL LMNE
	ROL
	DEY
	BNE _LOOP
	ADC #'A'-1
	STA MNE,X
	LDY PRFLAG
	BEQ _SKIP
	JSR OUTCH	; print the mnemonic as well
_SKIP	INX
	CPX #$03
	BNE _NEXT
	RTS	

; ****************************************
;      		DISASSEMBLER
; Adapted from code in a Dr Dobbs article 
; by Steve Wozniak and Allen Baum (Sep '76)
; ****************************************
	
DISASM	
	JSR ADDARG
	;BEQ _DODIS
	BEQ DSMBL
_COPY	JSR LVTOPC
;_DODIS	JMP DSMBL
; fall through

; ****************************************

DSMBL	
	;LDA #$13	; Count for 20 instruction dsmbly
	;STA COUNT
_DSMBL2	JSR INSTDSP	; Disassemble and display instr.
	JSR PCADJ
	STA PCL		; Update PCL,H to next instr.
	STY PCH
	;DEC COUNT	; Done first 19 instrs
	;BNE _DSMBL2	; * Yes, loop.  Else DSMBL 20th
	
	LDA KBDRDY	; Now disassemble until key press
	.if APPLE1
	BPL _DSMBL2
	.else
	BEQ _DSMBL2
	.endif
	LDA KBD

INSTDSP	JSR PRPC	; Print PCL,H
	LDA (PCL,X)	; Get op code
	TAY   
	LSR   		; * Even/odd test
	BCC _IEVEN
	ROR  		; * Test B1
	BCS _ERR	; XXXXXX11 instr invalid
	CMP #$A2	
	BEQ _ERR	; 10001001 instr invalid
	AND #$87	; Mask 3 bits for address mode
	;ORA #$80	; * add indexing offset
_IEVEN	LSR   		; * LSB into carry for
	TAX   		; Left/right test below
	LDA MODE,X	; Index into address mode table
	BCC _RTMODE	; If carry set use LSD for
	JSR LSR4
	;LSR   		; * print format index
	;LSR   		
	;LSR   		; If carry clear use MSD
	;LSR   
_RTMODE	AND #$0F	; Mask for 4-bit index
	BNE _GETFMT	; $0 for invalid opcodes
_ERR	LDY #$80	; Substitute $80 for invalid op,
	LDA #$00	; set print format index to 0
_GETFMT	TAX   
	LDA MODE2,X	; Index into print format table
	STA FORMAT	; Save for address field format
	AND #$03	; Mask 2-bit length.  0=1-byte
	STA LENGTH	; *  1=2-byte, 2=3 byte
	TYA   		; * op code
	JSR GETMNE
	LDY #$00
	PHA   		; Save mnemonic table index
_PROP	LDA (PCL),Y
	JSR OUTHEX
	LDX #$01
_PROPBL	JSR PRBL2
	CPY LENGTH	; Print instr (1 to 3 bytes)
	INY   		; *  in a 12-character field
	BCC _PROP
	LDX #$03	; char count for mnemonic print
	STX PRFLAG	; So EXPMNE prints the mnemonic
	CPY #$04
	BCC _PROPBL
	PLA   		; Recover mnemonic index
	TAX
	JSR EXPMNE
	JSR PRBLNK	; Output 3 blanks
	LDY LENGTH
	LDX #$06	; Count for 6 print format bits
_PPADR1	CPX #$03
	BEQ _PPADR5	; If X=3 then print address val
_PPADR2	ASL FORMAT	; Test next print format bit
	BCC _PPADR3	; If 0 don't print
	LDA CHAR1-1,X	; *  corresponding chars
	JSR OUTCH	; Output 1 or 2 chars
	LDA CHAR2-1,X	; *  (If char from char2 is 0,
	BEQ _PPADR3	; *   don't output it)
	JSR OUTCH
_PPADR3	DEX   
	BNE _PPADR1
	STX PRFLAG	; reset flag to 0
	RTS  		; Return if done 6 format bits
_PPADR4	DEY
	BMI _PPADR2
	JSR OUTHEX	; Output 1- or 2-byte address
_PPADR5	LDA FORMAT
	CMP #$E8	; Handle rel addressing mode
	LDA (PCL),Y	; Special print target adr
	BCC _PPADR4	; *  (not displacement)
_RELADR	JSR PCADJ3	; PCL,H + DISPL + 1 to A,Y
	TAX   
	INX   
	BNE PRNTYX	; *     +1 to X,Y
	INY   
PRNTYX	TYA   
PRNTAX	JSR OUTHEX	; Print target adr of branch
PRNTX	TXA   		; *  and return
	JMP OUTHEX
PRPC	JSR CRLF	; Output carriage return
	LDA PCH
	LDX PCL
	JSR PRNTAX	; Output PCL and PCH
PRBLNK	LDX #$03	; Blank count
PRBL2	JSR OUTSP	; Output a blank
	DEX   
	BNE PRBL2	; Loop until count = 0
	RTS   
PCADJ	SEC
PCADJ2	LDA LENGTH	; 0=1-byte, 1=2-byte, 2=3-byte
PCADJ3	LDY PCH	
	TAX   		; * test displ sign (for rel
	BPL _PCADJ4	; *  branch).  Extend neg
	DEY   		; *  by decrementing PCH
_PCADJ4	ADC PCL
	BCC _RTS	; PCL+LENGTH (or displ) + 1 to A
	INY   		; *  carry into Y (PCH)
_RTS	RTS 
	
GETMNE			; get mnemonic index for opcode in A
			; on completion, A holds the index 
			; into the mnemonic table
	STA TEMP1	; will need it later
	AND #$8F
	CMP #$8A
	BEQ CAT3
	ASL
	CMP #$10
	BEQ CAT2
	LDA TEMP1	; ? ABCD EFGH - thanks bogax, www.6502.org/forum
	ASL		; A BCDE FGH0
	ADC #$80	; B ?CDE FGHA
	ROL		; ? CDEF GHAB
	ASL		; C DEFG HAB0
	AND #$1F	; C 000G HAB0
	ADC #$20	; 0 001G HABC
	PHA
	LDA TEMP1	; get the opcode back
	AND #$9F
	BEQ CAT1
	ASL
	CMP #$20
	BEQ CAT4
	AND #$06
	BNE CAT67
CAT5			; remaining nnnX XX00 codes
	PLA
	AND #$07	; just low 3 bits
	CMP #$03
	BPL _3
	ADC #$02	; correction for 21 and 22
_3	ADC #$1F	; and add 20
	RTS
CAT4			; Branch instructions - nnn1 0000
	PLA
	AND #$07	; just low 3 bits
	ADC #$18	; and add 19 (carry is set)
	RTS
CAT1			; 0nn0 0000 - BRK, JSR, RTI, RTS
	PLA
	TAX
	LDA MNEDAT-$20,X
	RTS
MNEDAT	.byte $16, $21, $17, $18
CAT2			; nnnn 1000 - lots of no-arg mnemonics
	LDA TEMP1
LSR4	LSR		; need high 4 bits
	LSR
	LSR
	LSR
	RTS
CAT3			; 1nnn 1010 - TXA,TXS,TAX,TSX,DEX,-,NOP,-
	JSR CAT2	; need high 4 bits
	CMP #$0E
	BNE _2
	ADC #$FD
_2	ADC #$08	; then add 8
	RTS
CAT67			; gets the index for categories 6 and 7
	PLA		; i.e. nnnX XX01 and nnnX XX10 ($28-$2F, $30-$37)
	RTS		; it's already done
		
; Data and related constants

MODES			; Addressing mode constants
IMP = $00
ACC = $01
IMM = $02		; #$nn or #'<char>' or #LABEL
REL = $03		; *+nn or LABEL
ZPG = $04		; $nn or LABEL
ZPX = $05		; $nn,X or LABEL,X
ZPY = $06		; $nn,Y or LABEL,Y
IDX = $07		; ($nn,X) or (LABEL,X)
IDY = $08		; ($nn),Y or (LABEL),Y
ABS = $09		; $nnnn or LABEL
ABX = $0A		; $nnnn,X or LABEL,X
ABY = $0B		; $nnnn or LABEL
IND = $0C		; ($nnnn) or (LABEL)

NUMMN 	=$38		; number of mnemonics

; Tables

LMNETB
	.byte $82	; PHP
	.byte $1B	; CLC
	.byte $83	; PLP
	.byte $99	; SEC
	.byte $82	; PHA
	.byte $1B	; CLI
	.byte $83	; PLA
	.byte $99	; SEI
	.byte $21	; DEY
	.byte $A6	; TYA
	.byte $A0	; TAY
	.byte $1B	; CLV
	.byte $4B	; INY
	.byte $1B	; CLD
	.byte $4B	; INX
	.byte $99	; SED
	.byte $A6	; TXA
	.byte $A6	; TXS
	.byte $A0	; TAX
	.byte $A4	; TSX
	.byte $21	; DEX
	.byte $73	; NOP
	.byte $14	; BRK
	.byte $95	; RTI
	.byte $95	; RTS
	.byte $14	; BPL
	.byte $13	; BMI
	.byte $15	; BVC
	.byte $15	; BVS
	.byte $10	; BCC
	.byte $10	; BCS
	.byte $13	; BNE
	.byte $11	; BEQ
	.byte $54	; JSR
	.byte $12	; BIT
	.byte $53	; JMP
	.byte $9D	; STY
	.byte $61	; LDY
	.byte $1C	; CPY
	.byte $1C	; CPX
	.byte $7C	; ORA
	.byte $0B	; AND
	.byte $2B	; EOR
	.byte $09	; ADC
	.byte $9D	; STA
	.byte $61	; LDA
	.byte $1B	; CMP
	.byte $98	; SBC
	.byte $0C	; ASL
	.byte $93	; ROL
	.byte $64	; LSR
	.byte $93	; ROR
	.byte $9D	; STX
	.byte $61	; LDX
	.byte $21	; DEC
	.byte $4B	; INC


RMNETB
	.byte $20	; PHP
	.byte $06	; CLC
	.byte $20	; PLP
	.byte $46	; SEC
	.byte $02	; PHA
	.byte $12	; CLI
	.byte $02	; PLA
	.byte $52	; SEI
	.byte $72	; DEY
	.byte $42	; TYA
	.byte $72	; TAY
	.byte $2C	; CLV
	.byte $B2	; INY
	.byte $08	; CLD
	.byte $B0	; INX
	.byte $48	; SED
	.byte $02	; TXA
	.byte $26	; TXS
	.byte $70	; TAX
	.byte $F0	; TSX
	.byte $70	; DEX
	.byte $E0	; NOP
	.byte $96	; BRK
	.byte $12	; RTI
	.byte $26	; RTS
	.byte $18	; BPL
	.byte $52	; BMI
	.byte $86	; BVC
	.byte $A6	; BVS
	.byte $C6	; BCC
	.byte $E6	; BCS
	.byte $8A	; BNE
	.byte $62	; BEQ
	.byte $E4	; JSR
	.byte $68	; BIT
	.byte $60	; JMP
	.byte $32	; STY
	.byte $32	; LDY
	.byte $32	; CPY
	.byte $30	; CPX
	.byte $82	; ORA
	.byte $88	; AND
	.byte $E4	; EOR
	.byte $06	; ADC
	.byte $02	; STA
	.byte $02	; LDA
	.byte $60	; CMP
	.byte $86	; SBC
	.byte $D8	; ASL
	.byte $D8	; ROL
	.byte $E4	; LSR
	.byte $E4	; ROR
	.byte $30	; STX
	.byte $30	; LDX
	.byte $46	; DEC
	.byte $86	; INC
	
MIN			; Minimum legal value for MNE for each mode.
	.byte $00, $30, $25, $19, $24 
	.byte $28, $34, $28, $28, $21, $28
	.byte $28, $23
MAX			; Maximum +1 legal value of MNE for each mode. 
	.byte $18+1, $33+1, $2F+1, $20+1, $37+1
	.byte $33+1, $35+1, $2F+1, $2F+1, $37+1, $33+1
	.byte $2F+1, $23+1
BASE			; Base value for each opcode
	.byte $08, $18, $28, $38
	.byte $48, $58, $68, $78
	.byte $88, $98, $A8, $B8
	.byte $C8, $D8, $E8, $F8
	.byte $8A, $9A, $AA, $BA
	.byte $CA, $EA, $00, $40
	.byte $60, $10, $30, $50
	.byte $70, $90, $B0, $D0
	.byte $F0, $14, $20, $40
	.byte $80, $A0, $C0, $E0
	.byte $01, $21, $41, $61
	.byte $81, $A1, $C1, $E1
	.byte $02, $22, $42, $62
	.byte $82, $A2, $C2, $E2
OFFSET			; Default offset values for each mode, 
			; added to BASE to get Opcode
	.byte $00, $08, $00, $00, $04
	.byte $14, $14, $00, $10, $0C, $1C
	.byte $18, $2C


; offset adjustments for the mnemonic exceptions
ADJABY  =$04		; 
ADJIMM  =$08		; 

; disassembler data

; XXXXXXZ0 instrs
; * Z=0, left half-byte
; * Z=1, right half-byte
MODE	.byte $04, $20, $54, $30, $0D
	.byte $80, $04, $90, $03, $22
	.byte $54, $33, $0D, $80, $04
	.byte $90, $04, $20, $54, $33
	.byte $0D, $80, $04, $90, $04
	.byte $20, $54, $3B, $0D, $80
	.byte $04, $90, $00, $22, $44
	.byte $33, $0D, $C8, $44, $00
	.byte $11, $22, $44, $33, $0D
	.byte $C8, $44, $A9, $01, $22
	.byte $44, $33, $0D, $80, $04
	.byte $90, $01, $22, $44, $33
	.byte $0D, $80, $04, $90
; YYXXXZ01 instrs
	.byte $26, $31, $87, $9A
	
MODE2	.byte $00	; ERR
	.byte $21	; IMM
	.byte $81	; Z-PAG
	.byte $82	; ABS
	.byte $00	; IMPL
	.byte $00	; ACC
	.byte $59	; (Z-PAG,X)
	.byte $4D	; (Z-PAG),Y
	.byte $91	; Z-PAG,X
	.byte $92	; ABS,X
	.byte $86	; ABS,Y
	.byte $4A	; (ABS)
	.byte $85	; Z-PAG,Y
	.byte $9D	; REL
CHAR1	.byte ','
	.byte ')'
	.byte ','
	.byte '#'
	.byte '('
	.byte '$'
CHAR2	.byte 'Y'
	.byte $00	
	.byte 'X'
	.byte '$'
	.byte '$'
	.byte $00

; Special case mnemonics	
SPCNT	= $06		; duplicate some checks so I can use the same loop above
; Opcodes
SPINC1	.byte $22, $24, $25, $35, $36, $37
; 1st address mode to check
SPINC2	.byte $04, $05, $05, $02, $05, $05
; 2nd address mode to check
SPINC3	.byte $04, $05, $0A, $0B, $0A, $0A
	
; commands

NUMCMD	=$0D
CMDS	.text "NLXEMRDI!$AVP"

N1 = NEW-1
L1 = LIST-1
D1 = DELETE-1
E1 = EDIT-1
M1 = MEM-1
R1 = RUN-1
DIS1 = DISASM-1
I1 = INSERT-1
GL1 = GETLINE-1
MON1 = MONTOR-1
A1 = ASSEM-1
V1 = VALUE-1
P1 = PANIC-1

CMDH	.byte	>N1
	.byte	>L1
	.byte	>D1
	.byte	>E1
	.byte	>M1
	.byte	>R1
	.byte	>DIS1
	.byte	>I1
	.byte	>GL1
	.byte	>MON1
	.byte	>A1
	.byte	>V1
	.byte	>P1

CMDL	.byte	<N1
	.byte	<L1
	.byte	<D1
	.byte	<E1
	.byte	<M1
	.byte	<R1
	.byte	<DIS1
	.byte	<I1
	.byte	<GL1
	.byte	<MON1
	.byte	<A1
	.byte	<V1
	.byte	<P1

; Assembler directives - all entered with a leading '.'

BYTE 	='B'		; bytes
WORD	='W'		; word
STR	='S'		; string
EQU	='='		; equate
MOD	='M'		; start address for subsequent module

NUMDIR	=$05
DIRS	.text "BWS=M"

; Errors

UNKERR	=$00
INVMNE	=$01		; Invalid mnemonic
ILLADM	=$02		; Illegal addressing mode
SYNTAX	=$03		; Syntax error
OVRFLW	=$04		; Symbol table overflow
UNKSYM	=$05		; Unknown or duplicate symbol error
MAXERR	=$06

EMSGSZ	=$03		; The size of the error message strings
ERPRSZ	=$05		; The size of the error prefix string
ERRPRE	.text " :RRE"
ERRMSG
	.if UNK_ERR_CHECK
	.text "UNK"
	.endif
	.text "MNE"
	.text "ADD"
	.text "SYN"
	.text "OVF"
	.text "SYM"

MSGSZ = $1B
MSG	.text "NESSEW NEK YB 3.1 REDASURK",CR


	.if MINIMONITOR
; ****************************************
;      		MINIMONITOR
; A simple monitor to allow viewing and
; altering of registers, and changing the PC
; ****************************************
	
NREGS	=$5
DBGCMD	.text "PSYXALH"
NDBGCS	=NREGS+2
FLAGS	.text "CZIDB"
	.byte $00	; A non-printing character - this flag always on
	.text "VN"

GETCMD	JSR CRLF
	JSR PRDASH
	JSR GETCH1
	LDY #NDBGCS
_LOOP	CMP DBGCMD-1,Y
	BEQ DOCMD	; if we've found a PC or register change command, then run it
	DEY
	BNE _LOOP
	CMP #'R'	; resume?
	BNE _NOTR
	JSR RESTORE
	;CLI		; enable interrupts again
	JMP (PCL)	; Simulate the return so we can more easily manipulate the stack
_NOTR
	.if DOTRACE
	CMP #'T'	; trace?
	BNE NOTT	
TRACE	LDX #$08
XQINIT  LDA INITBL-1,X ;INIT XEQ AREA
	STA XQT,X
	DEX
	BNE XQINIT
	LDA (PCL,X)    ;USER OPCODE BYTE
	BEQ XBRK       ;SPECIAL IF BREAK
	LDY LENGTH     ;LEN FROM DISASSEMBLY
	CMP #$20
	BEQ XJSR       ;HANDLE JSR, RTS, JMP,
	CMP #$60       ;  JMP (), RTI SPECIAL
	BEQ XRTS
	CMP #$4C
	BEQ XJMP
	CMP #$6C
	BEQ XJMPAT
	CMP #$40
	BEQ XRTI
	AND #$1F
	EOR #$14
	CMP #$04       ;COPY USER INST TO XEQ AREA
	BEQ _XQ2       ;  WITH TRAILING NOPS
_XQ1    LDA (PCL),Y    ;CHANGE REL BRANCH
_XQ2    STA XQT,Y      ;  DISP TO 4 FOR
	DEY            ;  JMP TO BRANCH OR
	BPL _XQ1       ;  NBRANCH FROM XEQ.
	JSR RESTORE    ;RESTORE USER REG CONTENTS.
	JMP XQT        ;XEQ USER OP FROM RAM
NOTT
	.endif
	CMP #'!'	; MONITOR COMMAND
	BNE _MON
	JSR GETLINE
	JMP XBRK
_MON	CMP #'$'	; monitor?
	BNE GETCMD
	JMP MONTOR
DOCMD	LDX #$FE
_LOOP	JSR GETCH1
	STA ARGS+2,X
	INX
	BNE _LOOP
	JSR BYT2HX
	STA REGS-1,Y
	LDX SAVS
	TXS
_1	JMP XBRK

DEBUG   PLP
	JSR SAVE       ;SAVE REG'S ON BREAK
	PLA              ;  INCLUDING PC
	STA PCL
	PLA
	STA PCH
XBRK	TSX
	STX SAVS
	JSR SHOW
	JSR INSTDSP    ;PRINT USER PC.
	JMP GETCMD
	.if DOTRACE
XRTI    CLC
	PLA              ;SIMULATE RTI BY EXPECTING
	STA SAVP     ;  STATUS FROM STACK, THEN RTS
XRTS    PLA              ;RTS SIMULATION
	STA PCL        ;  EXTRACT PC FROM STACK
	PLA              ;  AND UPDATE PC BY 1 (LEN=0)
PCINC2  STA PCH
PCINC3  JSR PCADJ2	;UPDATE PC BY LEN
	STY PCH
	CLC
	BCC NEWPCL
XJSR    CLC
	JSR PCADJ2     ;UPDATE PC AND PUSH
	TAX              ;  ONTO STACK FOR
	TYA              ;  JSR SIMULATE
	PHA
	TXA
	PHA
	LDY #$02
XJMP    CLC
XJMPAT  LDA (PCL),Y
	TAX              ;LOAD PC FOR JMP,
	DEY              ;  (JMP) SIMULATE.
	LDA (PCL),Y
	STX PCH
NEWPCL  STA PCL
	BCS XJMP
	JMP XBRK
	.endif
SHOW	JSR CRLF
	LDX #NREGS
_LOOP	LDA DBGCMD-1,X
	JSR OUTCH
	JSR PRDASH
	LDA REGS-1,X
	JSR OUTHEX
	JSR OUTSP
	DEX
	BNE _LOOP
	LDA SAVP	; show the flags explicitly as well
	LDX #$08
_NEXT	ASL
	BCC _SKIP
	PHA
	LDA FLAGS-1,X
	JSR OUTCH
	PLA
_SKIP	DEX
	BNE _NEXT
	RTS
	.if DOTRACE
BRANCH  CLC              ;BRANCH TAKEN,
	LDY #$01       ;  ADD LEN+2 TO PC
	LDA (PCL),Y
	JSR PCADJ3
	STA PCL
	TYA
	SEC
	BCS PCINC2
NBRNCH  JSR SAVE       ;NORMAL RETURN AFTER
	SEC              ;  XEQ USER OF
	BCS PCINC3     ;GO UPDATE PC
INITBL  NOP
	NOP              ;DUMMY FILL FOR
	JMP NBRNCH     ;  XEQ AREA
	JMP BRANCH
	.endif
RESTORE LDA SAVP     ;RESTORE 6502 REG CONTENTS
	PHA              ;  USED BY DEBUG SOFTWARE
	LDA SAVA
	LDX SAVX
	LDY SAVY
	PLP
	RTS
SAVE    STA SAVA        ;SAVE 6502 REG CONTENTS
	STX SAVX
	STY SAVY
	PHP
	PLA
	STA SAVP
	TSX
	STX SAVS
	CLD
	RTS
	.endif

; ****************************************
; I/O routines
; ****************************************

PRDASH	
	LDA #MINUS
	JMP OUTCH
	
; ****************************************
	
	.if MINIMONITOR
GETCH1	JSR GETCH
	JMP OUTCH
	.endif

; ****************************************

SHWMOD			; Show name of module being assembled
	JSR CRLF
	LDX #$00
_LOOP2	LDA LABEL,X
	JSR OUTCH
	INX
	CPX #LBLSZ
	BNE _LOOP2
	JSR OUTSP
;	JMP PRLNNM	; falls through
	
; ****************************************	

PRLNNM
	LDA LINEH
	JSR PRHEX
	LDA LINEL
	JSR OUTHEX
	;JMP OUTSP
; falls through

OUTSP	
	LDA #SP
	JMP OUTCH
	
CRLF			; Go to a new line.
	LDA #CR		; "CR"
	.if APPLE1
	JMP OUTCH
	.else
	JSR OUTCH
	LDA #LF		; "LF" - is this needed for the Apple 1?
	JMP OUTCH
	.endif

GETCH   		; Get a character from the keyboard.
	LDA KBDRDY
	.if APPLE1
	BPL GETCH
	LDA KBD
	AND #INMASK
	.else
	BEQ GETCH
	.endif
	RTS
	
;-------------------------------------------------------------------------
;
;  The WOZ Monitor for the Apple 1
;  Written by Steve Wozniak 1976
;  Minor adjustments by Ken Wessen to support the minimonitor ! command
;  (i.e., Calling GETLINE as a subroutine)
;  Standard entry points are unchanged
;
;-------------------------------------------------------------------------

	.if INROM

BSA1		=     '_';$08		; backspace

XAML            =     $24             ;  Last "opened" location Low
XAMH            =     $25             ;  Last "opened" location High
STL             =     $26             ;  Store address Low
STH             =     $27             ;  Store address High
L               =     $28             ;  Hex value parsing Low
H               =     $29             ;  Hex value parsing High
YSAVM           =     $2A             ;  Used to see if hex value is given
MODEM           =     $2B             ;  $00=XAM, $74=STOR, $AE=BLOCK XAM

IN              =     $0200           ;  Input buffer to $027F

;KBD             =     $D010           ;  PIA.A keyboard input
;KBDCR           =     $D011           ;  PIA.A keyboard control register
DSP             =     $D012           ;  PIA.B display output register
DSPCR           =     $D013           ;  PIA.B display control register

MONPROMPT          =     '\'             ;  Prompt character

	        * =     $FF00
RESET           CLD                   ;  Clear decimal arithmetic mode
	        CLI
	        LDY     #$7F	      ;  Mask for DSP data direction reg
	        STY     DSP           ;   (DDR mode is assumed after reset)
	        LDA     #$A7          ;  KBD and DSP control register mask
	        STA     KBDRDY        ;  Enable interrupts, set CA1, CB1 for
	        STA     DSPCR         ;   positive edge sense/output mode.
ESCAPE          LDA     #MONPROMPT    ;  Print prompt character
	        JSR     OUTCH         ;  Output it.
MONLOOP	        JSR     GETLINE       ;  Attempt to read and execute one command
	        BCC     ESCAPE        ;  Error, generate ESC sequence
	        BCS     MONLOOP       ;  Read next command

GETLINE         JSR     CRLF
	        LDY     #0+1          ;  Start a new input line
BACKSPACE       DEY                   ;  Backup text index
	        BMI     GETLINE       ;  Oops, line's empty, reinitialize
NEXTCHAR        JSR     GETCH1
	        STA     IN,Y          ;  Add to text buffer
	        CMP     #CR           ;  CR?
	        BEQ     GOTCR         ;  Yes.
	        CMP     #BSA1         ;  Backspace key?
	        BEQ     BACKSPACE     ;  Yes
	        CMP     #ESC          ;  ESC?
	        BEQ     RETERR        ;  Yes
	        INY                   ;  Advance text index
	        BPL     NEXTCHAR      ;  Auto ESC if line longer than 127
RETERR	        CLC                   ;  Set C=0, indicating error
RETURN	        RTS                   ;  Return to caller (above or external)
GOTCR	                              ;  Line received, now let's parse it
	        LDY     #-1           ;  Reset text index
	        LDA     #0            ;  Default mode is XAM
	        TAX                   ;  X=0
SETSTOR         ASL                   ;  Leaves $74 if setting STOR mode
SETMODE         STA     MODEM         ;  Set mode flags
BLSKIP          INY                   ;  Advance text index
NEXTITEM        LDA     IN,Y          ;  Get character
	        CMP     #CR           ;  CR? (set C=1 if equal)
	        BEQ     RETURN        ;  Yes, done this line. Return C=1
	        ORA     #$80          ;  Set MSB for code below
	        CMP     #'.'+$80      ;  "."?"
	        BCC     BLSKIP        ;  Ignore everything below "."!
	        BEQ     SETMODE       ;  Set BLOCK XAM mode ("." = $AE)
	        CMP     #':'+$80
	        BEQ     SETSTOR       ;  Set STOR mode! $BA will become $74
	        CMP     #'R'+$80
	        BEQ     RUNM          ;  Run the program! Forget the rest
	        STX     L             ;  Clear input value (X=0)
	        STX     H
	        STY     YSAVM          ;  Save Y for comparison
NEXTHEX         LDA     IN,Y          ;  Get character for hex test
	        EOR     #$30          ;  Map digits to 0-9
	        CMP     #$0A          ;  Is it a decimal digit?
	        BCC     DIG           ;  Yes!
	        ADC     #$88          ;  Map letter "A"-"F" to $FA-FF
	        CMP     #$FA          ;  Hex letter?
	        BCC     NOTHEX        ;  No! Character not hex
DIG             ASL
	        ASL                   ;  Hex digit to MSD of A
	        ASL
	        ASL
	        LDX     #4            ;  Shift count
HEXSHIFT        ASL                   ;  Hex digit left, MSB to carry
	        ROL     L             ;  Rotate into LSD
	        ROL     H             ;  Rotate into MSD's
	        DEX                   ;  Done 4 shifts?
	        BNE     HEXSHIFT      ;  No, loop
	        INY                   ;  Advance text index
	        BNE     NEXTHEX       ;  Always taken
NOTHEX          CPY     YSAVM         ;  Check if L, H empty (no hex digits).
	        BEQ     RETERR        ;  Yes, generate ESC sequence.
	        BIT     MODEM         ;  Test MODE byte
	        BVC     NOTSTOR       ;  B6=0 is STOR, 1 is XAM or BLOCK XAM
	        LDA     L             ;  LSD's of hex data
	        STA     (STL,X)       ;  Store current 'store index'(X=0)
	        INC     STL           ;  Increment store index.
	        BNE     NEXTITEM      ;  No carry!
	        INC     STH           ;  Add carry to 'store index' high
TONEXTITEM      JMP     NEXTITEM      ;  Get next command item.
RUNM            JMP     (XAML)        ;  Run user's program
NOTSTOR         BMI     XAMNEXT       ;  B7 = 0 for XAM, 1 for BLOCK XAM
	        LDX     #2            ;  Copy 2 bytes
SETADR          LDA     L-1,X         ;  Copy hex data to
	        STA     STL-1,X       ;   'store index'
	        STA     XAML-1,X      ;   and to 'XAM index'
	        DEX                   ;  Next of 2 bytes
	        BNE     SETADR        ;  Loop unless X = 0
NXTPRNT         BNE     PRDATA        ;  NE means no address to print
	        JSR     CRLF
	        LDA     XAMH          ;  Output high-order byte of address
	        JSR     OUTHEX
	        LDA     XAML          ;  Output low-order byte of address
	        JSR     OUTHEX
	        LDA     #':'          ;  Print colon
	        JSR     OUTCH
PRDATA          JSR     OUTSP
	        LDA     (XAML,X)      ;  Get data from address (X=0)
	        JSR     OUTHEX        ;  Output it in hex format
XAMNEXT         STX     MODEM         ;  0 -> MODE (XAM mode).
	        LDA     XAML          ;  See if there's more to print
	        CMP     L
	        LDA     XAMH
	        SBC     H
	        BCS     TONEXTITEM    ;  Not less! No more data to output
	        INC     XAML          ;  Increment 'examine index'
	        BNE     MOD8CHK       ;  No carry!
	        INC     XAMH
MOD8CHK         LDA     XAML          ;  If address MOD 8 = 0 start new line
	        AND     #$07
	        BPL     NXTPRNT       ;  Always taken.

	* = $FFDC

	.if APPLE1
; Apple 1 I/O values
KBD     =$D010		; Apple 1 Keyboard character read.
KBDRDY  =$D011		; Apple 1 Keyboard data waiting when negative.

OUTHEX	PHA 		; Print 1 hex byte.
	LSR
	LSR 
	LSR
	LSR 
	JSR PRHEX
	PLA 
PRHEX	AND #$0F	; Print 1 hex digit
	ORA #$30
	CMP #$3A
	BCC OUTCH
	ADC #$06
OUTCH	BIT DSP         ;  DA bit (B7) cleared yet?
	BMI OUTCH       ;  No! Wait for display ready
	STA DSP         ;  Output character. Sets DA
	RTS
	.else
IOMEM	=$E000
PUTCH	=IOMEM+1
KBD	=IOMEM+4
KBDRDY  =IOMEM+4

OUTHEX	PHA 		; Print 1 hex byte.
	LSR
	LSR 
	LSR
	LSR 
	JSR PRHEX
	PLA 
PRHEX	AND #$0F	; Print 1 hex digit
	ORA #$30
	CMP #$3A
	BCC OUTCH
	ADC #$06
OUTCH	STA PUTCH
	RTS  
	.endif
	
	.if MINIMONITOR
	* = $FFFA	; INTERRUPT VECTORS
	.word $0F00
	.word RESET
	.word DEBUG
	.endif
	.else
; Apple 1 I/O values
OUTCH	=$FFEF		; Apple 1 Echo
PRHEX	=$FFE5		; Apple 1 Echo
OUTHEX	=$FFDC		; Apple 1 Print Hex Byte Routine
KBD     =$D010		; Apple 1 Keyboard character read.
KBDRDY  =$D011		; Apple 1 Keyboard data waiting when negative.
	.endif	; inrom

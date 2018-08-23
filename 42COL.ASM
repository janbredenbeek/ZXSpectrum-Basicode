; BASICODE-3 v3.1 FOR THE ZX SPECTRUM 48K
; Copyright (C) 1985-2017 by JAN BREDENBEEK, HILVERSUM, THE NETHERLANDS
; RELEASED UNDER GNU v3 PUBLIC LICENSE, 2017

; 42-COLUMN SCREEN DRIVER VERSION 1.6
; Last revision: 24 november 1987

; This code is largely based on the ZX Spectrum ROM, which is copyrighted by Amstrad.
; However, the Spectrum's ROM has been extensively documented in various disassemblies, starting with
; "The Complete Spectrum ROM Disassembly" by Ian Logan and Frank O'Hara (Melbourne House, 1983).
; This disassembly has been the basis of my driver which supports a 42-column screen for use
; with BASICODE programs. Code has been copied and modified for BASICODE compatibility while
; at the same time calls and jumps to the ROM code are used as much as possible to save space.
; This means that the presence of the 48K Spectrum's ROM is essential for proper operation.
; It would of course be very challenging to make the Spectrum ROM itself BASICODE compatible
; so we could save a lot of duplicated code in RAM. On a standalone (possibly emulated)
; 48K Spectrum this might be a viable option, however it would render a lot of hard- and software
; useless since they depend onto a large degree upon fixed addresses in the Spectrum ROM.
; But in these days of emulators where you can switch ROMs with a few clicks, it might be worth a try...

CHARS  EQU    58072           ; character set (needs to be 8-byte aligned!)

       ORG    56790
       JP     INIT            ; initialisation
       JP     SUB200          ; get a key currently depressed
       JP     PAUSE           ; wait for a key
       JP     PRTSTR          ; plot a string in the graphics coordinate system
       
S_POSN DEFW   #182B           ; 24-row number, 43-line number of cursor position
DF_CC  DEFW   #4000           ; address in display file
DF_SZ  DEFB   #00             ; number of rows in lower display window
SCFLAG DEFB   #FF             ; 'scroll?' prompt flag
TEMP_P DEFB   #00             ; Temporary save location for P_FLAG
BL_CT  DEFB   #00             ; counter for blinking cursor
       DEFM   "(C) 1984 J. Bredenbeek 1.6" ; a short message from the author

; Initialise the driver. This creates an extra 'S' channel in the CHANS area
; and makes #2 point to it.
       
INIT   LD     HL,(23635)
       DEC    HL
       LD     BC,11           ; make room for 11 bytes before PROG
       CALL   #1655
       LD     HL,TB_END
       LD     C,11
       LDDR                   ; and initialise the channel block
       LD     HL,(23631)
       EX     DE,HL
       INC    HL
       AND    A
       SBC    HL,DE
       INC    HL              ; form offset from CHANS +1 in HL
       LD     (23578),HL      ; and enter it into channel pointer for #2
       LD     A,#03
       CALL   #1601           ; select #3 (printer channel)
       LD     HL,(23633)
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       EX     DE,HL
       LD     BC,#09F4        ; address of standard output routine
       AND    A
       SBC    HL,BC           ; do we have a custom printer driver?
       JR     NZ,I_END        ; yes, leave it alone
       LD     HL,OUTCHR       ; but if using standard ZX printer, change the
       EX     DE,HL           ; driver's address to ours so it will print
       LD     (HL),D          ; in 42 columns too
       DEC    HL
       LD     (HL),E
I_END  LD     A,#02           ; re-select channel #2
       JP     #1601

       DEFW   OUTCHR          ; our output routine
       DEFW   GETKEY          ; our input routine
       DEFB   "S"             ; 'S'
       DEFW   11              ; output routine for shadow rom (dummy)
       DEFW   11              ; input routine for shadow rom (dummy)
       DEFW   11              ; length of channel definition block
TB_END EQU    $-1

; The output routine enters here
; The A register holds the character to be printed

; First, we have to do some tests to check if a CLS has been done somewhere.
; Since we don't use the ROM's system variables to keep track of our position,
; we have to check this every time a character is to be output :(

OUTCHR PUSH   AF              ; Save character
       LD     A,(23689)       ; Get 24-row number from S_POSN system variable
       CP     24              ; Has it been reset to 24?
       JR     NZ,TST_PR       ; Jump if not
       BIT    1,(IY+1)        ; Printer in use?
       JR     NZ,TST_PR       ; Yes
       LD     BC,#1721        ; Signal 'reset to top left position'
       CALL   #0DD9           ; and call the ROM's CL_SET routine
       LD     BC,#182B        ; Now do the same with our own CL_SET, but since
       CALL   CL_SET          ; we have a 24 x 42 grid the parameters are
                              ; 24 and 43 respectively
TST_PR BIT    1,(IY+48)       ; Is printer buffer clear?
       JR     NZ,NO_SET       ; No, skip
       LD     (IY+69),43      ; Reset P_POSN
NO_SET POP    AF              ; Retrieve character code

; Get current print position: 24-row number in B, 43-column number in C
; and address in display file or ZX printer buffer in HL

       CALL   L0B03           ; Our PO_FETCH routine
       
; Now consider the ASCII code; allowing for BASICODE-specific control codes
       
       CP     #7F             ; DELETE
       JR     Z,DELETE
       CP     #06             ; PRINT comma (21-column TAB)
       JR     Z,COMMA
       CP     #20             ; Printable code?
       JP     NC,L0AD9        ; yes, jump forward
       CP     #0D             ; Line end (ENTER)?
       JP     C,L0A69         ; print codes below 0Dh as question mark
       LD     HL,C1-#0D       ; Table address minus 0Dh
       LD     E,A
       LD     D,#00
       ADD    HL,DE           ; use character code as index
L0A0B  LD     E,(HL)          ; fetch offset
       ADD    HL,DE
       PUSH   HL              ; push address of handler onto stack
       JP     L0B03           ; Make indirect jump via PO_FETCH

; Table for control codes 0D to 1F

C1     DEFB   ENTER-$         ; EOL (ENTER)
       DEFB   L0A69-$         ; 0Eh - prints as question mark
       DEFB   L0A69-$         ; 0Fh - prints as question mark
       DEFB   L0A7A-$         ; 10h - INK control
       DEFB   L0A7A-$         ; 11h - PAPER control
       DEFB   L0A7A-$         ; 12h - FLASH control
       DEFB   L0A7A-$         ; 13h - BRIGHT control
       DEFB   L0A7A-$         ; 14h - INVERSE control
       DEFB   L0A7A-$         ; 15h - OVER control
       DEFB   L0A75-$         ; 16h - AT control
       DEFB   L0A75-$         ; 17h - TAB control
       DEFB   L0A7A-$         ; 18h - set no. of lines (NEW!)
       DEFB   COMMA-$         ; 19h - PRINT comma (why?)
       DEFB   SC_OFF-$        ; 1Ah - "scroll?" prompt off
       DEFB   SC_ON-$         ; 1Bh - "scroll?" prompt on

; The codes 1Ch to 1Fh are BASICODE control codes
; These are returned by the keyboard reading subroutines, but are not meant
; to be used in PRINT statements. However, when someone really tries to PRINT
; them, we'll do the right thing...

       DEFB   P_BACK-$        ; 1Ch - Cursor left
       DEFB   P_RGHT-$        ; 1Dh - Cursor right
       DEFB   P_DOWN-$        ; 1Eh - Cursor down
       DEFB   P_UP-$          ; 1Fh - Cursor up

; DELETE (7FH) - Do backspace, then print a space to rub out, then
; continue into P_BACK for another backspace

DELETE CALL   P_BACK
       LD     A,#20
       CALL   L0B65           ; Print a space to rubout

; Backspace (cursor left)

P_BACK INC    C               ; Go back one position
       LD     A,44
       CP     C               ; Test against limit
       JR     NZ,L0A3A        ; skip if OK
       BIT    1,(IY+1)        ; Using the ZX Printer?
       JR     NZ,L0A38        ; yes, only set column
       INC    B               ; Go up one row
       LD     C,#02           ; Set C to rightmost column
       LD     A,#19           ; Carefully avoid the ROM bug - it tested against
       CP     B               ; the wrong limit (18h)!
       JR     NZ,L0A3A        ; Skip unless we've fallen off the upper edge
       DEC    B               ; 19h goes to 18h - topmost row
L0A38  LD     C,#2B           ; set C to leftmost position
L0A3A  JP     CL_SET          ; Exit, setting print position

; Cursor right

P_RGHT LD     A,(#5C91)       ; Save P_FLAG
       PUSH   AF
       LD     (IY+87),#01     ; Temporarily set 'OVER 1'
       LD     A,#20
       CALL   L0B65           ; Print a space
       POP    AF
       LD     (#5C91),A       ; Restore P_FLAG
       JP     L0ADC           ; Exit via our PO_STORE (again avoiding the ROM bug!)

; Cursor down

P_DOWN DEC    B               ; Down one row
       LD     A,(DF_SZ)       ; The number of lines in OUR (not the ROM's!)
       CP     B               ; lower display
       RET    NC              ; Exit if not acceptable
       JR     E_SET           ; Else, store new position

; Cursor up

P_UP   LD     A,B             ; Get 24-row number
       CP     24              ; Already at the top row?
       RET    Z               ; Yes, exit early
       INC    B               ; Go up one row
       JR     E_SET           ; Store new position and exit

; Print a carriage return

ENTER  BIT    1,(IY+1)        ; ZX Printer being used?
       JP     NZ,#0ECD        ; Yes, jump to ROM handler
       LD     C,43            ; Set to leftmost column
       CALL   SCROLL          ; Scroll if needed, possibly waiting for a key press
       DEC    B               ; Go down one row
E_SET  JP     CL_SET          ; Exit, storing new position

; PRINT comma - essentially a TAB dividing the screen in two columns
; We use 21 as number of columns rather than the ROM's 16 since our screen
; is 42 columns wide!

COMMA  LD     A,C             ; Get 43-current column
       CP     23              ; In which half are we?
       LD     A,21            ; Assume left half
       JR     NC,L0AC3        ; jump if so
       XOR    A               ; Else, clear A and jump forward
       JR     L0AC3

; Come here with unprintable codes - print a question mark instead.

L0A69  LD     A,#3F
       JP     L0AD9

; Set "scroll?" prompt off (PRINT CHR$ 26) or on (PRINT CHR$ 27)
; This just sets the SCFLAG variable and returns

SC_OFF XOR    A               ; prompt off
       LD     (SCFLAG),A
       RET
SC_ON  LD     A,#FF           ; prompt on
       LD     (SCFLAG),A
       RET

; Handle control codes with 1 (e.g. INK, PAPER) or 2 (AT) operand(s)
; These work by temporarily altering the output address of the current channel

;; PO-TV-2
L0A6D  LD     DE,L0A87        ; Next address will be PO-CONT
       LD     (#5C0F),A       ; Store operand in TVDATA-hi
       JR     L0A80

;; PO-2-OPER
L0A75  LD     DE,L0A6D        ; Next address will be PO-TV-2
       JR     L0A7D           ; Skip

;; PO-1-OPER
L0A7A  LD     DE,L0A87        ; Next address will be PO-CONT
L0A7D  LD     (#5C0E),A       ; Store operand in TVDATA-lo
L0A80  LD     HL,(#5C51)      ; Fetch CURCHL
       LD     (HL),E          ; Store new output address
       INC    HL
       LD     (HL),D
       RET

;; PO-CONT
L0A87  LD     DE,OUTCHR       ; Reset address to regular output routine
       CALL   L0A80
       LD     HL,(#5C0E)      ; Get TVDATA - L holds original control code
       LD     D,A             ; Save current character (1st or 2nd operand)
       LD     A,L             ; Get control code
       CP     24              ; Is it our 'set # of rows' code?
       JR     NZ,CONT         ; Skip with other codes

; This is our new 'set number of rows on screen' handler.
; 'PRINT CHR$ 24 + CHR$ N' with N = 1 to 24 sets the number of rows which
; will be displayed until a 'scroll?' prompt occurs.
; By default this is 24 so you'll have the whole screen available but no
; prompt, it just waits for a keypress (unless you've disabled it using
; PRINT CHR$ 26). When N < 23, the 'scroll?' prompt will be displayed as usual
; but the bottom rows will not be available to BASICODE programs.

       INC    D               ; D holds number of rows - test against zero
       DEC    D
       JP     Z,#1E9F         ; If zero, report 'Integer out of range'
       SUB    D               ; A now holds 24 - number of rows wanted
       JR     C,L0AAC         ; ... which should be within range 1 to 24
       LD     (DF_SZ),A       ; now set our (not the ROM's!) DF_SZ variable
       LD     BC,#182B        ; Reset cursor to top left corner
       JP     CL_SET          ; and exit

; Continue with control codes 

CONT   CP     #16             ; Test against the code for 'AT'
       JP     C,#2211         ; Everything below is colour control, jump to ROM
       JR     NZ,L0AC2        ; Skip unless dealing with 'AT'.
       LD     B,H             ; First operand (line #) goes to B
       LD     C,D             ; Second operand (column #) goes to C
       LD     A,41
       SUB    C               ; Calculate 41 - column
       JR     C,L0AAC         ; Error if out of range
       ADD    A,#02
       LD     C,A             ; Now C = 43 - column
       BIT    1,(IY+1)
       JR     NZ,L0ABF        ; Skip if using ZX Printer
       LD     A,#17
       SUB    B               ; Else, perform A = 23 - column
L0AAC  JP     C,#1E9F         ; and check bounds
       INC    A
       LD     B,A             ; Now B = 24 - row
       LD     A,(DF_SZ)
       CP     B               ; Check against upper screen size
       JP     NC,#0C86        ; 'Out of screen' if we'd get into the lower part
L0ABF  JP     CL_SET          ; exit

; Come here with TAB; the PRINT comma handler enters at L0AC3

L0AC2  LD     A,H             ; TAB handler, first operand goes to A
L0AC3  CALL   L0B03           ; PRINT comma enters here, A is either 0 or 21
       ADD    A,C             ; Add operand to (43-current column)
       DEC    A               ; Reduce by 1
TABSUB SUB    42              ; Take this modulo 42
       JR     NC,TABSUB
       ADD    A,42            ; Now A holds number of spaces to be printed
       RET    Z               ; Return if none required
       LD     D,A             ; Else, pass it to D
L0AD0  LD     A,#20
       CALL   #0C3B           ; Print spaces recursively
       DEC    D
       JR     NZ,L0AD0        ; Loop back for all spaces
       RET                    ; Done

; Come here with printable codes (in A)

L0AD9  CALL   L0B24           ; Do the actual printing

; This is our equivalent of the PO-STORE ROM routine.
; Instead of using the ROM's system variables, we store the current position
; (24-row # in B, 43-column # in C, display address in HL) in our own
; variables since their values may be considered as 'out of range' by the ROM.
; This only goes for the screen, for the ZX Printer we use the ROM's variables.

;; PO-STORE
L0ADC  BIT    1,(IY+1)        ; Using ZX Printer?
       JP     NZ,#0AFC        ; Yes, jump to ROM handler
       LD     (S_POSN),BC     ; Store 43-column # and 24-row #
       LD     (DF_CC),HL      ; Store display address
       RET                    ; Done

; The opposite: Get 24-row # in B, 43-column # in C, display address in HL.

;; PO-FETCH
L0B03  BIT    1,(IY+1)        ; ... but only when using the screen
       JP     NZ,#0B1D        ; Jump to ROM handler for ZX Printer
       LD     BC,(S_POSN)     ; Get 43-column # and 24-row # in BC
       LD     HL,(DF_CC)      ; Get display address in HL.
       RET                    ; Done

; This subroutine handles the actual printing of printable characters

;;PO-ANY
L0B24  CP     #80
       JR     C,L0B65         ; Jump with ASCII codes 20h to 7Fh inclusive
       CP     #90
       JR     NC,L0B52        ; Jump with UDG and token codes

; Deal with mosaic codes 80h to 9Fh. We shouldn't really bother about this
; as they are illegal in BASICODE anyway, but we'll do it for completeness...

       LD     B,A             ; Copy code to B
       CALL   L0B38           ; Construct character in MEM area
       CALL   L0B03           ; Fetch position again
       LD     DE,#5C92        ; Point to character pattern in MEM area
       JP     PR_ALL          ; Jump to print it

; This subroutine constructs the mosaic character pattern in the MEM area
; (normally used by the calculator). We do have adapted this for our 6-pixel
; pattern though!

L0B38  LD     HL,#5C92        ; MEM-0
       CALL   L0B3E           ; Construct top half then bottom half

; This performs the actual construction, by shifting the lower 4 bits out
; and setting bits 2-4 and 5-7 accordingly.

L0B3E  RR     B               ; Shift out one bit
       SBC    A,A             ; A now holds all 0s or 1s accordingly
       AND    #1C             ; Keep rightmost 3 bits
       LD     C,A             ; Copy to C
       RR     B               ; Shift out a new bit
       SBC    A,A             ; Set A to 0s or 1s accordingly.
       AND    #E0             ; Keep leftmost 3 bits
       OR     C               ; Include rightmost 3 bits 
       LD     C,#04           ; Now store this as character pattern
L0B4C  LD     (HL),A          ; ... first upper 4 rows then lower 4 rows
       INC    HL
       DEC    C
       JR     NZ,L0B4C
       RET                    ; Done

; Come here with UDGs and tokens

;; PO-T&UDG
L0B52  SUB    #A5             ; First token starts at A5h
       JR     NC,PO_TOK       ; Jump with tokens
       ADD    A,#15           ; Else get A in range 00h to 14h
       PUSH   BC              ; Save BC
       LD     BC,(#5C7B)      ; Get pointer to UDG character set
       JR     L0B6A           ; Go print UDGs

; Handle tokens

PO_TOK CALL   #0C10           ; Just call the ROM to do it
       JR     L0B03           ; Exit but first jump to PO-FETCH

; We've finally come to the point where we have plain ASCII (20h to 7Fh)
; characters to be printed. This is where the magic starts. In order to be
; BASICODE compatible, we must be able to PRINT at least 40 columns per line.
; Since the Spectrum's display is 256 pixels wide, our character font
; should be no wider than 6 pixels, since 256 divided by 6 gives us 42 columns
; (plus 4 useless pixels at the right edge).
; This means we have to design our own character font (I did it using the
; Horizon's tape UDG designer and was more or less inspired by the fonts
; used by Teletext in the early '80s!). This set is pointed to by the CHARS
; symbol. In addition, printing is not as straightforward as it was in the
; ROM's code, since there is no simple byte-to-byte relationship between font
; pattern and the location where it is to be 'impressed'. But we'll cover
; that later. First, let's do some preparation work.

L0B65  PUSH   BC              ; Save BC
       LD     BC,CHARS-256    ; Point to our characters (minus 8*20H offset)
L0B6A  EX     DE,HL           ; Display addres goes to DE
       LD     HL,#5C3B        ; Point to FLAGS
       RES    0,(HL)          ; Assume no space to be printed
       CP     #20
       JR     NZ,L0B76        ; Skip if so
       SET    0,(HL)          ; Else signal 'Space to be printed' for later
L0B76  LD     H,#00
       LD     L,A             ; Copy code (20h-7Fh or UDG 00h-14h) to HL
       ADD    HL,HL
       ADD    HL,HL
       ADD    HL,HL           ; Multiply by 8 for 8 rows
       ADD    HL,BC           ; Add in base address (CHARS-256 or UDG)
       POP    BC              ; Retrieve BC
       EX     DE,HL           ; Pointer to font pattern to DE

; Now check if a newline or scroll will be needed

PR_ALL LD     A,C             ; A holds 43 - current column (0 to 42)
       DEC    A               ; A will be zero when already at the RHS
       LD     A,43            ; Pre-load A with 43
       JR     NZ,PR1          ; Skip if we're not at the RHS
       DEC    B               ; Go down one line
       LD     C,A             ; Set column to LHS
       BIT    1,(IY+1)        ; Using ZX Printer?
       JR     Z,PR1           ; No, skip
       PUSH   DE              ; Save DE while printing the line
       CALL   #0ECD           ; Empty the ZX Printer's buffer
       LD     C,43            ; Reset to LHS
       POP    DE              ; Retrieve DE
       LD     A,C             ; Really needed???
PR1    CP     C               ; At LHS?
       PUSH   DE
       CALL   Z,SCROLL        ; Yes, scroll if needed
       POP    DE
       PUSH   BC              ; Save line and column position
       PUSH   HL              ; Save display address
       PUSH   HL              ; ... twice
       LD     A,43
       SUB    C               ; Calculate in A the column number (0 for LHS)
       AND    #03             ; ... and take this modulo 4

; We now have four possible cases depending on our column MOD 3:
;
; Location in display/printer buffer: -- X  -- - X+1  -
;                   Column MOD 4 = 0: 765432.. ........
;                                  1: ......76 5432....
;                                  2: ....7654 32......
;                                  3: ..765432 ........
;
; The numbers are the bits from our character pattern to be 'impressed' onto 
; the current (and possibly next) byte in the display or printer buffer.
; Since 4 columns make up exactly 3 bytes (6 bits x 4), the pattern repeats
; after 4 columns. We use this property to handle the 4 cases separately so
; we can print as fast as possible, without having to bother about how many
; times we should rotate the font patterns and masks etc. Of course, this 
; wastes a few bytes of space but since we have to do a lot more work than
; the ROM code, which already has the reputation of being slow, speed is
; really an issue here (Compare this to the PRTSTR routine down below!)

       LD     C,A             ; Column MOD 3 to BC
       LD     B,0
       LD     HL,TABLE
       ADD    HL,BC           ; Index into the table
       LD     C,(HL)
       ADD    HL,BC           ; Address of handler to HL
       EX     (SP),HL         ; Put on stack and retrieve display location
       LD     C,(IY+87)       ; Get P_FLAG in C
       LD     A,#08           ; Eight lines to be printed
       BIT    1,(IY+1)        ; Using ZX Printer?
       RET    Z               ; If not, leave carry reset
       SET    1,(IY+48)       ; Signal 'Printer buffer has been used'
       SCF                    ; Set carry to signal using printer
       RET                    ; Make an indirect jump to the handler

; Table holding offsets for handler addresses

TABLE  DEFB   P0-$            ; Column 0, 4, 8, ...
       DEFB   P14-$           ; Column 1, 5, 9, ...
       DEFB   P24-$           ; Column 2, 6, 10, ...
       DEFB   P3-$            ; Column 3, 7, 11, ...

; Column 0, 4, 8, ...

P0     LD     B,#FC           ; Use bits 2 to 7
P03    EX     AF,AF'          ; Save counter and printer flag (carry)
       LD     A,(DE)          ; Get line of font pattern
       CALL   PRLINE          ; Print it
       EX     AF,AF'          ; Retrieve counter and printer flag
       CALL   C,PR6           ; Adjust HL when using the printer
       INC    H               ; Go down one line in display
       INC    E               ; Next font pattern line
       DEC    A               ; Loop for 8 lines
       JR     NZ,P03          
       JR     ATTR            ; All lines done, jump to handle attributes

; Column 1, 5, 9, ... two bytes on display or printer buffer to be considered

P14    EX     AF,AF'          ; Save counter and flag
       LD     A,(DE)          ; Get line of font pattern
       RLCA                   ; Rotate bits into right position
       RLCA
       PUSH   AF              ; Save this
       LD     B,#03
       CALL   PRLINE          ; Now print the two rightmost bits of left byte
       INC    L               ; Go right one location
       POP    AF              ; Retrieve bit pattern
       LD     B,#F0
       CALL   PRLINE          ; Now print four leftmost bits of right byte
       DEC    L               ; Go back to left byte
       EX     AF,AF'          ; Retrieve counter and flag
       CALL   C,PR6           ; Adjust HL when using printer
       INC    H
       INC    E
       DEC    A
       JR     NZ,P14          ; Loop for 8 lines as with P0
       JR     ATTR            ; Jump to handle attributes

; Column 2, 6, 10, ... again two bytes, 4-bit shift

P24    EX     AF,AF'          ; Save counter and flag
       LD     A,(DE)          ; Get line of font pattern
       RLCA                   ; Rotate four times
       RLCA
       RLCA
       RLCA
       PUSH   AF              ; Save pattern
       LD     B,#0F
       CALL   PRLINE          ; Print four rightmost bits of left byte
       INC    L               ; Go right one location
       POP    AF
       LD     B,#C0
       CALL   PRLINE          ; Print two leftmost bits of right byte
       DEC    L               ; Go back left
       EX     AF,AF'          ; Retrieve counter and flags
       CALL   C,PR6           ; Adjust HL when using printer
       INC    H
       INC    E
       DEC    A
       JR     NZ,P24          ; Loop for 8 lines
       JR     ATTR            ; Jump to handle attributes

; Column 3, 7, 11, ... - one byte but 2-bit shift needed

P3     LD     B,#3F           ; Set mask
P34    EX     AF,AF'          ; Save counter and flag
       LD     A,(DE)
       RRCA                   ; Rotate font pattern 2 times right
       RRCA
       CALL   PRLINE          ; Print the line
       EX     AF,AF'          ; Retrieve counter and flags
       CALL   C,PR6           ; Adjust HL when using printer
       INC    H
       INC    E
       DEC    A
       JR     NZ,P34          ; Loop for 8 lines

; Now consider the attribute byte. Unfortunately, as the attributes are on an
; 8x8 pixel matrix, and we use a 6x8 font, our characters will not cover an
; attribute location exactly. In cases (0) and (3) above, one character will
; only partly match the attribute location (either the six leftmost or
; rightmost bits), in cases (1) and (2) it will even overlap two attribute
; locations! This leads to the infamous 'attribute bleeding'.

ATTR   DEC    H               ; Point H to correct location in display area
       CALL   NC,#0BDB        ; Now call the ROM to set the attribute byte
       POP    HL              ; Retrieve original location
       POP    BC              ; and 24-row and 43-column number
       LD     A,43
       SUB    C               ; Get column number in A
       DEC    C               ; Go right one column
       AND    #03             ; Take it MOD 4
       RET    Z               ; In case (0), return with original HL location
       INC    L               ; Go to next buffer location in HL
       CP     #03
       RET    Z               ; In case (3) we are done now
       BIT    1,(IY+1)
       RET    NZ              ; Return also when using the ZX Printer
       PUSH   HL
       CALL   #0BDB           ; Else, set next attribute location too
       POP    HL              
       RET                    ; Done (finally!), exit via PO-STORE

; Print one font pattern line
; On entry, B holds a mask telling which bits of A are to be 'impressed' onto
; (HL) and C holds the flags in P_FLAG.

PRLINE BIT    2,C             ; Test INVERSE flag
       JR     Z,INV0          ; Skip if INVERSE 0
       XOR    B               ; Else, invert relevant bits
INV0   BIT    0,C             ; Test OVER flag
       JR     NZ,OVER1
       XOR    (HL)            ; if OVER 0, this will clear the relevant bits
OVER1  AND    B               ; Mask off the unwanted bits
       XOR    (HL)            ; XOR result with bits already there
       LD     (HL),A          ; Now enter result
       RET                    ; Done

; This routine is called to get the address of the next line in the 
; printer buffer

PR6    EX     AF,AF'          ; Save counter and flag
       LD     A,#20
       ADD    A,L             ; The next line is 32 bytes further
       LD     L,A
       EX     AF,AF'          ; Restore counter and flag
       DEC    H               ; Adjust H so HL will remain in printer buffer
       RET                    ; Done

; The SCROLL routine
; The current line is full and scrolling might be needed. But first, do some
; checks.

SCROLL BIT    1,(IY+1)        ; ZX Printer being used?
       RET    NZ              ; Yes, return immediately
       LD     A,(DF_SZ)       ; Get number of lines in lower screen section
       CP     B               ; Compare against current row position
       JR     NZ,CL_SET       ; No scroll needed, exit via CL_SET
SCR2   DEC    (IY+82)         ; Decrease scroll counter
       JR     NZ,SCR3         ; Scroll unless it has reached zero
       LD     A,#18
       SUB    B               ; Find number of rows in upper screen section
       LD     (23692),A       ; And reset scroll counter
       LD     A,(SCFLAG)      ; Is 'scroll?' prompt enabled?
       AND    A
       JR     Z,SCR3          ; Jump if not
       LD     A,#FD
       CALL   #1601           ; Select stream 'K'
       RES    5,(IY+2)        ; Signal 'do not clear lower screen section'
       LD     A,(DF_SZ)       ; Now compare 'our' DF_SZ against the ROM's one
       CP     (IY+49)         ; ... to see if we can display the message
       JR     C,NO_MSG        ; no, not enough lines...
       SET    5,(IY+2)        ; else, signal 'clear lower screen afterwards'
       XOR    A
       LD     DE,#0CF8        ; The 'scroll?' message
       CALL   #0C0A           ; ... and print it!
NO_MSG LD     HL,#5C3B        ; Point at FLAGS
       SET    3,(HL)          ; Signal 'L' mode
       RES    5,(HL)          ; Clear any previous key stroke
       EXX                    ; Switch regs as we call recursively
       CALL   #15DE           ; Call WAIT_KEY1
       EXX                    ; Switch regs back
       CP     #20             ; Consider key pressed - 'space' means 'break'
       JR     Z,SC_BRK
       CP     #E2             ; ... And so means 'STOP'
       JR     Z,SC_BRK
       OR     #20
       CP     #6E             ; ... And 'n' or 'N'.
SC_BRK JP     Z,#0D00         ; Jump to signal REPORT-D
       LD     A,#02
       CALL   #1601           ; Re-open stream 02 ('S')
SCR3   CALL   #0DFE           ; Perform the actual scrolling
       LD     A,(DF_SZ)       ; Get number of rows in lower screen section
       INC    A
       LD     B,A             ; Add 1 and use this as new row position
       LD     C,43            ; Set column to left edge
       DEC    A               ; Test A against zero
       CALL   NZ,#0CDB        ; if nonzero, reset attributes for bottom line

; The CL_SET routine calculates the address in the display or printer buffer
; based on the line and column in the BC register. Since we have to consider a
; 42-column display, our code is a bit different from the equivalent ROM code.

CL_SET LD     HL,#5B00        ; Start of printer buffer
       BIT    1,(IY+1)        ; Really using ZX Printer?
       JR     NZ,CL_S2        ; Yes, jump forward
CL_S1  PUSH   BC              ; Else, call CL_ADDR in the ROM to get the
       CALL   #0E9B           ; start address in the display file of the
       POP    BC              ; current line
CL_S2  LD     A,43
       SUB    C               ; Get 43-column position in A.
       LD     E,A             ; Copy to E
       ADD    A,A             ; Now A = 2 * (43-column)
       ADD    A,E             ; ... And now 3 * (43-column)
       RRA                    ; Since each column occupies 6 bits, every 4
       AND    A               ; columns occupy exactly 3 bytes - so dividing A
       RRA                    ; by 4 gives us the right byte position
       OR     L               ; within the row - transfer this to L.
       LD     L,A
       JP     L0ADC           ; Exit, storing the new position.

; The 'GOSUB 200' or 'get key currently depressed' routine
; This returns the code of the key currently being depressed in BC.
; It also caters for special BASICODE codes (1CH-1FH, 7FH) and characters like
; [ \ ] { | } ~ which are only available in E-mode on the Spectrum's keyboard.
; Now you can just press Symbol Shift and the corresponding key to get these
; characters. Unlike INKEY$, which returns token codes that would be somewhat
; confusing for BASICODE programs!

SUB200 LD     BC,#0000        ; Pre-load BC with 0 for 'no key depressed'
       LD     HL,#5C3B        ; Point to FLAGS
       SET    3,(HL)          ; Signal 'L mode'
       BIT    5,(HL)          ; Is a key being depressed?
       RET    Z               ; If not, return with BC = 0
       LD     A,(23560)       ; Get key code
       RES    5,(HL)          ; Signal 'got key'
       CALL   K_TEST          ; Test and if necessary convert the code to
       LD     C,A             ; something sensible; copy this to BC
       RET    C               ; Return if the code is acceptable
       LD     C,#00           ; Else, set BC to zero and return.
       RET

; The 'GOSUB 450' routine (wait specified time or until a key is pressed)
; BASIC code: LET SD=(SD*5+USR 56796)/5: LET IN=PEEK 23560
; where SD = time (*100ms) to wait, IN = code of key pressed
; Routine fetches SD*5 (number of 20 ms frames) from the calculator stack
; and pushes back the remaining number of frames. Since it always returns zero
; in BC, SD will be assigned the remaining time (*100ms).
; Returns with code of key pressed in LAST_K (or zero).
       
PAUSE  CALL   #1E99           ; Number of frames from calculator stack to BC
       SET    3,(IY+1)        ; Signal 'L mode'

; Now enter a loop to count down

PAUSE1 HALT                   ; Wait for next frame interrupt
       LD     A,B
       OR     C
       JR     Z,PAUSE2        ; Jump if BC has reached zero
       DEC    BC              ; Else, count down
       BIT    5,(IY+1)        ; Has a key been pressed?
       JR     Z,PAUSE1        ; Loop back as long as there hasn't
PAUSE2 CALL   #2D2B           ; Re-stack remaining time in BC
       LD     A,(23560)       ; Get key code from LAST_K
       LD     BC,#0000        ; Pre-load BC with zero
       LD     (IY-50),C       ; Clear the key code
       BIT    5,(IY+1)        ; Test (again) the flag
       RET    Z               ; Return with BC=0 if no key pressed
       RES    5,(IY+1)        ; Reset the flag
       CALL   K_TEST          ; Test if the key code is acceptable
       LD     C,#00           ; Reset C register to zero
       RET    NC              ; Return if no acceptable key code
       LD     (23560),A       ; Else, store key code in LAST_K
       RET                    ; Finished (note: BC always 0)

; The Input routine for channel #2
; This is used by GOSUB 210 which waits for a key to be pressed.
; A flashing cursor is printed before and unprinted afterwards.

GETKEY LD     A,(23697)       ; Get P_FLAG
       LD     (TEMP_P),A      ; and save it temporarily
       RES    7,(IY+2)        ; Spare bit of TV_FLAG used as cursor flash status
       LD     HL,#5C3B        ; Point to FLAGS
       SET    3,(HL)          ; Signal 'L' mode
       BIT    5,(HL)          ; Has a key been pressed?
       JR     Z,K_WAIT        ; No, jump
K_FETC LD     A,(23560)       ; Fetch key code
       RES    5,(IY+1)        ; Clear flag
       PUSH   AF              ; Save code
       LD     D,0
       LD     E,(IY-1)        ; Load DE with value of PIP
       LD     HL,#00C8        ; The pitch
       CALL   #03B5           ; Now call BEEPER to give audible feedback
       BIT    7,(IY+2)        ; Was the cursor visible?
       RES    7,(IY+2)        ; Clear flag anyway
       JR     Z,RSTOR_P       ; Skip if not
       LD     A,#20           ; Now 'unprint' the cursor
       CALL   OUTCHR
       LD     A,28            ; ..and go back one character
       CALL   OUTCHR
RSTOR_ LD     A,(TEMP_P)      ; Restore P_FLAG
       LD     (23697),A
       POP    AF              ; Retrieve key code

; The following routine checks if the key pressed is acceptable to BASICODE.
; If necessary, control codes are converted to their BASICODE counterparts.
; The carry flag is returned set if the code is acceptable (either BASICODE
; control codes 0Dh, 1CH to 1FH or ASCII codes 20H-7EH.
; The routine also replaces the token codes on the keys Y, U, A, S, D, F and G
; which are obtained in conjunction with Symbol Shift with their corresponding
; ASCII characters [ ] ~ | \ { }, avoiding the need to use E-mode.

K_TEST LD     C,A             ; Copy the code from A to C
       LD     HL,K_TAB        ; Base of substitution table
       CALL   #16DC           ; Call the INDEXER routine to look up the code
       LD     A,(HL)          ; Fetch any substitution code
       RET    C               ; Return this code if found in the table
       LD     A,C             ; Else, restore code to A
       CP     #20             ; Is it a 'printable' ASCII code?
       CCF                    ; This inverts the carry flag
       RET    C               ; Return carry flag set if printable ASCII code
       CP     #06             ; Test against code for CAPS LOCK
       JR     NZ,NO_KEY       ; Skip if not CAPS LOCK
       LD     A,(23658)       ; Else, invert bit 3 of FLAGS2
       XOR    #08
       LD     (23658),A
NO_KEY CP     A               ; No acceptable code found, return zero flag set
       RET                    ; and carry reset

; The following table contains entries in the form
; first byte: original code, second byte: substitution code

K_TAB  DEFB   #08,28          ; Cursor left
       DEFB   #09,29          ; Cursor right
       DEFB   #0A,30          ; Cursor down
       DEFB   #0B,31          ; Cursor up
       DEFB   #0C,#7F         ; Delete
       DEFB   #0D,#0D         ; ENTER
       DEFB   #AC,"?"         ; AT - replaced by '?'
       DEFB   #C3,"|"         ; NOT - replaced by '|'
       DEFB   #C5,"]"         ; OR - replaced by ']'
       DEFB   #C6,"["         ; AND - replaced by '['
       DEFB   #C7,"?"         ; '<=' - replaced by '?'
       DEFB   #C8,"?"         ; '>=' - replaced by '?'
       DEFB   #C9,"?"         ; '<>' - replaced by '?'
       DEFB   #CB,"}"         ; THEN - replaced by '}'
       DEFB   #CC,"{"         ; TO - replaced by '{'
       DEFB   #CD,"\"         ; STEP - replaced by '\'
       DEFB   #E2,"~"         ; STOP - replaced by '~'
       DEFB   #00             ; End marker

; wait for key input, flashing cursor in #2       
       
K_WAIT LD     HL,23697
       LD     A,(HL)
       LD     (TEMP_P),A
       SET    2,(HL)
       SET    0,(HL)
K_CURS LD     A,13
       LD     (BL_CT),A
       LD     A,#20
       CALL   OUTCHR
       LD     A,28
       CALL   OUTCHR
       LD     A,(23612)
       XOR    #80
       LD     (23612),A
K_HALT HALT
       BIT    5,(IY+1)
       JP     NZ,K_FETCH
       LD     A,(BL_CT)
       DEC    A
       LD     (BL_CT),A
       JR     NZ,K_HALT
       JR     K_CURS
       
; Plot a string in the graphics coordinate system
; Called by GOSUB 650
; String to be plotted must be on the calculator stack       
       
PRTSTR LD     A,#07
       CP     (IY+68)
       JR     C,PLOTSTR
       LD     (23678),A       ; do not plot off the bottom of the screen!
PLOTST CALL   #2BF1           ; STK-FETCH
       CALL   #2AB6           ; STK-STORE to balance the stack
STR_LP LD     A,B
       OR     C
       RET    Z               ; finished with string (but see note at the end!)
       PUSH   BC
       PUSH   DE
       LD     A,(DE)          ; get next char
       LD     L,A
       LD     H,0
       ADD    HL,HL
       ADD    HL,HL
       ADD    HL,HL
       LD     DE,CHARS-256
       ADD    HL,DE           ; point to first byte in character set
       EX     DE,HL
       LD     BC,(23677)      ; COORDS
       LD     A,C
       ADD    A,6
       LD     (23677),A       ; advance by 6 pixels (NOTE: no overflow check)
       LD     A,#BF           ; our graphic screen has 191 lines not 175.
       SUB    B
       CALL   #22B0           ; get start address in display file
       INC    A
       LD     C,A             ; pixel position of upper left + 1
       LD     B,#FF           ; assume all '1' pixels in char should be set
       BIT    3,(IY+87)       ; this is the permanent 'INVERSE 1' flag
       JR     Z,PR_ROW
       INC    B               ; if set, pixels on screen should be cleared
       
; loop for each line       
       
PR_ROW PUSH   BC
       PUSH   DE
       LD     A,(DE)          ; get pixel mask from character
       LD     D,A
       LD     E,#00           ; DE now holds pixel mask in MSB
SH_LOO DEC    C               ; C initially holds horizontal pixel position
       JR     Z,DO_PR         ; within the byte
       SRL    D               ; shift pixel mask in DE rightwards C times
       RR     E
       JR     SH_LOOP
       
; We now have B set according to INVERSE status (0 for INVERSE 1; $FF for INVERSE 0)
; and DE holding the mask corresponding to the character's bit pattern for this line
; The bits in B (0 or 1) are now 'impressed' onto the location in the display file
; (2 bytes since the 6-bit character pattern may overlap)
       
DO_PR  LD     A,B             ; get INVERSE mask (0 means INVERSE 1)
       XOR    (HL)
       AND    D               ; set or clear bits according to character pattern
       XOR    (HL)
       LD     (HL),A
       INC    L               ; and do so for next location
       LD     A,B
       XOR    (HL)
       AND    E
       XOR    (HL)
       LD     (HL),A
       DEC    L               ; go back to original location
       INC    H               ; go down one line (=256 bytes further)
       LD     A,H
       AND    #07             ; but first test if we're on a row boundary
       JR     NZ,PG_NXT       ; (multiple of 8 lines)
       LD     A,L
       ADD    A,#20           ; if so, the next line is 32 bytes further
       LD     L,A
       JR     C,PG_NXT        ; carry set if we've reached a new third in DFILE
       LD     A,H
       SUB    #08             ; else, adjust H so we remain in the same third
       LD     H,A
PG_NXT POP    DE              ; restore character set pointer
       POP    BC              ; restore INVERSE flag and pixel position
       INC    E               ; next byte in character set
       LD     A,E
       AND    #07             ; loop for 8 lines
       JR     NZ,PR_ROW       ; NOTE: CHARS should be on an 8-byte boundary!
       POP    DE              ; restore string pointer
       POP    BC              ; and length
       INC    DE              ; get next character from string
       DEC    BC
       JR     STR_LP

; NOTE: This routine fails to set the attribute location. This isn't a problem
; in BASICODE-3 (which has no colour support) but it is in BASICODE-3C.
; The cure seems to be to call the PO-ATTR routine in the ROM at location $0BDB
; for each character. This will set the attribute byte according to the values
; of ATTR-T and MASK-T. However, since this routine is supposed to plot a
; string anywhere in the graphics coordinate system, chances are big that the
; string to be plotted will overlap two adjacent attribute rows.
; One question which needs to be solved: should we set only one attribute row
; (and which one?) or go for two rows? In both cases the result may not look
; quite as we want it to...
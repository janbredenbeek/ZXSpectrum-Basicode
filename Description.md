BASICODE-3 FOR THE ZX SPECTRUM v4.0
COPYRIGHT (C) 1986, 1987, 2017 BY JAN BREDENBEEK
RELEASED UNDER GNU PUBLIC LICENSE v3, 2017
################################################

TECHNICAL DESCRIPTION
=====================

This BASICODE-3 implementation for the ZX Spectrum consists of the following parts:

- BASIC program of about 2.5K containing the standard BASICODE subroutines and a few support routines;
- Machinecode of 11.5K containing read/write and conversion routines, a 42-column text screen driver, and a Basicode interpreter EXTension (BEXT).

The machinecode part consists of 7 sections:

=======                             =================
SECTION                             ADDRESS (decimal)
=======                             =================
Conversion & Tape routines          53950
42-Column text screen driver        56790
42-Column character set             58072
Functions for BASICode EXTension    58840
BASICode EXTension                  59450
Interrupt vector table              65024-65280 ($FE00-$FF00) all locations hold $FD
EOF status table                    65281-65344 ($FF01-$FF40) all locations hold $00

The original source was assembled using Hisoft Devpac v3 and was hardly
commented because of tight memory constraints. The aim of this project is to
document the code as much as possible. Each part will be discussed in detail below.

CONVERSION & TAPE ROUTINES
==========================
This section contains the code for the menu (accessed by entering '*' from 
BASIC), the routines to convert BASICODE to Spectrum BASIC vice versa and the
tape routines. The latter routines are used for reading and writing the
BASICODE program in ASCII-form from and to the tape using audible signals,
as well as handling tape file I/O in BASICODE (the subroutines 500-580).
This section contains 3 hooks in a jump table at the beginning, which are 
called from the file handling standard subroutines.
One notable location here is the BCPROG variable which holds the start address
of the BASICODE-program as stored in ASCII form. This may be useful for LOADing
and SAVing BASICODE programs as ASCII files instead of cassette tape. In the
current build this variable is at location 55791, but it may be useful to move
it to a more static location (e.g. the end of the Spectrum's RAM area).
The BASICODE program in ASCII-form is held in RAM about 100 bytes above STKEND,
which is in the Spectrum's free memory area. As this is not a reserved area and
likely to fill up, it should stay there only temporarily and be converted or 
SAVEd as soon as possible.

42-COLUMN TEXT SCREEN DRIVER
============================
BASICODE was designed with a screen width of at least 40 columns in mind, and 
although there are facilities to allow programs to adapt their output to 
different screen sizes, the Spectrum's native 32-column text screen proves
inadequate for most BASICODE applications. For this reason, a driver has been
written which allows for narrower characters using a 6 x 8 pixel pattern, 
enabling a text screen size of 24 lines of 42 columns. The number of lines is 
also configurable by PRINTing CHR$(24)+CHR$(N) where N can be up to 24 
(when N is >22, the 'scroll?' prompt will be suppressed but the output will
still wait for a key to be pressed).
The character set for this driver is stored at location 58072; like the
Spectrum's original character set there are 96 characters each occupying 8
bytes, but in this case only the 6 most significant bits of each row are used.
Please note that this driver ONLY attaches itself to channel #2 (screen) and
#3 (ZX Printer); the 'automatic' BASIC listings when editing programs are still
handled by the 32-column Spectrum driver.
This driver also includes routines which handle keyboard input and plotting of
strings in the graphics coordinate system.

FUNCTIONS FOR BASICODE EXTENSION
================================
This section contains code for a number of BASIC functions, which are either
called directly by user-defined FN functions or indirectly by the extended
BASIC interpreter using hooks at the start of the code.
The functions are LEFT$, MID$, RIGHT$, SHIFT$, and EOF (called as
user-defined FN functions either by the application program or BASICODE sub-
routines), and VAL and SCREEN$ (called from the BASIC interpreter).

Basicode EXTension
==================
The largest section, and this is what it's all about :-)
The BASICode EXTension (BEXT) transforms your Spectrum's BASIC into a 
BASICODE-compatible BASIC. Forget about all the limitations of Sinclair's
original BASIC such as single-letter names for strings, arrays and FOR-NEXT
variables, static-length strings in string arrays, line numbers that don't go
above 9999 and so on, that hampered the Spectrum's ability to run BASICODE.
BEXT removes this incompatibilities, this freeing you from the cumbersome task
of adapting programs manually. Large parts of the Spectrum's BASIC have been 
rewritten to comply with BASICODE and in the process some operations (notably
string handling) have been speeded up and memory usage of the BASIC program
reduced by leaving off the hidden binary numbers. The latter means that
programs containing many numeric DATA statements will now fit into memory at 
only a minor speed penalty.
Rewriting the Spectrum's BASIC in this way has of course major consequences for
the way programs and variables are stored. A program run by BEXT cannot be run
by the Spectrum's original BASIC and is highly likely to produce error messages
at best and crashes at worst. Thus, we must prevent by all means that a jump
into a location somewhere in the Spectrum's ROM disables our BEXT interpreter.
This is probably the most difficult part, as there are many add-ons for the
Spectrum (notably storage systems) which interact with the Spectrum ROM one way
or another in order to provide their own 'enhanced' BASIC commands. BEXT 
contains provisions to avoid being disabled by other 'extensions' or the 
Spectrum's BASIC itself (the Spectrum's editor is a notorious example), and to 
allow extensions such as the Microdrive/Interface 1 to work with BEXT. 
Sometimes this leads to awkward syntax constructs such as 
SAVE *"m";FN o()+1;FN o$()+NF$, but as these extensions are expected to be used
mostly within the BASICODE standard subroutines this is IMHO not a great problem.

Program and Variables Storage
=============================
The Spectrum's original BASIC is very efficient when it comes to memory usage,
which is a legacy from the ZX81 which in its original form had only 1K RAM to
play with. Variables are stored starting with a single byte indicating its type 
(in the upper 3 bits) and first letter (in the lower 5 bits). There are six
possible types:

====                =====
Type				Value
====                =====
Numeric, 1 letter	011xxxxx
Numeric, >1 letter	101xxxxx
FOR-NEXT			111xxxxx
String				010xxxxx
Numeric array		100xxxxx
String array		110xxxxx
==================  ========

Notice that either bit 6 or 7 are 1, they cannot both be 0. This is because
the ROM uses a single routine to search for BASIC program lines and variables
(the 'NEXT-ONE' routine), and since line numbers are stored MSB first and are
limited to 9999 they always have bits 6 and 7 both 0, so the routine knows how
to distinguish them from variables! 
Simple numeric variables can have more letters (up to 255!) but other types 
such as strings, arrays and FOR-NEXT variables are restricted to one letter 
only. Compare this to BASICODE, where all variables can have names up to two
characters (but not more!) and line numbers up to 32767! So we need a new
format to store our variables. The following concept has been adopted:

- Variable names (including string, array and FOR-NEXT) can have any number of characters (up to 255) and all characters are significant.

- String variables (either single or element of a string array) are stored as pointers in the VARS area. The strings itself are stored in a special 'string space', located between the GOSUB stack and RAMTOP. This space is of fixed length, defined by an extended CLEAR command. The CLEAR command now takes a second parameter which defines the size of the string space, e.g. CLEAR 53999,100 sets RAMTOP at 53999 and defines a string space of 100 bytes. Either parameter may be omitted in which case RAMTOP is left unchanged and/or a string space of 100 is assumed. As this space eventually fills up, a 'garbage collect' routine is called which reclaims unused space and resets the variable pointers. If, after this, there is still insufficient space for a new string to be entered then the extended error 'S Out of string space' is thrown. Note that literal strings in a program are not stored again in this space but referenced by a pointer, relative to the PROG base.

- All strings in a string array have dynamic length. No more extra 'length' DIMension needed, no Procrustean padding or truncating of strings.

- Array subscripts start at zero. A statement DIM A(10) defines an array with 11 elements, numbered A(0) to A(10).

- DEF FN functions can have more letters too, and are stored as variables. Space is reserved for the formal parameters as a local VARS area and followed by a pointer to the function's definition, relative to the PROG base. As a consequence, the DEF FN statement has to be *executed* before the function can be used in a program (which is different from Spectrum BASIC but conform BASICODE specification). Note that the DEF FN command was 'legalised' only in the second edition of BASICODE-3 (1988) and has been used by very few (if any) application programs. 

- This BASICODE implementation also uses DEF FN to define the string slicing functions LEFT$, MID$ and RIGHT$ since it does not support the Sinclair way of string slicing. The 'FN' keyword is automatically prepended to any occurrence of these functions when reading BASICODE, and removed when writing BASICODE. A user-defined function FN EOF is also used to return the end-of-file status in the file handling subroutines 500-580. The functions FN o() and FN o$() are used in standard subroutines to prevent the BEXT interpreter from being disabled when executing BASIC commands from hardware extensions such as the Sinclair Interface 1 and other storage systems (see notes at the beginning of this section).

- Line numbers now run from 1 to 32767 inclusive.

- When using a variable which has not been assigned a value yet (or an array which hasn't been DIM'd), a value of zero or the empty string is returned. While this is considered bad programming practice and officially against the BASICODE protocol, there are many published BASICODE programs which contain this error. Since it is expected that this BASICODE implementation will be mainly used to run existing BASICODE programs, I have decided to allow this behaviour and not throw a 'Variable not found' error during execution.

- A FOR-NEXT variable is not treated as a special variable (unlike in Spectrum BASIC) and not restricted to one letter. Instead, the extra information needed in a FOR-NEXT loop (such as limit, step, and location of loop start) is stored on the GOSUB stack using a special marker to distinguish it from a GOSUB entry. As a consequence, the NEXT statement may be used without a variable (which is officially not allowed in BASICODE!), which terminates the innermost FOR-loop. Note that it is still possible to RETURN from an incomplete FOR-NEXT loop as the interpreter will clean up the stack, but in general this is considered bad programming practice!

- ON..GOTO and ON..GOSUB, which are not supported by Spectrum BASIC, are implemented using a special syntax: GOTO/GOSUB *<expression>;<line1>,<line2>,<line3> etc. The expression is evaluated and the GOTO/GOSUB target chosen according to its index value (line1 for 1, line2 for 2 etc). If the value does not fit in the list of line numbers then execution simply continues at the next statement. Note that, although BEXT still supports calculated GOTOs and GOSUBs like Spectrum BASIC, these are illegal in BASICODE; only literal line numbers are allowed as target of GOTO and GOSUB.

So, using these concepts, the variables are stored as follows:

First byte:
  bits 0-4 first letter of name (01h-1Ah)
  bit 5: 1 for ordinary numeric or string variable, 0 for arrays & FNs
  bit 6: 1 for numeric type (simple/array/FN), 0 for string type
  bit 7: 1 means a DEFFN function

Second, third and so on byte: subsequent characters of name (lowercase).

All names are terminated by a null byte, and all characters are significant.

For arrays and FNs, the next two bytes define the length of following block.

All simple variables and array elements have 5 bytes. For strings these are
as follows:
Byte 0: 0 means absolute address, <>0 means relative address (to PROG)
Byte 1-2: pointer to string (absolute or relative, see byte 0)
Byte 3-4: length of string

DEFFN functions:
+------+---+--------+--------+------+-----+--------+--------+
| name | 0 | len-lo | len-hi | args | 80h | ptr-lo | ptr-hi |
+------+---+--------+--------+------+-----+--------+--------+
args is a local variable storage (terminated by 80h)
ptr is pointer to the function definition, relative to PROG

As with the Spectrum's BASIC, a 80h byte marks the end of the VARS area.

Numbers in a BASIC program
==========================
When you enter any number in a BASIC line, the Spectrum stores it twice. For
example, when entering 'GO SUB 100', the '100' is first stored in plain ASCII 
and then in binary form, using a marker byte (Hex 0E) which is invisible in 
program listings. 
While this is a good thing in terms of speed, it will increase the program size
considerably when it contains a lot of numbers. For instance, a line containing:

DATA 1,2,3,4,5,6,7,8

would take 64 bytes in Spectrum BASIC, a 4-fold increase from the original!
This is the reason why a BASIC line in the Spectrum's memory can actually take
MORE bytes than the original ASCII line in BASICODE, despite the fact that 
keywords are being tokenised. It can also mean that you might run out of memory
when translating a BASICODE program to Spectrum BASIC, even if the original
untokenised program does fit!
For this reason, Basicode EXTension does NOT insert the binary representation
of numbers in a program. This of course has a speed penalty, but in most cases
this will be small as most numbers in a program are small integers which are
converted to binary rapidly by an efficient algorithm.
Unfortunately this also means that the Spectrum ROM cannot parse a BASIC line
written using BEXT, and when it still has to do this (e.g. when loading the
BEXT machinecode or using 'extended commands' from a storage system) you have
to use either FN o()/FN o$() (see above) or use the more traditional methods
to avoid literal numbers (e.g. VAL "number", NOT PI for 0, SGN PI for 1, etc.).


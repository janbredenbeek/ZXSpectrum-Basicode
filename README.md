# ZXSpectrum-Basicode
BASICODE-3 for the ZX Spectrum computer

This project documents my implementation of BASICODE-3 for the ZX Spectrum computer, written in 1986-1987.
For an explanation of BASICODE, please read https://github.com/janbredenbeek/basicode.

The source code is divided into six parts:

- BASICODE standard subroutines and support subroutines (BASIC)
- Read/Write/translate routines
- 42 column screen routines
- Extra BASIC functions
- BEXT Extended Basic interpreter part 1
- BEXT Extended Basic interpreter part 2

Unless otherwise stated, all parts are written in Z80 Assembly. The original code was written for the Hisoft Devpac assembler and, because of tight memory constraints, hardly documented. No use has been made of macros and very little use of special assembler directives so it should not be too difficult to port this to another platform.

For a more technical description, please read the [Description.rst](https://github.com/janbredenbeek/ZXSpectrum-Basicode/blob/master/Description.rst) file.

I don't own a ZX Spectrum anymore but have successfully tested the program on various emulators such as Spectaculator, Fuse and EightyOne, despite the huge dependency on the original ZX Spectrum ROM and accurate CPU timing. As for the latter, Spectaculator is my preferred choice. It can also read in BASICODE programs saved as 8-bit .WAV files at high speed. You must set it to emulate the 48K Spectrum though as the program does not currently work in 128K mode.

## Instructions for use

### Loading BASICODE programs from tape (*L)
If you have recorded BASICODE programs on tape and use an emulator, you can convert the tape signals to a suitable .WAV file using various available utilities. The .WAV file should be readable by the emulator (programs saved using the Spectrum's native format should be LOADable). Usually, 8-bit mono format will do. The sample frequency doesn't have to be as high as 44100 Hz, a sample rate of 16000 Hz should be more than enough.

You should LOAD the translator program first using LOAD "" from tape or a snapshot. Once loaded, you can enter its menu at any time from BASIC by typing an asterisk '\*' followed by ENTER. A menu option may be invoked by pressing the relevant key in the menu or just entering an asterisk + letter from BASIC. So entering '\*L' from BASIC has the same effect as pressing 'L' in the menu and will cause the Spectrum to look for a BASICODE signal on the tape. You should of course have positioned the tape (or the virtual cassette recorder in the emulator) at the beginning of the recorded BASICODE program first. A recorded BASICODE program uses different frequencies than the Spectrum's native cassette format (it will sound higher pitched, with a 5-second high-pitch tone at the beginning and the end). When found, the Spectrum's screen border will show the familiar stripe pattern during loading and you will see the program text being displayed at the bottom row of the screen (usually too fast to be readable!).\
When the whole BASICODE program has been loaded, you will either be returned to the menu or the Spectrum will display an error message when something went wrong. In the latter case, you may still be able to translate the program but it may contain errors. It is recommended to use the LIST menu option to view the loaded program before translating it (see below).

### Loading BASICODE programs from an ASCII file
Many BASICODE programs published over the years are now available as ASCII files in the BASICODE repository. Using an emulator, these files may be imported into the BASICODE translator program by loading them into the Spectrum's memory as binary data files. To successfully do this, the following conditions must be observed:

- Lines in the ASCII program must be terminated with a CR character (the translator program currently doesn't process LF or CR+LF correctly). In addition, the file should start with a STX character (with bit 7 set, so Hex 82 or CHR$ 130) and end with an ETX character (also bit 7 set, so Hex 83 or CHR$ 131). These markers define the begin and end of the program. If the file doesn't contain these characters, you may POKE them into memory afterwards.

- The file must be loaded into the Spectrum's free memory area, starting at a location at least 100 bytes above STKEND, and must not extend into the memory reserved for the translator program, which is above location 53950 (you should leave at least 100 bytes free below this as the machine stack resides here). Any existing program above line 1000 must have been deleted first (invoking the \*L menu option followed by BREAK will do this). In practice, the size of the raw BASICODE program must be no greater than about 27K bytes on the standard 48K Spectrum.

- The start address of the file must be POKEd into the locations 55791 (low byte) and 55792 (high byte). If you enter a BASICODE load command (\*L) first and then BREAK out of the loader, the locations will already have been set correctly and entering 'PRINT PEEK 55791+256\*PEEK 55792' will display the start address to be used. At this location, there should be a STX (CHR$ 130) character. If the file doesn't contain this character, you should load it at one location higher and POKE 130 into the start address.
**Note**: The locations 55791 and 55792 are valid for version 4.0. For version 3.1, the locations to POKE will be 55773 and 55774 respectively, and for version 1.0 56405 and 56406.

- It is very important that the ETX marker (Hex 83, CHR$ 131) is present at the end of the program in memory. Failure to do so will result in rubbish being imported after the program when translating to BASIC!

If your BASICODE file doesn't have the proper line termination and/or STX/ETX characters, you can use a good text editor such as Notepad++ to reformat it. For example, to change the line termination from CR+LF to CR, choose in the Edit menu the option EOL Conversion -> CR (Macintosh). STX and ETX characters may be added to the beginning and end of the file by typing ALT-0130 and ALT-0131 respectively (hold down ALT while typing the digits). Be sure to change the Encoding menu option from UTF-8 to ANSI or you'll end up with the wrong codes!

As an example, you must take the following steps to import a BASICODE program from an ASCII text file into the Spectrum:

1. Enter '\*L', then use BREAK to exit from the loader. This will delete any existing program above line 1000.

2. Enter the command **PRINT PEEK 55791+256\*PEEK 55792** (for v4.0, other versions see note above). Note the address, it will usually be around 26000 to 27000.

3. Use the 'load binary file into memory' feature of your emulator to load the BASICODE program at the start address. On Spectaculator, you should choose File -> Open, then select the option 'Z80 Machine code (.raw,.bin) in the drop-down box right to the file name (You probably have to rename the file to something ending in .raw or .bin first. Do **NOT** check the box 'Execute after import'!).\
On Fuse, you can use the menu option File -> Load binary data. Enter the start address in the dialog box following.\
**IMPORTANT**: If your ASCII file does *not* start with a STX (CHR$ 130) character, then you should load the file at an address 1 higher than the start address mentioned and POKE 130 into the byte at the start address (Example: if you get '27000' from step 2 then load the file at address 27001 and enter POKE 27000,130 afterwards).

4. If the file you've loaded into memory ends with an ETX character (Hex 83 or CHR$ 131), you may continue to the next chapter. If not, you have to work out where it ends in memory. You need the *exact* length, not just the simplified '12KB' or so that Windows Explorer tells you (if it does at all). Right-click and look at 'Properties' which tells you the exact length. If you use Fuse, you don't have to go to this hassle since it will tell you the length of the file after you selected it in the 'Load binary data' dialog.\
Now add the length of the file to the address where you just loaded it. E.g. when you've loaded it at 27001 (allowing for POKE 27000,130 above) and the file is 12350 bytes, then you should enter **POKE 27001+12350,131** (yes, I'm too lazy to work out the address by hand!).\

### LISTing the BASICODE program (*K, *P)
Using the \*K menu option, you may inspect the BASICODE program loaded into memory. Version 4 and later also allow you to send the listing to the printer channel using the \*P option (for this, you need to have OPENed stream #3 to a suitable device beforehand). If this option does nothing, you probably have made a mistake in the previous chapter's procedure (the location pointed to by PEEK 55791+256\*PEEK 55792 must contain a STX (CHR$ 130) character for this to work). If you see rubbish displayed after the program, it isn't properly terminated by an ETX (CHR$ 131) character (see previous chapter to correct this).\
You may abort the listing in the usual way by pressing SPACE or N after each page displayed.

### Translating the BASICODE program to Spectrum BASIC (*T)
If your loaded BASICODE program looks well, you can now translate it to Spectrum BASIC using the \*T option. You will see the program listed as the translation progresses. Keywords will be tokenised and some conversions done (like inserting LET or GOTO where Spectrum BASIC needs it). On completion, you can SAVE it using the \*S option or simply RUN it (see next chapter).

### RUNning a BASICODE program
You may have noticed that the BASICODE program you've just translated probably contains a lot of things that standard ZX BASIC considers 'illegal', such as string names like IN$, array names like CC(1), and line numbers above 9999 (up to 32767). Nevertheless, most of these programs will run without error on your Spectrum. The 'magic' that makes this possible is a BASIC extension of about 6.5K that has taken control of your Spectrum. Also, the screen display has been extended from 32 to 42 columns by installing a driver that uses narrower characters, since most BASICODE programs expect a screen size of at least 24 rows and 40 columns. Together with the routines needed for loading and saving BASICODE, this will use about 11.5K of memory above address 53950. This machine code needs to be present at any time when RUNning a BASICODE program. Earlier attempts to adapt BASICODE to the Spectrum, without using these machinecode hacks, usually required a lot of more or less manual changes to the BASICODE programs by renumbering lines, changing variable names to single-letter ones, modifying array subscripts, and even then the result wasn't always satisfactory (specially when using string arrays). So in the end, I decided not to adapt BASICODE to ZX BASIC but to adapt ZX BASIC to BASICODE!

Some of the concepts of BASICODE (or rather M\*\*\*\*S\*\*\* BASIC) could not be implemented without having to resort to some hacks. These are LEFT$, MID$, RIGHT$ and ON..GOTO/GOSUB. The first three, which do string slicing, are implemented as user-defined functions FN LEFT$, FN MID$ and FN RIGHT$ (they are handled by machinecode calls, though). You can no longer slice a string by specifying something like A$(3 TO 4), since strings in string arrays now have dynamic length (so DIM A$(10) now gives you 11 dynamic-length strings A$(0) to A$(10), not a static-length string of 10 characters as in ZX BASIC).

ON x GOTO/GOSUB n1,n2,.. is rewritten as GOTO/GOSUB \*x;n1,n2,.. Like the string functions above, conversion from and to BASICODE is done automatically by the translation routines.

CLEAR needs an extra parameter which specifies the number of bytes reserved for strings. The new syntax is CLEAR r,s where r is the new RAMTOP (0 or omit to leave it alone) and s the size of the string space. This is required to be set by the BASICODE program in line 1000 (the variable A). Default is 100 bytes. If specified too small, an error 'S Out of string space' may result.

The file I/O subroutines at line 500 to 590 and 950 to 980 use some awkward syntax to make Microdrives and other storage systems work with the new BASIC extension. In the extended commands, literal numbers must be prepended by 'FN o()+' and strings by 'FN o$()+'. The FN calls ensure that expressions will be correctly evaluated by the extended commands.

Unlike ZX BASIC, this extended interpreter does NOT check the syntax of a BASIC line on entry. You will usually get a 'Nonsense in BASIC' report when there is a syntax error. I do not consider this a great loss since its main use is to run BASICODE programs which have already been written. If you do get 'Nonsense in BASIC' when running a BASICODE program, check the corresponding line for errors (mostly caused by improper use of separators in PRINT statements, e.g. PRINT "The value of A is"A ) and manually correct it.

The BASICODE extension stores variables in a different way than ZX BASIC. As a consequence, variables are not saved along with the program and you cannot save them using SAVE..DATA. BASICODE-3 has provisions for storing data using the subroutines 500 to 580, which can be used for storing and retrieving data in a sequential way, using BASICODE tape format or microdrive/floppy emulation (depending on the value of NF, for NF>=2 the subroutines work as-is on a Interface-1 compatible storage system).

If you make any changes to the BASIC program, all variables will be cleared.

### Converting a BASIC program to BASICODE (*C)
This does the opposite of the \*T command. A BASICODE-compliant program is converted from the Spectrum to BASICODE. 

You must observe the rules laid out in the BASICODE-3 protocol. Only the keywords and functions which are legal to BASICODE will be accepted, else the conversion will stop with an error message. Some additional requirements:

- The first line of your program must be 1000 and contain 'LET A=X: GOTO 20: REM "program name"'. X must be a literal number, representing the number of bytes reserved for strings. If you set this too low, an 'S Out of string space' error may occur or your program will run slower because BASIC needs to clean up the string space too often. For small programs, 100 may be sufficient, for larger programs a value of 250 to 1000 may be needed (a too large value may result in 'Out of memory').

- Variable names must not exceed two characters (one letter followed by a digit or second letter), even though this extended BASIC allows more. Some variable names are reseved and may not be used in programs, notably those who start with the letter O (see BASICODE reference for more info).

- Strings are limited to a maximum of 255 characters, even though the Spectrum allows more.

- GOTO and GOSUB must have literal numbers. A construct like A=1000:GOTO A is not allowed; in that case use ON..GOTO/GOSUB (written as GOTO/GOSUB \*A;line1,line2,..).

- Function arguments MUST be in brackets, even if not required by the Spectrum. So SIN (X) and TAB (10) are legal, SIN X and TAB 10 are not.

- BASIC lines generated by the conversion may not be longer than 60 characters. A warning message is given if a line is found to be too long.

Once you have successfully converted the program, it may be viewed using the \*K command and sent to a printer or another device using the \*P command. It may be written to a (virtual) tape device using the \*W command (see below).

**CAUTION**: Be sure to SAVE the program first before using this command. If there is no room for both the original and translated BASICODE program, the translation process will first delete the already translated part of the original program, and display the message 'BASIC PROGRAM OVERWRITTEN' (it is then still available in translated form). If, after this operation, there is still not enough memory left, an 'Out of memory' error is thrown and you will have lost everything!

### Writing a program in BASICODE to tape or .WAV file (*W)
This will be self-explanatory when you have a real Spectrum and a tape recorder. However, when using an emulator, you will be used to 'virtual' tape recorders and .TAP or .TZX files.

BASICODE uses different signals from the standard Spectrum format, and so cannot be recorded on .TAP or .TZX files (well it could probably be if these standards were extended to include BASICODE, but so far it hasn't been done). So you need to record the BASICODE signal in (preferrably) a .WAV file. To make this easier, the \*W command will output the BASICODE signal as an audible signal from the Spectrum's speaker. Depending on your emulator, you may capture this either from the emulator itself or from the sound card.\
In general, when using an emulator, it will probably be easier to write the BASICODE program to an ASCII file (using the \*P command and redirecting the printer channel #3 to a file) so use this option only when you feel nostalgic about hearing the good old 'buzz saw' sounds from the '80s :-).

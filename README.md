# ZXSpectrum-Basicode
Source code of BASICODE-3 for the ZX Spectrum computer

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

I don't own a ZX Spectrum anymore but have successfully tested the program on various emulators such as Spectaculator and EightyOne, despite the huge dependency on the original ZX Spectrum ROM and accurate CPU timing. As for the latter, Spectaculator is my preferred choice. It can also read in BASICODE programs saved as 8-bit .WAV files at high speed. You must set it to emulate the 48K Spectrum though as the program does not currently work in 128K mode.

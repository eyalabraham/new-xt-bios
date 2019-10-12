;********************************************************************
; config.asm
;
;  BIOS rewrite for PC/XT
;  BIOS replacement for PC/XT clone
;
;  This file is the New BIOS Configuration
;
;********************************************************************
;
; change log
;------------
; created       06/24/2019              file
;
;
;======================================
; default startup CRT properties
;======================================
;
DEFBAUDSIOA:    equ         BAUD19200           ; debug console baud rate
DEFBAUDSIOB:    equ         BAUD57600           ; RPi display interface baud rate
DEFVIDEOMODE:   equ         9                   ; BIOS POST goes into special mode 9 for mon88                                                for OS boot, video mode is set based on DIP SW.5 & 6 setting
;
;======================================
; fixed disk properties
;======================================
;
MAXCYL:         equ         462                 ; cylinder count
MAXHEAD:        equ         8                   ; head count
MAXSEC:         equ         17                  ; sectors per track
;
FDLASTLBA:      equ         ((MAXCYL*MAXHEAD*MAXSEC)-1) ; zero-based last LBA number
FDHOSTOFFSET:   equ         15000               ; LBA offset into host drive
;
;======================================
; Debug output
;======================================
;
%define         DebugConsole    0               ; SIO UART Ch.A debug console: 0=on, 1=off
;
%define         INT09_Debug     0               ; set to '1' to enable debug, '0' to disable
%define         INT10_Debug     0
%define         INT13_Debug     0
%define         INT14_Debug     0
%define         INT16_Debug     0
%define         CHS2LBA_Debug   0

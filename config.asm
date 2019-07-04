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
DEFBAUDSIOA:    equ         BAUD19200
DEFBAUDSIOB:    equ         BAUD38400
DEFVIDEOMODE:   equ         9                   ; BIOS POST goes into special mode 9 for mon88                                                for OS boot, video mode is set based on DIP SW.5 & 6 setting
;
;======================================
; Debug output
;======================================
;
%define         DebugConsole    0               ; SIO UART Ch.A debug console: 0=no, 1=yes
;
%define         INT09_Debug     1
%define         INT10_Debug     1
%define         INT13_Debug     0
%define         INT16_Debug     1
%define         CHS2LBA_Debug   0

# newbios (and associated files)
This is a BIOS rewrite for a PC/XT type machine.
The BIOS replacement is for a PC/XT clone, strip-down 8088 / 640KB mother board.
The hardware added on the system board are:
- BIOS replacement for PC/XT clone
- Hardware includes Z80-SIO USART (on channel B) + RPi to replace CRT.
- Reconstructed keyboard interface for PS/2 protocol.
- COM1 with UART 16550
- COM2 based Z80-SIO channel A, optionally "hide" this USART and use it as a SLIP network interface or a serial debug console.
- IDE-8255 interface for CF card.
- BIOS with required POST and services to boot MS-DOS 3.31, modified MINIX 2.0
- ROM monitor functions

This custom BIOS will initialize a system and provide support for booting and running DOS 3.31 and Minix 2.0.
  
Includes a basic monitor mode that allows the user to directly load the host HDD, load and execute code. Can be used to read or write floppy or fixed disk images for booting different OSs.

## BIOS POST process
Cross reference of BIOS POST steps:

| Line |  Label       | Step                                        |
|------|--------------|---------------------------------------------|
| 59   |              | CPU check                                   |
| 122  |              | PPI setup                                   |
| 133  |              | TIMER setup and test                        |
| 186  |              | DMA controller test and refresh setup       |
| 255  |              | Determine memory size and test first 2K     |
| 297  |              | First 2K ok and setup STACK                 |
| 309  |              | Setup interrupt controller and vectors      |
| 371  |              | SIO-ch.B setup and RPi rendezvous           |
| 420  |              | Set RPI VGA card                            |
| 447  |              | SIO-ch.A setup and RPi rendezvous           |
| 484  |              | UART1 setup and test                        |
| 553  |              | Setup system configuration                  |
| 601  |              | RAM test                                    |
| 642  |              | setup keyboard buffer, time of day, EI, NMI |
| 692  |              | IDE setup                                   |
| 862  |  IPLBOOT     | Boot OS                                     |
| 907  |  MONITOR     | Monitor mode                                |

## Video emulation
Video display is emulated by a Raspberry Pi Zero (RPi). The RPi runs an emulation program that emulates CGA, MDA and Hercules cards on the RPI's frame buffer. BIOS video commands are translated and exchanged with the emulation code via serial link through a Z80-SIO dual-USART (channel B). Emulation commands are described in iodef.asm.

## Keyboard
A PS/2 keyboard is connected through an AVR ATmega328p, which controls the PS/2 keyboard as well as translates PS/2 scan codes into PC-XT codes. The AVR connects directly into the motherboard, **replaces** the 74LS322 shift register, and inputs the codes directly into the system's 8255 PPI. This setup avoid the need to translate the scan codes into a serial format expected by the PC-XT.

## Floppy drives and hard drive emulation
An IDE interface implemented with a 8255 PPI is used to interface with a CF card. The BIOS emulates two floppy drives and a hard drive on a single CF card. Floppy A can have up to four images selectable via DIP switches 7 and 8, which allows user to emulate floppy disk changes. The images of the floppies are saved on a PC, and written to the CF card into specific locations using Linux 'dd'.

## INT 10h register mapping
Resource [BIOS 10h calls](http://stanislavs.org/helppc/int_10.html)
Register usage mapping of implemented BIOS functions:

| call      | function                                              |  AL    | BH     |BL     |CH     |CL     |DH     |DL      |
|-----------|-------------------------------------------------------|--------|--------|-------|-------|-------|-------|--------|
| INT 10,0  | Set video mode                                        |  mode  |        |       |       |       |       |        |
| INT 10,1  | Set cursor type                                       |        |        |       |top    |bottom |       |        |
| INT 10,2  | Set cursor position                                   |        | page   |       |       |       |row    |col     |
| INT 10,3  | Read cursor position                                  |        | page   |       |       |       |       |        |
| INT 10,4  | Read light pen                                        |        |        |       |       |       |       |        |
| INT 10,5  | Select active display page                            |  page  |        |       |       |       |       |        |
| INT 10,6  | Scroll active page up                                 |  count | attrib |       |tl-row |tl-col |br-row |br-col  |
| INT 10,7  | Scroll active page down                               |  count | attrib |       |tl-row |tl-col |br-row |br-col  |
| INT 10,8  | Read character and attribute at cursor                |        | page   |       |       |       |       |        |
| INT 10,9  | Write character and attribute at cursor               |  ascii | page   |attrib |cnt-hi |cnt-lo |       |        |
| INT 10,A  | Write character at current cursor                     |  ascii | page   |color  |cnt-hi |cnt-lo |       |        |
| INT 10,B  | Set color palette                                     |        | pallete|color  |       |       |       |        |
| INT 10,C  | Write graphics pixel at coordinate                    |  color | page   |       |x-hi   |x-lo   |y-hi   |y-lo    |
| INT 10,D  | Read graphics pixel at coordinate                     |        | page   |       |x-hi   |x-lo   |y-hi   |y-lo    |
| INT 10,E  | Write text in teletype mode                           |  ascii | page   |color  |       |       |       |        |
| INT 10,F  | Get current video state                               |        |        |       |       |       |       |        |
| INT 10,10 | Set/get palette registers (EGA/VGA)                   |        |        |       |       |       |       |        |
| INT 10,11 | Character generator routine (EGA/VGA)                 |        |        |       |       |       |       |        |
| INT 10,12 | Video subsystem configuration (EGA/VGA)               |        |        |       |       |       |       |        |
| INT 10,13 | Write string (BIOS after 1/10/86)                     |  mode  | page   |attrib |cnt-hi |cnt-lo |row    |col     |
| INT 10,14 | Load LCD char font (convertible)                      |        |        |       |       |       |       |        |
| INT 10,15 | Return physical display parms (convertible)           |        |        |       |       |       |       |        |
| INT 10,1A | Video Display Combination (VGA)                       |        |        |       |       |       |       |        |
| INT 10,1B | Video BIOS Functionality/State Information (MCGA/VGA) |        |        |       |       |       |       |        |
| INT 10,1C | Save/Restore Video State  (VGA only)                  |        |        |       |       |       |       |        |
| INT 10,FE | Get DESQView/TopView Virtual Screen Regen Buffer      |        |        |       |       |       |       |        |
| INT 10,FF | Update DESQView/TopView Virtual Screen Regen Buffer   |        |        |       |       |       |       |        |

## Resources
- [Manuals and technical references](http://bitsavers.trailing-edge.com/pdf/ibm/pc/)
- [BIOS interface](http://stanislavs.org/helppc/)

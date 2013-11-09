# -------------------------------------
#  This make file is for compiling the 
#  PC/XT new BIOS ROM
#
#  Use:
#    clean      - clean environment
#    all        - build all outputs
#    bin        - build binary output
#    srec       - build S-record output
#
#    all output build will create a listing file
#
# -------------------------------------

#
# change log
# -------------------
# 02/03/2013        created
#

BINDIR = ~/Documents/bios/bin
DEPENDENCIES = newbios.asm memdef.asm iodef.asm

all : bin srec

bin : newbios.bin

srec : newbios.srec

newbios.bin : $(DEPENDENCIES)
	nasm -f bin newbios.asm -o $(BINDIR)/newbios.bin -l $(BINDIR)/newbios.lst

newbios.srec : $(DEPENDENCIES)
	nasm -f srec newbios.asm -o $(BINDIR)/newbios.srec -l $(BINDIR)/newbios.lst

.PHONY : CLEAN
clean :
	rm -f $(BINDIR)/*bin
	rm -f $(BINDIR)/*srec
	rm -f $(BINDIR)/*lst


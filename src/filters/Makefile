# ************************************************************************* #
# Organizacion del Computador II                                            #
#                                                                           #
#   Trabajo Practico 2                                                      #
#                                                                           #
# ************************************************************************* #

all: C_blur.o ASM_blur1.o ASM_blur2.o C_merge.o ASM_merge1.o ASM_merge2.o C_hsl.o ASM_hsl1.o ASM_hsl2.o filter_toX.o aux.o 

CFLAGS=-Wall -Wextra -pedantic -O0 -ggdb -lm -std=c99
NASMFLAGS=-f elf64 -g -F DWARF

%.o: %.c filters.h
	gcc $(CFLAGS) -c -o $@ $<
	
%.o: %.asm
	nasm $(NASMFLAGS) -o $@ $<

clean:
	rm  -f *.o

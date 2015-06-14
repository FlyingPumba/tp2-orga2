# ************************************************************************* #
# Organizacion del Computador II                                            #
#                                                                           #
#   Trabajo Practico 2                                                      #
#                                                                           #
# ************************************************************************* #

all: C_blur.o ASM_blur1.o ASM_blur2.o EXP_C_blur1.o EXP_C_blur2.o EXP_C_blur3.o EXP_ASM_blur3.o EXP_ASM_blur4.o C_merge.o ASM_merge1.o ASM_merge2.o ASM_merge3.o EXP_C_merge.o EXP_ASM_merge.o C_hsl.o ASM_hsl1.o ASM_hsl1_1.o ASM_hsl1_2.o ASM_hsl1_3.o ASM_hsl1_4.o ASM_hsl2.o ASM_hsl2_1.o ASM_hsl2_2.o filter_toX.o aux.o

CFLAGS=-Wall -Wextra -pedantic -O2 -ggdb -lm -std=c99
NASMFLAGS=-f elf64 -g -F DWARF

%.o: %.c filters.h
	gcc $(CFLAGS) -c -o $@ $<

%.o: %.asm
	nasm $(NASMFLAGS) -o $@ $<

clean:
	rm  -f *.o

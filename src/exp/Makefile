# ************************************************************************* #
# Organizacion del Computador II                                            #
#                                                                           #
#   Trabajo Practico 2                                                      #
#                                                                           #
# ************************************************************************* #

all: makes exe

CFLAGS=-Wall -Wextra -pedantic -O0 -ggdb -lm -std=c99

makes:
	make -C ../bmp
	make -C ../filters

%.o: %.c rdtsc.h
	gcc $(CFLAGS) -c -o $@ $<
	
exe: rdtsc.h experimentos.c makes
	gcc $(CFLAGS) experimentos.c rdtsc.h ../filters/*.o ../bmp/*.o -o exe -lm
	cp exe ../../bin/
	
clean:
	make -C ../bmp clean
	make -C ../filters clean
	rm  -f *.o exe
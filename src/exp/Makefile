# ************************************************************************* #
# Organizacion del Computador II                                            #
#                                                                           #
#   Trabajo Practico 2                                                      #
#                                                                           #
# ************************************************************************* #

all: makes exe

CFLAGS=-w -O0 -ggdb -lm -std=c99
#-Wall -Wextra -pedantic

makes:
	make --silent -C ../bmp
	make --silent -C ../filters

%.o: %.c rdtsc.h
	gcc $(CFLAGS) -c -o $@ $<
	
exe: rdtsc.h experimentos.c makes
	gcc $(CFLAGS) experimentos.c rdtsc.h ../filters/*.o ../bmp/*.o -o exe -lm
	cp exe ../../bin/
	
clean:
	make --silent -C ../bmp clean
	make --silent -C ../filters clean
	rm  -f *.o exe
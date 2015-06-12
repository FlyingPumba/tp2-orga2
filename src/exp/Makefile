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

blur: rdtsc.h exp_blur.c makes
		gcc $(CFLAGS) exp_blur.c rdtsc.h ../filters/*.o ../bmp/*.o -o exp_blur -lm
		cp exp_blur ../../bin/

merge: rdtsc.h exp_merge.c makes
		gcc $(CFLAGS) exp_merge.c rdtsc.h ../filters/*.o ../bmp/*.o -o exp_merge -lm
		cp exp_blur ../../bin/

hsl: rdtsc.h exp_hsl.c makes
		gcc $(CFLAGS) exp_hsl.c rdtsc.h ../filters/*.o ../bmp/*.o -o exp_hsl -lm
		cp exp_hsl ../../bin/

clean:
	make --silent -C ../bmp clean
	make --silent -C ../filters clean
	rm  -f *.o exe

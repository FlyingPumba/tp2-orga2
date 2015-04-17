/* ************************************************************************* */
/* Organizacion del Computador II                                            */
/*                                                                           */
/*   Definiciones de funciones de ejecucion de filtros                       */
/*                                                                           */
/* ************************************************************************* */

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include "bmp/bmp.h"
#include "filters/filters.h"

int run_blur(int c, char* src, char* dst);

int run_merge(int c, char* src1, char* src2, char* dst, float value);

int run_hsl(int c, char* src, char* dst, float hh, float ss, float ll);

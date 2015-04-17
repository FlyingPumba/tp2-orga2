/* ************************************************************************* */
/* Organizacion del Computador II                                            */
/*                                                                           */
/*   Definiciones de los filtros y estructuras de datos utiles               */
/*                                                                           */
/* ************************************************************************* */

#ifndef FILTER_HH
#define FILTER_HH

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include "../bmp/bmp.h"

typedef struct __attribute__((packed)) s_RGB {
  uint8_t b;
  uint8_t g;
  uint8_t r;
} RGB;

typedef struct __attribute__((packed)) s_RGBA {
  uint8_t a;
  uint8_t b;
  uint8_t g;
  uint8_t r;
} RGBA;

void to24(uint32_t w, uint32_t h, uint8_t* src32, uint8_t* dst24);
void to32(uint32_t w, uint32_t h, uint8_t* src24, uint8_t* dst32);

void    C_blur(uint32_t w, uint32_t h, uint8_t* data);
void ASM_blur1(uint32_t w, uint32_t h, uint8_t* data);
void ASM_blur2(uint32_t w, uint32_t h, uint8_t* data);

void    C_merge(uint32_t w, uint32_t h, uint8_t* data1, uint8_t* data2, float value);
void ASM_merge1(uint32_t w, uint32_t h, uint8_t* data1, uint8_t* data2, float value);
void ASM_merge2(uint32_t w, uint32_t h, uint8_t* data1, uint8_t* data2, float value);

void    C_hsl(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll);
void ASM_hsl1(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll);
void ASM_hsl2(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll);

void rgbTOhsl(uint8_t *src, float *dst);
void hslTOrgb(float *src, uint8_t *dst);

int max(int a,int b, int c);
int min(int a,int b, int c);

#endif
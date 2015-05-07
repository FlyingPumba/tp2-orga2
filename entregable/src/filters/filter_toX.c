/* ************************************************************************* */
/* Organizacion del Computador II                                            */
/*                                                                           */
/*   Funciones de conversion entre color 24 y 32 bits                        */
/*                                                                           */
/* ************************************************************************* */

#include "filters.h"

void to24(uint32_t w, uint32_t h, uint8_t* src32, uint8_t* dst24) {
  int i;
  for(i=0;i<(int)(w*h);i++) {
    dst24[i*3+0]=src32[i*4+1];
    dst24[i*3+1]=src32[i*4+2];
    dst24[i*3+2]=src32[i*4+3];
  }
}

void to32(uint32_t w, uint32_t h, uint8_t* src24, uint8_t* dst32) {
  int i;
  for(i=0;i<(int)(w*h);i++) {
    dst32[i*4+0]=0xff;
    dst32[i*4+1]=src24[i*3+0];
    dst32[i*4+2]=src24[i*3+1];
    dst32[i*4+3]=src24[i*3+2];
  }  
}
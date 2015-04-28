/* ************************************************************************* */
/* Organizacion del Computador II                                            */
/*                                                                           */
/*   Implementacion de la funcion Merge                                      */
/*                                                                           */
/* ************************************************************************* */

#include "filters.h"
#include <math.h>

void C_merge(uint32_t w, uint32_t h, uint8_t* data1, uint8_t* data2, float value) {
  uint8_t (*m1)[w][4] = (uint8_t (*)[w][4]) data1;
  uint8_t (*m2)[w][4] = (uint8_t (*)[w][4]) data2;
  int ih,iw,ii;
  for(ih=0;ih<(int)h;ih++) {
    for(iw=0;iw<(int)w;iw++) {
      for(ii=1;ii<4;ii++) {
           m1[ih][iw][ii] = (uint8_t)(value * ((float)m1[ih][iw][ii]) + (1.0-value) * ((float)m2[ih][iw][ii]));
      }
    }
  }
}
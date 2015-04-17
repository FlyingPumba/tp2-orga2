/* ************************************************************************* */
/* Organizacion del Computador II                                            */
/*                                                                           */
/*   Implementacion de la funcion Blur                                       */
/*                                                                           */
/* ************************************************************************* */

#include "filters.h"

void C_blur( uint32_t w, uint32_t h, uint8_t* data ) {
  uint8_t (*m)[w][4] = (uint8_t (*)[w][4]) data;
  int ih,iw,ii;
  for(ih=1;ih<(int)h-1;ih++) {
    for(iw=1;iw<(int)w-1;iw++) {
      for(ii=0;ii<4;ii++) {
        m[ih][iw][ii] = ( 
          (int)m[ih-1][iw-1][ii] + (int)m[ih-1][iw][ii] + (int)m[ih-1][iw+1][ii] +
          (int)m[ih]  [iw-1][ii] + (int)m[ih]  [iw][ii] + (int)m[ih]  [iw+1][ii] +
          (int)m[ih+1][iw-1][ii] + (int)m[ih+1][iw][ii] + (int)m[ih+1][iw+1][ii] ) / 9;
      }
    }
  }
}

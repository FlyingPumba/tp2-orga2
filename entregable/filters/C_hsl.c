/* ************************************************************************* */
/* Organizacion del Computador II                                            */
/*                                                                           */
/*   Implementacion de la funcion HSL                                        */
/*                                                                           */
/* ************************************************************************* */

#include "filters.h"

void C_hsl(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll) {
  uint8_t (*m)[w][4] = (uint8_t (*)[w][4]) data;
  int ih,iw;
  for(ih=0;ih<(int)h;ih++) {
    for(iw=0;iw<(int)w;iw++) {
      float dst[4]; // A H S L
      rgbTOhsl((uint8_t*)(&(m[ih][iw])),(float*)(&dst));
      dst[1] = (dst[1]+hh) >= 360 ? dst[1]+hh-360 : ( (dst[1]+hh) < 0 ? dst[1]+hh+360 : dst[1]+hh ) ;
      dst[2] = (dst[2]+ss) >=  1  ? 1 : ( (dst[2]+ss) < 0 ? 0 : dst[2]+ss ) ;
      dst[3] = (dst[3]+ll) >=  1  ? 1 : ( (dst[3]+ll) < 0 ? 0 : dst[3]+ll ) ;   
      hslTOrgb((float*)(&dst),(uint8_t*)(&(m[ih][iw])));
    }
  }
}
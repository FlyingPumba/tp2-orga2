/* ************************************************************************* */
/* Organizacion del Computador II                                            */
/*                                                                           */
/*   Implementacion de la funcion Merge en C para 1/4 de los componentes     */
/*   Azules de la imagen                                                     */
/*                                                                           */
/* ************************************************************************* */

#include "../filters/filters.h"
#include <math.h>

void C_merge_corto(uint32_t w, uint32_t h, uint8_t* data1, uint8_t* data2, float value) {
  uint8_t (*m1)[w][4] = (uint8_t (*)[w][4]) data1;
  uint8_t (*m2)[w][4] = (uint8_t (*)[w][4]) data2;
  int ih,iw;
  // Itero 1/4 de la imagen
  for(ih=0;ih<(int)(h/4);ih++) {
    for(iw=0;iw<(int)(w/4);iw++) {
        // la componente de indice 2 corresponde al azul
        m1[ih][iw][2] = (uint8_t)(value * ((float)m1[ih][iw][2]) + (1.0-value) * ((float)m2[ih][iw][2]));
    }
  }
}

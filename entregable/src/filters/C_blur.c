/* ************************************************************************* */
/* Organizacion del Computador II                                            */
/*                                                                           */
/*   Implementacion de la funcion Blur                                       */
/*                                                                           */
/* ************************************************************************* */

#include "filters.h"

void C_blur( uint32_t w, uint32_t h, uint8_t* data ) {
  
    int ih,iw,ii;
    uint8_t (*m)[w][4] = (uint8_t (*)[w][4]) data;
  uint8_t (*m_row_0)[4] = (uint8_t (*)[4]) malloc(w*4);
  uint8_t (*m_row_1)[4] = (uint8_t (*)[4]) malloc(w*4);  
  uint8_t (*m_tmp)[4];
  for(iw=0;iw<(int)w;iw++) {
    for(ii=0;ii<4;ii++) {
      m_row_1[iw][ii] = m[0][iw][ii];
    }
  }
  for(ih=1;ih<(int)h-1;ih++) {
    m_tmp = m_row_0;
    m_row_0 = m_row_1;
    m_row_1 = m_tmp;
    for(iw=0;iw<(int)w;iw++) {
      for(ii=0;ii<4;ii++) {
        m_row_1[iw][ii] = m[ih][iw][ii];
      }
    }
    for(iw=1;iw<(int)w-1;iw++) {
      for(ii=0;ii<4;ii++) {
        m[ih][iw][ii] = ( 
          (int)m_row_0[iw-1][ii] + (int)m_row_0[iw][ii] + (int)m_row_0[iw+1][ii] +
          (int)m_row_1[iw-1][ii] + (int)m_row_1[iw][ii] + (int)m_row_1[iw+1][ii] +
          (int)m[ih+1][iw-1][ii] + (int)m[ih+1][iw][ii] + (int)m[ih+1][iw+1][ii] ) / 9;
      }
    }
  }
  free(m_row_0);
  free(m_row_1);
}

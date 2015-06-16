/* ************************************************************************* */
/* Organizacion del Computador II                                            */
/*                                                                           */
/*   Implementacion de la funcion Blur                                       */
/*                                                                           */
/* ************************************************************************* */

#include "filters.h"

void EXP_C_blur3( uint32_t w, uint32_t h, uint8_t* data ) {

    int ih,iw;
    uint8_t (*m)[w][4] = (uint8_t (*)[w][4]) data;
    uint8_t (*m_row_0)[4] = (uint8_t (*)[4]) malloc(w*4);
    uint8_t (*m_row_1)[4] = (uint8_t (*)[4]) malloc(w*4);
    uint8_t (*m_tmp)[4];
    for(iw=0;iw<(int)w;iw++) {
        m_row_1[iw][0] = m[0][iw][0];
    }
    for(ih=1;ih<(int)h-1;ih++) {
            m_tmp = m_row_0;
            m_row_0 = m_row_1;
            m_row_1 = m_tmp;
            for(iw=0;iw<(int)w;iw++) {
                m_row_1[iw][0] = m[ih][iw][0];
            }
            for(iw=1;iw<(int)w-1;iw++) {
                m[ih][iw][0] = ( (int)m_row_0[iw-1][0] + (int)m_row_0[iw][0] ) / 2;
            }
        }
    free(m_row_0);
    free(m_row_1);
}

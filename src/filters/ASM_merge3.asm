; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion Merge 3                                    ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_merge3(uint32_t w, uint32_t h, uint8_t* data1, uint8_t* data2, float value)
global ASM_merge3
%define PIXEL_SIZE 4

section .rodata
    unos: dd 1.0, 1.0, 1.0, 1.0

section .text
ASM_merge3:
  push rbp
  mov rbp, rsp
  ;*******
  ; rdi = width
  ; rsi = height
  mov r8, rdx ; r8 = *data1
  mov r9, rcx ; r9 = *data2
  ; xmm0 tiene un scalar float SP que es el value. xmm0 = | ceros .. value |

  ; convierto xmm0 a 4 floats SP
  movdqu xmm1, xmm0 ; xmm1 = xmm0
  pslldq xmm1, 4 ; xmm1 = | ceros .. value ceros (4 bytes) |
  addps xmm0, xmm1 ; xmm0 = | ceros .. value value |
  movdqu xmm1, xmm0 ; xmm1 = xmm0
  pslldq xmm1, 8 ; xmm1 = | value value ceros .. |
  addps xmm0, xmm1 ; xmm0 = | value | value | value | value |

  ; preparo un vector en xmm15 que va a tener: | 1-value | 1-value | 1-value | 1-value |
  movdqu xmm15, [unos] ; xmm15 = | 1 1 1 1 | (en floats SP)
  subps xmm15, xmm0 ; xmm15 = | 1-value | 1-value | 1-value | 1-value |

  ; preparo un registro auxiliar para saber cuantos bytes procesar
  mov rax, rdi ; rax = w
  mul rsi ; rax = w * h
  mov rsi, PIXEL_SIZE ; rsi = PIXEL_SIZE
  mul rsi ; rax = w * h * PIXEL_SIZE = *data.size()

  xor rcx, rcx ; contador de bytes procesados
  .ciclo:
      cmp rcx, rax
      jge .fin

      ; vamos a cargar la mayor cantidad de pixeles que podamos, que en memoria se veria:
      ; data1 = | p1-0 | p1-1 | p1-2 | p1-3 |
      ; data2 = | p2-0 | p2-1 | p2-2 | p2-3 |
      movdqu xmm1, [r8 + rcx] ; xmm1 = | p1-3 | p1-2 | p1-1 | p1-0 |
      movdqu xmm2, [r9 + rcx] ; xmm2 = | p2-3 | p2-2 | p2-1 | p2-0 |

      ; ahora, convierto todos los canales de 1 byte a canales de 2 bytes
      ; entonces, cada pixel va a pasar a medir 8 bytes (64bits) en vez de 4 bytes

      pxor xmm14, xmm14 ; xmm14 = ceros
      movdqu xmm3, xmm1 ; xmm3 = xmm1
      punpcklbw xmm1, xmm14 ; xmm1 = | p1-1 | p1-0 |
      punpckhbw xmm3, xmm14 ; xmm3 = | p1-3 | p1-2 |

      movdqu xmm4, xmm2 ; xmm4 = xmm2
      punpcklbw xmm2, xmm14 ; xmm2 = | p2-1 | p2-0 |
      punpckhbw xmm4, xmm14 ; xmm4 = | p2-3 | p2-2 |

      ; calculo primer pixel
      ; paso los canales de 2 bytes enteros a canales de 4 bytes enteros
      movdqu xmm5, xmm1
      punpcklwd xmm5, xmm14 ; xmm5 = | p1-0 |
      movdqu xmm6, xmm2
      punpcklwd xmm6, xmm14 ; xmm6 = | p2-0 |
       
      psubd xmm5, xmm6 ; xmm5 = | p1-0 - p2-0 |
      cvtdq2ps xmm5, xmm5 ; xmm5 = | p1-0 - p2-0 | (float)
      cvtdq2ps xmm6, xmm6 ; xmm6 = | p2-0 | (float)

      mulps xmm5, xmm0 ; xmm5 = | (p1-0 - p2-0) * value |
      addps xmm5, xmm6 ; xmm5 = | (p1-0 + p2-0) * value + p2-0 |

      ; calculo segundo pixel (idem primero)
      movdqu xmm7, xmm1
      punpckhwd xmm7, xmm14 ; xmm7 = | p1-1 |
      movdqu xmm8, xmm2
      punpckhwd xmm8, xmm14 ; xmm8 = | p2-1 |

      psubd xmm7, xmm8 ; xmm7 = | p1-1 - p2-1 |
      cvtdq2ps xmm7, xmm7 ; xmm7 = | (p1-1 - p2-1) | (float)
      cvtdq2ps xmm8, xmm8 ; xmm8 = | p2-1 | (float)

      mulps xmm7, xmm0 ; xmm7 = | (p1-1 - p2-1) * value |
      addps xmm7, xmm8 ; xmm7 = | (p1-1 - p2-1) * value + p2-1 |

      ; calculo tercer pixel (idem primero)
      movdqu xmm9, xmm3
      punpcklwd xmm9, xmm14 ; xmm9 = | p1-2 |
      movdqu xmm10, xmm4
      punpcklwd xmm10, xmm14 ; xmm10 = | p2-2 |

      psubd xmm9, xmm10 ; xmm9 = | p1-2 - p2-2 |
      cvtdq2ps xmm9, xmm9 ; xmm9 = | p1-2 | (float)
      cvtdq2ps xmm10, xmm10 ; xmm10 = | p2-2 | (float)

      mulps xmm9, xmm0 ; xmm9 = | (p1-2 - p2-2) * value |
      addps xmm9, xmm10 ; xmm9 = | (p1-2 - p2-2) * value + p2-2 |

      ; calculo cuarto pixel (idem primero)
      movdqu xmm11, xmm3
      punpckhwd xmm11, xmm14 ; xmm11 = | p1-3 |
      movdqu xmm12, xmm4
      punpckhwd xmm12, xmm14 ; xmm12 = | p2-3 |

      psubd xmm11, xmm12 ; xmm11 = | p1-3 - p2-3 |
      cvtdq2ps xmm11, xmm11 ; xmm11 = | (p1-3 - p2-3) | (float)
      cvtdq2ps xmm12, xmm12 ; xmm12 = | p2-3 | (float)

      mulps xmm11, xmm0 ; xmm11 = | (p1-3 - p2-3) * value |
      addps xmm11, xmm12 ; xmm11 = | (p1-3 - p2-3) * value + p2-3 |

      ; transformo todos los resultados de floats SP a enteros 32 bits
      cvtps2dq xmm5, xmm5 ; xmm5 = | p1-0 * value + p2-0 * (1-value) | (enteros 32b)
      cvtps2dq xmm7, xmm7 ; xmm7 = | p1-1 * value + p2-1 * (1-value) | (enteros 32b)
      cvtps2dq xmm9, xmm9 ; xmm9 = | p1-2 * value + p2-2 * (1-value) | (enteros 32b)
      cvtps2dq xmm11, xmm11 ; xmm11 = | p1-3 * value + p2-3 * (1-value) | (enteros 32b)

      ; transformo todos los resultados de enteros 32 bits a enteros 16 bits
      packusdw xmm5, xmm14 ; xmm5 = | ceros | p1-0 * value + p2-0 * (1-value) | (enteros 16b)
      packusdw xmm7, xmm14 ; xmm7 = | ceros | p1-1 * value + p2-1 * (1-value) | (enteros 16b)
      packusdw xmm9, xmm14 ; xmm9 = | ceros | p1-2 * value + p2-2 * (1-value) | (enteros 16b)
      packusdw xmm11, xmm14 ; xmm11 = | ceros | p1-3 * value + p2-3 * (1-value) | (enteros 16b)

      ; transformo todos los resultados de enteros 16 bits a enteros 8 bits
      packuswb xmm5, xmm14 ; xmm5 = | ceros | ceros | ceros | p1-0 * value + p2-0 * (1-value) | (enteros 8b)
      packuswb xmm7, xmm14 ; xmm7 = | ceros | ceros | ceros | p1-1 * value + p2-1 * (1-value) | (enteros 8b)
      packuswb xmm9, xmm14 ; xmm9 = | ceros | ceros | ceros | p1-2 * value + p2-2 * (1-value) | (enteros 8b)
      packuswb xmm11, xmm14 ; xmm11 = | ceros | ceros | ceros | p1-3 * value + p2-3 * (1-value) | (enteros 8b)

      ; junto los 4 pixeles en xmm5
      pslldq xmm7, 4 ; xmm7 = | ceros | ceros | p1-1 * value + p2-1 * (1-value) | ceros |
      pslldq xmm9, 8 ; xmm9 = | ceros | p1-2 * value + p2-2 * (1-value) | ceros | ceros |
      pslldq xmm11, 12 ; xmm11 = | p1-3 * value + p2-3 * (1-value) | ceros | ceros | ceros |
      por xmm5, xmm7 ; xmm5 = | ceros | ceros | p1-1 * value + p2-1 * (1-value) | p1-0 * value + p2-0 * (1-value) |
      por xmm9, xmm11 ; xmm9 = | p1-3 * value + p2-3 * (1-value) | p1-2 * value + p2-2 * (1-value) | ceros | ceros |
      por xmm5, xmm9 ; xmm5 = | p1-3 * value + p2-3 * (1-value) | p1-2 * value + p2-2 * (1-value) | p1-1 * value + p2-1 * (1-value) | p1-0 * value + p2-0 * (1-value) |

      ; bajo a memoria en el mismo lugar donde levante los 4 pixeles de *data1
      movdqu [r8 + rcx], xmm5

      ;incremento el puntero para ir al proximo pixel
      lea rcx, [rcx + 4*PIXEL_SIZE]
      jmp .ciclo
  .fin:
  ;*******
  pop rbp
  ret

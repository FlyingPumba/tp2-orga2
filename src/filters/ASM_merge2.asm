; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion Merge 2                                    ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_merge2(uint32_t w, uint32_t h, uint8_t* data1, uint8_t* data2, float value)
global ASM_merge2
%define PIXEL_SIZE 4
%define k_byte 1

section .rodata
    uno_f: dd 1.0
    uno_i: dd 1
    k_bits: dd 8

section .text
ASM_merge2:
  push rbp
  mov rbp, rsp
  ;*******
  ; rdi <- width
  ; rsi <- height
  mov r8, rdx ; r8 <- *data1
  mov r9, rcx ; r9 <- *data2
  ; xmm0 tiene un scalar float SP que es el value. xmm0 = | ceros .. value |

  ; preparo un registro auxiliar para saber cuantos bytes procesar
  mov rax, rdi ; rax = w
  mul rsi ; rax = w * h
  mov rsi, PIXEL_SIZE ; rsi = PIXEL_SIZE
  mul rsi ; rax = w * h * PIXEL_SIZE = *data.size()

  ; calculo 2^k
  movd xmm3, [uno_i]
  pslldq xmm3, k_byte ; shift k=8 bits. xmm3 = 2^k (int 32b)

  ; calculo value*2^k
  pxor xmm4, xmm4
  movd edi, xmm3
  cvtsi2ss xmm4, edi ; xmm4 = 2^k (float SP)
  mulss xmm4, xmm0 ; xmm4 = value * 2^k (float SP)
  cvtss2si edi, xmm4
  movd xmm4, edi ; xmm4 = value * 2^k (int 32b)

  ; empaqueto value*2^k
  movdqu xmm1, xmm4 ; xmm1 = xmm4 = value * 2^k (int 32b)
  pslldq xmm1, 4 ; xmm1 = | ceros .. value*2^k ceros (4 bytes) |
  addps xmm4, xmm1 ; xmm0 = | ceros .. value*2^k value*2^k |
  movdqu xmm1, xmm4 ; xmm1 = xmm4
  pslldq xmm1, 8 ; xmm1 = | value*2^k value*2^k ceros .. |
  addps xmm4, xmm1 ; xmm4 = | value*2^k | value*2^k | value*2^k | value*2^k |

  ; empaqueto 2^k
  movdqu xmm2, xmm3 ; xmm2 = xmm3 = 2^k (int 32b)
  pslldq xmm2, 4 ; xmm2 = | ceros .. 2^k ceros (4 bytes) |
  addps xmm3, xmm2 ; xmm3 = | ceros .. 2^k 2^k |
  movdqu xmm2, xmm3 ; xmm2 = xmm3
  pslldq xmm2, 8 ; xmm2 = | 2^k 2^k ceros .. |
  addps xmm3, xmm2 ; xmm3 = | 2^k | 2^k | 2^k | 2^k |

  ; preparo un registro con (1-value)*2^k empaquetado
  movdqu xmm15, xmm3
  subpd xmm15, xmm4 ; xmm15 = | (1-value)*2^k | (1-value)*2^k | (1-value)*2^k | (1-value)*2^k |

  ; muevo el empaquetado de value*2^k a uno de los ultimos registros
  movdqu xmm14, xmm4 ; xmm14 = | value*2^k | value*2^k | value*2^k | value*2^k |

  ; cargo k en bits para usarlo en las operaciones
  movd xmm13, [k_bits] ; xmm13 = 8

  ; preparo registro con ceros para las operaciones de unpack
  pxor xmm12, xmm12 ; xmm12 = ceros

  xor rcx, rcx ; contador de filas (en pixeles)
  .ciclo:
      cmp rcx, rax
      jge .fin

      ; vamos a cargar la mayor cantidad de pixeles que podamos, que en memoria se veria:
      ; data1 = | p1-0 | p1-1 | p1-2 | p1-3 | p1-4 | p1-5 | p1-6 | p1-7 |
      ; data2 = | p2-0 | p2-1 | p2-2 | p2-3 | p2-4 | p2-5 | p2-6 | p2-7 |
      movdqu xmm1, [r8 + rcx] ; xmm1 = | p1-3 | p1-2 | p1-1 | p1-0 |
      movdqu xmm2, [r9 + rcx] ; xmm2 = | p2-3 | p2-2 | p2-1 | p2-0 |

      ; ahora, convierto todos los canales de 1 byte a canales de 2 bytes
      ; entonces, cada pixel va a pasar a medir 8 bytes (64bits) en vez de 4 bytes

      movdqu xmm3, xmm1 ; xmm3 = xmm1
      punpcklbw xmm1, xmm12 ; xmm1 = | p1-1 | p1-0 |
      punpckhbw xmm3, xmm12 ; xmm3 = | p1-3 | p1-2 |

      movdqu xmm4, xmm2 ; xmm4 = xmm2
      punpcklbw xmm2, xmm12 ; xmm2 = | p2-1 | p2-0 |
      punpckhbw xmm4, xmm12 ; xmm4 = | p2-3 | p2-2 |

      ; calculo primer pixel
      ; paso los canales de 2 bytes enteros a canales de 4 bytes enteros
      movdqu xmm5, xmm1
      punpcklwd xmm5, xmm12 ; xmm5 = | p1-0 |
      movdqu xmm6, xmm2
      punpcklwd xmm6, xmm12 ; xmm6 = | p2-0 |

      pmulld xmm5, xmm14 ; xmm5 = | p1-0 * value * 2^k |
      pmulld xmm6, xmm15 ; xmm6 = | p2-0 * (1-value) * 2^k |
      paddd xmm5, xmm6 ; xmm5 = | p1-0 * value * 2^k + p2-0 * (1-value) * 2^k |
      psrld xmm5, xmm13 ; xmm5 = | (p1-0 * value * 2^k + p2-0 * (1-value) * 2^k) / 2^k |

      ; calculo segundo pixel (idem primero)
      movdqu xmm7, xmm1
      punpckhwd xmm7, xmm12 ; xmm7 = | p1-1 |
      movdqu xmm8, xmm2
      punpckhwd xmm8, xmm12 ; xmm8 = | p2-1 |

      pmulld xmm7, xmm14 ; xmm7 = | p1-1 * value * 2^k |
      pmulld xmm8, xmm15 ; xmm8 = | p2-1 * (1-value) * 2^k |
      paddd xmm7, xmm8 ; xmm7 = | p1-1 * value * 2^k + p2-1 * (1-value) * 2^k |
      psrld xmm7, xmm13 ; xmm7 = | (p1-1 * value * 2^k + p2-1 * (1-value) * 2^k) / 2^k |

      ; calculo tercer pixel (idem primero)
      movdqu xmm9, xmm3
      punpcklwd xmm9, xmm12 ; xmm9 = | p1-2 |
      movdqu xmm10, xmm4
      punpcklwd xmm10, xmm12 ; xmm10 = | p2-2 |

      pmulld xmm9, xmm14 ; xmm9 = | p1-2 * value * 2^k |
      pmulld xmm10, xmm15 ; xmm10 = | p2-2 * (1-value) * 2^k |
      paddd xmm9, xmm10 ; xmm9 = | p1-2 * value * 2^k + p2-0 * (1-value) * 2^k |
      psrld xmm9, xmm13 ; xmm9 = | (p1-2 * value * 2^k + p2-2 * (1-value) * 2^k) / 2^k |

      ; calculo cuarto pixel (idem primero)
      movdqu xmm10, xmm3
      punpckhwd xmm10, xmm12 ; xmm10 = | p1-3 |
      movdqu xmm11, xmm4
      punpckhwd xmm11, xmm12 ; xmm11 = | p2-3 |

      pmulld xmm10, xmm14 ; xmm10 = | p1-3 * value * 2^k |
      pmulld xmm11, xmm15 ; xmm11 = | p2-3 * (1-value) * 2^k |
      paddd xmm10, xmm11 ; xmm10 = | p1-3 * value * 2^k + p2-3 * (1-value) * 2^k |
      psrld xmm10, xmm13 ; xmm10 = | (p1-3 * value * 2^k + p2-3 * (1-value) * 2^k) / 2^k |

      ; transformo todos los resultados de enteros 32 bits a enteros 16 bits
      packusdw xmm5, xmm12 ; xmm5 = | ceros | p1-0 * value + p2-0 * (1-value) | (enteros 16b)
      packusdw xmm7, xmm12 ; xmm7 = | ceros | p1-1 * value + p2-1 * (1-value) | (enteros 16b)
      packusdw xmm9, xmm12 ; xmm9 = | ceros | p1-2 * value + p2-2 * (1-value) | (enteros 16b)
      packusdw xmm10, xmm12 ; xmm10 = | ceros | p1-3 * value + p2-3 * (1-value) | (enteros 16b)

      ; transformo todos los resultados de enteros 16 bits a enteros 8 bits
      packuswb xmm5, xmm12 ; xmm5 = | ceros | ceros | ceros | p1-0 * value + p2-0 * (1-value) | (enteros 8b)
      packuswb xmm7, xmm12 ; xmm7 = | ceros | ceros | ceros | p1-1 * value + p2-1 * (1-value) | (enteros 8b)
      packuswb xmm9, xmm12 ; xmm9 = | ceros | ceros | ceros | p1-2 * value + p2-2 * (1-value) | (enteros 8b)
      packuswb xmm10, xmm12 ; xmm10 = | ceros | ceros | ceros | p1-3 * value + p2-3 * (1-value) | (enteros 8b)

      ; junto los 4 pixeles en xmm5
      pslldq xmm7, 4 ; xmm7 = | ceros | ceros | p1-1 * value + p2-1 * (1-value) | ceros |
      pslldq xmm9, 8 ; xmm9 = | ceros | p1-2 * value + p2-2 * (1-value) | ceros | ceros |
      pslldq xmm10, 12 ; xmm10 = | p1-3 * value + p2-3 * (1-value) | ceros | ceros | ceros |
      por xmm5, xmm7 ; xmm5 = | ceros | ceros | p1-1 * value + p2-1 * (1-value) | p1-0 * value + p2-0 * (1-value) |
      por xmm9, xmm10 ; xmm9 = | p1-3 * value + p2-3 * (1-value) | p1-2 * value + p2-2 * (1-value) | ceros | ceros |
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

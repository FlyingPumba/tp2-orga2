; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion Merge 2                                    ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_merge2(uint32_t w, uint32_t h, uint8_t* data1, uint8_t* data2, float value)
global ASM_merge2
section .rodata
    uno: dd 1.0

section .text
ASM_merge2:
  push rbp
  mov rbp, rsp
  sub rsp, 8
  push rbx
  push r12
  push r13
  push r14
  push r15
  ;*******
  mov r12, rdi ; r12 <- width
  mov r13, rsi ; r13 <- height
  mov r14, rdx ; r14 <- *data1
  mov r15, rcx ; r15 <- *data2

  ; xmm0 tiene un scalar float SP que es el value. xmm0 = | ceros .. value |
  movdqu xmm2, xmm0
  ; calculo 1-value
  movd xmm1, [uno]
  subss xmm1, xmm0 ; xmm1 = 1-value
  movd edi, xmm0 ; edi = | signo (1bit) | exponente (8bit) | mantisa (23bit) |
  movd esi, xmm1

  ; extraigo de value el valor del exponente
  shl edi, 1 ; shifteo a la izquierda 1 bit. edi = | exponente (8bit) | mantisa (23bit) | 0 (1bit) |
  shr edi, 24 ; shifteo a la derecha 24 bits. edi = | ceros (24bit) | exponente (8bit) |

  ; extraigo de 1-value el valor del exponente
  shl esi, 1 ; shifteo a la izquierda 1 bit. esi = | exponente (8bit) | mantisa (23bit) | 0 (1bit) |
  shr esi, 24 ; shifteo a la derecha 24 bits. esi = | ceros (24bit) | exponente (8bit) |

  ; me fijo cual es el menor de ambos.
  ; Este es el k que voy a usar para pasar a enteros los valores de value y 1-value
  cmp edi, esi
  jle .value_menor_exp
  ; le resto el exponente a 127 para obtener el k. Se que va a dar positivo por que 0<= value <= º
  mov rax, 127
  sub eax, esi
  jmp .computar_values_enteros
  .value_menor_exp:
  mov rax, 127
  sub eax, edi
  .computar_values_enteros:
  mov rbx, 1
  mov cl, al
  movd xmm12, eax ; xmm12 = k
  shl rbx, cl ; rbx = 2^k
  cvtsi2ss xmm3, rbx ; rbx = 2^k (float SP)
  mulss xmm2, xmm3 ; xmm2 = value * 2^k
  cvtss2si rdi, xmm2

  ; los conviertos a 4 enteros 32b
  movq xmm0, rdi ; xmm0 = value*2^k
  movdqu xmm1, xmm0 ; xmm1 = xmm0
  pslldq xmm1, 4 ; xmm1 = | ceros .. value*2^k ceros (4 bytes) |
  addps xmm0, xmm1 ; xmm0 = | ceros .. value*2^k value*2^k |
  movdqu xmm1, xmm0 ; xmm1 = xmm0
  pslldq xmm1, 8 ; xmm1 = | value*2^k value*2^k ceros .. |
  addps xmm0, xmm1 ; xmm0 = | value*2^k | value*2^k | value*2^k | value*2^k |

  movq xmm13, rbx ; xmm13 = 2^k
  movdqu xmm2, xmm13 ; xmm2 = xmm13
  pslldq xmm2, 4 ; xmm2 = | ceros .. 2^k ceros (4 bytes) |
  addps xmm13, xmm2 ; xmm13 = | ceros .. 2^k 2^k |
  movdqu xmm2, xmm13 ; xmm2 = xmm13
  pslldq xmm2, 8 ; xmm2 = | 2^k 2^k ceros .. |
  addps xmm13, xmm2 ; xmm13 = | 2^k | 2^k | 2^k | 2^k |

  ; preparo un registro con (1-value)*2^k
  movdqu xmm15, xmm13
  subpd xmm15, xmm0 ; xmm15 = | (1-value)*2^k | (1-value)*2^k | (1-value)*2^k | (1-value)*2^k |

  mov r8, r12
  shl r8, 2 ; r8 = width * 4 (ancho en bytes de la imagen)

  mov r9, r8
  sub r9, 8; r9 = width * 4 - 8 (ancho en bytes a recorrer)

  xor rcx, rcx ; contador de filas (en pixeles)
  .ciclo_fila:
      ; preparo rdi como registro auxiliar para levantar datos
      mov rax, r8
      mul rcx
      mov rdi, rax ; rdi = contador_filas * width * 4

      xor rdx, rdx ; contador de columnas (en bytes)
      .ciclo_columna:
          mov rsi, rdx ; rsi = contador_columnas (bytes)
          add rsi, rdi ; rsi = contador_columnas (bytes) + (contador_filas * width * 4)(bytes)
          ; vamos a cargar la mayor cantidad de pixeles que podamos, que en memoria se veria:
          ; data1 = | p1-0 | p1-1 | p1-2 | p1-3 | p1-4 | p1-5 | p1-6 | p1-7 |
          ; data2 = | p2-0 | p2-1 | p2-2 | p2-3 | p2-4 | p2-5 | p2-6 | p2-7 |
          movdqu xmm1, [r14 + rsi] ; xmm1 = | p1-3 | p1-2 | p1-1 | p1-0 |
          movdqu xmm2, [r15 + rsi] ; xmm2 = | p2-3 | p2-2 | p2-1 | p2-0 |

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

          pmulld xmm5, xmm0 ; xmm5 = | p1-0 * value |
          pmulld xmm6, xmm15 ; xmm6 = | p2-0 * (1-value) |
          paddd xmm5, xmm6 ; xmm5 = | p1-0 * value + p2-0 * (1-value) |
          psrld xmm5, xmm12 ; xmm5 = | (p1-0 * value * 2^k + p2-0 * (1-value) * 2^k) / 2^k |

          ; calculo segundo pixel (idem primero)
          movdqu xmm7, xmm1
          punpckhwd xmm7, xmm14 ; xmm7 = | p1-1 |
          movdqu xmm8, xmm2
          punpckhwd xmm8, xmm14 ; xmm8 = | p2-1 |

          pmulld xmm7, xmm0 ; xmm7 = | p1-1 * value |
          pmulld xmm8, xmm15 ; xmm8 = | p2-1 * (1-value) |
          paddd xmm7, xmm8 ; xmm7 = | p1-1 * value + p2-1 * (1-value) |
          psrld xmm7, xmm12 ; xmm7 = | (p1-1 * value * 2^k + p2-1 * (1-value) * 2^k) / 2^k |

          ; calculo tercer pixel (idem primero)
          movdqu xmm9, xmm3
          punpcklwd xmm9, xmm14 ; xmm9 = | p1-2 |
          movdqu xmm10, xmm4
          punpcklwd xmm10, xmm14 ; xmm10 = | p2-2 |

          pmulld xmm9, xmm0 ; xmm9 = | p1-2 * value |
          pmulld xmm10, xmm15 ; xmm10 = | p2-2 * (1-value) |
          paddd xmm9, xmm10 ; xmm9 = | p1-2 * value + p2-0 * (1-value) |
          psrld xmm9, xmm12 ; xmm9 = | (p1-2 * value * 2^k + p2-2 * (1-value) * 2^k) / 2^k |

          ; calculo cuarto pixel (idem primero)
          movdqu xmm11, xmm3
          punpckhwd xmm11, xmm14 ; xmm11 = | p1-3 |
          movdqu xmm12, xmm4
          punpckhwd xmm12, xmm14 ; xmm12 = | p2-3 |

          pmulld xmm11, xmm0 ; xmm11 = | p1-3 * value |
          pmulld xmm12, xmm15 ; xmm12 = | p2-3 * (1-value) |
          paddd xmm11, xmm12 ; xmm11 = | p1-3 * value + p2-3 * (1-value) |
          psrld xmm11, xmm12 ; xmm11 = | (p1-3 * value * 2^k + p2-3 * (1-value) * 2^k) / 2^k |

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
          movdqu [r14 + rsi], xmm5

          add rdx, 16 ; incremento en 16 (4 pixeles * 4 bytes c/u) el contador_columna
          cmp rdx, r9
          jl .ciclo_columna

      inc rcx	; Incremento el contador de filas
      cmp rcx, r13; Me fijo si termine las filas
      jl .ciclo_fila
  ;*******
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  add rsp, 8
  pop rbp
  ret

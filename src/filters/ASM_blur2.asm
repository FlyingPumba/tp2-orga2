; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion Blur 2                                     ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_blur2( uint32_t w, uint32_t h, uint8_t* data )
global ASM_blur2
extern malloc
extern free

%define PIXEL_SIZE              4 ; en bytes
%define OFFSET_ALPHA 			0
%define OFFSET_RED              1
%define OFFSET_GREEN            2
%define OFFSET_BLUE             3

section .rodata
    mascara_limpiar: dw 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0x0, 0x0, 0x0, 0x0
    division_9: dd 9.0, 9.0, 9.0, 9.0

section .text
ASM_blur2:
    push rbp
    mov rbp, rsp
    sub rsp, 8
    push rbx
    push r12
    push r13
    push r14
    push r15
    ;*******
    mov rbx, rdx ; rbx <- *data
    mov r12, rdi ; r12 <- width
    mov r13, rsi ; r13 <- height

    shl rdi, 2 ; rdi = width * 4
    call malloc
    mov r14, rax ; r14, vector auxiliar

    mov rdi, r12
    shl rdi, 2 ; rdi = width * 4
    call malloc
    mov r15, rax ; r15, vector auxiliar

    mov r8, r12
    shl r8, 2 ; r8 = width * 4 (ancho en bytes de la imagen)

    ;copio la primera fila en [r15], para preservar la fila procesada en cada ciclo
    xor rdi, rdi
    .ciclo_vectores_inicial:
        cmp rdi, r8
        jge .procesar_fila
        movdqu xmm0, [rbx + rdi] ; copio 4 pixeles
        movdqu [r15 + rdi], xmm0 ; pego 4 pixeles
        lea rdi, [rdi + 4*PIXEL_SIZE]
        jmp .ciclo_vectores_inicial

    .procesar_fila:
    xor rcx, rcx ; contador de filas (en pixeles)
    .ciclo_fila:
        ; preparo rdi como registro auxiliar para levantar datos
        mov rax, r8 ; rax = width * 4
        mul rcx ; rax = contador_filas * width * 4
        mov rdi, rax ; rdi = contador_filas * width * 4 (offset de fila actual)

        ; cargo los nuevos vectores auxiliares
        xor rdx, rdx ; contador de columnas (en bytes)

        ;pongo en [r14] los datos de la fila anterior, para eso, intercambio los punteros de r14 y r15
        mov r9, r15
        mov r15, r14
        mov r14, r9

        ;pongo en [r15] los datos de la fila actual
        lea rax, [rbx + rdi] ; rax apunta a donde empieza la fila actual
        add rax, r8 ; rax = rax + width * 4 = fila siguiente
        .ciclo_vectores_nuevos:
            cmp rdx, r8
            jge .procesar_columna ; if (contador_columnas) >= ancho_imagen

            ; cargo el nuevo pixel correspondiente en el vector auxiliar de una fila mas arriba que la actual
            movdqu xmm0, [rax + rdx] ; copio 4 pixeles de la fila actual en xmm0
            movdqu [r15 + rdx], xmm0 ; los paso al vector de r15

            lea rdx, [rdx + 4*PIXEL_SIZE] ; aumento el indice segun los 4 pixeles
            jmp .ciclo_vectores_nuevos

        .procesar_columna:
        xor rdx, rdx ; contador de columnas (en bytes)
        .ciclo_columna:
            lea rsi, [rdi +rdx] ; rsi = contador_columnas (bytes) + (contador_filas * width * 4)(bytes)
            lea rsi, [rsi + 2*r8] ; rsi = dos filas mas adelante que rdi (una mas que la actual)
            ; vamos a cargar una matriz de pixeles
            movdqu xmm0, [r14 + rdx] ; xmm0 = | p14 | p13 | p12 | p11 |
            movdqu xmm1, [r15 + rdx] ; xmm1 = | p24 | p23 | p22 | p21 |
            movdqu xmm2, [rbx + rsi] ; xmm2 = | p34 | p33 | p32 | p31 |
            movdqu xmm3, [r14 + rdx+ 2*PIXEL_SIZE] ; xmm3 = | p16 | p15 | p14 | p13 |
            movdqu xmm4, [r15 + rdx+ 2*PIXEL_SIZE] ; xmm4 = | p26 | p25 | p24 | p23 |
            movdqu xmm5, [rbx + rsi+ 2*PIXEL_SIZE] ; xmm5 = | p36 | p35 | p34 | p33 |

            ; ahora convierto todos los canales de 1 byte a canales de 2 bytes, para realizar las sumas sin romper nada.
            ; entonces, cada pixel va a pasar a medir 8 bytes (64bits) en vez de 4 bytes

            pxor xmm15, xmm15 ; xmm15 = ceros

            movdqu xmm6, xmm0 ; xmm6 = | p14 | p13 | p12 | p11 |
            punpcklbw xmm0, xmm15
            punpckhbw xmm6, xmm15 ; xmm6 = | p14 | p13 | , xmm0 = | p12 | p11 |

            movdqu xmm7, xmm1 ; xmm7 = | p24 | p23 | p22 | p21 |
            punpcklbw xmm1, xmm15 
            punpckhbw xmm7, xmm15 ; xmm7 = | p24 | p23 | , xmm1 = | p22 | p21 |

            movdqu xmm8, xmm2 ; xmm8 = | p34 | p33 | p32 | p31 |
            punpcklbw xmm2, xmm15 
            punpckhbw xmm8, xmm15 ; xmm8 = | p34 | p33 | , xmm2 = | p32 | p31 |

            movdqu xmm9, xmm3
            punpckhbw xmm9, xmm15 ; xmm9 = | p16 | p15 |

            movdqu xmm10, xmm4
            punpckhbw xmm10, xmm15 ; xmm10 = | p26 | p25 |

            movdqu xmm11, xmm5
            punpckhbw xmm11, xmm15 ; xmm11 = | p36 | p35 |

            paddw xmm0, xmm1
            paddw xmm0, xmm2 ; xmm0 = | p12 + p22 + p32 | p11 + p21 + p31 |
            paddw xmm6, xmm7
            paddw xmm6, xmm8 ; xmm6 = | p14 + p24 + p34 | p13 + p23 + p33 |
            paddw xmm9, xmm10
            paddw xmm9, xmm11 ; xmm9 = | p16 + p26 + p36 | p15 + p25 + p35 |

            ;separo cada columna en registros cuyos canales son de 32 bits
            movdqu xmm1, xmm0
            punpcklwd xmm0, xmm15 ; xmm0 = |p11 + p21 + p31| = col1
            punpckhwd xmm1, xmm15 ; xmm1 = |p12 + p22 + p32| = col2
            movdqu xmm7, xmm6
            punpcklwd xmm6, xmm15 ; xmm6 = |p13 + p23 + p33| = col3
            punpckhwd xmm7, xmm15 ; xmm7 = |p14 + p24 + p34| = col4
            movdqu xmm10, xmm9
            punpcklwd xmm9, xmm15 ; xmm9 = |p15 + p25 + p35| = col5
            punpckhwd xmm10, xmm15 ; xmm10 = |p16 + p26 + p36| = col6

            ;sumo las columnas correspondientes para luego convertirlas a float y dividir
            paddd xmm0, xmm1
            paddd xmm0, xmm6 ; xmm0 = col1 + col2 + col3 = i1
            paddd xmm1, xmm6
            paddd xmm1, xmm7 ; xmm1 = col2 + col3 + col4 = i2
            paddd xmm6, xmm7
            paddd xmm6, xmm9 ; xmm6 = col3 + col4 + col5 = i3
            paddd xmm7, xmm9
            paddd xmm7, xmm10 ; xmm7 = col4 + col5 + col6 = i4

            ; convierto a floats SP para hacer la division, tengo 4 canales de 32 bits
            cvtdq2ps xmm0, xmm0 ; xmm0 = floats(i1) = f1
            cvtdq2ps xmm1, xmm1 ; xmm1 = floats(i2) = f2
            cvtdq2ps xmm2, xmm6 ; xmm2 = floats(i3) = f3
            cvtdq2ps xmm3, xmm7 ; xmm3 = floats(i4) = f4

            ; hago la division por 9 de cada canal
            movdqu xmm8, [division_9] ; xmm8 = | 9, 9, 9, 9 | (cada 9 es un float SP)
            divps xmm0, xmm8 ; xmm0 = f1 / 9
            divps xmm1, xmm8 ; xmm0 = f2 / 9
            divps xmm2, xmm8 ; xmm0 = f3 / 9
            divps xmm3, xmm8 ; xmm0 = f4 / 9

            ;convierto los resultados a int8
            cvtps2dq xmm0, xmm0 ; xmm0 = | pixel1 | , paso de floats a enteros de 32 bits
            packusdw xmm0, xmm15 ; xmm0 = | 0 | pixel1 | , paso a enteros de 16 bits
            packuswb xmm0, xmm15 ; xmm0 = | 0 | 0 | 0 | pixel1 | , paso a enteros de 8 bits
            cvtps2dq xmm1, xmm1 ; xmm1 = | pixel2 | , paso de floats a enteros de 32 bits
            packusdw xmm1, xmm15 ; xmm1 = | 0 | pixel2 | , paso a enteros de 16 bits
            packuswb xmm1, xmm15 ; xmm1 = | 0 | 0 | 0 | pixel2 | , paso a enteros de 8 bits
            cvtps2dq xmm2, xmm2 ; xmm2 = | pixel3 | , paso de floats a enteros de 32 bits
            packusdw xmm2, xmm15 ; xmm2 = | 0 | pixel3 | , paso a enteros de 16 bits
            packuswb xmm2, xmm15 ; xmm2 = | 0 | 0 | 0 | pixel3 | , paso a enteros de 8 bits
            cvtps2dq xmm3, xmm3 ; xmm3 = | pixel4 | , paso de floats a enteros de 32 bits
            packusdw xmm3, xmm15 ; xmm3 = | 0 | pixel4 | , paso a enteros de 16 bits
            packuswb xmm3, xmm15 ; xmm3 = | 0 | 0 | 0 | pixel4 | , paso a enteros de 8 bits

            ;combino los cuatro pixeles resultado en xmm0
            pslldq xmm1, 4 ; xmm1 = | 0 | 0 | pixel2 | 0 |
            pslldq xmm2, 8 ; xmm2 = | 0 | pixel3 | 0 | 0 |
            pslldq xmm3, 12 ; xmm3 = | pixel4 | 0 | 0 | 0 |
            por xmm0, xmm1 ; xmm0 = | 0 | 0 | pixel2 | pixel1 |
            por xmm0, xmm2 ; xmm0 = | 0 | pixel3 | pixel2 | pixel1 |
            por xmm0, xmm3 ; xmm0 = | pixel4 | pixel3 | pixel2 | pixel1 |

            add rsi, PIXEL_SIZE ; incremento la columna en uno
            sub rsi, r8 ; vuelvo a ubicar rsi en la fila actual de la matriz

            lea rdx, [rdx + 4*PIXEL_SIZE] ; sumo al contador_columna la cantidad de bytes que procese en esta vuelta
            cmp rdx, r8
            jge .ultimas_columnas
            movdqu [rbx + rsi], xmm0 ; muevo | pixel4 | pixel3 | pixel2 | pixel1 | a la matriz
            jmp .ciclo_columna
            .ultimas_columnas
            movq [rbx + rsi], xmm0 ; muevo | pixel2 | pixel1 | a la matriz

            inc rcx	; Incremento el contador de filas

            mov rax, r13
            sub rax, 2
			cmp rcx, rax; Me fijo si termine las filas
			je .fin
			jmp .ciclo_fila

    .fin:
    mov rdi, r14
    call free

    mov rdi, r15
    call free
    ;*******
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    add rsp, 8
    pop rbp
    ret

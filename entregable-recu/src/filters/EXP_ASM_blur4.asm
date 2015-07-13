; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion Alternativa de la funcion Blur 1                                     ;
;                                                                           ;
; ************************************************************************* ;

; void EXP_ASM_blur4( uint32_t w, uint32_t h, uint8_t* data )
global EXP_ASM_blur4
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
    unpckl8a16: db 0x00, 0xFF, 0x01, 0xFF, 0x02, 0xFF, 0x03, 0xFF, 0x04, 0xFF, 0x05, 0xFF, 0x06, 0xFF, 0x07, 0xFF
    unpckh8a16: db 0x08, 0xFF, 0x09, 0xFF, 0x0A, 0xFF, 0x0B, 0xFF, 0x0C, 0xFF, 0x0D, 0xFF, 0x0E, 0xFF, 0x0F, 0xFF

section .text
EXP_ASM_blur4:
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

    mov r9, r8
    sub r9, 8; r9 = width * 4 - 8 (ancho en bytes a recorrer)

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
        mov rax, r15
        mov r15, r14
        mov r14, rax

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
        movdqu xmm13, [unpckl8a16] ; xmm13 tiene la mascara especial para pasar la parte baja de un registro de int 8b a int 16b
        movdqu xmm12, [unpckh8a16] ; xmm12 tiene la mascara especial para pasar la parte alta de un registro de int 8b a int 16b
        .ciclo_columna:
            ; vamos a cargar una matriz de pixeles, que en memoria se veria:
            ; | p0 | p1 | p2 |
            ; | p3 | p4 | p5 |
            ; | p6 | p7 | p8 |
            ; (los numeros son simplemente indicativos, no indican precedencia)

            ; antes, me fijo si llegue al caso especial del ultimo pixel a procesar
            ; en este caso no puedo levantar asi nomas 128 bits, porque me puedo ir del array
            lea rax, [r9 - PIXEL_SIZE]
            cmp rdx, rax
            jne .levantar_pixel_normal
            ; estamos en el ultimo pixel
            mov rax, rdx
            sub rax, PIXEL_SIZE ; rax = contador_columnas - 4 bytes (1 pixel)

            lea rsi, [rdi +rax] ; rsi = contador_columnas (bytes) + (contador_filas * width * 4)(bytes)
            lea rsi, [rsi + 2*r8] ; rsi = dos filas mas adelante que rdi (una mas que la actual)

            ; posicion del pixel en la columna:  w   w-1  w-2    w-3
            movdqu xmm0, [r14 + rax] ; xmm0 = | p2 | p1 | p0 | basura |
            movdqu xmm1, [r15 + rax] ; xmm1 = | p5 | p4 | p3 | basura |
            movdqu xmm2, [rbx + rsi] ; xmm2 = | p8 | p7 | p6 | basura |
            psrldq xmm0, 4 ; xmm0 = | ceros | p2 | p1 | p0 |
            psrldq xmm1, 4 ; xmm1 = | ceros | p5 | p4 | p3 |
            psrldq xmm2, 4 ; xmm2 = | ceros | p8 | p7 | p6 |

            ; antes de empezar a procesar, pongo rsi como si hubieramos levantado un pixel normal
            ; para que al bajar a memoria la posicion sea correcta
            lea rsi, [rdi +rdx] ; rsi = contador_columnas (bytes) + (contador_filas * width * 4)(bytes)
            lea rsi, [rsi + 2*r8] ; rsi = dos filas mas adelante que rdi (una mas que la actual)
            jmp .procesar_pixel

            .levantar_pixel_normal:
            lea rsi, [rdi +rdx] ; rsi = contador_columnas (bytes) + (contador_filas * width * 4)(bytes)
            lea rsi, [rsi + 2*r8] ; rsi = dos filas mas adelante que rdi (una mas que la actual)
            movdqu xmm0, [r14 + rdx] ; xmm0 = | basura | p2 | p1 | p0 |
            movdqu xmm1, [r15 + rdx] ; xmm1 = | basura | p5 | p4 | p3 |
            movdqu xmm2, [rbx + rsi] ; xmm2 = | basura | p8 | p7 | p6 |

            .procesar_pixel:
            ; ahora convierto todos los canales de 1 byte a canales de 2 bytes, para realizar las sumas sin romper nada.
            ; entonces, cada pixel va a pasar a medir 8 bytes (64bits) en vez de 4 bytes
            pxor xmm7, xmm7 ; xmm7 = ceros
            movdqu xmm3, xmm0 ; xmm3 = | basura | p2 | p1 | p0 |
            pshufb xmm0, xmm13 ; xmm0 = | p1 | p0 |
            pshufb xmm3, xmm12 ; xmm3 = | basura | p2 |

            movdqu xmm4, xmm1 ; xmm4 = | basura | p5 | p4 | p3 |
            pshufb xmm1, xmm13 ; xmm1 = | p4 | p3 |
            pshufb xmm4, xmm12 ; xmm4 = | basura | p5 |

            movdqu xmm5, xmm2 ; xmm5 = | basura | p8 | p7 | p6 |
            pshufb xmm2, xmm13 ; xmm2 = | p7 | p6 |
            pshufb xmm5, xmm12 ; xmm5 = | basura | p8 |

            paddw xmm0, xmm1 ; xmm0 = | p1 + p4 | p0 + p3 |
            paddw xmm0, xmm2 ; xmm0 = | p1 + p4 + p7 | p0 + p3 + p6 |
            paddw xmm3, xmm4 ; xmm3 = | basura | p2 + p5 |
            paddw xmm3, xmm5 ; xmm3 = | basura | p2 + p5 + p8 |

            ; limpio la basura en xmm3 para poder sumar tranqui
            movdqu xmm8, [mascara_limpiar] ; xmm8 = | 0 | 0 | 0 | 0 | F | F | F |F |
            pand xmm3, xmm8 ; xmm3 = | ceros | p2 + p5 + p8 |

            ; sumo tranqui
            paddw xmm0, xmm3 ; xmm0 = | p1 + p4 + p7 | p0 + p3 + p6 + p2 + p5 + p8 |
            movdqu xmm3, xmm0 ; xmm3 = | p1 + p4 + p7 | p0 + p3 + p6 + p2 + p5 + p8 |
            psrldq xmm0, 8 ; xmm0 = | ceros | p1 + p4 + p7 |
            paddw xmm0, xmm3 ; xmm0 = | basura | p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8 |

            ; convierto a floats SP para hacer la division, tengo 4 canales de 32 bits
            punpcklwd xmm0, xmm7 ; xmm0 = | p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8 |
            cvtdq2ps xmm0, xmm0 ; xmm0 = | p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8 |

            ; hago la division por 9 de cada canal
            movdqu xmm8, [division_9] ; xmm8 = | 9, 9, 9, 9 | (cada 9 es un float SP)
            divps xmm0, xmm8 ; xmm0 = | (p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8) / 9 |

            ; paso devuelta a enteros de 32 bits:
            cvtps2dq xmm0, xmm0 ; xmm0 = | (p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8) / 9 |
            ; paso a enteros de 16 bits
            packusdw xmm0, xmm7 ; xmm0 = | basura | (p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8) / 9 |
            ; paso a enteros de 8 bits
            packuswb xmm0, xmm7 ; xmm0 = | basura | basura | basura | (p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8) / 9 |

            add rsi, PIXEL_SIZE ; incremento la columna en uno
            sub rsi, r8 ; vuelvo a ubicar rsi en la fila del centro de la matriz
            movd [rbx + rsi], xmm0 ; muevo el resultado al centro de la matriz

            add rdx, PIXEL_SIZE ; sumo al contador_columna la cantidad de bytes que procese en esta vuelta (1 pixel)
            cmp rdx, r9
            jl .ciclo_columna

            inc rcx	; Incremento el contador de filas

            mov rax, r13
            sub rax, 2
			cmp rcx, rax; Me fijo si termine las filas
			jge .fin
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

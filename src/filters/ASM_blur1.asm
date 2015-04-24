; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion Blur 1                                     ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_blur1( uint32_t w, uint32_t h, uint8_t* data )
global ASM_blur1
extern malloc
extern free

%define PIXEL_SIZE              4 ; en bytes
%define OFFSET_ALPHA 			0
%define OFFSET_RED              1
%define OFFSET_GREEN            2
%define OFFSET_BLUE             3

section .rodata
    mascara_limpiar: dw 0xF, 0xF, 0xF, 0xF, 0x0, 0x0, 0x0, 0x0
    division_9: dw 0x9, 0x9, 0x9, 0x9, 0x1, 0x1, 0x1, 0x1

section .text
ASM_blur1:
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
    mov r14, rax ; r0, vector auxiliar

    mov rdi, r12
    shl rdi, 2 ; rdi = width * 4
    call malloc
    mov r15, rax ; r1, vector auxiliar

    mov r8, r12
    shl r8, 2 ; r8 = width * 4 (ancho en bytes de la imagen)

    mov r9, r8
    sub r9, 8; r9 = width * 4 - 8 (ancho en bytes a recorrer)

    xor rcx, rcx ; contador de filas (en pixeles)
    .ciclo_fila:
        xor rdx, rdx ; contador de columnas (en bytes)

        ; preparo rdi como registro auxiliar para levantar datos
        mov rax, r8
        mul rcx
        mov rdi, rax ; rdi = contador_filas * width * 4
        .ciclo_columna:
            mov rsi, rdx
            add rsi, rdi ; rsi = contador_columnas (bytes) + (contador_filas * width * 4)(bytes)
            ; vamos a cargar una matriz de pixeles, que en memoria se veria:
            ; | p0 | p1 | p2 |
            ; | p3 | p4 | p5 |
            ; | p6 | p7 | p8 |
            ; (los numeros son simplemente indicativos, no indican precedencia)
            movdqu xmm0, [rbx + rsi] ; xmm0 = | basura | p2 | p1 | p0 |
            add rsi, r8 ; rsi = rsi + width*4
            movdqu xmm1, [rbx + rsi] ; xmm1 = | basura | p5 | p4 | p3 |
            add rsi, r8 ; rsi = rsi + width*4
            movdqu xmm2, [rbx + rsi] ; xmm2 = | basura | p8 | p7 | p6 |

            ; ahora convierto todos los canales de 1 byte a canales de 2 bytes, para realizar las sumas sin romper nada.
            ; entonces, cada pixel va a pasar a medir 8 bytes (64bits)

            pxor xmm7, xmm7 ; xmm7 = ceros
            movdqu xmm3, xmm0 ; xmm3 = xmm0
            punpcklbw xmm0, xmm7 ; xmm0 = | p1 | p0 |
            punpckhbw xmm3, xmm7 ; xmm3 = | basura | p2 |

            pxor xmm7, xmm7 ; xmm7 = ceros
            movdqu xmm4, xmm1 ; xmm4 = xmm1
            punpcklbw xmm1, xmm7 ; xmm1 = | p4 | p3 |
            punpckhbw xmm4, xmm7 ; xmm4 = | basura | p5 |

            pxor xmm7, xmm7 ; xmm7 = ceros
            movdqu xmm5, xmm2 ; xmm5 = xmm2
            punpcklbw xmm2, xmm7 ; xmm2 = | p7 | p6 |
            punpckhbw xmm5, xmm7 ; xmm5 = | basura | p8 |

            paddw xmm0, xmm1 ; xmm0 = | p1 + p4 | p0 + p3 |
            paddw xmm0, xmm2 ; xmm0 = | p1 + p4 + p7 | p0 + p3 + p6 |
            paddw xmm3, xmm4 ; xmm3 = | basura | p2 + p5 |
            paddw xmm3, xmm5 ; xmm3 = | basura | p2 + p5 + p8 |

            ; limpio la basura en xmm3 para poder supar tranqui
            movdqu xmm8, [mascara_limpiar]
            pand xmm3, xmm8 ; xmm3 = | ceros | p2 + p5 + p8 |
            paddw xmm0, xmm3 ; xmm0 = | p1 + p4 + p7 | p0 + p3 + p6 + p2 + p5 + p8 |
            movdqu xmm3, xmm0 ; xmm3 = | p1 + p4 + p7 | p0 + p3 + p6 + p2 + p5 + p8 |
            psrldq xmm0, 8 ; xmm0 = | ceros | p1 + p4 + p7 |
            paddw xmm0, xmm3 ; xmm0 = | ceros | p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8 |

            ; convierto a floats SP para hacer la division, tengo 4 canales de 32 bits
            pxor xmm7, xmm7 ; xmm7 = ceros
            punpcklwd xmm0, xmm7 ; xmm0 = | p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8 |
            cvtdq2ps xmm0, xmm0 ; xmm0 = | p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8 |

            ; hago la division por 9 de cada canal
            movdqu xmm8, [division_9]
            divps xmm0, xmm8 ; xmm0 = | (p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8) / 9 |

            ; paso devuelta a enteros de 32 bits:
            cvtps2dq xmm0, xmm0 ; xmm0 = | (p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8) / 9 |
            ; paso a enteros de 16 bits
            pxor xmm7, xmm7 ; xmm7 = ceros
            packssdw xmm0, xmm7 ; xmm0 = | basura | (p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8) / 9 |
            ; paso a enteros de 8 bits
            packsswb xmm0, xmm7 ; xmm0 = | basura | basura | basura | (p1 + p4 + p7 + p0 + p3 + p6 + p2 + p5 + p8) / 9 |

            add rsi, PIXEL_SIZE ; incremento la columna en uno
            sub rsi, r8 ; vuelvo a ubicar rsi en la fila del centro de la matriz
            movd [rbx + rsi], xmm0 ; muevo el resultado al centro de la matriz

            add rdx, 4 ; sumo al contador_columna la cantidad de bytes que procese en esta vuelta
            cmp rdx, r9
            jl .ciclo_columna

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

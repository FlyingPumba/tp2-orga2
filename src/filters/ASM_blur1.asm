; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion Blur 1                                     ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_blur1( uint32_t w, uint32_t h, uint8_t* data )
global ASM_blur1
%define PIXEL_SIZE              4 ; en bytes
%define OFFSET_ALPHA 			0
%define OFFSET_RED              1
%define OFFSET_GREEN            2
%define OFFSET_BLUE             3
ASM_blur1:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    ;*******
    mov r12, rdi ; r12 <- width
    mov r13, rsi ; r13 <- height
    mov rbx, rdx ; rbx <- *data

    sub QWORD rdi, 2 ; resto dos al ancho para no tener en cuenta el borde
    sub QWORD rsi, 2 ; resto dos al alto para no tener en cuenta el borde
    shl rdi, 2 ; multiplico rdi por 4
    shl rsi, 2 ; multiplico rsi por 4
    shl r12, 2 ; multiplico r12 por 4

    mov rdx, rdi
    add rdx, rsi ; rdx <- cantidad de bytes que tengo que recorrer

    xor rcx, rcx
    add rcx, PIXEL_SIZE ; empiezo en el segundo pixel
    .ciclo:
        cmp rcx, rdx
        je .ciclo_fin
    	lea rdi, [rbx + rcx]  ;rdi es donde empieza la matriz de 3x3: (0,0)
        ; la matriz es:
        ; | p0 | p1 | p2 |
        ; | p3 | p4 | p5 |
        ; | p6 | p7 | p8 |
        movdqu xmm0, [rdi] ; xmm0 = | basura | p2 | p1 | p0 |
        movdqu xmm1, [rdi + 1*r12] ; xmm1 = | basura | p5 | p4 | p3 |
        movdqu xmm2, [rdi + 2*r12] ; xmm2 = | basura | p8 | p7 | p6 |

        ; dos formas: shuffle vs. punpck

        ; ahora convierto todos los canales de 1 byte a canales de 2 bytes, para realizar las sumas sin romper nada.
        ; entonces, cada pixel va a pasar a medir 8 bytes (64b)

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
        paddw xmm0, mm2 ; xmm0 = | p1 + p4 + p7 | p0 + p3 + p6 |
        paddw xmm3, xmm4 ; xmm3 = | basura | p2 + p5 |
        paddw xmm3, xmm5 ; xmm3 = | basura | p2 + p5 + p7 |

        paddb xmm0, xmm1 ; suma de a bytes. xmm0 = | p0 + p3 | p1 + p4 | p2 + p5 | basura |
        paddb xmm0, xmm2 ; suma de a bytes. xmm0 = | p0 + p3 + p6 | p1 + p4 + p7 | p2 + p5 + p8 | basura |

        movdqu xmm1, xmm0 ; xmm1 = xmm0
        pslldq xmm1, 4 ; shift 4 bytes. xmm1 = | p1 + p4 + p7 | p2 + p5 + p8 | basura | ceros |
        paddb xmm0, xmm1 ; suma de a bytes. xmm0 = | p0 + p3 + p6 + p1 + p4 + p7 | basura | basura | basura |
        pslldq xmm1, 4 ; shift 4 bytes. xmm1 = | p2 + p5 + p8 | basura | ceros | ceros |
        paddb xmm0, xmm1 ; deja en los 4 bytes mas altos de xmm0 la sumatoria de los 9 pixeles
        ; xmm0 = | p0 + p3 + p6 + p1 + p4 + p7 + p2 + p5 + p8 | basura | basura | basura |

        mov QWORD rdi, 0x9999000000000000
        movq xmm1, rdi
        pslldq xmm1, 8 ; shift 4 bytes

        divss xmm0, xmm1 ; aca quiero packed. no scalar

        psrldq xmm0, 12 ; muevo el pixel a la parte baja de xmm0
        movq xmm0, rsi
        lea rdi, [rbx + rcx]  ;rdi es donde empieza la matriz de 3x3: (0,0)
        mov [rdi + r12 + PIXEL_SIZE], esi ; muevo el resultado al centro de la matriz

        add rcx, PIXEL_SIZE
        jmp .ciclo
    .ciclo_fin:
    ;*******
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

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

    mov r9, r12
    sub QWORD r9, 2
    shl r9, 2 ; r9 = (width - 2) * 4

    mov rax, r12 ; rax = width
    mul rsi
    shl rax, 2 ; rax = 4 * width * height
    mov rdx, rax ; rdx = 4 * width * height
    sub rdx, r12
    sub rdx, r12 ; rdx = 4 * width * height - 2 * width

    xor rcx, rcx ; contador de pixeles overall
    xor r8, r8 ; contador de pixeles a lo ancho

    xor rdi, rdi
    .ciclo_vectores:
        cmp rdi, r12
        jge .ciclo
        lea rsi, [rbx + rdi]
        mov DWORD esi, [rsi + 1*r12] ; copio un pixel
        mov [r14 + rdi], esi ; pego un pixel
        lea rsi, [rbx + rdi]
        mov DWORD esi, [rsi + 2*r12] ; copio un pixel del siguiente
        mov [r15 + rdi], esi ; pego un pixel
        add rdi, PIXEL_SIZE
        jmp .ciclo_vectores

    .ciclo:
        cmp r8, r9
        jl .procesar
        add rcx, 2*PIXEL_SIZE ; avanzo 2 pixeles, 1 por la fila actual y 1 por la siguiente fila
        xor r8, r8
    .procesar:
        cmp rcx, rdx
        jge .ciclo_fin
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

        lea rdi, [rbx + rcx]  ;rdi es donde empieza la matriz de 3x3: (0,0)
        movd [rdi + r12 + PIXEL_SIZE], xmm0 ; muevo el resultado al centro de la matriz

        add rcx, PIXEL_SIZE
        add r8, PIXEL_SIZE
        jmp .ciclo
    .ciclo_fin:
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

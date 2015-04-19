; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion Blur 1                                     ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_blur1( uint32_t w, uint32_t h, uint8_t* data )
global ASM_blur1
%define PIXEL_SIZE              32
%define OFFSET_ALPHA 			0 ; no se si estos offsets son corrects
%define OFFSET_RED              8
%define OFFSET_GREEN            16
%define OFFSET_BLUE             24
ASM_blur1:
    push rbp
    mov rbp, rsp
    sub rsp, 8
    push rbx
    push r12
    push r13
    ;*******
    mov r12, rdi ; r12 <- width
    mov r13, rsi ; r13 <- height
    mov rbx, rdx ; rbx <- *data

    sub QWORD rdi, 2 ; resto dos al ancho para no tener en cuenta el borde
    sub QWORD rsi, 2 ; resto dos al alto para no tener en cuenta el borde
    mov rax, PIXEL_SIZE
    mul rdi
    mov rdi, rax ; rdi <- (ancho-2) * tamaño pixel en bytes
    mov rax, PIXEL_SIZE
    mul rsi
    mov rsi, rax ; rsi <- (alto-2) * tamaño pixel en bytes
    mov rax, PIXEL_SIZE
    mul r12
    mov rdi, rax ; rdi <- ancho * tamaño pixel en bytes

    mov rdx, rdi
    add rdx, rsi ; rdx <- cantidad de bytes que tengo que recorrer

    xor rcx, rcx
    add rcx, PIXEL_SIZE ; empiezo en el segundo pixel
    .ciclo:
        cmp rcx, rdx
        je .ciclo_fin
    	lea rdi, [rbx + rcx]  ;rdi es donde empieza la matriz de 3x3: (0,0)
        movdqu xmm0, [rdi] ; cargo primeros 3/9 pixeles
        movdqu xmm1, [rdi + 1*r12] ; cargo segundos 3/9 pixeles
        movdqu xmm2, [rdi + 2*r12] ; cargo terceros 3/9 pixeles

        paddb xmm0, xmm1 ; suma de a bytes
        paddb xmm0, xmm2 ; suma de a bytes

        movdqu xmm1, xmm0
        pslldq xmm1, 4 ; shift 4 bytes
        paddb xmm0, xmm1
        pslldq xmm1, 4 ; shift 4 bytes
        paddb xmm0, xmm1 ; deja en los 4 bytes mas altos de xmm0 la sumatoria de los 9 pixeles

        mov QWORD rdi, 0x9999000000000000
        movq xmm1, rdi
        pslldq xmm1, 8 ; shift 4 bytes

        divss xmm0, xmm1

        psrldq xmm0, 12 ; muevo el pixel a la parte baja de xmm0
        movq xmm0, rsi
        lea rdi, [rbx + rcx]  ;rdi es donde empieza la matriz de 3x3: (0,0)
        mov [rdi + r12 + PIXEL_SIZE], esi ; muevo el resultado al centro de la matriz

        add rcx, PIXEL_SIZE
        jmp .ciclo
    .ciclo_fin:
    ;*******
    pop r13
    pop r12
    pop rbx
    add rsp, 8
    pop rbp
    ret

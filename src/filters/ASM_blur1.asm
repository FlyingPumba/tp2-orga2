; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion Blur 1                                     ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_blur1( uint32_t w, uint32_t h, uint8_t* data )
global ASM_blur1
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

    sub QWORD r12, 2 ; resto dos al ancho para no tener en cuenta el borde
    sub QWORD r13, 2 ; resto dos al alto para no tener en cuenta el borda

    xor rcx, rcx ; rcx <- contador de fila
    add rcx, 32 ; empiezo en el segundo pixel
    .ciclo_fila:
        cmp QWORD r12, 0
        je .fin_fila
    	xor rdx, rdx ; rdx <- contador de columna
    	add rdx, 32 ; empiezo en el segundo pixel
    	lea rdi, [rbx + rcx*r13 + rdx] ; rdi <- i*height + j
        .ciclo_columna:
            movups xmm0, [rdi] ; cargo primeros 3/9 pixeles
            movups xmm1, [rdi + 1*height] ; cargo primeros 6/9 pixeles
            movups xmm2, [rdi + 2*height] ; cargo primeros 9/9 pixeles

        jmp .ciclo_fila
    ;*******
    pop r13
    pop r12
    pop rbx
    add rsp, 8
    ret
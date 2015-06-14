; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion HSL 1                                      ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_hsl1(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll)
global ASM_hsl1

extern rgbTOhsl
extern hslTOrgb

%define RGB_PIXEL_SIZE     	4
%define RGB_OFFSET_ALPHA 	0
%define RGB_OFFSET_RED      1
%define RGB_OFFSET_GREEN    2
%define RGB_OFFSET_BLUE     3

%define HSL_PIXEL_SIZE 		16
%define HSL_OFFSET_ALPHA 	0
%define HSL_OFFSET_HUE		4
%define HSL_OFFSET_SAT		8
%define HSL_OFFSET_LUM		12

%define FALSE	0

section .rodata

hsl_max_dato: dd 1.0,360.0,1.0,1.0

section .text

ASM_hsl1:
	;stack frame
	push rbp
	mov rbp, rsp
	push r15
	push rbx
	sub rsp, 32
	;*****

	mov rbx, rdx ; rbx = *data (aumenta en cada ciclo)

	pslldq xmm0, 4 ; xmm0 |0.0|0.0|HH|0.0|
	pslldq xmm1, 8 ; xmm1 |0.0|SS|0.0|0.0|
	pslldq xmm2, 12 ; xmm2 |LL|0.0|0.0|0.0|
	por xmm1, xmm0
	por xmm2, xmm1; xmm2 |LL|SS|HH|0.0|
	movdqu [rsp+16], xmm2

	mov rax, rdi ; rax = w
	mul rsi ; rax = w * h
	mov rsi, RGB_PIXEL_SIZE ; rsi = RGB_PIXEL_SIZE
	mul rsi ; rax = w * h * RGB_PIXEL_SIZE = *data.size()
	add rax, rbx ; rax = *data.end()
	mov r15, rax ; r15 = *data.end()

	.ciclo:
		cmp rbx, r15
		jge .fin

		; paso el pixel actual a HSL
		mov rdi, rbx ; rdi = *(pixel_actual)
		mov rsi, rsp ; rsi = (address_hsl)
		call rgbTOhsl ; [rsp] = |a|h|s|l|

		; preparo los datos de la suma
		movdqu xmm0, [rsp] ; xmm0 = |l|s|h|a|

		; consigo los parametros de entrada
		movdqu xmm1, [rsp+16] ; xmm1 = |LL|SS|HH|0.0|

		; hago la suma de floats
		addps xmm0, xmm1 ; xmm0 = |l+LL|s+SS|h+HH|a|
		movdqu xmm2, xmm0 ; xmm2 = |l+LL|s+SS|h+HH|a| (temporal)

		.check:

			movups xmm6, [hsl_max_dato]; xmm6 = |1|1|360|1|
			minps xmm0, xmm6 ; me aseguro que los 4 floats de xmm0 no se pasen del maximo
			pxor xmm7, xmm7; xmm7 = |0|0|0|0|
			maxps xmm0, xmm7 ; me aseguro que los 4 floats de xmm0 no sean menores que el minimo

			psrldq xmm0, 4; xmm0 = |0|l+LL|s+SS|h+HH|
			movd [rsp+HSL_OFFSET_HUE], xmm0
			psrldq xmm0, 4; xmm0 = |0|0|l+LL|s+SS|
			movd [rsp+HSL_OFFSET_SAT], xmm0
			psrldq xmm0, 4; xmm0 = |0|0|0|l+LL|
			movd [rsp+HSL_OFFSET_LUM], xmm0

			psrldq xmm2, 4; xmm2 = |0|l+LL|s+SS|h+HH|
			movdqu xmm3, xmm2; xmm3 = |0|l+LL|s+SS|h+HH|
			movdqu xmm4, xmm2; xmm4 = |0|l+LL|s+SS|h+HH|
			psrldq xmm6, 4; xmm6 = |0|1|1|360|

			.check_max:
			cmpltss xmm2, xmm6 ; xmm0 = |basura...|h < max_h| (bool)
			movd eax, xmm2
			cmp eax, FALSE
			jne .check_min
			subss xmm3, xmm6
			movd [rsp+HSL_OFFSET_HUE], xmm3
			jmp .fin_ciclo

			.check_min:
			cmpnltss xmm4, xmm7 ; xmm0 = |basura...|h >= 0.0| (bool)
			movd eax, xmm4
			cmp eax, FALSE
			jne .fin_ciclo
			addss xmm3, xmm6
			movd [rsp+HSL_OFFSET_HUE], xmm3

		.fin_ciclo:

		;hago la conversion de HSL a RGB
		mov rdi, rsp ; *rdi = |a_valido|h_valido|s_valido|l_valido|
		mov rsi, rbx ; rsi = rbx
		call hslTOrgb ; *rbx = |a_final|r_final|g_final|b_final|

		;incremento el puntero para ir al proximo pixel
		add rbx, RGB_PIXEL_SIZE ; rbx = *(proximo_pixel)
		jmp .ciclo

	.fin:
	;*****
	add rsp, 32
	pop rbx
	pop r15
	pop rbp
	ret

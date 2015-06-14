; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion HSL 1                                      ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_hsl1_3(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll)
global ASM_hsl1_3

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

section .text

ASM_hsl1_3:
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
	movdqu [rsp+16], xmm2 ; [rsp+16] = |0.0|HH|SS|LL|

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
		; [rsp] = |a|h|s|l|
		movdqu xmm0, [rsp] ; xmm0 = |l|s|h|a|

		; consigo los parametros de entrada
		; [rsp+16] = |0.0|HH|SS|LL|
		movdqu xmm1, [rsp+16] ; xmm1 = |LL|SS|HH|0.0|

		addps xmm0, xmm1 ; xmm0 = |l+LL|s+SS|h+HH|a|

		mov eax, __float32__(0.0)
		mov edi, __float32__(1.0)
		mov esi, __float32__(360.0)

		movd xmm6, eax ; xmm6 = |basura|basura|basura|0.0|
		movd xmm7, edi ; xmm7 = |basura|basura|basura|1.0|
		movd xmm8, esi ; xmm8 = |basura|basura|basura|360.0|

		psrldq xmm0, 4; xmm0 = |0.0|l+LL|s+SS|h+HH|

		movdqu xmm4, xmm0; xmm4 = |0.0|l+LL|s+SS|h+HH|
		movdqu xmm5, xmm0; xmm5 = |0.0|l+LL|s+SS|h+HH|

		.check_max:

		cmpltss xmm4, xmm8 ; xmm4 = |basura...|h+HH < max_h| (bool)
		movd eax, xmm4
		cmp eax, FALSE
		jne .check_min
		subss xmm0, xmm8 ; xmm0 = |0.0|l+LL|s+SS|h+HH-360.0|
		jmp .seguir

		.check_min:

		cmpnltss xmm5, xmm6 ; xmm5 = |basura...|h+HH >= 0.0| (bool)
		movd eax, xmm5
		cmp eax, FALSE
		jne .seguir
		addss xmm0, xmm8 ; xmm0 = |0.0|l+LL|s+SS|h+HH+360.0|

		.seguir:

		movss DWORD [rsp+HSL_OFFSET_HUE], xmm0 ; [rsp] = |a|h_final|s|l|

		psrldq xmm0, 4; xmm0 = |0.0|0.0|l+LL|s+SS|

		minss xmm0, xmm7 ; me aseguro que no sea mayor a 1.0
		maxss xmm0, xmm6 ; me aseguro que no sea menor a 0.0

		movss DWORD [rsp+HSL_OFFSET_SAT], xmm0 ; [rsp] = |a|h_final|s_final|l|

		psrldq xmm0, 4; xmm0 = |0.0|0.0|0.0|l+LL|

		minss xmm1, xmm7 ; me aseguro que no sea mayor a 1.0
		maxss xmm1, xmm6 ; me aseguro que no sea menor a 0.0

		movss DWORD [rsp+HSL_OFFSET_LUM], xmm0 ; [rsp] = |a|h_final|s_final|l_final|

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

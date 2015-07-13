; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion HSL 1                                      ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_hsl1_4(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll)
global ASM_hsl1_4

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

ASM_hsl1_4:
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
		movaps xmm0, [rsp] ; xmm0 = |l|s|h|a|

		; consigo los parametros de entrada
		; [rsp+16] = |0.0|HH|SS|LL|
		movdqu xmm1, [rsp+16] ; xmm1 = |LL|SS|HH|0.0|

		; hago la suma de floats
		addps xmm0, xmm1 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
		movaps xmm5, xmm0 ; xmm5 = |l+LL|s+SS|h+HH|a| (donde guardo el dato respuesta)

		.check:

			pxor xmm1, xmm1; xmm1 = |0.0|0.0|0.0|0.0|
			maxps xmm5, xmm1; xmm5 = |max(l+LL,0.0)|max(s+SS,0.0)|max(h+HH,0.0)|max(a,0.0)| = |l2|s2|h2|a2|

			movups xmm1, [hsl_max_dato]; xmm1 = |1.0|1.0|360.0|1.0|
			minps xmm5, xmm1; xmm5 = |min(l2,1.0)|min(s2,1.0)|min(h2,360.0)|min(a2,1.0)| = |l3|s3|h3|a3|

		.check_max:

			psrldq xmm0, 4; xmm0 = |basura...|h+HH|
			psrldq xmm1, 4; xmm1 = |basura...|360.0|
			movaps xmm6, xmm0; xmm6 = |basura...|h+HH|

			cmpltss xmm0, xmm1 ; xmm0 = |basura...|h+HH < max_h| (bool)
			movd edi, xmm0 ; edi = h+HH < max_h

			cmp edi, FALSE
			jne .check_min

			; caso h+HH >= max_h
			subss xmm6, xmm1 ; xmm6[0] = h+HH-360.0 = h_valido
			insertps xmm5, xmm6, 0x10 ; xmm5[1] = h_valido
			jmp .fin_ciclo

		.check_min:

			movaps xmm0, xmm6; xmm0 = |basura...|h+HH|
			pxor xmm3, xmm3; xmm3 = |0.0|0.0|0.0|0.0|

			cmpnltss xmm0, xmm3 ; xmm0 = |basura...|h+HH >= 0.0| (bool)
			movd edi, xmm0; edi = h+HH >= 0.0

			cmp edi, FALSE
			jne .fin_ciclo

			; caso h+HH < 0.0
			addss xmm6, xmm1 ; xmm6[0] = h+HH+360.0 = h_valido
			insertps xmm5, xmm6, 0x10 ; xmm5[1] = h_valido

		.fin_ciclo:

		movaps [rsp], xmm5 ; [rsp] = |a_valido|h_valido|s_valido|l_valido|

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

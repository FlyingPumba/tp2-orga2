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

;checks
hsl_max_dato: dd 1.0, 360.0, 1.0, 1.0 ; |max_a|max_h|max_s|max_l|
hsl_min_dato: dd 0.0, 0.0, 0.0, 0.0 ; |0.0|0.0|0.0|0.0|
hsl_fix_dato: dd 0.0, 360.0, 0.0, 0.0 ; |0.0|360.0|0.0|0.0|

section .text

ASM_hsl1:
	;stack frame
	push rbp
	mov rbp, rsp
	push r14
	push r15
	push rbx
	sub rsp, 56
	;*****

	;
	; Variables en la pila:
	;
	; hsl_temp_dato: [rsp]
	; hsl_suma_dato: [rsp+16]
	; hsl_params_dato: [rsp+32]
	; rgb_result: [rsp+48]
	;

	mov rbx, rdx ; rbx = *data (aumenta en cada ciclo)

	pxor xmm4, xmm4 ; xmm4 |0.0|0.0|0.0|0.0|
	pslldq xmm0, 4 ; xmm0 |0.0|0.0|HH|0.0|
	pslldq xmm1, 8 ; xmm1 |0.0|SS|0.0|0.0|
	pslldq xmm2, 12 ; xmm2 |LL|0.0|0.0|0.0|
	por xmm4, xmm0
	por xmm4, xmm1
	por xmm4, xmm2 ; xmm4 = |LL|SS|HH|0.0|

	mov rax, rdi ; rax = w
	mul rsi ; rax = w * h
	mov rsi, RGB_PIXEL_SIZE ; rsi = RGB_PIXEL_SIZE
	mul rsi ; rax = w * h * RGB_PIXEL_SIZE = *data.size()
	add rax, rbx ; rax = *data.end()
	mov r15, rax ; r15 = *data.end()

	pxor xmm0, xmm0 ; xmm0 = zeros
	xor eax, eax ; eax = 0
	movdqu [rsp], xmm0 ; hsl_temp_dato: [rsp] = zeros(float)
	movdqu [rsp+16], xmm0 ; hsl_suma_dato: [rsp+16] = zeros(float)
	movdqu [rsp+32], xmm4 ; hsl_params_dato: [rsp+32] = |0.0|HH|SS|LL|
	mov dword [rsp+48], eax ; rgb_result: [rsp+48] = zeros(byte)

	.ciclo:
		cmp rbx, r15
		jge .fin

		; paso el pixel actual a HSL
		mov rdi, rbx ; rdi = *(pixel_actual)
		mov rsi, rsp ; rsi = (address_hsl)
		call rgbTOhsl ; [rsp] = |a|h|s|l|

		; preparo los datos de la suma
		movdqu xmm0, [rsp] ; xmm0 = |l|s|h|a|
		movdqu xmm1, [rsp+32] ; xmm1 = |LL|SS|HH|0.0|

		; hago la suma de floats
		addps xmm0, xmm1 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)

		; uso xmm3 para comparar y fixear el HUE resultante
		pxor xmm3, xmm3
		mov eax, __float32__(360.0)
		movd xmm3, eax ; xmm3 = |0.0|0.0|0.0|360.0|

		movdqu xmm2, xmm0 ; xmm2 = |l+LL|s+SS|h+HH|a| (temporal para guardar el valor original de xmm0)
		movdqu xmm5, xmm0 ; xmm5 = |l+LL|s+SS|h+HH|a| (donde guardo el dato)

		.check:

			pxor xmm1, xmm1; xmm1 = |0.0|0.0|0.0|0.0|
			maxps xmm5, xmm1; xmm5 = |max(l+LL,0.0)|max(s+SS,0.0)|max(h+HH,0.0)|max(a,0.0)| = |l2|s2|h2|a2|

			movdqu xmm1, [hsl_max_dato]; xmm1 = |1.0|1.0|360.0|1.0|
			minps xmm5, xmm1; xmm5 = |min(l2,1.0)|min(s2,1.0)|min(h2,360.0)|min(a2,1.0)| = |l3|s3|h3|a3|

			pslldq xmm3, 4; xmm3 = |0.0|0.0|360.0|0.0|

		.check_max:

			psrldq xmm0, 4; xmm0 = |basura...|h+HH|
			psrldq xmm1, 4; xmm1 = |basura...|360.0|
			cmpltss xmm0, xmm1 ; xmm0 = |basura...|h+HH < max_h| (bool)
			movd edi, xmm0 ; edi = h+HH < max_h

			cmp edi, FALSE
			jne .check_min

			; caso h+HH >= max_h
			movdqu xmm0, xmm2; xmm0 = |l+LL|s+SS|h+HH|a|
			subps xmm0, xmm3 ; xmm0[1] = h+HH-360.0
			insertps xmm5, xmm0, 0x50 ; xmm5[1] = h+HH-360.0
			jmp .fin_ciclo

		.check_min:

			movdqu xmm0, xmm2; xmm0 = |l+LL|s+SS|h+HH|a|
			pxor xmm1, xmm1; xmm1 = |0.0|0.0|0.0|0.0|
			psrldq xmm0, 4; xmm0 = |basura...|h+HH|
			cmpnltss xmm0, xmm1 ; xmm0 = |basura...|h+HH >= 0.0| (bool)
			movd edi, xmm0; edi = h+HH >= 0.0

			cmp edi, FALSE
			jne .fin_ciclo

			; caso h+HH < 0.0
			addps xmm2, xmm3 ; xmm2[1] = h+HH+360.0
			insertps xmm5, xmm2, 0x50 ; xmm5[1] = h+HH+360.0

		.fin_ciclo:

		movdqu [rsp+16], xmm5

		;hago la conversion de HSL a RGB
		lea rdi, [rsp+16] ; *rdi = |a_valido|h_valido|s_valido|l_valido|
		lea rsi, [rsp+48] ; *rsi = |X|X|X|X|
		call hslTOrgb ; *rsp+48 = |a_final|r_final|g_final|b_final|

		;asigno la conversion a la matriz
		mov dword esi, [rsp+48] ; esi = |a_final|r_final|g_final|b_final|
		mov dword [rbx], esi ; [pixel_actual] = |a_final|r_final|g_final|b_final|

		;incremento el puntero para ir al proximo pixel
		add rbx, RGB_PIXEL_SIZE ; rbx = *(proximo_pixel)
		jmp .ciclo

	.fin:
	;*****
	add rsp, 56
	pop rbx
	pop r15
	pop r14
	pop rbp
	ret

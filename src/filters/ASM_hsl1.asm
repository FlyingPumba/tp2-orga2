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
		movdqu xmm2, xmm0 ; xmm2 = |l+LL|s+SS|h+HH|a| (float)

		; pongo la respuesta en [rsp+16], aca voy a mantener el dato respuesta
		movdqu [rsp+16], xmm0 ; [rsp+16] = |a|h+HH|s+SS|l+LL| (float)

		; uso xmm3 para comparar y fixear el HUE resultante
		mov eax, __float32__(360.0)
		movd xmm3, eax
		pslldq xmm3, 12
		psrldq xmm3, 8

		.check_max:

			movdqu xmm1, [hsl_max_dato]
			cmpltps xmm0, xmm1 ; xmm0 = |l < max_l|s < max_s|h < max_h|a < max_a| (bool)
			
			movdqu xmm4, xmm0
			psrldq xmm4, 4
			movd edi, xmm4 ; edi = h < max_h
			psrldq xmm4, 4
			movd esi, xmm4 ; esi = s < max_s
			psrldq xmm4, 4
			movd edx, xmm4 ; edx = l < max_l

			.check_max_hue:
			cmp edi, FALSE
			jne .check_max_sat ; if ( (h < max_h) == false )
			movdqu xmm0, xmm2 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
			subps xmm0, xmm3 ; xmm0 = |l+LL|s+SS|h+HH-360|a| (float)
			movdqu [rsp+16], xmm0 ; [rsp+16] = |a|h+HH-360|s+SS|l+LL|

			.check_max_sat:
			cmp esi, FALSE
			jne .check_max_lum ; if ( (s < max_s) == false )
			mov dword [rsp+16+HSL_OFFSET_SAT], __float32__(1.0) ; s = max_s

			.check_max_lum:
			cmp edx, FALSE
			jne .check_min ; if ( (l < max_l) == false )
			mov dword [rsp+16+HSL_OFFSET_LUM], __float32__(1.0) ; l = max_l

		.check_min:

			movdqu xmm0, xmm2 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
			pxor xmm1, xmm1
			cmpnltps xmm0, xmm1 ; xmm0 = |l >= 0.0|s >= 0.0|h >= 0.0|a >= 0.0| (bool)

			movdqu xmm4, xmm0
			psrldq xmm4, 4
			movd edi, xmm4 ; edi = h >= 0.0
			psrldq xmm4, 4
			movd esi, xmm4 ; esi = s >= 0.0
			psrldq xmm4, 4
			movd edx, xmm4 ; edx = l >= 0.0

			.check_min_hue:
			cmp edi, FALSE
			jne .check_min_sat ; if ( (h >= min_h) == false )
			movdqu xmm0, xmm2 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
			addps xmm0, xmm3 ; xmm0 = |l+LL|s+SS|h+HH+360|a| (float)
			movdqu [rsp], xmm0 ; [rsp] = |a|h+HH+360|s+SS|l+LL|
			mov dword r14d, [rsp+HSL_OFFSET_HUE] ; r14d = h+HH+360
			mov dword [rsp+16+HSL_OFFSET_HUE], r14d ; h+HH+360 ; obs: no puedo sobreescribir todo

			.check_min_sat:
			cmp esi, FALSE
			jne .check_min_lum ; if ( (s >= min_s) == false )
			mov dword [rsp+16+HSL_OFFSET_SAT], __float32__(0.0) ; s = min_s

			.check_min_lum:
			cmp edx, FALSE
			jne .fin_ciclo ; if ( (l >= min_l) == false )
			mov dword [rsp+16+HSL_OFFSET_LUM], __float32__(0.0) ; l = min_l

		.fin_ciclo:

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

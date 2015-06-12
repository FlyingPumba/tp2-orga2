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
	movaps [rsp+16], xmm2

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
		movaps xmm1, [rsp+16] ; xmm1 = |LL|SS|HH|0.0|

		; hago la suma de floats
		addps xmm0, xmm1 ; xmm0 = |l+LL|s+SS|h+HH|a|
		movaps xmm2, xmm0 ; xmm2 = |l+LL|s+SS|h+HH|a| (temporal)

		psrldq xmm0, 4; xmm0 = |0|l+LL|s+SS|h+HH|
		movd [rsp+HSL_OFFSET_HUE], xmm0
		psrldq xmm0, 4; xmm0 = |0|0|l+LL|s+SS|
		movd [rsp+HSL_OFFSET_SAT], xmm0
		psrldq xmm0, 4; xmm0 = |0|0|0|l+LL|
		movd [rsp+HSL_OFFSET_LUM], xmm0

		.check_max:

			movaps xmm0, xmm2
			movups xmm6, [hsl_max_dato]
			cmpltps xmm0, xmm6 ; xmm0 = |l < max_l|s < max_s|h < max_h|a < max_a| (bool)

			psrldq xmm0, 4
			movd edi, xmm0
			psrldq xmm0, 4
			movd esi, xmm0
			psrldq xmm0, 4
			movd edx, xmm0
			
			.check_max_hue:
			cmp edi, FALSE
			jne .check_max_sat ; if ( (h < max_h) == false )
			movaps xmm1, xmm2 ; xmm1 = |l+LL|s+SS|h+HH|a| (float)
			subps xmm1, xmm6 ; xmm1 = |l+LL|s+SS|h+HH-360|a| (float)
			psrldq xmm1, 4
			movd [rsp+HSL_OFFSET_HUE], xmm1

			.check_max_sat:
			cmp esi, FALSE
			jne .check_max_lum ; if ( (s < max_s) == false )
			mov dword [rsp+HSL_OFFSET_SAT], __float32__(1.0) ; s = max_s

			.check_max_lum:
			cmp edx, FALSE
			jne .check_min ; if ( (l < max_l) == false )
			mov dword [rsp+HSL_OFFSET_LUM], __float32__(1.0) ; l = max_l

		.check_min:

			movaps xmm0, xmm2 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
			pxor xmm1, xmm1
			cmpnltps xmm0, xmm1 ; xmm0 = |l >= 0.0|s >= 0.0|h >= 0.0|a >= 0.0| (bool)

			psrldq xmm0, 4
			movd edi, xmm0 ; edi = h >= 0.0
			psrldq xmm0, 4
			movd esi, xmm0 ; esi = s >= 0.0
			psrldq xmm0, 4
			movd edx, xmm0 ; edx = l >= 0.0

			.check_min_hue:
			cmp edi, FALSE
			jne .check_min_sat ; if ( (h >= min_h) == false )
			addps xmm2, xmm6 ; xmm2 = |l+LL|s+SS|h+HH+360|a| (float)
			psrldq xmm2, 4
			movd [rsp+HSL_OFFSET_HUE], xmm2

			.check_min_sat:
			cmp esi, FALSE
			jne .check_min_lum ; if ( (s >= min_s) == false )
			mov dword [rsp+HSL_OFFSET_SAT], 0 ; s = min_s

			.check_min_lum:
			cmp edx, FALSE
			jne .fin_ciclo ; if ( (l >= min_l) == false )
			mov dword [rsp+HSL_OFFSET_LUM], 0 ; l = min_l

		; .check:

		; 	movaps xmm1, xmm0

		; 	pxor xmm2, xmm2; xmm2 = |0.0|0.0|0.0|0.0|
		; 	cmpnltps xmm0, xmm2 ; xmm0 = |l >= 0.0|s >= 0.0|h >= 0.0|a >= 0.0|

		; 	movups xmm3, [hsl_max_dato]; xmm1 = |1.0|1.0|360.0|1.0|
		; 	cmpltps xmm1, xmm3; xmm1 = |l < max_l|s < max_s|h < max_h|a < max_a|

		; 	movaps xmm7, xmm5; xmm7 = |l+LL|s+SS|h+HH|a|

		; 	pxor xmm1, xmm0; xmm1 = xmm1 xor xmm0 (hay que hacer algo)
		; 	pand xmm6, xmm0; xmm6 = S and xmm0 (el signo del numero a sumar es negativo)
		; 	por xmm3, xmm6; niega el signo de xmm3 (1,1,360,0) si es necesario
		; 	pand xmm1, xmm3; pone el resultado en xmm1 si habia que hacer algo, sino deja todo en 0

		; 	addps xmm7, xmm1; le suma 0, 360 o -360 segun corresponda

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

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

hsl_max_dato: dd 1.0, 360.0, 1.0, 1.0 ; |max_a|max_h|max_s|max_l|
hsl_min_dato: dd 0.0, 0.0, 0.0, 0.0 ; |0.0|0.0|0.0|0.0|
hsl_fix_dato: dd 0.0, 360.0, 0.0, 0.0 ; |0.0|360.0|0.0|0.0|

section .data

hsl_temp_dato: dd 0.0, 0.0, 0.0, 0.0
hsl_suma_dato: dd 0.0, 0.0, 0.0, 0.0

rgb_result: db 0, 0, 0, 0

section .text

ASM_hsl1:
	;stack frame
	push rbp
	mov rbp, rsp
	push r14
	push r15
	push rbx
	sub rsp, 8
	;*****

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

	.ciclo:
		cmp rbx, r15
		jg .fin

		; consigo los parametros originales de la funcion
		movdqu [hsl_suma_dato], xmm4 ; [hsl_suma_dato] = |0.0|HH|SS|LL|

		; paso el pixel actual a HSL
		mov rdi, rbx ; rdi = *(pixel_actual)
		mov rsi, hsl_temp_dato ; rsi = (address_hsl)
		call rgbTOhsl ; [hsl_temp_dato] = |a|h|s|l|

		; preparo los datos de la suma
		movdqu xmm0, [hsl_temp_dato] ; xmm0 = |l|s|h|a|
		movdqu xmm1, [hsl_suma_dato] ; xmm1 = |LL|SS|HH|0.0|

		; hago la suma de floats
		addps xmm0, xmm1 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
		movdqu xmm2, xmm0 ; xmm2 = |l+LL|s+SS|h+HH|a| (float)

		; pongo la respuesta en [hsl_suma_dato], aca voy a mantener el dato respuesta
		movdqu [hsl_suma_dato], xmm0 ; [hsl_suma_dato] = |a|h+HH|s+SS|l+LL| (float)

		; uso xmm3 para comparar y fixear el HUE resultante
		movdqu xmm3, [hsl_fix_dato] ; xmm0 = |0.0|0.0|360.0|0.0| (float)

		.check_max:

			movdqu xmm1, [hsl_max_dato]
			cmpltps xmm0, xmm1 ; xmm0 = |l < max_l|s < max_s|h < max_h|a < max_a| (bool)
			movdqu [hsl_temp_dato], xmm0 ; [hsl_temp_dato] = |a < max_a|h < max_h|s < max_s|l < max_l| (bool)

			mov dword edi, [hsl_temp_dato+HSL_OFFSET_HUE] ; edi = h < max_h
			mov dword esi, [hsl_temp_dato+HSL_OFFSET_SAT] ; esi = s < max_s
			mov dword edx, [hsl_temp_dato+HSL_OFFSET_LUM] ; edx = l < max_l

			.check_max_hue:
			cmp edi, FALSE
			jne .check_max_sat ; if ( (h < max_h) == false )
			movdqu xmm0, xmm2 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
			subps xmm0, xmm3 ; xmm0 = |l+LL|s+SS|h+HH-360|a| (float)
			movdqu [hsl_suma_dato], xmm0 ; [hsl_suma_dato] = |a|h+HH-360|s+SS|l+LL|

			.check_max_sat:
			cmp esi, FALSE
			jne .check_max_lum ; if ( (s < max_s) == false )
			mov dword r14d, [hsl_max_dato+HSL_OFFSET_SAT]
			mov dword [hsl_suma_dato+HSL_OFFSET_SAT], r14d ; s = max_s

			.check_max_lum:
			cmp edx, FALSE
			jne .check_min ; if ( (l < max_l) == false )
			mov dword r14d, [hsl_max_dato+HSL_OFFSET_LUM]
			mov dword [hsl_suma_dato+HSL_OFFSET_LUM], r14d ; l = max_l

		.check_min:

			movdqu xmm0, xmm2 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
			movdqu xmm1, [hsl_min_dato]
			cmpnltps xmm0, xmm1 ; xmm0 = |l >= 0.0|s >= 0.0|h >= 0.0|a >= 0.0| (bool)
			movdqu [hsl_temp_dato], xmm0 ; [hsl_temp_dato] = |a > 0.0|h > 0.0|s > 0.0|l > 0.0| (bool)

			mov dword edi, [hsl_temp_dato+HSL_OFFSET_HUE] ; edi = h >= 0.0
			mov dword esi, [hsl_temp_dato+HSL_OFFSET_SAT] ; esi = s >= 0.0
			mov dword edx, [hsl_temp_dato+HSL_OFFSET_LUM] ; edx = l >= 0.0

			.check_min_hue:
			cmp edi, FALSE
			jne .check_min_sat ; if ( (h >= min_h) == false )
			movdqu xmm0, xmm2 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
			addps xmm0, xmm3 ; xmm0 = |l+LL|s+SS|h+HH+360|a| (float)
			movdqu [hsl_temp_dato], xmm0 ; [hsl_temp_dato] = |a|h+HH+360|s+SS|l+LL|
			mov dword r14d, [hsl_temp_dato+HSL_OFFSET_HUE] ; r14d = h+HH+360
			mov dword [hsl_suma_dato+HSL_OFFSET_HUE], r14d ; h+HH+360 ; obs: no puedo sobreescribir todo

			.check_min_sat:
			cmp esi, FALSE
			jne .check_min_lum ; if ( (s >= min_s) == false )
			mov dword r14d, [hsl_min_dato+HSL_OFFSET_SAT]
			mov dword [hsl_suma_dato+HSL_OFFSET_SAT], r14d ; s = min_s

			.check_min_lum:
			cmp edx, FALSE
			jne .fin_ciclo ; if ( (l >= min_l) == false )
			mov dword r14d, [hsl_min_dato+HSL_OFFSET_LUM]
			mov dword [hsl_suma_dato+HSL_OFFSET_LUM], r14d ; l = min_l

		.fin_ciclo:

		;hago la conversion de HSL a RGB
		mov rdi, hsl_suma_dato ; *rdi = |a_valido|h_valido|s_valido|l_valido|
		mov rsi, rgb_result ; *rsi = |X|X|X|X|
		call hslTOrgb ; *rgb_result = |a_final|r_final|g_final|b_final|

		;asigno la conversion a la matriz
		mov dword esi, [rgb_result] ; esi = |a_final|r_final|g_final|b_final|
		mov dword [rbx], esi ; [pixel_actual] = |a_final|r_final|g_final|b_final|

		;incremento el puntero para ir al proximo pixel
		lea rbx, [rbx + RGB_PIXEL_SIZE] ; lea = *(proximo_pixel)
		jmp .ciclo

	.fin:
	;*****
	add rsp, 8
	pop rbx
	pop r15
	pop r14
	pop rbp
	ret
  
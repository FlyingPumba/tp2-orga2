; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion HSL 1                                      ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_hsl1_1(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll)
global ASM_hsl1_1

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

section .text

ASM_hsl1_1:
	;stack frame
	push rbp
	mov rbp, rsp
	push r15
	push rbx
	sub rsp, 32
	;*****

	;
	; Variables en la pila:
	;
	; hsl_suma_dato: [rsp]
	; hsl_params_dato: [rsp+16]
	;

	mov rbx, rdx ; rbx = *data (aumenta en cada ciclo)

	pxor xmm4, xmm4 ; xmm4 |0.0|0.0|0.0|0.0|
	pslldq xmm0, 4 ; xmm0 |0.0|0.0|HH|0.0|
	pslldq xmm1, 8 ; xmm1 |0.0|SS|0.0|0.0|
	pslldq xmm2, 12 ; xmm2 |LL|0.0|0.0|0.0|
	por xmm4, xmm0
	por xmm4, xmm1
	por xmm4, xmm2 ; xmm4 = |LL|SS|HH|0.0|

	movdqu [rsp+16], xmm4 ; [rsp+16] = |0.0|HH|SS|LL|

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
		movdqu xmm1, [rsp+16] ; xmm1 = |LL|SS|HH|0.0|

		; hago la suma de floats
		addps xmm0, xmm1 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
		movdqu xmm2, xmm0 ; xmm2 = |l+LL|s+SS|h+HH|a| (copia parcial)

		; pongo la respuesta en [rsp], aca voy a mantener el dato respuesta
		movdqu [rsp], xmm0 ; [rsp] = |a|h+HH|s+SS|l+LL|

		; uso xmm3 para fixear el HUE resultante (sumo o resto si es necesario)
		mov eax, __float32__(360.0)
		movd xmm3, eax ; xmm3 = |basura|basura|basura|360.0|

		.check_max:

			movdqu xmm1, [hsl_max_dato]
			cmpltps xmm0, xmm1 ; xmm0 = |l < max_l|s < max_s|h < max_h|a < max_a| (bool)
			
			psrldq xmm0, 4
			movd edi, xmm0 ; edi = h < max_h
			psrldq xmm0, 4
			movd esi, xmm0 ; esi = s < max_s
			psrldq xmm0, 4
			movd edx, xmm0 ; edx = l < max_l

			.check_max_hue:
			cmp edi, FALSE
			jne .check_max_sat ; if ( (h < max_h) == false )
			movdqu xmm0, xmm2 ; xmm0 = |l+LL|s+SS|h+HH|a|
			psrldq xmm0, 4 ; xmm0 = |0.0|l+LL|s+SS|h+HH|
			subss xmm0, xmm3 ; xmm0 = |0.0|l+LL|s+SS|h+HH-360|
			movss dword [rsp+HSL_OFFSET_HUE], xmm0 ; [rsp] = |a|h+HH-360|s+SS|l+LL|

			.check_max_sat:
			cmp esi, FALSE
			jne .check_max_lum ; if ( (s < max_s) == false )
			mov dword [rsp+HSL_OFFSET_SAT], __float32__(1.0) ; s = max_s

			.check_max_lum:
			cmp edx, FALSE
			jne .check_min ; if ( (l < max_l) == false )
			mov dword [rsp+HSL_OFFSET_LUM], __float32__(1.0) ; l = max_l

		.check_min:

			movdqu xmm0, xmm2 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
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
			movdqu xmm0, xmm2 ; xmm0 = |l+LL|s+SS|h+HH|a|
			psrldq xmm0, 4 ; xmm0 = |0.0|l+LL|s+SS|h+HH|
			addss xmm0, xmm3 ; xmm0 = |0.0|l+LL|s+SS|h+HH-360|
			movss dword [rsp+HSL_OFFSET_HUE], xmm0 ; [rsp] = |a|h+HH-360|s+SS|l+LL|

			.check_min_sat:
			cmp esi, FALSE
			jne .check_min_lum ; if ( (s >= min_s) == false )
			mov dword [rsp+HSL_OFFSET_SAT], __float32__(0.0) ; s = min_s

			.check_min_lum:
			cmp edx, FALSE
			jne .fin_ciclo ; if ( (l >= min_l) == false )
			mov dword [rsp+HSL_OFFSET_LUM], __float32__(0.0) ; l = min_l

		.fin_ciclo:

		;hago la conversion de HSL a RGB
		mov rdi, rsp ; *rdi = |a_valido|h_valido|s_valido|l_valido|
		mov rsi, rbx ; rsi = rbx
		call hslTOrgb ; *rbx = |a_final|r_final|g_final|b_final| (rgb)

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

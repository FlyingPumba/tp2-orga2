; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion HSL 2                                      ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_hsl2(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll)
global ASM_hsl2
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
hsl_first_dword_mask: dd 0xffffffff, 0, 0, 0 ; |1..1|0|0|0|
hsl_second_dword_mask: dd 0, 0xffffffff, 0, 0 ; |1..1|0|0|0|
fabs_mask: dd 0.0, 0.0, 0.0, 0x7fffffff

zero_fdword: dd 0.0, 0.0, 0.0, 0.0 ; |0|0|0|0|
l_divisor_fdword: dd 1.0, 510.0, 1.0, 1.0 ; |510.0|1.0|1.0|1.0|
l_mul2_fdword: dd 1.0, 1.0, 1.0, 2.0 ; |1.0|1.0|1.0|2.0|
l_subfirst_fdword: dd 0.0, 0.0, 0.0, 1.0 ; |0.0|0.0|0.0|1.0|
l_addhead: dd 1.0, 1.0, 1.0, 0.0 ; |1.0|1.0|1.0|0.0|
l_div_255: dd 1.0, 1.0, 1.0, 255.0001

section .data

hsl_temp_dato: dd 0.0, 0.0, 0.0, 0.0
hsl_suma_dato: dd 0.0, 0.0, 0.0, 0.0

rgb_result: db 0, 0, 0, 0

section .text

ASM_hsl2:
	;stack frame
	push rbp
	mov rbp, rsp
	push r12
	push r13
	push r14
	push r15
	push rbx
	sub rsp, 8
	;*****

	mov rbx, rdx ; rbx = *data (aumenta en cada ciclo)

	pxor xmm3, xmm3 ; xmm3 |0.0|0.0|0.0|0.0|
	pslldq xmm0, 4 ; xmm0 |0.0|0.0|HH|0.0|
	pslldq xmm1, 8 ; xmm1 |0.0|SS|0.0|0.0|
	pslldq xmm2, 12 ; xmm2 |LL|0.0|0.0|0.0|
	por xmm3, xmm0
	por xmm3, xmm1
	por xmm3, xmm2 ; xmm3 = |LL|SS|HH|0.0|
	movdqu [hsl_suma_dato], xmm3 ; [hsl_suma_dato] = |0.0|HH|SS|LL|

	mov rax, uuurdi ; rax = w
	mul rsi ; rax = w * h
	mov rsi, RGB_PIXEL_SIZE ; rsi = RGB_PIXEL_SIZE
	mul rsi ; rax = w * h * RGB_PIXEL_SIZE = *data.size()
	add rax, rbx ; rax = *data.end()
	mov r15, rax ; r15 = *data.end()

	.ciclo:
		cmp rbx, r15
		jg .fin

		; paso el pixel actual a HSL
		mov rdi, rbx ; rdi = *(pixel_actual)
		mov rsi, hsl_temp_dato ; rsi = (address_hsl)
		call rgbTOhsl ; [hsl_temp_dato] = |a|h|s|l|

		movdqu xmm0, [hsl_temp_dato] ; xmm0 = |l|s|h|a|
		movdqu xmm1, [hsl_suma_dato] ; xmm1 = |LL|SS|HH|0.0|

		addps xmm0, xmm1 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
		movdqu xmm2, xmm0 ; xmm2 = |l+LL|s+SS|h+HH|a| (float)

		movdqu [hsl_suma_dato], xmm0 ; [hsl_suma_dato] = |a|h+HH|s+SS|l+LL| (float)

		movdqu xmm3, [hsl_fix_dato]

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
			movdqu xmm0, xmm2
			subps xmm0, xmm3
			movdqu [hsl_temp_dato], xmm0
			mov dword r12d, [hsl_temp_dato+HSL_OFFSET_HUE]
			mov dword [hsl_suma_dato+HSL_OFFSET_HUE], r12d ; h = h - 360

			.check_max_sat:
			cmp esi, FALSE
			jne .check_max_lum ; if ( (s < max_s) == false )
			mov dword r13d, [hsl_max_dato+HSL_OFFSET_SAT]
			mov dword [hsl_suma_dato+HSL_OFFSET_SAT], r13d ; s = max_s

			.check_max_lum:
			cmp edx, FALSE
			jne .check_min ; if ( (l < max_l) == false )
			mov dword r14d, [hsl_max_dato+HSL_OFFSET_LUM]
			mov dword [hsl_suma_dato+HSL_OFFSET_LUM], r14d ; l = max_l

		.check_min:

			movdqu xmm0, xmm2 ; xmm0 = |l+LL|s+SS|h+HH|a| (float)
			movdqu xmm1, [hsl_min_dato]
			cmpnltps xmm0, xmm1 ; xmm0 = |l > 0.0|s > 0.0|h > 0.0|a > 0.0| (bool)
			movdqu [hsl_temp_dato], xmm0 ; [hsl_temp_dato] = |a > 0.0|h > 0.0|s > 0.0|l > 0.0| (bool)

			mov dword edi, [hsl_temp_dato+HSL_OFFSET_HUE] ; edi = h >= 0.0
			mov dword esi, [hsl_temp_dato+HSL_OFFSET_SAT] ; esi = s >= 0.0
			mov dword edx, [hsl_temp_dato+HSL_OFFSET_LUM] ; edx = l >= 0.0

			.check_min_hue:
			cmp edi, FALSE
			jne .check_min_sat ; if ( (h >= min_h) == false )
			movdqu xmm0, xmm2
			addps xmm0, xmm3
			movdqu [hsl_temp_dato], xmm0
			mov dword r12d, [hsl_temp_dato+HSL_OFFSET_HUE]
			mov dword [hsl_suma_dato+HSL_OFFSET_HUE], r12d ; h = h + 360

			.check_min_sat:
			cmp esi, FALSE
			jne .check_min_lum ; if ( (s >= min_s) == false )
			mov dword r13d, [hsl_min_dato+HSL_OFFSET_SAT]
			mov dword [hsl_suma_dato+HSL_OFFSET_SAT], r13d ; s = min_s

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
	pop r13
	pop r12
	pop rbp
	ret



rgbTOhsl:
    pxor xmm6, xmm6 ; limpio xmm6
    movdqu xmm4, [rdi] ; guardo en xmm4 el contenido del pixel (y sus vecinos)

    ; desempaqueto convierto las componentes del pixel a int de 32 bits
    punpckhbw xmm4, xmm6
    punpckhwd xmm4, xmm6 ; xmm4 = ints(p)
    movdqu xmm9, xmm4 ; xmm9 = xmm4

    movdqu xmm5, xmm4 ; xmm5 = xmm4
    movdqu xmm6, xmm6 ; xmm6 = xmm4
    
    pslldq xmm4, 4 ; xmm4 = | R | G | B | 0 |
    maxps xmm5, xmm4 ; xmm5 = | - | max(R,G) | - | - |
    minps xmm6, xmm4 ; xmm6 = | - | min(R,G) | - | - |
    pslldq xmm4, 4 ; xmm4 = | G | B | 0 | 0 |
    maxps xmm5, xmm4 ; xmm5 = | - | max(R,G,B) | - | - |
    minps xmm6, xmm4 ; xmm6 = | - | min(R,G,B) | - | - |

    movdqu xmm8, xmm5 ; xmm8 = xmm5

    ; calculo l
    movdqu xmm7, xmm5 ; xmm7 = xmm5
    paddd xmm7, xmm6 ; xmm7 = | - | max + min | - | -|
    cvtdq2ps xmm7, xmm7 ; xmm7 = | - | float(max + min) | - | - |
    movdqu xmm6, xmm7 ; xmm6 = xmm7
 
    divpx xmm7, [l_divisor_fdword] ; xmm7 = | - | l | - | - |
    andps xmm7, [hsl_second_dword_mask] ; xmm7 = | 0.0 | l | 0.0 | 0.0 | 
    pslldq xmm7, 8 ; xmm7 = | 0 | 0 | 0 | l |
    
    psubd xmm5, xmm6 ; xmm5 = | - | max(R,G,B) - min(R,G,B) | - | - |
    ; convierto a la dif entre max y min a float
    cvtdq2ps xmm5, xmm5 ; xmm5 = | - | float(max - min) | - | - |

    andps xmm5, [hsl_second_dword_mask] ; xmm5 = | 0.0 | float(max - min) | 0.0 | 0.0 |
    cmpps xmm5, zero_fdword
    jne .rgbTOhsl_not_zero

    ; cmax == cmin so we have the three components
    cvtdq2ps xmm9, xmm9 ; xmm9 = floats(p)
    andps xmm9, [hsl_first_dword_mask] ; xmm9 = | A | 0 | 0 | 0 |

    paddd xmm9, xmm7 ; xmm4 = | A | 0.0 | 0.0 | L |
    movdqu [rsi], xmm9 ; dst = xmm9

    jmp .rgbTOhsl_fin

    .rgbTOhsl_not_zero:
        ; ya puedo calcular s
        movdqu xmm4, xmm7 ; xmm4 = xmm7 = | 0 | 0 | 0 | l |
        mulps xmm4, [l_mul2_fdword] ; xmm4 = | 0 | 0 | 0 | l * 2.0 |
        psubd xmm4, [l_subfirst_fdword] ; xmm4 = | 0 | 0 | 0 | l * 2.0 - 1.0f |

        andps xmm4, [fabs_mask] ; xmm4 = | 0 | 0 | 0 | fabs(l*2.0 - 1.0f) |
        movdqu xmm6, [l_subfirst_fdword] ; xmm6 = | 0 | 0 | 0 | 1.0 |
        psubd xmm6, xmm4 ; xmm6 = | 0 | 0 | 0 | 1.0 - fabs(l * 2.0 - 1.0f) |
        paddd xmm6, [l_addhead] ; xmm6 = | 1.0 | 1.0 | 1.0 | 1.0 - fabs(l * 2.0 - 1.0f) |
        psrldq xmm5, 8 ; xmm5 = | 0 | 0 | 0 | cmax - cmin |
        divps xmm5, xmm6 ; xmm5 = | 0 | 0 | 0 | d / 1.0 - fabs(l * 2.0 - 1.0f) |
        divps xmm5, [l_div_255] ; xmm5 = | 0 | 0 | 0 | d / 1.0 - fabs(l * 2.0 - 1.0f) / 255.0001 |
        
        pslldq xmm5, 8
        andps xmm5, [hsl_second_dword_mask] ; xmm7 = | 0.0 | s | 0.0 | 0.0 | 
        psrldq xmm5, 4
        paddd xmm7, xmm5 ; xmm7 = | 0.0 | 0.0 | s | l |

        ; calculo h
        andps xmm8, [hsl_second_dword_mask] ; xmm5 = | 0 | max(R,G,B) | 0 | 0 |
        movdqu xmm10, xmm9; xmm10 = ints(p)
        andps xmm10, [hsl_second_dword_mask] ; xmm10 = | 0 | R | 0 | 0 |
        cmpps xmm8, xmm10
        jne .rgbTOhsl_test_g



        .rgbTOhsl_test_g:
        movdqu xmm10, xmm9
        psrldq xmm10, 4 
        andps xmm10, [hsl_second_dword_mask] ; xmm10 = | 0 | G | 0 | 0 |
        cmpps xmm8, xmm10
        jne .rgbTOhsl_test_b

        .rgbTOhsl_test_b:
        movdqu xmm10, xmm9
        psrldq xmm10, 4 
        andps xmm10, [hsl_second_dword_mask] ; xmm10 = | 0 | B | 0 | 0 |
         
        ;divps xmm5, 
    ;s = d/(1.0f-fabs(2.0f*l-1.0f))/255.0001f;

        .rgbTOhsl_non_zero_fin:
            

    .rgbTOhsl_fin:
    ret

; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion HSL 2                                      ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_hsl2(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll)
global ASM_hsl2
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

hsl_second_dword_mask: dd 0, 0xffffffff, 0, 0 ; |1..1|0|0|0|
hsl_second_dword_one: dd 0.0, 0.0, 1.0, 0.0 ; |1..1|0|0|0|
hsl_l_divisor: dd 1.0, 510.0, 1.0, 1.0 ; |1.0|1.0|510.0|1.0|
hsl_s_divisor: dd 1.0, 1.0, 255.0001, 1.0 ; |1.0|255.001|1.0|1.0|
hsl_fabs_mask: dd 0x7fffffff, 0x7fffffff, 0x7fffffff, 0x7fffffff
hsl_second_dword_zero: dd 1.0, 1.0, 0.0, 1.0
hsl_sixty_mask: dd 60.0, 60.0, 60.0, 60.0
hsl_final_sub_mask: dd 0.0, 360.0, 360.0, 360.0
hsl_h_add_mask: dd 0.0, 4.0, 6.0, 2.0

section .data

hsl_temp_dato: dd 0.0, 0.0, 0.0, 0.0
hsl_suma_dato: dd 0.0, 0.0, 0.0, 0.0
hsl_params_dato: dd 0.0, 0.0, 0.0, 0.0

rgb_result: db 0, 0, 0, 0

section .text

ASM_hsl2:
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
	movdqu [hsl_params_dato], xmm4 ; [hsl_suma_dato] = |0.0|HH|SS|LL|

	mov rax, rdi ; rax = w
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

		; preparo los datos de la suma
		movdqu xmm0, [hsl_temp_dato] ; xmm0 = |l|s|h|a|
		movdqu xmm1, [hsl_params_dato] ; xmm1 = |LL|SS|HH|0.0|

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

rgbTOhsl:
    ; el resultado parcial se guarda en xmm8
    pxor xmm8, xmm8

    ; calculo cmax, cmin y d
    movd xmm4, [rdi] ; xmm4 = | ceros | R | G | B | A | (cada canal en int 8b)
    ; convierto las componentes del pixel a int 8b a int 32b
    pxor xmm6, xmm6 ; limpio xmm6
    punpcklbw xmm4, xmm6 ; xmm4 = | ceros | R | G | B | A | (cada canal en int 16b)
    punpcklwd xmm4, xmm6 ; xmm4 = | R | G | B | A | (cada canal en int 32b)

    movdqu xmm5, xmm4 ; xmm5 = | R | G | B | A |
    movdqu xmm6, xmm4 ; xmm6 = | R | G | B | A |

    psrldq xmm4, 4 ; xmm4 = | 0 | R | G | B |

    pmaxud xmm5, xmm4 ; xmm5 = | - | - | max(G,B) | - |
    pminud xmm6, xmm4 ; xmm6 = | - | - | min(G,B) | - |
    psrldq xmm4, 4 ; xmm4 = | 0 | 0 | R | G |
    pmaxud xmm5, xmm4 ; xmm5 = | - | - | max(R,G,B) | - |
    pminud xmm6, xmm4 ; xmm6 = | - | - | min(R,G,B) | - |
    movdqu xmm4, xmm5 ; xmm4 = | - | - | max(R,G,B) | - |
    psubd xmm4, xmm6 ; xmm4 = | - | - | max - min | - |

    pextrd ecx, xmm4, 1 ; ecx = maxc - minc = d

    ; calculo L
    movdqu xmm9, xmm5 ; xmm9 = | - | - | max(R,G,B) | - |
    paddd xmm9, xmm6 ; xmm9 = | - | - | max + min | - |
    cvtdq2ps xmm9, xmm9 ; xmm9 = | - | - | float(max + min) | - |
    movdqu xmm7, [hsl_l_divisor]
    divps xmm9, xmm7 ; xmm9 = | - | - | L | - |
	pslldq xmm9, 8 ;  xmm9 = | L | - | - | - |
    psrldq xmm9, 12 ;  xmm9 = | 0 | 0 | 0 | L |
	movdqu xmm8, xmm9 ;  xmm8 = | 0 | 0 | 0 | L |

    ; calculo S
    cmp ecx, FALSE
    je .rgbTOhsl_calc_h ; si cmax == cmin dejo s en 0

    pslldq xmm9, 8 ; vuelvo a posicionar L en la segunda posición | 0 | L | 0 | 0 |
    movdqu xmm7, [hsl_second_dword_one]
    addps xmm7, xmm7 ; xmm7 = | 0 | 2.0 | 0 | 0 |
    mulps xmm9, xmm7 ; xmm9 = | 0 | 2L | 0 | 0 |
    movdqu xmm7, [hsl_second_dword_one] ; xmm7 = | 0 | 1.0 | 0 | 0 |
    subps xmm9, xmm7 ; xmm9 = | 0 | 2L - 1 | 0 | 0 |
    movdqu xmm10, [hsl_fabs_mask]
    andps xmm9, xmm10  ; xmm9 = | 0 | fabs(2L - 1) | 0 | 0 |
    subps xmm7, xmm9 ; xmm7 = | 0 | 1 - fabs(2L - 1) | 0 | 0 |
    movdqu xmm9, [hsl_second_dword_zero] ; para no dividir por 0
    addps xmm7, xmm9 ; xmm7 = | 1 | 1 - fabs(2L -1) | 1 | 1 |
    movdqu xmm9, xmm4 ; xmm9 = | - | - | max - min | - |
	pslldq xmm9, 4 ; xmm9 = | - | max - min | - | - |
    cvtdq2ps xmm9, xmm9; xmm9 = | - | float(max - min) | - | - |
    divps xmm9, xmm7 ; xmm9 = | - | d/(1 - fabs(2L -1)) | - | - |
    movdqu xmm7, [hsl_s_divisor]
    divps xmm9, xmm7 ; xmm9 = | 0 | d/(1 - fabs(2L -1))/255.0001 | 0 | 0 |

    pslldq xmm9, 4 ; xmm9 = | S | - | -| 0 |
	psrldq xmm9, 12 ; xmm9 = | 0 | 0 | 0 | S |
	pslldq xmm9, 4 ; xmm9 = | 0 | 0 | S | 0 |
    addps xmm8, xmm9 ; xmm9 = | 0 | 0 | S | L |

    .rgbTOhsl_calc_h:
    ; calculo h
    cmp ecx, FALSE
    je .rgbTOhsl_fin ; si cmax == cmin dejo h en 0

    ; ordeno los datos
	movd xmm7, [rdi] ; xmm7 = | ceros | R | G | B | A | (cada canal en int 8b)
    pxor xmm9, xmm9 ; limpio xmm9
    punpcklbw xmm7, xmm6 ; xmm4 = | ceros | R | G | B | A | (cada canal en int 16b)
    punpcklwd xmm7, xmm6 ; xmm4 = | R | G | B | A | (cada canal en int 32b)

    pshufd xmm9, xmm7, 0b11010010 ; xmm0 = ints(a, g, b, r)

    psubd xmm7, xmm9 ; | - | r-g | g-b | b-r |
    cvtdq2ps xmm7, xmm7 ; xmm7 = floats(-,r-g,g-b,b-r)
    cvtdq2ps xmm4, xmm4 ; xmm4 = floats(-, d, 0, 0)
    pshufd xmm4, xmm4, 0b10101010 ; xmm4 = floats(d, d, d, d)

    divps xmm7, xmm4 ; xmm7 = | 0 | (r-g)/d | (g-b)/d | (b-r)/d |
    movdqu xmm10, [hsl_h_add_mask]
    addps xmm7, xmm10 ; xmm7 = | 0 | (r-g)/d + 4 | (g-b)/d + 6 | (b-r)/d + 2 |
    movdqu xmm10, [hsl_sixty_mask]
    mulps xmm7, xmm10 ; xmm7 = 60*xmm7

    pextrd ecx, xmm5, 12 ; ecx = maxc
    .rgbTOhsl_max_r:
    extractps edx, xmm9, 0 ; edx = r
    cmp edx, ecx
    jne .rgbTOhsl_max_g

    jmp .rgbTOhsl_h_fin

    .rgbTOhsl_max_g:
    extractps edx, xmm9, 8 ; edx = g
    cmp edx, ecx
    jne  .rgbTOhsl_max_b

    pslldq xmm7, 4
    jmp .rgbTOhsl_h_fin

    .rgbTOhsl_max_b:
    pslldq xmm7, 4

    .rgbTOhsl_h_fin:
    movdqu xmm4, [hsl_second_dword_mask]
    pand xmm7, xmm4 ; limpio xmm7

    extractps edx, xmm7, 2
    cmp edx, 360
    jl .rgbTOhsl_h_sum_fin

    subps xmm7, [hsl_final_sub_mask]

    .rgbTOhsl_h_sum_fin:
    addps xmm8, xmm7

    .rgbTOhsl_fin:
    movdqu [rsi], xmm8

    ret

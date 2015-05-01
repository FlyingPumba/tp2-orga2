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

hsl_second_dword_mask: dd 0, 0xffffffff, 0, 0
hsl_first_dword_one: dd 1.0, 0.0, 0.0, 0.0
hsl_l_divisor: dd 510.0, 1.0, 1.0, 1.0
hsl_s_divisor: dd 255.0001, 1.0, 1.0, 1.0
; la mascara fabs tiene para cada dword 1s excepto en el primer bit, que tiene un cero
; esto hace que al aplicarle esta mascara a un float SP con un AND, el numero pase a ser positivo (si no lo era)
hsl_fabs_mask: dd 0x7fffffff, 0x7fffffff, 0x7fffffff, 0x7fffffff
hsl_first_dword_zero: dd 0.0, 1.0, 1.0, 1.0
hsl_h_add_mask: dd 0.0, 2.0, 6.0, 4.0
hsl_sixty_mask: dd 60.0, 60.0, 60.0, 60.0
hsl_sub_360: dd 360.0, 0.0, 0.0, 0.0

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

; void rgbTOhsl(uint8_t *src, float *dst)
rgbTOhsl:
	push rbp
	mov rbp, rsp
	; **********
    ; limpio xmm15 para usarlo como registro auxiliar
    pxor xmm15, xmm15
	; limpio xmm14 para ir almacenendo la representacion en HSL
    pxor xmm14, xmm14

    ; cargo el pixel y convierto los canales a enteros 32b
    movd xmm0, [rdi] ; xmm0 = | ceros | R | G | B | A | (cada canal en int 8b)
    punpcklbw xmm0, xmm15 ; xmm0 = | ceros | R | G | B | A | (cada canal en int 16b)
    punpcklwd xmm0, xmm15 ; xmm0 = | R | G | B | A | (cada canal en int 32b)

	; calculo cmax, cmin y d
    movdqu xmm1, xmm0 ; xmm1 = | R | G | B | A | (int 32b)
    movdqu xmm2, xmm0 ; xmm2 = | R | G | B | A | (int 32b)
	movdqu xmm3, xmm0 ; xmm3 = | R | G | B | A | (int 32b)
	pslldq xmm3, 4 ; xmm3 = | G | B | A | 0 |

    pmaxud xmm1, xmm3 ; xmm1 = | max(R,G) | max(G,B) | max(B,A) | A | (int 32b)
    pminud xmm2, xmm3 ; xmm2 = | min(R,G) | min(G,B) | min(B,A) | 0 | (int 32b)
    pslldq xmm3, 4 ; xmm3 = | B | A | 0 | 0 | (int 32b)
    pmaxud xmm1, xmm3  ; xmm1 = | max(R,G,B) | max(G,B,A) | max(B,A) | A | (int 32b)
    pminud xmm2, xmm3 ; xmm2 = | min(R,G,B) | min(G,B,A) | 0 | 0 | (int 32b)
    movdqu xmm3, xmm1  ; xmm3 = | max(R,G,B) | max(G,B,A) | max(B,A) | A | (int 32b)
    psubd xmm3, xmm2  ; xmm3 = | max(R,G,B) - min(R,G,B) | max(G,B,A) - min(G,B,A) | max(B,A) | A | (int 32b)

	; guardo d en ecx para hacer despues las comparaciones en el calculo de H y S
	psrldq xmm3, 12 ; xmm3 = | 0 | 0 | 0 | max(R,G,B) - min(R,G,B) | (int 32b)
	movd ecx, xmm3 ; ecx = maxc - minc = d (int 32b)

	; preparo en xmm4 cmax + cmin, para el calculo de L
	movdqu xmm4, xmm1 ; xmm4 = | max(R,G,B) | max(G,B,A) | max(B,A) | A | (int 32b)
	paddd xmm4, xmm2 ; xmm4 = | max(R,G,B) + min(R,G,B) | max(G,B,A) + min(G,B,A) | max(B,A) | A | (int 32b)
	psrldq xmm4, 12 ; xmm4 = | 0 | 0 | 0 | max(R,G,B) + min(R,G,B) | (int 32b)

	; preparo en xmm1 cmax, para el calculo de H
	psrldq xmm1, 12 ; xmm4 = | 0 | 0 | 0 | max(R,G,B) | (int 32b)

    ; calculo L
    cvtdq2ps xmm4, xmm4 ; xmm4 = | 0 | 0 | 0 | float(cmax + cmin) |
    movdqu xmm13, [hsl_l_divisor] ; xmm13 = | 1.0 | 1.0 | 1.0 | 510.0 |
    divps xmm4, xmm13 ; xmm4 = | 0 | 0 | 0 | L = (cmax + cmin)/510 | (floats SP)
	movdqu xmm14, xmm4 ;  xmm14 = | 0 | 0 | 0 | L | (floats SP)
	pslldq xmm14, 12 ; xmm14 = | L | 0 | 0 | 0 | (floats SP)

    ; calculo S
    cmp ecx, DWORD 0
    je .rgbTOhsl_calc_h ; si cmax == cmin dejo S en 0

	; multiplico L por 2 y le resto 1
    movdqu xmm5, [hsl_first_dword_one] ; xmm5 = | 0.0 | 0.0 | 0.0 | 1.0 |
    addps xmm5, xmm5 ; xmm5 = | 0.0 | 0.0 | 0.0 | 2.0 |
    mulps xmm4, xmm5 ; xmm4 = | 0 | 0 | 0 | 2*L | (floats SP)
    movdqu xmm5, [hsl_first_dword_one] ; xmm5 = | 0.0 | 0.0 | 0.0 | 1.0 |
    subps xmm4, xmm5 ; xmm4 = | 0 | 0 | 0 | 2*L - 1 | (floats SP)

	; a lo anterior, le aplico fabs y luego se lo resto a 1
    movdqu xmm6, [hsl_fabs_mask] ; xmm6 = | 0x7fffffff | 0x7fffffff | 0x7fffffff | 0x7fffffff |
    andps xmm4, xmm6  ; xmm4 = | 0 | 0 | 0 | fabs(2*L - 1) | (floats SP)
    subps xmm5, xmm4 ; xmm5 = | 0 | 0 | 0 | 1 - fabs(2*L - 1) | (floats SP)

	; lo que obtuve, se lo divido a d
    movdqu xmm6, [hsl_first_dword_zero] ; para no dividir por 0. ; xmm6 = | 1.0 | 1.0 | 1.0 | 0.0 |
    addps xmm5, xmm6 ; xmm5 = | 1 | 1 | 1 | 1 - fabs(2*L - 1) | (floats SP)
	movdqu xmm4, xmm3 ; xmm4 = | 0 | 0 | 0 | d | (int 32b)
    cvtdq2ps xmm4, xmm4 ; xmm4 = | 0 | 0 | 0 | d | (floats SP)
    divps xmm4, xmm5 ; xmm4 = | 0 | 0 | 0 | d/(1 - fabs(2*L -1)) | (floats SP)
    movdqu xmm5, [hsl_s_divisor] ; xmm5 = | 1.0 | 1.0 | 1.0 | 255.0001 |
    divps xmm4, xmm5 ; xmm4 = | 0 | 0 | 0 | S = d/(1 - fabs(2*L -1))/255.0001 | (floats SP)

	; ubico S en el registro de resultados
	pslldq xmm4, 8 ; xmm4 = | 0 | S | 0 | 0 |
    addps xmm14, xmm4 ; xmm14 = | L | S | 0 | 0 |

    .rgbTOhsl_calc_h:
    ; calculo H
	cmp ecx, DWORD 0
    je .rgbTOhsl_fin ; si cmax == cmin dejo H en 0

    ; preparo un registro con los datos: | G | B | R | - | parar restarselo a | R | G | B | A |
	movdqu xmm4, xmm0 ; xmm4 = | R | G | B | A | (int 32b)
	movdqu xmm5, xmm0 ; xmm5 = | R | G | B | A | (int 32b)
	psrldq xmm5, 4 ; xmm5 = | 0 | R | G | B | (int 32b)
	pslldq xmm5, 8 ; xmm5 = | G | B | 0 | 0 | (int 32b)
	movdqu xmm6, xmm0 ; xmm6 = | R | G | B | A | (int 32b)
	psrldq xmm6, 8 ; xmm6 = | 0 | 0 | R | G | (int 32b)
	paddd xmm5, xmm6 ; xmm5 = | G | B | R | G | (int 32b)
	; hago la resta
	psubd xmm4, xmm5 ; xmm4 = | R-G | G-B | B-R | A-G | (int 32b)

	; divido por d
    cvtdq2ps xmm4, xmm4 ; xmm4 = | R-G | G-B | B-R | A-G | (floats SP)
	movdqu xmm5, xmm3 ; xmm5 = | 0 | 0 | 0 | d | (int 32b)
	pslldq xmm5, 4 ; xmm5 = | 0 | 0 | d | 0 | (int 32b)
	paddd xmm3, xmm5 ; xmm3 = | 0 | 0 | d | d | (int 32b)
	movdqu xmm5, xmm3 ; xmm5 = | 0 | 0 | d | d | (int 32b)
	pslldq xmm5, 8 ; xmm5 = | d | d | 0 | 0 | (int 32b)
	paddd xmm3, xmm5 ; xmm3 = | d | d | d | d | (int 32b)
	cvtdq2ps xmm3, xmm3 ; xmm3 = | d | d | d | d | (floats SP)
	divps xmm4, xmm3 ; xmm4 = | (R-G)/d | (G-B)/d | (B-R)/d | (A-G)/d | (floats SP)

    ; le sumo los numeritos locos
    movdqu xmm6, [hsl_h_add_mask] ; xmm6 = | 4.0 | 6.0 | 2.0 | 0.0 |
    addps xmm4, xmm6 ; xmm4 = | (R-G)/d + 4 | (G-B)/d + 6 | (B-R)/d + 2 | (A-G)/d | (floats SP)

	; multiplico por 60
    movdqu xmm6, [hsl_sixty_mask]
    mulps xmm4, xmm6 ; xmm4 = | 60 * ((R-G)/d + 4) | 60 * ((G-B)/d + 6) | 60 * ((B-R)/d + 2) | 60 * (A-G)/d | (floats SP)

	; me fijo en que if caigo de los calculos de H
	; para eso, preparo registros auxiliares con maxc, R, G y B
	movd edx, xmm1 ; edx = maxc (int 32b)
	movdqu xmm2, xmm0 ; xmm2 = | R | G | B | A | (int 32b)
	psrldq xmm2, 4 ; xmm2 = | 0 | R | G | B | (int 32b)
	movd eax, xmm2 ; eax = B (int 32b)
	psrldq xmm2, 4 ; xmm2 = | 0 | 0 | R | G | (int 32b)
	movd r8d, xmm2 ; r8d = G (int 32b)
	psrldq xmm2, 4 ; xmm2 = | 0 | 0 | 0 | R | (int 32b)
	movd r9d, xmm2 ; r9d = R (int 32b)

    .rgbTOhsl_max_r:
    cmp edx, r9d
    jne .rgbTOhsl_max_g
	; cmax == R
	psrldq xmm4, 8 ; xmm4 = | 0 | 0 | 60 * ((R-G)/d + 4) | 60 * ((G-B)/d + 6) | (floats SP)
	movd edx, xmm4 ; edx = 60 * ((G-B)/d + 6) (float SP)
    jmp .rgbTOhsl_h_360

    .rgbTOhsl_max_g:
    cmp edx, r8d
    jne .rgbTOhsl_max_b
	; cmax == G
	psrldq xmm4, 4 ; xmm4 = | 0 | 60 * ((R-G)/d + 4) | 60 * ((G-B)/d + 6) | 60 * ((B-R)/d + 2) | (floats SP)
	movd edx, xmm4 ; edx = 60 * ((B-R)/d + 2) (float SP)
	jmp .rgbTOhsl_h_360

    .rgbTOhsl_max_b:
	; cmax == B
	psrldq xmm4, 12 ; xmm4 = | 0 | 0 | 0 | 60 * ((R-G)/d + 4) | (floats SP)
	movd edx, xmm4 ; edx = 60 * ((R-G)/d + 4) (float SP)

    .rgbTOhsl_h_360:
    cmp edx, 360
    jl .rgbTOhsl_h_menor_360
	movd xmm1, edx ; xmm1 = | 0 | 0 | 0 | H | (float SP)
	movdqu xmm2, [hsl_sub_360] ; xmm2 = | 0.0 | 0.0 | 0.0 | 360.0 |
	subps xmm1, xmm2 ; xmm1 = | 0 | 0 | 0 | H-360 | (float SP)
	pslldq xmm1, 4 ; xmm1 = | 0 | 0 | H-360 | 0 | (float SP)
	addps xmm14, xmm1 ; xmm14 = | L | S | H | 0 |
	jmp .rgbTOhsl_fin

    .rgbTOhsl_h_menor_360:
	movd xmm1, edx ; xmm1 = | 0 | 0 | 0 | H | (float SP)
	pslldq xmm1, 4 ; xmm1 = | 0 | 0 | H | 0 | (float SP)
	addps xmm14, xmm1 ; xmm14 = | L | S | H | 0 |

    .rgbTOhsl_fin:
	pslldq xmm0, 12 ; xmm0 = | A | 0 | 0 | 0 | (int 32b)
	psrldq xmm0, 12 ; xmm0 = | 0 | 0 | 0 | A | (int 32b)
	cvtdq2ps xmm0, xmm0 ; xmm0 = | 0 | 0 | 0 | A | (floats SP)
	por xmm14, xmm0 ; xmm14 = | L | S | H | A |
    movdqu [rsi], xmm14
	;*****
	pop rbp
	ret

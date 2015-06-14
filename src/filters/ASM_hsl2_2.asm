; ************************************************************************* ;
; Organizacion del Computador II                                            ;
;                                                                           ;
;   Implementacion de la funcion HSL 2                                      ;
;                                                                           ;
; ************************************************************************* ;

; void ASM_hsl2_2(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll)
global ASM_hsl2_2
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

; mascaras para rgbTOhsl
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

; mascaras para hslTOrgb
hsl_mul_255: dd 255.0, 255.0, 255.0, 255.0
hsl_const_60: dd 60.0, 0.0, 0.0, 0.0
hsl_const_120: dd 120.0, 0.0, 0.0, 0.0
hsl_const_180: dd 180.0, 0.0, 0.0, 0.0
hsl_const_240: dd 240.0, 0.0, 0.0, 0.0
hsl_const_300: dd 300.0, 0.0, 0.0, 0.0
hsl_const_360: dd 360.0, 0.0, 0.0, 0.0

section .text

ASM_hsl2_2:
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
    movdqu xmm6, [hsl_sixty_mask] ; xmm6 = | 60.0 | 60.0 | 60.0 | 60.0 |
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
    jmp .rgbTOhsl_h_360

    .rgbTOhsl_max_g:
    cmp edx, r8d
    jne .rgbTOhsl_max_b
	; cmax == G
	psrldq xmm4, 4 ; xmm4 = | 0 | 60 * ((R-G)/d + 4) | 60 * ((G-B)/d + 6) | 60 * ((B-R)/d + 2) | (floats SP)
	jmp .rgbTOhsl_h_360

    .rgbTOhsl_max_b:
	; cmax == B
	psrldq xmm4, 12 ; xmm4 = | 0 | 0 | 0 | 60 * ((R-G)/d + 4) | (floats SP)

    .rgbTOhsl_h_360:
    pxor xmm1, xmm1
	movss xmm1, xmm4 ; xmm1 = |0|0|0|H|
	mov edx, __float32__(360.0)
	movd xmm2, edx ; xmm1 = |0|0|0|360.0|
	cmpltss xmm4, xmm2 ; xmm4[0] = H < 360.0
	movd edx, xmm4 ; edx = H < 360.0

    cmp edx, FALSE
    jne .rgbTOhsl_h_menor_360
	subss xmm1, xmm2 ; xmm1 = | 0 | 0 | 0 | H-360 | (float SP)
	pslldq xmm1, 4 ; xmm1 = | 0 | 0 | H-360 | 0 | (float SP)
	addps xmm14, xmm1 ; xmm14 = | L | S | H | 0 |
	jmp .rgbTOhsl_fin

    .rgbTOhsl_h_menor_360:
	pslldq xmm1, 4 ; xmm1 = | 0 | 0 | H | 0 | (float SP)
	addps xmm14, xmm1 ; xmm14 = | L | S | H | 0 |

    .rgbTOhsl_fin:
	pslldq xmm0, 12 ; xmm0 = | A | 0 | 0 | 0 | (int 32b)
	psrldq xmm0, 12 ; xmm0 = | 0 | 0 | 0 | A | (int 32b)
	cvtdq2ps xmm0, xmm0 ; xmm0 = | 0 | 0 | 0 | A | (floats SP)
	por xmm14, xmm0 ; xmm14 = | L | S | H | A |
    movdqu [rsi], xmm14 ; [rsi] = | L | S | H | A |
	;*****
	pop rbp
	ret


	; void hslTOrgb(float *dst, uint8_t *src)
	hslTOrgb:
		push rbp
		mov rbp, rsp
		; **********
	    ; limpio xmm15 para usarlo como registro auxiliar
	    pxor xmm15, xmm15
		; limpio xmm14 para ir almacenendo la representacion en HSL
	    pxor xmm14, xmm14

	    ; cargo el pixel
	    movdqu xmm0, [rdi] ; xmm0 = | L | S | H | A | (floats SP)

		; paso L, S y H cada uno a un registro
		movdqu xmm1, xmm0 ; xmm1 = | L | S | H | A | (floats SP)
		psrldq xmm1, 12 ; xmm1 = | 0 | 0 | 0 | L | (float SP)
		movdqu xmm2, xmm0 ; xmm2 = | L | S | H | A | (floats SP)
		pslldq xmm2, 4
		psrldq xmm2, 12 ; xmm2 = | 0 | 0 | 0 | S | (float SP)
		movdqu xmm3, xmm0 ; xmm3 = | L | S | H | A | (floats SP)
		pslldq xmm3, 8
		psrldq xmm3, 12 ; xmm3 = | 0 | 0 | 0 | H | (float SP)

		; voy a usar xmm14, 13 y 12 para almacenar c, x y m respectivamente

		; calculo c
		; multiplico L por 2 y le resto 1
		movdqu xmm4, xmm1 ; xmm4 = | 0 | 0 | 0 | L | (float SP)
	    movdqu xmm5, [hsl_first_dword_one] ; xmm5 = | 0.0 | 0.0 | 0.0 | 1.0 |
	    addps xmm5, xmm5 ; xmm5 = | 0.0 | 0.0 | 0.0 | 2.0 |
	    mulps xmm4, xmm5 ; xmm4 = | 0 | 0 | 0 | 2*L | (floats SP)
	    movdqu xmm5, [hsl_first_dword_one] ; xmm5 = | 0.0 | 0.0 | 0.0 | 1.0 |
	    subps xmm4, xmm5 ; xmm4 = | 0 | 0 | 0 | 2*L - 1 | (floats SP)

		; a lo anterior, le aplico fabs y luego se lo resto a 1
	    movdqu xmm6, [hsl_fabs_mask] ; xmm6 = | 0x7fffffff | 0x7fffffff | 0x7fffffff | 0x7fffffff |
	    andps xmm4, xmm6  ; xmm4 = | 0 | 0 | 0 | fabs(2*L - 1) | (floats SP)
	    subps xmm5, xmm4 ; xmm5 = | 0 | 0 | 0 | 1 - fabs(2*L - 1) | (floats SP)

		; lo multiplico por S
		mulps xmm5, xmm2 ; xmm5 = | 0 | 0 | 0 | (1 - fabs(2*L - 1)) * S | (floats SP)
		movdqu xmm14, xmm5 ; xmm14 = | 0 | 0 | 0 | c | (floats SP)

		; calculo x
		; cargo H y lo divido por 60
		movdqu xmm4, xmm3 ; xmm4 = | 0 | 0 | 0 | H | (float SP)
		movdqu xmm6, [hsl_sixty_mask] ; xmm6 = | 60.0 | 60.0 | 60.0 | 60.0 |
		divps xmm4, xmm6 ; xmm4 = | 0 | 0 | 0 | H/60 | (float SP)

		; calculo fmod(H/60, 2)
		movdqu xmm5, [hsl_first_dword_one] ; xmm5 = | 0.0 | 0.0 | 0.0 | 1.0 |
		movdqu xmm7, xmm5 ; xmm7 = | 0.0 | 0.0 | 0.0 | 1.0 |
		addps xmm5, xmm5 ; xmm5 = | 0.0 | 0.0 | 0.0 | 2.0 |
		movdqu xmm8, [hsl_first_dword_zero] ; xmm8 = | 1.0 | 1.0 | 1.0 | 0.0 |
		addps xmm5, xmm8 ; xmm5 = | 1.0 | 1.0 | 1.0 | 2.0 |
		divps xmm4, xmm5 ; xmm4 = | 0.0 | 0.0 | 0.0 | (H/60)/2.0 | (floats SP)
		movdqu xmm6, xmm4 ; xmm6 = | 0.0 | 0.0 | 0.0 | (H/60)/2.0 | (floats SP)
		cvttps2dq xmm6, xmm6 ; xmm6 = | 0.0 | 0.0 | 0.0 | int_32((H/60)/2.0) | (ints 32b)
		cvtdq2ps xmm6, xmm6 ; xmm6 = | 0.0 | 0.0 | 0.0 | parte_entera((H/60)/2.0) | (floats SP)
		subps xmm4, xmm6 ; xmm4 = | 0.0 | 0.0 | 0.0 | ((H/60)/2.0) - parte_entera((H/60)/2.0) | (floats SP)
		mulps xmm4, xmm5 ; xmm4  = | 0.0 | 0.0 | 0.0 | fmod(H/60,2.0) | (floats SP)

		; le resto 1 a fmod(H/60, 2)
		subps xmm4, xmm7 ; xmm4  = | 0.0 | 0.0 | 0.0 | fmod(H/60,2.0) - 1 | (floats SP)

		; aplico fabs a lo que obtuve recien
		movdqu xmm6, [hsl_fabs_mask] ; xmm6 = | 0x7fffffff | 0x7fffffff | 0x7fffffff | 0x7fffffff |
	    andps xmm4, xmm6  ; xmm4 = | 0 | 0 | 0 | fabs(fmod(H/60,2.0) - 1) | (floats SP)

		; le resto lo que obtuve a 1
	    subps xmm7, xmm4 ; xmm5 = | 0 | 0 | 0 | 1 - fabs(fmod(H/60,2.0) - 1) | (floats SP)

		; lo multiplico por c
		mulps xmm7, xmm14 ; xmm7 = | 0 | 0 | 0 | c*(1 - fabs(fmod(H/60,2.0) - 1)) | (floats SP)
		movdqu xmm13, xmm7 ; xmm13 = | 0 | 0 | 0 | x | (floats SP)

		; calculo m
		; cargo c y lo divido por 2
		movdqu xmm4, xmm14 ; xmm4 = | 0 | 0 | 0 | c | (floats SP)
		divps xmm4, xmm5 ; xmm4 = | 0 | 0 | 0 | c/2 | (floats SP)

		; le resto lo que obtuve a L
		movdqu xmm12, xmm1 ; xmm12 = | 0 | 0 | 0 | L | (floats SP)
		subps xmm12, xmm4 ; xmm4 = | 0 | 0 | 0 | m = L - c/2 | (floats SP)

		; me fijo en que rango está el H para decidir cuales son los valores de R, G y B
		; voy a usar xmm9, 10 y 11 para almacenar R, G y B respectivamente
		.hslTOrgb_h_menor_60:
		movdqu xmm6, [hsl_const_60] ; xmm6 = | 0.0 | 0.0 | 0.0 | 60.0 |
		cmpleps xmm6, xmm3 ; xmm6 = | basura | basura | basura | 60.0 <= H |
		movd eax, xmm6 ; eax = 60.0 <= H
		cmp eax, DWORD 0
		jne .hslTOrgb_h_menor_120 ; salto <=> (60 <= H != FALSE ) <=> (60 <= H == TRUE)
		movdqu xmm9, xmm14 ; R = c
		movdqu xmm10, xmm13 ; G = x
		pxor xmm11, xmm11 ; B = 0
		jmp .hslTOrgb_escalas

		.hslTOrgb_h_menor_120:
		movdqu xmm6, [hsl_const_120] ; xmm6 = | 0.0 | 0.0 | 0.0 | 120.0 |
		cmpleps xmm6, xmm3 ; xmm6 = | basura | basura | basura | 120.0 <= H |
		movd eax, xmm6 ; eax = 120.0 <= H
		cmp eax, DWORD 0
		jne .hslTOrgb_h_menor_180 ; salto <=> (120 <= H != FALSE ) <=> (120 <= H == TRUE)
		movdqu xmm9, xmm13 ; R = x
		movdqu xmm10, xmm14 ; G = c
		pxor xmm11, xmm11 ; B = 0
		jmp .hslTOrgb_escalas

		.hslTOrgb_h_menor_180:
		movdqu xmm6, [hsl_const_180] ; xmm6 = | 0.0 | 0.0 | 0.0 | 180.0 |
		cmpleps xmm6, xmm3 ; xmm6 = | basura | basura | basura | 180.0 <= H |
		movd eax, xmm6 ; eax = 180.0 <= H
		cmp eax, DWORD 0
		jne .hslTOrgb_h_menor_240 ; salto <=> (180 <= H != FALSE ) <=> (180 <= H == TRUE)
		pxor xmm9, xmm9 ; R = 0
		movdqu xmm10, xmm14 ; G = c
		movdqu xmm11, xmm13 ; B = x
		jmp .hslTOrgb_escalas

		.hslTOrgb_h_menor_240:
		movdqu xmm6, [hsl_const_240] ; xmm6 = | 0.0 | 0.0 | 0.0 | 240.0 |
		cmpleps xmm6, xmm3 ; xmm6 = | basura | basura | basura | 240.0 <= H |
		movd eax, xmm6 ; eax = 240.0 <= H
		cmp eax, DWORD 0
		jne .hslTOrgb_h_menor_300 ; salto <=> (240 <= H != FALSE ) <=> (240 <= H == TRUE)
		pxor xmm9, xmm9 ; R = 0
		movdqu xmm10, xmm13 ; G = x
		movdqu xmm11, xmm14 ; B = c
		jmp .hslTOrgb_escalas

		.hslTOrgb_h_menor_300:
		movdqu xmm6, [hsl_const_300] ; xmm6 = | 0.0 | 0.0 | 0.0 | 300.0 |
		cmpleps xmm6, xmm3 ; xmm6 = | basura | basura | basura | 300.0 <= H |
		movd eax, xmm6 ; eax = 300.0 <= H
		cmp eax, DWORD 0
		jne .hslTOrgb_h_menor_360 ; salto <=> (300 <= H != FALSE ) <=> (300 <= H == TRUE)
		movdqu xmm9, xmm13 ; R = x
		pxor xmm10, xmm10 ; G = 0
		movdqu xmm11, xmm14 ; B = c
		jmp .hslTOrgb_escalas

		.hslTOrgb_h_menor_360:
		movdqu xmm9, xmm14 ; R = c
		pxor xmm10, xmm10 ; G = 0
		movdqu xmm11, xmm13 ; B = x

		; calculo la escala de R, G y B
		.hslTOrgb_escalas:
		; le sumo a R, G y B  el m calculado
		addps xmm9, xmm12 ; R = R + m . xmm9 = | 0 | 0 | 0 | R + m | (floats SP)
		addps xmm10, xmm12 ; G = G + m. xmm10 = | 0 | 0 | 0 | G + m | (floats SP)
		addps xmm11, xmm12  ; B = B + m. xmm11 = | 0 | 0 | 0 | B + m | (floats SP)

		; junto los tres valores (R, G y B) en un solo registro y los multiplico por 255
		pslldq xmm9,  12 ;  xmm9 = | R | 0 | 0 | 0 | (floats SP)
		pslldq xmm10,  8 ;  xmm9 = | 0 | G | 0 | 0 | (floats SP)
		pslldq xmm11,  4 ;  xmm9 = | 0 | 0 | B | 0 | (floats SP)
		por xmm9, xmm10
		por xmm9, xmm11 ;  xmm9 = | R | G | B | 0 | (floats SP)
		movdqu xmm6, [hsl_mul_255] ; xmm6 = | 255.0 | 255.0 | 255.0 | 255.0 |
		mulps xmm9, xmm6 ;  xmm9 = | R*255 | G*255 | B*255 | 0 | (floats SP)

		; junto los R,G,B con de Alpha original y paso a enteros de 32 bits
		cvtps2dq xmm9, xmm9 ;  xmm9 = | R | G | B | 0 | (ints 32b)
		pslldq xmm0, 12 ; xmm0 = | A | 0 | 0 | 0 | (floats SP)
		psrldq xmm0, 12 ; xmm0 = | 0 | 0 | 0 | A | (floats SP)
		cvtps2dq xmm0, xmm0 ; xmm0 = | 0 | 0 | 0 | A | (ints 32b)
		paddd xmm0, xmm9 ; xmm0 = | R | G | B | A | (int 32b)

		; paso el resultado a enteros de 8 bits
		packusdw xmm0, xmm15 ; xmm0 = | ceros | R | G | B | A | (int 16b)
		packuswb xmm0, xmm15 ; xmm0 = | ceros | R | G | B | A | (int 8b)

		; escribo el resultado
		movd [rsi], xmm0 ; [rsi] = | R | G | B | A |
		;*****
		pop rbp
		ret

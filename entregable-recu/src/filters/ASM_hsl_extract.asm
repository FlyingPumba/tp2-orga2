push   r15
push   r14
push   r13
push   r12
push   rbp
push   rbx
sub    rsp,56                                    
;test   esi,esi      
mov    DWORD PTR [rsp+28],esi                    
movss  DWORD PTR [rsp+8],xmm0                    
movss  DWORD PTR [rsp+12],xmm1                    
movss  DWORD PTR [rsp+24],xmm2                   
;jle    0x402754 <C_hsl+324
mov    eax,edi                                     
mov    r14d,edi                                    
mov    rbp,rdx                                     
shl    rax,2
xor    r13d,r13d                                   
mov    QWORD PTR [rsp+16],rax     
lea    eax,[rdi-1]                               
lea    r12,[rax*4+4]                             
nop    DWORD PTR [rax+rax]
.B:
test   r14d,r14d                                   
jle    .304
xor    ebx,ebx                                     
jmp    .C
nop    DWORD PTR [rax]
.F:
subss  xmm0,DWORD PTR [rip+0x22f8]1.0
.D:
movss  xmm1,DWORD PTR [rsp+12]
addss  xmm1,DWORD PTR [rsp+40]
movss  DWORD PTR [rsp+36],xmm0
movss  xmm0,DWORD PTR [rip+0x22da]1.0
ucomiss xmm1,xmm0
jb     .288
.E:
movss  xmm1,DWORD PTR [rsp+24]
addss  xmm1,DWORD PTR [rsp+44]
movss  DWORD PTR [rsp+40],xmm0
movss  xmm0,DWORD PTR [rip+0x22b7]1.0
ucomiss xmm1,xmm0
jb     .272
.G:
lea    rdi,[rsp+32]                              
mov    rsi,r15                                     
add    rbx,0x4                                     
movss  DWORD PTR [rsp+44],xmm0                   
call   hslTOrgb
cmp    rbx,r12                                     
je     .304
.C:
lea    r15,[rbx+rbp]                             
lea    rsi,[rsp+32]                              
mov    rdi,r15                                     
call   rgbTOhsl
movss  xmm0,DWORD PTR [rsp+8]                    
addss  xmm0,DWORD PTR [rsp+36]                   
ucomiss xmm0,DWORD PTR [rip+0x2276]0.0
jae    .F
xorps  xmm3,xmm3                                   
ucomiss xmm3,xmm0                                  
jbe    .D
addss  xmm0,DWORD PTR [rip+0x225c]1.0
jmp    .D
nop    DWORD PTR [rax]
.272:
xorps  xmm0,xmm0                                   
maxss  xmm0,xmm1                                   
jmp    .G
nop    DWORD PTR [rax]
.288:
xorps  xmm0,xmm0                                   
maxss  xmm0,xmm1                                   
jmp    .E
nop    DWORD PTR [rax]
.304:                   
add    r13d,1
add    rbp,QWORD PTR [rsp+16]                    
cmp    r13d,DWORD PTR [rsp+28]                   
jne    .B
add    rsp,56
pop    rbx                                         
pop    rbp                                         
pop    r12                                         
pop    r13                                         
pop    r14                                         
pop    r15                                         
ret                                                


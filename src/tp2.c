/* ************************************************************************* */
/* Organizacion del Computador II                                            */
/*                                                                           */
/*   main: Archivo principal para la solucion del trabajo practico 2         */
/*                                                                           */
/* ************************************************************************* */

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include "run.h"
#include "bmp/bmp.h"
#include "filters/filters.h"

#define MAXOPSPARAM 6

typedef struct s_options {
  char* program_name;
  int help;
  int c_asm;
  char* filter;
  char* ops[6];
  int valid;
} options;


void print_help(char* name);

int read_options(int argc, char* argv[], options* opt);

int main(int argc, char* argv[]){

  // (0) leer parametros
  options opt;
  if (argc == 1) {print_help(argv[0]); return 0;}
  if(read_options(argc, argv, &opt))
  {printf("ERROR reading parameters\n"); return 1;}
  
  //(1) ejecutar filtro
  int result;
  if(!strcmp(opt.filter,"blur") && opt.valid==2) {
    result = run_blur(opt.c_asm, opt.ops[0], opt.ops[1]);
  } else
  if(!strcmp(opt.filter,"merge") && opt.valid==4) {
    result = run_merge(opt.c_asm, opt.ops[0], opt.ops[1], opt.ops[2], atof(opt.ops[3]));
  } else    
  if(!strcmp(opt.filter,"hsl") && opt.valid==5) {
    result = run_hsl(opt.c_asm, opt.ops[0], opt.ops[1], atof(opt.ops[2]), atof(opt.ops[3]), atof(opt.ops[4]) );
  } else { 
    printf("Error: filtro desconocido (%s)\n",opt.filter);
    return 1;}
  if(result) { 
    printf("Error: ejecutando el filtro %s\n",opt.filter);
    return 1;}
  
  return 0;
}

void print_help(char* name) {
    printf ( "Uso: %s <c/asm1/asm2> <fitro> <parametros...>\n", name );
    printf ( "\n" );
    printf ( "Opcion C o ASM\n" );
    printf ( "         c : ejecuta el codigo C\n" );
    printf ( "      asm1 : ejecuta el codigo ASM version 1\n" );
    printf ( "      asm2 : ejecuta el codigo ASM version 2\n" );
    printf ( "\n" );
    printf ( "Filtro:\n" );
    printf ( "      <c/asm1/asm2> blur <src> <dst>\n");
    printf ( "      <c/asm1/asm2> merge <src1> <src2> <dst> <value>\n");
    printf ( "      <c/asm1/asm2> hsl <src> <dst> <h> <s> <l>\n");
    printf ( "\n" );
}

int read_options(int argc, char* argv[], options* opt) {
  opt->program_name = argv[0];
  opt->help = 0;
  opt->c_asm = -1;
  opt->filter = 0;
  int i;
  for(i=1;i<argc;i++) {
    if(!strcmp(argv[i],"-h")||!strcmp(argv[i],"-help"))
    {opt->help = 1; return 1;}
  }
  if(argc<1) {opt->help = 1; return 1;}
  if(!strcmp(argv[1],"c")||!strcmp(argv[1],"C")) {opt->c_asm = 0;}
  else if(!strcmp(argv[1],"a1")||!strcmp(argv[1],"asm1")||!strcmp(argv[1],"ASM1")) {opt->c_asm = 1;}
  else if(!strcmp(argv[1],"a2")||!strcmp(argv[1],"asm2")||!strcmp(argv[1],"ASM2")) {opt->c_asm = 2;}
  else {opt->help = 1; return 1;}
  if(argc<2) {opt->help = 1; return 1;}
  opt->filter = argv[2];
  int o=0;
  for(i=3;i<argc;i++) {
     opt->ops[o] = argv[i];
     o++; if(o>MAXOPSPARAM) break;
  }
  opt->valid = o;
  return 0;
}

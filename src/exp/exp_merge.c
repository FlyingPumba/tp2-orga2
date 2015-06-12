/* ************************************************************************* */
/* Organizacion del Computador II                                            */
/*                                                                           */
/*   Implementacion de la funcion Merge en C para 1/4 de los componentes     */
/*   Azules de la imagen                                                     */
/*                                                                           */
/* ************************************************************************* */

//DIRS
#include <dirent.h>
//STRINGS
#include <string.h>
//FILTROS
#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include "../run.h"
#include "../bmp/bmp.h"
#include "../filters/filters.h"
#include "rdtsc.h"

#define func_merge_size 5
#define func_size 5

void exp_merge(uint32_t w, uint32_t h, uint8_t* data1, uint8_t* data2, float value);
static const char* files_path = "img/";
static const void (*func_merge[func_merge_size])(uint32_t w, uint32_t h, uint8_t* data1, uint8_t* data2, float value) = {C_merge, ASM_merge1, ASM_merge2, EXP_C_merge, EXP_ASM_merge};

void execute_exp(BMP*, unsigned long*, float);
void print_results(FILE*, unsigned long*, char*, int, int, float);
void serialize();
int longcmp(const void *a, const void *b);
void copy_data(uint32_t w, uint32_t h, uint8_t* src, uint8_t* dst);

int main(void)
{
  FILE *file = fopen("datos_merge.dat", "w+");
  fprintf(file, "img\tw\th\ttam\tv\tcmerge\tasm1\tasm2\texpc\texpasm\n");
  DIR *d;
  struct dirent *dir;
  d = opendir(files_path);
  if (d){
    while ((dir = readdir(d)) != NULL){
      if (dir->d_name[0]!='.'){
        char path[64];
        strcpy(path, files_path);
        strcat(path, dir->d_name);
        BMP* img = bmp_read(path);
  			float v = (float)rand() / (float)RAND_MAX;
        printf("Ejecutando: %s \n", dir->d_name);
        unsigned long tiempos[func_size][30];
        for (int i=0; i<30; i++){
          unsigned long temp[func_size];
          execute_exp(img, temp, v);
          for (int j=0; j<func_size; j++){
            tiempos[j][i] = temp[j];
          }
        }
        for (int i=0; i<func_size; i++){
          qsort(tiempos[i], 30, sizeof(unsigned long), longcmp);
        }
        unsigned long res[func_size];
        for (int i=0; i<func_size; i++){
          res[i] = 0;
          for (int j=0; j<10; j++){
            res[i] += tiempos[i][j+10];
          }
          res[i] = res[i]/10;
        }
        print_results(file, res, dir->d_name, *(bmp_get_w(img)), *(bmp_get_h(img)), v);
        bmp_delete(img);
      }
    }
    closedir(d);
  }
  fclose(file);
  return(0);
}

void execute_exp(BMP* img, unsigned long* res, float v)
{
  // Leo archivo
  BMP* bmps[func_size];
  uint32_t h = *(bmp_get_h(img));
  uint32_t w = *(bmp_get_w(img));
  uint8_t *data1s[func_size];
  uint8_t *data2s[func_size];
  for (int i=0; i<func_size ;i++){
    bmps[i] = bmp_copy(img, 1);
    if(bmps[i]==0) {return;}
    uint8_t* data = bmp_get_data(bmps[i]);
    if(w%4!=0) {return;}
    data1s[i] = malloc(sizeof(uint8_t)*4*h*w);
    data2s[i] = malloc(sizeof(uint8_t)*4*h*w);
    if(*(bmp_get_bitcount(bmps[i])) == 24) {
      to32(w,h,data,data1s[i]);
      to32(w,h,data,data2s[i]);
    } else {
      copy_data(w,h,data,data1s[i]);
      copy_data(w,h,data,data1s[i]);
    }
  }
  // Me quedan los datos en w,h,data1,data2

  // Tests ------------------------------------------

  // Merge
  for (int i=0; i<func_merge_size; i++){
    serialize();
    unsigned long start, end;
    RDTSC_START(start);
    (*func_merge[i])(w,h,data1s[i], data2s[i], v);
    RDTSC_STOP(end);
    res[i] = end - start;
  }

  // End Tests ------------------------------------------

  // Libero memoria
  for (int i=0; i<func_size ;i++){
    if(*(bmp_get_bitcount(bmps[i])) == 24) {
      free(data1s[i]);
      free(data2s[i]);
    }
    bmp_delete(bmps[i]);
  }
}

void print_results(FILE* file, unsigned long* res, char* image_name, int w, int h, float v)
{
    // calculo el tipo
    int tipo = -1;

    const char s[2] = ".";
    char *token;
    /* get the first token */
    strtok(image_name, s);

  fprintf(file, "%s\t%d\t%d\t%d\t%f ", image_name, w, h, w*h, v);
  for(int i=0;i<func_size;i++) {
    fprintf(file, "%ld ", res[i]);
  }
  fprintf(file, "\n");
}

int longcmp(const void *a, const void *b)
{
  return (*(const unsigned long *)(a) < *(const unsigned long *)(b)) ? -1 : (*(const unsigned long *)(a) > *(const unsigned long *)(b));
}

void serialize()
{
  __asm__ __volatile__("cpuid; ");
}

void copy_data(uint32_t w, uint32_t h, uint8_t* src, uint8_t* dst)
{
  int i;
  for(i=0;i<(int)(w*h);i++) {
    dst[i*4+0]=src[i*4+0];
    dst[i*4+1]=src[i*4+1];
    dst[i*4+2]=src[i*4+2];
    dst[i*4+3]=src[i*4+3];
  }
}

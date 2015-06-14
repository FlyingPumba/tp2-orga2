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

#define func_size 6
#define muestras 50

static const char* files_path = "img/";
static const void (*func_hsl[func_size])(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll) = {C_hsl, ASM_hsl1_1, ASM_hsl1_2, ASM_hsl1_3, ASM_hsl1_4, ASM_hsl2};

void execute_exp(BMP*, unsigned long*);
void print_results(FILE*, unsigned long*, char*, int, int);
void serialize();
int longcmp(const void *a, const void *b);
void copy_data(uint32_t w, uint32_t h, uint8_t* src, uint8_t* dst);

int main(void)
{
  FILE *file = fopen("datos_hsl.dat", "w+");
  fprintf(file, "img hsl_c hsl_asm1_1 hsl_asm1_2 hsl_asm1_3 hsl_asm1_4 hsl_asm2 \n");
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
        printf("Ejecutando: %s \n", dir->d_name);
        unsigned long tiempos[func_size][muestras];
        for (int i=0; i<muestras; i++){
          unsigned long temp[func_size];
          execute_exp(img, temp);
          for (int j=0; j<func_size; j++){
            tiempos[j][i] = temp[j];
          }
        }
        for (int i=0; i<func_size; i++){
          qsort(tiempos[i], muestras, sizeof(unsigned long), longcmp);
        }
        unsigned long res[func_size];
        for (int i=0; i<func_size; i++){
          res[i] = 0;
          int start = (muestras/2)-5;
          for (int j=0; j<10; j++){
            res[i] += tiempos[i][j+start];
          }
          res[i] = res[i]/10;
        }
        print_results(file, res, dir->d_name, *(bmp_get_w(img)), *(bmp_get_h(img)));
        bmp_delete(img);
      }
    }
    closedir(d);
  }
  fclose(file);
  return(0);
}

void execute_exp(BMP* img, unsigned long* res)
{
  // Leo archivo
  BMP* bmps[func_size];
  uint32_t h = *(bmp_get_h(img));
  uint32_t w = *(bmp_get_w(img));
  uint8_t *data1s[func_size];
  for (int i=0; i<func_size ;i++){
    bmps[i] = bmp_copy(img, 1);
    if(bmps[i]==0) {return;}
    uint8_t* data = bmp_get_data(bmps[i]);
    if(w%4!=0) {return;}
    data1s[i] = malloc(sizeof(uint8_t)*4*h*w);
    if(*(bmp_get_bitcount(bmps[i])) == 24) {
      to32(w,h,data,data1s[i]);
    } else {
      copy_data(w,h,data,data1s[i]);
      copy_data(w,h,data,data1s[i]);
    }
  }
  // Me quedan los datos en w,h,data1,data2
  
  // Tests ------------------------------------------

  // Hsl
  for (int i=0; i<func_size; i++){
    serialize();
    unsigned long start, end;
    RDTSC_START(start);
    (*func_hsl[i])(w,h,data1s[i], 30.0, 0.1, 0.1);
    RDTSC_STOP(end);
    res[i] = end - start;
  }

  // End Tests ------------------------------------------

  // Libero memoria
  for (int i=0; i<func_size ;i++){
    if(*(bmp_get_bitcount(bmps[i])) == 24) {
      free(data1s[i]);
    }
    bmp_delete(bmps[i]);
  }
}

void print_results(FILE* file, unsigned long* res, char* image_name, int w, int h)
{
  fprintf(file, "%s ", image_name);
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

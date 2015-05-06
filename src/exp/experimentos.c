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

static const char* files_path = "img/";
static const void (*func_blur[3])(uint32_t w, uint32_t h, uint8_t* data) = {C_blur, ASM_blur1, ASM_blur2};
static const void (*func_merge[3])(uint32_t w, uint32_t h, uint8_t* data1, uint8_t* data2, float value) = {C_merge, ASM_merge1, ASM_merge2};
static const void (*func_hsl[3])(uint32_t w, uint32_t h, uint8_t* data, float hh, float ss, float ll) = {C_hsl, ASM_hsl1, ASM_hsl2};

void execute_exp(BMP*, unsigned long*);
void print_results(FILE*, unsigned long*, char*, int, int);
void serialize();
int longcmp(const void *a, const void *b);

int main(void)
{
  FILE *file = fopen("datos.dat", "w+");
  fprintf(file, "img w h c_blur asm1_blur asm2_blur c_merge asm1_merge asm2_merge c_hsl asm1_hsl asm2_hsl\n");
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
        unsigned long tiempos[9][30];
        for (int i=0; i<30; i++){
          unsigned long temp[9];
          BMP* bmp = bmp_copy(img, 1);
          execute_exp(bmp, temp);
          for (int j=0; j<9; j++){
            tiempos[j][i] = temp[j];
          }
        }
        for (int i=0; i<9; i++){
          qsort(tiempos[i], 30, sizeof(unsigned long), longcmp);
        }
        unsigned long res[9];
        for (int i=0; i<9; i++){
          res[i] = 0;
          for (int j=0; j<9; j++){
            res[i] += tiempos[i][j+10];
          }
          res[i] = res[i]/10;
        }
        print_results(file, res, dir->d_name, *(bmp_get_w(img)), *(bmp_get_h(img)));
      }
    }
    closedir(d);
  }
  fclose(file);
  return(0);
}

void execute_exp(BMP* bmp, unsigned long* res)
{
  // Leo archivo
  if(bmp==0) {return;}
  uint8_t* data = bmp_get_data(bmp);
  uint32_t h = *(bmp_get_h(bmp));
  uint32_t w = *(bmp_get_w(bmp));
  if(w%4!=0) {return;}
  uint8_t* data1 = 0;
  uint8_t* data2 = 0;
  if(*(bmp_get_bitcount(bmp)) == 24) {
    data1 = malloc(sizeof(uint8_t)*4*h*w);
    data2 = malloc(sizeof(uint8_t)*4*h*w);
    to32(w,h,data,data1);
    to32(w,h,data,data2);
  } else {
    data1 = data;
    data2 = data;
  }
  // Me quedan los datos en w,h,data1,data2
  
  // Tests ------------------------------------------

  // Blur
  for (int i=0; i<3; i++){
    serialize();
    unsigned long start, end;
    RDTSC_START(start);
    (*func_blur[i])(w,h,data1);
    RDTSC_STOP(end);
    res[i] = end - start;
  }

  // Merge
  for (int i=0; i<3; i++){
    serialize();
    unsigned long start, end;
    RDTSC_START(start);
    (*func_merge[i])(w,h,data1,data2,0.5);
    RDTSC_STOP(end);
    res[i+3] = end - start;
  }

  // Hsl
  for (int i=0; i<3; i++){
    serialize();
    unsigned long start, end;
    RDTSC_START(start);
    (*func_hsl[i])(w,h,data1, 30.0, 0.1, 0.1);
    RDTSC_STOP(end);
    res[i+6] = end - start;
  }

  // End Tests ------------------------------------------

  // Libero memoria
  if(*(bmp_get_bitcount(bmp)) == 24) {
    to24(w,h,data1,data);
    to24(w,h,data2,data);
    free(data1);
    free(data2);
  }
  bmp_delete(bmp);
}

void print_results(FILE* file, unsigned long* res, char* image_name, int w, int h)
{
  fprintf(file, "%s %d %d ", image_name, w, h);
  for(int i=0;i<9;i++) {  
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

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
void copy_data(uint32_t w, uint32_t h, uint8_t* src, uint8_t* dst);

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
          execute_exp(img, temp);
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
  BMP* bmps[9];
  uint32_t h = *(bmp_get_h(img));
  uint32_t w = *(bmp_get_w(img));
  uint8_t *data1s[9];
  uint8_t *data2s[9];
  for (int i=0; i<9 ;i++){
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

  // Blur
  for (int i=0; i<3; i++){
    serialize();
    unsigned long start, end;
    RDTSC_START(start);
    (*func_blur[i])(w,h,data1s[i]);
    RDTSC_STOP(end);
    res[i] = end - start;
  }

  // Merge
  for (int i=0; i<3; i++){
    serialize();
    unsigned long start, end;
    RDTSC_START(start);
    (*func_merge[i])(w,h,data1s[i+3],data2s[i+3],0.5);
    RDTSC_STOP(end);
    res[i+3] = end - start;
  }

  // Hsl
  for (int i=0; i<3; i++){
    serialize();
    unsigned long start, end;
    RDTSC_START(start);
    (*func_hsl[i])(w,h,data1s[i+6], 30.0, 0.1, 0.1);
    RDTSC_STOP(end);
    res[i+6] = end - start;
  }

  // End Tests ------------------------------------------

  // Libero memoria
  for (int i=0; i<9 ;i++){
    if(*(bmp_get_bitcount(bmps[i])) == 24) {
      free(data1s[i]);
      free(data2s[i]);
    }
    bmp_delete(bmps[i]);
  }
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

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

#define func_blur_size 7
#define func_size 7

static const char* files_path = "img/";
static const void (*func_blur[func_blur_size])(uint32_t w, uint32_t h, uint8_t* data) = {C_blur, ASM_blur1, ASM_blur2, EXP_C_blur1, EXP_C_blur2, EXP_C_blur3, EXP_ASM_blur3};

void execute_exp(BMP*, unsigned long*);
void print_results(FILE*, unsigned long*, char*, int, int);
void serialize();
int longcmp(const void *a, const void *b);
void copy_data(uint32_t w, uint32_t h, uint8_t* src, uint8_t* dst);

int main(void)
{
  FILE *file = fopen("datos_blur.dat", "w+");
  fprintf(file, "img w h tam cblur asm1blur asm2blur expcblur1 expcblur2 expcblur3 expasm3\n");
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
        unsigned long tiempos[func_size][30];
        for (int i=0; i<30; i++){
          unsigned long temp[func_size];
          execute_exp(img, temp);
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

  // Blur
  for (int i=0; i<func_blur_size; i++){
    serialize();
    unsigned long start, end;
    RDTSC_START(start);
    (*func_blur[i])(w,h,data1s[i]);
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

void print_results(FILE* file, unsigned long* res, char* image_name, int w, int h)
{
    // calculo el tipo
    int tipo = -1;

    const char s[2] = ".";
    char *token;
    /* get the first token */
    strtok(image_name, s);

  fprintf(file, "%s %d %d %d ", image_name, w, h, w*h);
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

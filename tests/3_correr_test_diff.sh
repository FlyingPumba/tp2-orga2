#!/bin/bash

# Este script ejecuta su implementacion y compara los resultados con los generados por la catedra

source param.sh

img0=${IMAGENES[0]}
img0=${img0%%.*}
img1=${IMAGENES[1]}
img1=${img1%%.*}

#$1 : Programa Ejecutable
#$2 : Filtro e Implementacion Ejecutar
#$3 : Archivos de Entrada
#$4 : Archivo de Salida (sin path)
#$5 : Parametros del filtro
#$6 : DIFF
function run_test {
    echo -e "dale con... $VERDE $4 $DEFAULT"
    $1 $2 $3 $ALUMNOSDIR/$4 $5
    if [ $? -ne 0 ]; then
      echo -e "$ROJO ERROR DE EJECUCION";
      echo -e "$AZUL Corregir errores en $2. Ver de probar la imagen $3, que se rompe.";
      echo -e "$AZUL Correr nuevamente $DEFAULT $1 $2 $3 $ALUMNOSDIR/$4 $5";
      ret=-1; return;
    fi
    $DIFFER $ALUMNOSDIR/$4 $CATEDRADIR/$4 $6
    if [ $? -ne 0 ]; then
      echo -e "$ROJO ERROR DE DIFERENCIAS";
      echo -e "$AZUL correr nuevamente $DEFAULT $DIFFER -v $ALUMNOSDIR/$4 $CATEDRADIR/$4 $6";
      echo -e "$AZUL Para poder ver en que pixeles hay diferencias. $DEFAULT";
      ret=-1; return;
    fi
    ret=0; return;
}

for imp in c asm1 asm2; do

  # BLUR
  for s in ${SIZES[*]}; do
    run_test "$TP2ALU" "$imp blur" "$TESTINDIR/$img0.$s.bmp" "$imp.$img0.$s.blur.bmp" "" "$DIFFBLUR"
    if [ $ret -ne 0 ]; then exit -1; fi
    run_test "$TP2ALU" "$imp blur" "$TESTINDIR/$img1.$s.bmp" "$imp.$img1.$s.blur.bmp" "" "$DIFFBLUR"
    if [ $ret -ne 0 ]; then exit -1; fi
  done

  # MERGE
  for s in ${SIZES[*]}; do
  for v in 0 0.131 0.223 0.313 0.409 0.5 0.662 0.713 0.843 0.921 1; do
    run_test "$TP2ALU" "$imp merge" "$TESTINDIR/$img0.$s.bmp $TESTINDIR/$img1.$s.bmp" "$imp.$img0.$s.merge$v.bmp" "$v" "$DIFFMERGE"
    if [ $ret -ne 0 ]; then exit -1; fi
  done; done

  # HSL
  for s in ${SIZESCROP[*]}; do
  for hh in 0  50.93 -30.72 181.44; do
  for ss in 0  0.313 -0.409 -0.843; do
  for ll in 0 -0.131  0.213  0.713; do
    run_test "$TP2ALU" "$imp hsl" "$TESTINDIR/$img1.$s.bmp" "$imp.$img1.$s.hsl$hh-$ss-$ll.bmp" "$hh $ss $ll" "$DIFFHSL"
    if [ $ret -ne 0 ]; then exit -1; fi
  done; done; done; done

done

echo ""
echo -e "$VERDE Felicitaciones los test de FUNCIONAMIENTO finalizaron correctamente $DEFAULT"


#!/bin/bash

# Este script ejecuta la implementacion de la catedra

source param.sh

#  $TESTINDIR $CATEDRADIR $ALUMNOSDIR
# TP2CAT

img0=${IMAGENES[0]}
img0=${img0%%.*}
img1=${IMAGENES[1]}
img1=${img1%%.*}

for imp in c asm1 asm2; do

  # BLUR
  for s in ${SIZES[*]}; do
  echo $TP2CAT $imp blur $TESTINDIR/$img0.$s.bmp $CATEDRADIR/$imp.$img0.$s.blur.bmp
       $TP2CAT $imp blur $TESTINDIR/$img0.$s.bmp $CATEDRADIR/$imp.$img0.$s.blur.bmp
  echo $TP2CAT $imp blur $TESTINDIR/$img1.$s.bmp $CATEDRADIR/$imp.$img1.$s.blur.bmp
       $TP2CAT $imp blur $TESTINDIR/$img1.$s.bmp $CATEDRADIR/$imp.$img1.$s.blur.bmp
  done

  # MERGE
  for s in ${SIZES[*]}; do
  for v in 0 0.131 0.223 0.313 0.409 0.5 0.662 0.713 0.843 0.921 1; do
  echo $TP2CAT $imp merge $TESTINDIR/$img0.$s.bmp $TESTINDIR/$img1.$s.bmp $CATEDRADIR/$imp.$img0.$s.merge$v.bmp $v
       $TP2CAT $imp merge $TESTINDIR/$img0.$s.bmp $TESTINDIR/$img1.$s.bmp $CATEDRADIR/$imp.$img0.$s.merge$v.bmp $v
  done; done

  # HSL
  for s in ${SIZESCROP[*]}; do
  for hh in 0  50.93 -30.72 181.44; do
  for ss in 0  0.313 -0.409 -0.843; do
  for ll in 0 -0.131  0.213  0.713; do
  echo $TP2CAT $imp hsl $TESTINDIR/$img1.$s.bmp $CATEDRADIR/$imp.$img1.$s.hsl$hh-$ss-$ll.bmp $hh $ss $ll
       $TP2CAT $imp hsl $TESTINDIR/$img1.$s.bmp $CATEDRADIR/$imp.$img1.$s.hsl$hh-$ss-$ll.bmp $hh $ss $ll
  done; done; done; done
  
done
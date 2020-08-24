#!/bin/csh
set opath=/home/ogihara/work/ToyViewer2.6/OPENSTEP/src06/obj-i386-opt/pao2png.tproj
cc -Wall -g -c -o $opath/convert.o convert.c
cc -Wall -g -c -o $opath/pao2png.o pao2png.c
cc -Wall -g -c -o $opath/paoread.o paoread.c
cc -g -o /home/ogihara/work/ToyViewer2.6/OPENSTEP/src06/ToyViewer.app/Resources/pao2png $opath/*.o -L../lib -lpng -lz

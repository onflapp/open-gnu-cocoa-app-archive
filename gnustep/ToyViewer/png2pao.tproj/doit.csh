#!/bin/csh
cc -Wall -g -c -o /home/ogihara/work/ToyViewer2.6/OPENSTEP/src06/obj-i386-opt/png2pao.tproj/png2pao.o png2pao.c
cc -Wall -g -c -o /home/ogihara/work/ToyViewer2.6/OPENSTEP/src06/obj-i386-opt/png2pao.tproj/sub.o sub.c
cc -Wall -g -c -o /home/ogihara/work/ToyViewer2.6/OPENSTEP/src06/obj-i386-opt/png2pao.tproj/convert.o convert.c
cc -g -o /home/ogihara/work/ToyViewer2.6/OPENSTEP/src06/ToyViewer.app/Resources/png2pao /home/ogihara/work/ToyViewer2.6/OPENSTEP/src06/obj-i386-opt/png2pao.tproj/*.o -L../lib -lpng -lz

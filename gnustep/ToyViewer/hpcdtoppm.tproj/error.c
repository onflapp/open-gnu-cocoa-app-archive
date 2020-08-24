/* hpcdtoppm (Hadmut's pcdtoppm) v0.6
*  Copyright (c) 1992, 1993, 1994 by Hadmut Danisch (danisch@ira.uka.de).
*  Permission to use and distribute this software and its
*  documentation for noncommercial use and without fee is hereby granted,
*  provided that the above copyright notice appear in all copies and that
*  both that copyright notice and this permission notice appear in
*  supporting documentation. It is not allowed to sell this software in 
*  any way. This software is not public domain.
*/

#include "hpcdtoppm.h"
#define X(a,b) ((a == b) ? "->" : "  ")

void eerror(enum ERRORS e,char *file,int line)
 {
  
  switch(e)
   {case E_NONE:   return;
    case E_IMP:    fprintf(stderr,"Sorry, Not yet implemented. [%s:%d]\n",file,line); break;
    case E_READ:   fprintf(stderr,"Error while reading.\n"); break;
    case E_WRITE:  fprintf(stderr,"Error while writing.\n"); break;
    case E_INTERN: fprintf(stderr,"Internal error. [%s:%d]\n",file,line); break;
    case E_ARG:    fprintf(stderr,"Error in Arguments !\n\n"); 
#ifdef SHORT_HELP
                   fprintf(stderr,"Usage: hpcdtoppm [options] pcd-file [ppm-file]\n");
                   fprintf(stderr,"       ( - means stdin )\n");
                   fprintf(stderr,"Opts:         [ -> = Default ] \n\n");
                   fprintf(stderr,"   [-x] [-s] [-d] [-i] [-m]\n");
                   fprintf(stderr,"   [-crop] [-pos] [-rep] [-vert] [-hori] [-S h v]\n");
                   fprintf(stderr,"   [-n] [-r] [-l] [-h] [-a]\n");
                   fprintf(stderr,"   [-ppm] [-pgm] [-ycc] [-ps] [-eps] [-psg] [-epsg] [-psd] [-epsd]\n");
                   fprintf(stderr,"   [-pl f] [-pb f] [-pw f] [-ph f] [-dpi f] [-fak f]\n");
                   fprintf(stderr,"   [-c0] [-c-] [-c+]\n");
                   fprintf(stderr,"   [-0] [-C d s] [-1] [-2] [-3] [-4] [-5] [-6]\n");

#endif
#ifdef LONG_HELP
                   fprintf(stderr,"Usage: hpcdtoppm [options] pcd-file [ppm-file]\n");
                   fprintf(stderr,"       ( - means stdin )\n");
                   fprintf(stderr,"Opts:         [ -> = Default ] \n\n");

                   fprintf(stderr,"     -x     Overskip mode (tries to improve color quality.)\n");
                   fprintf(stderr,"     -s     Apply simple sharpness-operator on the Luma-channel.\n");
                   fprintf(stderr,"     -i     Give some (buggy) informations from fileheader.\n");
                   fprintf(stderr,"     -m     Show the decoding steps to stderr.\n");
                   fprintf(stderr,"     -crop  Try to cut off the black frame.\n");
                   fprintf(stderr,"     -pos   Print file position of image to stderr.\n");
                   fprintf(stderr,"     -rep   Try to jump over defects in the Huffman Code.\n");
                   fprintf(stderr,"     -S h v Decode subrectangle with hori. and vert. boundaries h,v,\n");
                   fprintf(stderr,"            h,v of the form a-b or a+b, a and b integer or float [0.0...1.0]\n");
                   fprintf(stderr,"\n");

                   fprintf(stderr," %s  -c0    don't correct (linear).\n", X(C_DEFAULT,C_LINEAR));
                   fprintf(stderr," %s  -c-    correct darker.\n",         X(C_DEFAULT,C_DARK));
                   fprintf(stderr," %s  -c+    correct brighter.\n",       X(C_DEFAULT,C_BRIGHT));
                   fprintf(stderr,"\n");

                   fprintf(stderr," %s  -0     Extract thumbnails from Overview file.\n",        X(S_DEFAULT,S_Over));
                   fprintf(stderr," %s  -C d s Extract contact sheet from Overview file, d images width,\n",X(S_DEFAULT,S_Contact)); 
                   fprintf(stderr,"            with contact sheet orientation s ( one of n l r h).\n");
                   fprintf(stderr," %s  -1     Extract  128x192   from Image file.\n",           X(S_DEFAULT,S_Base16));
                   fprintf(stderr," %s  -2     Extract  256x384   from Image file.\n",           X(S_DEFAULT,S_Base4));
                   fprintf(stderr," %s  -3     Extract  512x768   from Image file.\n",           X(S_DEFAULT,S_Base));
                   fprintf(stderr," %s  -4     Extract 1024x1536  from Image file.\n",           X(S_DEFAULT,S_4Base));
                   fprintf(stderr," %s  -5     Extract 2048x3072  from Image file.\n",           X(S_DEFAULT,S_16Base));
                   fprintf(stderr," %s  -6     Extract 4096x6144  from Image file and 64Base-Directory.\n",           X(S_DEFAULT,S_64Base));
                   fprintf(stderr,"\n");
#endif
                   break;
    case E_OPT:    fprintf(stderr,"These Options are not allowed together.\n");break;
    case E_MEM:    fprintf(stderr,"Not enough memory !\n"); break;
    case E_HUFF:   fprintf(stderr,"Error in Huffman-Code-Table\n"); break;
    case E_SEQ:    fprintf(stderr,"Error in Huffman-Sequence, try option -rep\n"); break;
    case E_SEQ1:   fprintf(stderr,"Error1 in Huffman-Sequence, try option -rep\n"); break;
    case E_SEQ2:   fprintf(stderr,"Error2 in Huffman-Sequence, try option -rep\n"); break;
    case E_SEQ3:   fprintf(stderr,"Error3 in Huffman-Sequence, try option -rep\n"); break;
    case E_SEQ4:   fprintf(stderr,"Error4 in Huffman-Sequence, try option -rep\n"); break;
    case E_SEQ5:   fprintf(stderr,"Error5 in Huffman-Sequence, try option -rep\n"); break;
    case E_SEQ6:   fprintf(stderr,"Error6 in Huffman-Sequence, try option -rep\n"); break;
    case E_SEQ7:   fprintf(stderr,"Error7 in Huffman-Sequence, try option -rep\n"); break;
    case E_POS:    fprintf(stderr,"Error in file-position\n"); break;
    case E_OVSKIP: fprintf(stderr,"Can't read this resolution in overskip-mode\n"); break;
    case E_TAUTO:  fprintf(stderr,"Can't determine the orientation in overview mode\n");break;
    case E_SUBR:   fprintf(stderr,"Error in Subrectangle Parameters\n");break;
    case E_PRPAR:  fprintf(stderr,"Bad printing parameters\n");break;
    case E_CONFIG: fprintf(stderr,"Something is wrong with your configuration [see %s:%d]\n",file,line);
                   fprintf(stderr,"Edit the config.h and recompile...\n"); break;
    case E_TCANT:  fprintf(stderr,"Sorry, can't determine orientation for this file.\n");
                   fprintf(stderr,"Please give orientation parameters. \n");break;
    case E_FOPEN:  fprintf(stderr,"Can't open file\n"); break;
    default:       fprintf(stderr,"Unknown error %d ???  [%s:%d]\n",e,file,line);break;
   }
  close_all();
  exit(9);
 }



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



void writepicture(FILE *fout, sizeinfo *si, 
                  implane *r,implane *g,implane *b)
 {dim w,h;

  w=si->imhlen;
  h=si->imvlen;

  melde("writepicture\n");
     if((!r) || (r->iwidth != w ) || (r->iheight != h) || (!r->im)) error(E_INTERN);
  
     if((!g) || (g->iwidth != w ) || (g->iheight != h) || (!g->im)) error(E_INTERN);
     if((!b) || (b->iwidth != w ) || (b->iheight != h) || (!b->im)) error(E_INTERN);

  write_ppm(fout,w,h,
	r->im,r->mwidth,1, g->im,g->mwidth,1, b->im,b->mwidth,1);
 }




struct ph1 
 {char  id1[8];
  uBYTE ww1[14];
  char  id2[20];
  char  id3[4*16+4];
  short ww2;
  char  id4[20];
  uBYTE ww3[2*16+1];
  char  id5[4*16];
  uBYTE idx[11*16];
 } ;


void druckeid(void)
{struct ph1 *d;
 char ss[100];

 d=(struct ph1 *)sbuffer;

#define dr(feld,kennung)   \
     strncpy(ss,feld,sizeof(feld));\
     ss[sizeof(feld)]=0;\
     fprintf(stderr,"%s: %s \n",kennung,ss);


dr(d->id1,"Id1")
dr(d->id2,"Id2")
dr(d->id3,"Id3")
dr(d->id4,"Id4")
dr(d->id5,"Id5")

#undef dr 

}







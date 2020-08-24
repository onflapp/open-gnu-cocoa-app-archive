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




static uBYTE BUF[own_BUsize];
#define BUinit {BUcount=0;BUptr=BUF;}

#define BUrgb_flush        {fwrite(BUF,BUcount*3,1,fout);BUinit; }
#define BUrgb_write(r,g,b) {if(BUcount>=own_BUsize/3) BUrgb_flush; *BUptr++ = r ; *BUptr++ = g ; *BUptr++ = b ; BUcount++;}

#define BUgreyflush        {fwrite(BUF,BUcount,1,fout);BUinit; }
#define BUgreywrite(g)     {if(BUcount>=own_BUsize) BUgreyflush;  *BUptr++ = g ;  BUcount++;}




void write_ppm(FILE *fout,dim w,dim h, 
               uBYTE *rptr,sdim rzeil,sdim rpix,  
               uBYTE *gptr,sdim gzeil,sdim gpix,  
               uBYTE *bptr,sdim bzeil,sdim bpix) 
 {register uBYTE *pr,*pg,*pb;
  dim x,y;
  static uBYTE *BUptr;
  sINT   BUcount;

  fprintf(fout,PPM_Header,w,h);
  BUinit;
  for(y=0;y<h;y++)
   {
     pr= rptr; rptr+=rzeil;
     pg= gptr; gptr+=gzeil;
     pb= bptr; bptr+=bzeil;
     for(x=0;x<w;x++) 
      {BUrgb_write(*pr,*pg,*pb);
       pr+=rpix;  pg+=gpix;  pb+=bpix;
      }
   }
  BUrgb_flush;

 }


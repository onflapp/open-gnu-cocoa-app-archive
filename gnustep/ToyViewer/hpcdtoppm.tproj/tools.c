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


void halve(implane *p)
 {dim w,h,x,y;
  uBYTE *optr,*nptr;

  melde("halve\n");
  if ((!p) || (!p->im)) error(E_INTERN);

  w=p->iwidth/=2;      
  h=p->iheight/=2;     


  for(y=0;y<h;y++)
   {
    nptr=(p->im) +   y*(p->mwidth);
    optr=(p->im) + 2*y*(p->mwidth);

    for(x=0;x<w;x++,nptr++,optr+=2)
     { *nptr = *optr;
     }

   }

 }







void interpolate(implane *p)
 {dim w,h,x,y,yi;
  uBYTE *optr,*nptr,*uptr;

  melde("interpolate\n");
  if ((!p) || (!p->im)) error(E_INTERN);

  w=p->iwidth;
  h=p->iheight;

  if(p->mwidth  < 2*w ) error(E_INTERN);
  if(p->mheight < 2*h ) error(E_INTERN);


  p->iwidth=2*w;
  p->iheight=2*h;


  for(y=0;y<h;y++)
   {yi=h-1-y;
    optr=p->im+  yi*p->mwidth + (w-1);
    nptr=p->im+2*yi*p->mwidth + (2*w - 2);

    nptr[0]=nptr[1]=optr[0];

    for(x=1;x<w;x++)
     { optr--; nptr-=2;
       nptr[0]=optr[0];
       nptr[1]=(((sINT)optr[0])+((sINT)optr[1])+1)>>1;
     }
    }

  for(y=0;y<h-1;y++)
   {optr=p->im + 2*y*p->mwidth;
    nptr=optr+p->mwidth;
    uptr=nptr+p->mwidth;

    for(x=0;x<w-1;x++)
     {
      nptr[0]=(((sINT)optr[0])+((sINT)uptr[0])+1)>>1;
      nptr[1]=(((sINT)optr[0])+((sINT)optr[2])+((sINT)uptr[0])+((sINT)uptr[2])+2)>>2;
      nptr+=2; optr+=2; uptr+=2;
     }
    *(nptr++)=(((sINT)*(optr++))+((sINT)*(uptr++))+1)>>1;
    *(nptr++)=(((sINT)*(optr++))+((sINT)*(uptr++))+1)>>1;
   }


  optr=p->im + (2*h-2)*p->mwidth;
  nptr=p->im + (2*h-1)*p->mwidth;
  for(x=0;x<w;x++)
   { *(nptr++) = *(optr++);  *(nptr++) = *(optr++); }

 }




static sINT testbegin(void)
 {sINT i,j;
  for(i=j=0;i<32;i++)
    if(sbuffer[i]==0xff) j++;

  return (j>30);
  
 }


sINT Skip4Base(void)
 {sINT cd_offset,cd_offhelp;
  
  cd_offset = L_Head + L_Base16 + L_Base4 + L_Base ;
  SEEK(cd_offset+3);          
  EREADBUF;    
  cd_offhelp=((((sINT)sbuffer[510])<<8)|sbuffer[511]) + 1;

  cd_offset+=cd_offhelp;

  SEEK(cd_offset);
  EREADBUF;
  while(!testbegin())
   {cd_offset++;
    EREADBUF;
   }
  return cd_offset;
 }





void planealloc(implane *p, dim width, dim height)
 {melde("planealloc\n");
 
  p->iwidth=p->iheight=0;
  p->mwidth=width;
  p->mheight=height;

  p->mp = ( p->im = ( uBYTE * ) malloc  (width*height*sizeof(uBYTE)) );
  if(!(p->im)) error(E_MEM);
 }




/* Test Data types for their size an whether they 
   are signed / unsigned */

void typecheck(void)
 { sBYTE sbyte;
   uBYTE ubyte;
   sINT  sint;
   uINT  uInt;


   if(sizeof(sBYTE) != 1) error(E_CONFIG);
   sbyte=126; sbyte++; sbyte++;
   if(sbyte > 126 ) error(E_CONFIG);

   if(sizeof(uBYTE) != 1) error(E_CONFIG);
   ubyte=126; ubyte++; ubyte++;
   if(ubyte < 126 ) error(E_CONFIG);

#ifdef U_TOO_LONG
   if(sizeof(sINT) < 4) error(E_CONFIG);
   if(sizeof(uINT) < 4) error(E_CONFIG);
#else
   if(sizeof(sINT) != 4) error(E_CONFIG);
   if(sizeof(uINT) != 4) error(E_CONFIG);
#endif

   sint=1; sint--; sint--;
   if(sint>1) error(E_CONFIG);

   uInt=1; uInt--; uInt--;
   if(uInt<1) error(E_CONFIG);

 }


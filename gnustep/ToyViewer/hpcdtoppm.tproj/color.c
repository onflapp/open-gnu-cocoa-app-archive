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

extern sINT RGB_BitSh1,RGB_Maximum1;
extern sINT RGB_F_LL;
extern sINT RGB_F_C1,RGB_O_C1;
extern sINT RGB_F_C2,RGB_O_C2;
extern sINT RGB_F_G1,RGB_F_G2,RGB_O_G;
extern uBYTE RGB_corr0[],RGB_corr1[],RGB_corr2[];


static uBYTE *RGB_corr=0;
static sINT T_L[256],T_R[256],T_G[256],T_g[256],T_B[256];

#define slen 3072



static void initcorr(void)
 { 
  switch(corrmode)
   {case C_LINEAR: RGB_corr=RGB_corr0; break;
    case C_DARK:   RGB_corr=RGB_corr1; break;
    case C_BRIGHT: RGB_corr=RGB_corr2; break;
    default: error(E_INTERN);
   }
 }



static void initctable(void)
 {sINT i;
  static sINT init=0;

  if(init) return;

  init=1;

  initcorr();

  for(i=0;i<256;i++)
   {  T_L[i] = i * RGB_F_LL;
      T_R[i] = i * RGB_F_C2 + RGB_O_C2;
      T_G[i] = i * RGB_F_G1;
      T_g[i] = i * RGB_F_G2 + RGB_O_G;
      T_B[i] = i * RGB_F_C1 + RGB_O_C1;      
   }
  
 }


void ycctorgb(implane *l,implane *c1,implane *c2)
 {dim x,y,w,h;
  uBYTE *pl,*pc1,*pc2;
  sINT red,green,blue;
  sINT L;

  melde("ycctorgb\n");
  initctable();

  w=l->iwidth;
  h=l->iheight;

  for(y=0;y<h;y++)
   {
    pl =  l->im + y *  l->mwidth;
    pc1= c1->im + y * c1->mwidth;
    pc2= c2->im + y * c2->mwidth;

    for(x=0;x<w;x++)
     {
      L    =  T_L[*pl]; 
      red  = (L + T_R[*pc2]             )>>RGB_BitSh1;
      green= (L + T_G[*pc1] + T_g[*pc2] )>>RGB_BitSh1; 
      blue = (L + T_B[*pc1]             )>>RGB_BitSh1;

      red   = TRIF(red,  0,RGB_Maximum1,0,red,  RGB_Maximum1);
      green = TRIF(green,0,RGB_Maximum1,0,green,RGB_Maximum1);
      blue  = TRIF(blue ,0,RGB_Maximum1,0,blue, RGB_Maximum1);

      *(pl++ )=RGB_corr[red]; 
      *(pc1++)=RGB_corr[green]; 
      *(pc2++)=RGB_corr[blue];
     }
   }
 }
#undef BitShift


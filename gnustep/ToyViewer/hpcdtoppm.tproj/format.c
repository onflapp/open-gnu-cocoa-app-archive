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

struct pcdquad { uBYTE len,highseq,lowseq,key;};
struct pcdhqt  { uBYTE entries; struct pcdquad entry[256];};
struct myhqt   { uINT seq,mask,len; uBYTE key; };

static struct myhqt myhuff0[256],myhuff1[256],myhuff2[256];
static sINT          myhufflen0=0,myhufflen1=0,myhufflen2=0;




static void readhqtsub(struct pcdhqt *quelle,struct myhqt *ziel,sINT *anzahl)
#define E ((uINT) 1)
 {sINT i;
  struct pcdquad *sub;
  struct myhqt *help;
  *anzahl=(quelle->entries)+1;

  for(i=0;i<*anzahl;i++)
   {sub = (struct pcdquad *)(((uBYTE *)quelle)+1+i*sizeof(*sub));
    help=ziel+i;

    help->seq = (((uINT) sub->highseq) << 24) |(((uINT) sub->lowseq) << 16);
    help->len = ((uINT) sub->len) +1;
    help->key = sub->key;

#ifdef DEBUGhuff
   fprintf(stderr," Anz: %d A1: %08x  A2: %08x X:%02x %02x %02x %02x Seq:  %08x   Laenge:  %d %d\n",
          *anzahl,(uINT)sbuffer,(uINT)sub,
          ((uBYTE *)sub)[0],((uBYTE *)sub)[1],((uBYTE *)sub)[2],((uBYTE *)sub)[3],
          help->seq,help->len,sizeof(uBYTE));
#endif

    if(help->len > 16) error(E_HUFF);

    help->mask = ~ ( (E << (32-help->len)) -1); 

  }
#ifdef DEBUGhpc
  for(i=0;i<*anzahl;i++)
   {help=ziel+i;
    fprintf(stderr,"H: %3d  %08lx & %08lx (%2d) = %02x = %5d  %8x\n",
        i, help->seq,help->mask,help->len,help->key,(sBYTE)help->key,
        help->seq & (~help->mask));
   }
#endif

#undef E
}







void readhqt(sINT n)
 {
  uBYTE *ptr;

  melde("readhqt\n");
  EREADBUF;
  ptr = sbuffer;

  readhqtsub((struct pcdhqt *)ptr,myhuff0,&myhufflen0);

  if(n<2) return;
  ptr+= 1 + 4* myhufflen0;
  readhqtsub((struct pcdhqt *)ptr,myhuff1,&myhufflen1);

  if(n<3) return;
  ptr+= 1 + 4* myhufflen1;
  readhqtsub((struct pcdhqt *)ptr,myhuff2,&myhufflen2);

}

void readhqtx(sINT n)
 {
  uBYTE *ptr;

  melde("readhqtx\n");
  ptr = sbuffer;

  readhqtsub((struct pcdhqt *)ptr,myhuff0,&myhufflen0);

  if(n<2) return;
  ptr+= 1 + 4* myhufflen0;
  readhqtsub((struct pcdhqt *)ptr,myhuff1,&myhufflen1);

  if(n<3) return;
  ptr+= 1 + 4* myhufflen1;
  readhqtsub((struct pcdhqt *)ptr,myhuff2,&myhufflen2);

}









#ifdef FASTHUFF

static struct myhqt *HTAB0[0x10000],*HTAB1[0x10000],*HTAB2[0x10000];

static void inithuff(sINT hlen,struct myhqt *ptr,struct myhqt *TAB[])
 {sINT i,n;
  sINT seq,len;
  struct myhqt *help;

  for(i=0;i<0x10000;i++) TAB[i]=0;

  for(n=0;n<hlen;n++)
   {help=ptr+n;
    seq=(help->seq)>>16;
    len=help->len;

    for(i=0;i<(1<<(16-len));i++)
      TAB[seq | i] = help;
   }
 }
#endif



void decode(sizeinfo *si,int fak,implane *f,implane *f1,implane *f2,sINT autosync)
 {dim w,h,hlen,hende,vlen,vende,anfang,ende;
  sINT htlen,sum,do_inform,part;
  uINT sreg,maxwidth;
  uINT inh,n,zeile,segment,ident;
  struct myhqt *hp;

  uBYTE *nptr;
  uBYTE *lptr;

#define nextbuf  {  nptr=sbuffer; if(READBUF<1) error(E_READ); }
#define checkbuf { if (nptr >= sbuffer + sizeof(sbuffer)) nextbuf; }

#ifdef U_TOO_LONG
#define shiftreg(n) sreg = (sreg<< n ) & 0xffffffff;
#else
#define shiftreg(n) sreg<<=n;
#endif

#define shiftout(n){ shiftreg(n); inh-=n; \
                     while (inh<=24) \
                      {checkbuf; \
                       sreg |= ((uINT)(*(nptr++)))<<(24-inh);\
                       inh+=8;\
                      }\
                    }  
#define issync     ((sreg & 0xffffff00) == 0xfffffe00) 
#define brutesync  ((sreg & 0x00fff000) == 0x00fff000) 
#define seeksync { while (!brutesync) shiftout(8); while (!issync) shiftout(1);}

#ifdef FASTHUFF
  struct myhqt **HTAB;
  HTAB=0;
  inithuff(myhufflen0,myhuff0,HTAB0);
  inithuff(myhufflen1,myhuff1,HTAB1);
  inithuff(myhufflen2,myhuff2,HTAB2);
#define SETHUFF0 HTAB=HTAB0;
#define SETHUFF1 HTAB=HTAB1;
#define SETHUFF2 HTAB=HTAB2;
#define FINDHUFF(x) {x=HTAB[sreg>>16];}

#else

  sINT i;
  struct myhqt *htptr;
  htptr=0;
#define SETHUFF0 { htlen=myhufflen0 ; htptr = myhuff0 ; }
#define SETHUFF1 { htlen=myhufflen1 ; htptr = myhuff1 ; }
#define SETHUFF2 { htlen=myhufflen2 ; htptr = myhuff2 ; }
#define FINDHUFF(x)  {for(i=0, x=htptr;(i<htlen) && ((sreg & x ->mask)!= x->seq); i++,x++); \
                      if(i>=htlen) x=0;}
#endif

  melde("decode\n");
  anfang=ende=0;

  if(fak >= 0)
   {w   =si->w     *fak;
    h   =si->h     *fak;
    hlen=si->rdhlen*fak;  hende=hlen;
    vlen=si->rdvlen*fak;  vende=vlen;
   }
  else
   {fak = -fak;
    w   =si->w     /fak;
    h   =si->h     /fak;
    hlen=si->rdhlen/fak;  hende=hlen; 
    vlen=si->rdvlen/fak;  vende=vlen;
   }

    if ((hlen & 1) || (vlen & 1))
	error(E_INTERN);  /* Must be all even */

  if( f  && ((! f->im) || ( f->iheight != vlen  ) ||  (f->iwidth != hlen  ))) error(E_INTERN);
  if( f1 && ((!f1->im) || (f1->iheight != vlen/2) || (f1->iwidth != hlen/2))) error(E_INTERN);
  if( f2 && ((!f2->im) || (f2->iheight != vlen/2) || (f2->iwidth != hlen/2))) error(E_INTERN);

  htlen=sreg=maxwidth=0;
  zeile=0;
  nextbuf;
  inh=32;
  lptr=0;
  part=do_inform=0;
  shiftout(16);
  shiftout(16);

  if(autosync) seeksync;
  
  if(!issync) error(E_SEQ6);

  n=0;

  for(; ;)
   {
    if (issync)
     {shiftout(24);
      ident=sreg>>16;
      shiftout(16);

      zeile=(ident>>1) & 0x1fff;
      segment=ident>>14;
      if(do_inform) {fprintf(stderr,"Synchron mark found Line %d\n",zeile);do_inform=0;}
#ifdef DEBUGhpc
      fprintf(stderr,"Id %4x Zeile: %6d Seg %3d Pix bisher: %5d  Position: %8lx+%5lx=%8x\n",
          ident,zeile,segment,n,bufpos,nptr-sbuffer,bufpos+nptr-sbuffer);
#endif


      if(lptr && (n!=maxwidth)) error(E_SEQ1);
      n=0;

      if(zeile==h) {RPRINT; return; }
      if(zeile >h) error(E_SEQ2);    
      switch(segment)
       {
        case 1: error(E_SEQ3);
        case 0: maxwidth=w;
                if((!f) && autosync) {seeksync; n=maxwidth; break;}
                if(!f) error(E_SEQ7);
                if(zeile >= vende) {seeksync; n=maxwidth; break;}
                anfang=0; ende=hende;
                lptr=f->im + zeile * f->mwidth;
                SETHUFF0;
                part=0;
                break;

        case 2: maxwidth=w>>1;
                if(!f1) return;
                /*if((!f1) && autosync) {seeksync; break;}*/
                if(zeile >= vende) {seeksync; n=maxwidth; break;}
                anfang=0; ende=hende>>1;
                lptr=f1->im + (zeile >> 1)*f1->mwidth;
                SETHUFF1;
                part=1;
                break;
 
        case 3: maxwidth=w>>1;
                if(!f2) return;
                /*if((!f2) && autosync) {seeksync; break;}*/
                if(zeile >= vende) {seeksync; n=maxwidth; break;}
                anfang=0; ende=hende>>1;
                lptr=f2->im + (zeile >> 1)*f2->mwidth;
                SETHUFF2;
                part=2;
                break;

        default:error(E_SEQ3);
	}
     }
    else
     {
      if(!lptr)      error(E_SEQ6);

      if(n>maxwidth) 
        {
#ifdef DEBUGhpc
         fprintf(stderr,"Register: %08lx Pos: %08lx\n",sreg,bufpos+nptr-sbuffer);
#endif
         error(E_SEQ4);
       }
      else
       {FINDHUFF(hp);
        if(!hp) error(E_SEQ5);
        if((n>= anfang) && (n<ende))
           {sum=((sINT)(*lptr)) + ((sBYTE)hp->key);
            NORM(sum);
            *(lptr++) = sum;
           }

          n++; 
          shiftout(hp->len);
       }
     }

   }


#undef nextbuf  
#undef checkbuf 
#undef shiftout
#undef issync
#undef seeksync

 }



/* Decode the 64Base files */
void decodex(FILE **fp, int tag , struct ic_descr *descr,sizeinfo *si,int fak,implane *f,sINT autosync)
 {dim w,h,hlen,hende,vlen,vende,anfang,ende;
  sINT htlen,sum,do_inform,part;
  uINT sreg,maxwidth;
  uINT inh,n,pos,zeile,segment,ident,sector,offset,length;
  struct myhqt *hp;

  uBYTE *nptr;
  uBYTE *lptr;
 
  int bufcont;



#define nextbuf  {  nptr=sbuffer; \
                    do\
                     {bufcont=fread(sbuffer,1,sizeof(sbuffer),*fp);\
                      if(bufcont<1)\
                       {if(feof(*fp)) fp++;\
                        else error(E_READ);\
                        if(!*fp)      return; }\
                     } while (bufcont<1); }


#define checkbuf { if (nptr >= sbuffer + bufcont) nextbuf; }

#ifdef U_TOO_LONG
#define shiftreg(n) sreg = (sreg<< n ) & 0xffffffff;
#else
#define shiftreg(n) sreg<<=n;
#endif

#define shiftout(n){ shiftreg(n); inh-=n; \
                     while (inh<=24) \
                      {checkbuf; \
                       sreg |= ((uINT)(*(nptr++)))<<(24-inh);\
                       inh+=8;\
                      }\
                    }  
#define issync     ((sreg & 0xffffff00) == 0xfffffe00) 
#define brutesync  ((sreg & 0x00fff000) == 0x00fff000) 
#define seeksync { while ((!brutesync) && (bufcont>0)) shiftout(8); \
                   while ((!issync) && (bufcont>0)) shiftout(1);}

#ifdef FASTHUFF
  struct myhqt **HTAB;
  HTAB=0;
  switch(tag)
   {case 0:  inithuff(myhufflen0,myhuff0,HTAB0); break;
    case 1:  inithuff(myhufflen1,myhuff1,HTAB1); break;
    case 2:  inithuff(myhufflen2,myhuff2,HTAB2); break;
    default: error(E_INTERN);
   }
#define SETHUFF0 HTAB=HTAB0;
#define SETHUFF1 HTAB=HTAB1;
#define SETHUFF2 HTAB=HTAB2;
#define FINDHUFF(x) {x=HTAB[sreg>>16];}

#else

  sINT i;
  struct myhqt *htptr;
  htptr=0;
#define SETHUFF0 { htlen=myhufflen0 ; htptr = myhuff0 ; }
#define SETHUFF1 { htlen=myhufflen1 ; htptr = myhuff1 ; }
#define SETHUFF2 { htlen=myhufflen2 ; htptr = myhuff2 ; }
#define FINDHUFF(x)  {for(i=0, x=htptr;(i<htlen) && ((sreg & x ->mask)!= x->seq); i++,x++); \
                      if(i>=htlen) x=0;}
#endif







  melde("decodex\n");
  anfang=ende=0;
  maxwidth=FILE32(descr->length);
  h       =FILE16(descr->height);
  offset  =FILE16(descr->offset);
  length  =FILE32(descr->length);


  if(fak >= 0)
   {w   =si->w     *fak;
    h   =si->h     *fak;
    hlen=si->rdhlen*fak;  hende=hlen;
    vlen=si->rdvlen*fak;  vende=vlen;
   }
  else
   {fak = -fak;
    w   =si->w     /fak;
    h   =si->h     /fak;
    hlen=si->rdhlen/fak;  hende=hlen; 
    vlen=si->rdvlen/fak;  vende=vlen;
   }

    if ((hlen & 1) || (vlen & 1))
	error(E_INTERN);  /* Must be all even */

  if(!f) error(E_INTERN);

#ifdef DEBUGhpc
  fprintf(stderr,"fak %d\n",fak);
  fprintf(stderr,"f->im %x  \n",(unsigned)f->im);
  fprintf(stderr,"f->iheight  %d   %d\n",f->iheight,vlen);
  fprintf(stderr,"f->iwidth   %d   %d\n",f->iwidth,hlen);
  fprintf(stderr,"hoffset %d hende %d voffset %d vende %d\n",0,hende,0,vende);
#endif

  if((! f->im) || ( f->iheight != vlen  ) ||  (f->iwidth != hlen  )) error(E_INTERN);


  switch(tag)
   {case 0: SETHUFF0; break;
    case 1: SETHUFF1; break;
    case 2: SETHUFF2; break;
    default: error(E_INTERN);
   }



  htlen=sreg=0;
  zeile=0;
  nextbuf;
  inh=32;
  lptr=0;
  part=do_inform=0;
  shiftout(16);
  shiftout(16);

  if(autosync) seeksync;
  
  if(!issync) error(E_SEQ6);

  n=pos=0;

  for(; ;)
   {if (issync)
     {shiftout(24);
      ident=(sreg>>8) & 0xffffff;
      shiftout(24);

      segment=(ident>>20) & 0xf;
      zeile  =(ident>>6 ) & 0x3fff;
      sector =(ident>>1 ) & 0x1f;

      if(segment != tag) {fprintf(stderr,"Falsches Segment\n"); return;}
      if(do_inform)      {fprintf(stderr,"Synchron mark found Line %d\n",zeile);do_inform=0;}
      if(zeile >= vende) return;
   


#ifdef DEBUGhpc
      fprintf(stderr,"Id %4x Zeile: %6d Seg %3d Sect %d Pix bisher: %5d \n",
          ident,zeile,segment,sector,n);
#endif


      if(lptr && (n!=maxwidth)) error(E_SEQ1);

      n=0;

      if(zeile==h) {RPRINT; return; }
      if(zeile >h) error(E_SEQ2);    
      switch(tag)
          {case 0: anfang=0; ende=hende;
                   pos=offset + sector*length;
                   if((pos>=ende) || (pos+length < anfang)) { n=maxwidth; seeksync; continue;}
                   lptr=f->im + zeile * f->mwidth + (pos>anfang?(pos-anfang):0)  ;

                   break;
           case 1:
           case 2: anfang=0; ende=hende;
                   pos=(offset>>1) + sector*length;
                   if((pos>=ende) || (pos+length < anfang)) { n=maxwidth; seeksync; continue;}
                   lptr=f->im + zeile * f->mwidth + (pos>anfang?(pos-anfang):0)  ;

                   break;


           default: error(E_INTERN);
          }
     }
    else /* for if (issync) */
     {if(!lptr)      error(E_SEQ6);

      FINDHUFF(hp);
      if(!hp) error(E_SEQ5);
      if((pos >= anfang) && (pos<ende)) 
           {sum=((sINT)(*lptr)) + ((sBYTE)hp->key);    
            NORM(sum);   
            *(lptr++) = sum;  
           }
      n++; pos++;
      shiftout(hp->len);
      if(n==maxwidth) 
         { if ((zeile >= vende -1) && (pos >= hende)) return;
           seeksync;
         }
     }
   }




#undef nextbuf  
#undef checkbuf 
#undef shiftout
#undef issync
#undef seeksync

 }












enum ERRORS readplain(sizeinfo *si,int fak,implane *l,implane *c1,implane *c2)
 {dim i,w,h,hlen,vlen;
  uBYTE *pl=0,*pc1=0,*pc2=0;

  melde("readplain\n");

#ifdef DEBUGhpc
  fprintf(stderr,"readplain %d %d %d %d %d %d %d\n",fak,si->w,si->h,0,si->rdhlen,0,si->rdvlen);
#endif

    if(fak >= 0) {
	w   =si->w     *fak;
	h   =si->h     *fak;
	hlen=si->rdhlen*fak;
	vlen=si->rdvlen*fak;
    }else {
	fak = -fak;
	w   =si->w     /fak;
	h   =si->h     /fak;
	hlen=si->rdhlen/fak;
	vlen=si->rdvlen/fak;
    }

    if ((hlen & 1) || (vlen & 1))
	error(E_INTERN);  /* Must be all even */

    
  if(l)
   { if ((l->mwidth<hlen) || (l->mheight<vlen) || (!l->im)) error(E_INTERN);
     l->iwidth=hlen;
     l->iheight=vlen;
     pl=l->im;
   }

  if(c1)
   { if ((c1->mwidth<(hlen>>1)) || (c1->mheight<(vlen>>1)) || (!c1->im)) error(E_INTERN);
     c1->iwidth=hlen>>1;
     c1->iheight=vlen>>1;
     pc1=c1->im;
   }

  if(c2)
   { if ((c2->mwidth<(hlen>>1)) || (c2->mheight<(vlen>>1)) || (!c2->im)) error(E_INTERN);
     c2->iwidth=hlen>>1;
     c2->iheight=vlen>>1;
     pc2=c2->im;
   }

  for(i=0;i<vlen>>1;i++)
   {
    if(pl)
     { if(hlen==w)
        {if(READ(pl,w)<1) return(E_READ);
         pl+= l->mwidth;

         if(READ(pl,w)<1) return(E_READ);
         pl+= l->mwidth;
        }
       else
        {
         if(READ(pl,hlen)<1) return(E_READ);
         pl+= l->mwidth;
         
         SKIPr(w-hlen);

         if(READ(pl,hlen)<1) return(E_READ);
         pl+= l->mwidth;

         SKIPr(w-hlen);         
        }
     }
    else SKIPr(2*w);
     
    if(pc1)
     {
       if(hlen==w)
        {
         if(READ(pc1,w>>1)<1) return(E_READ);
         pc1+= c1->mwidth;
        }
       else
        {
         if(READ(pc1,hlen>>1)<1) return(E_READ);
         pc1+= c1->mwidth;
         SKIPr((w-hlen)>>1);
        }
     }
    else SKIPr(w>>1);
     
    if(pc2)
     {
       if(hlen==w)
        {
         if(READ(pc2,w>>1)<1) return(E_READ);
         pc2+= c2->mwidth;
        }
       else
        {
         if(READ(pc2,hlen>>1)<1) return(E_READ);
         pc2+= c2->mwidth;
         SKIPr((w-hlen)>>1);
        }
     }
    else SKIPr(w>>1);


   }
  RPRINT;
  return E_NONE;
 }

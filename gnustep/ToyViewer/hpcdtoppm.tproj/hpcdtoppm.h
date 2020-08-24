/* hpcdtoppm (Hadmut's pcdtoppm) v0.6
*  Copyright (c) 1992, 1993, 1994 by Hadmut Danisch (danisch@ira.uka.de).
*  Permission to use and distribute this software and its
*  documentation for noncommercial use and without fee is hereby granted,
*  provided that the above copyright notice appear in all copies and that
*  both that copyright notice and this permission notice appear in
*  supporting documentation. It is not allowed to sell this software in 
*  any way. This software is not public domain.
*/


#include <stdio.h>
#include <string.h>
// #include <malloc.h>
#include <stdlib.h>
#include <sys/types.h>
#include <ctype.h>
#include "config.h"



/* Format definitions */

#define BaseW ((dim)768)
#define BaseH ((dim)512)

#define SECSIZE 0x800

#define SeHead   2
#define L_Head   (1+SeHead)

#define SeBase16 18
#define L_Base16 (1+SeBase16)

#define SeBase4  72
#define L_Base4  (1+SeBase4)

#define SeBase   288
#define L_Base   (1+SeBase)


#define neutrLum 128
#define neutrCh1 156
#define neutrCh2 137







/* Structures and definitions */
struct _implane
 {dim  mwidth,mheight,
       iwidth,iheight;
  uBYTE *im,*mp;
 };
typedef struct _implane implane;

#define nullplane ((implane *) 0)





struct _sizeinfo
 {dim w,h;  /* Image Resolution */
  dim rdhlen, rdvlen; /* Size of Image in Memory */
  dim imhlen, imvlen; /* Real Size of Image */
 };
typedef struct _sizeinfo sizeinfo;




/* Definitions for 64Base */

struct file32 { uBYTE x1,x2,x3,x4;};
struct file16 { uBYTE x1,x2;};
#define FILE32(x) ( (((uINT)x.x1)<<24) | (((uINT)x.x2)<<16) | (((uINT)x.x3)<<8) | (uINT)x.x4 )
#define FILE16(x) ( (((uINT)x.x1)<<8) | (uINT)x.x2 )

struct ic_header {char ic_name[0x28];
                  struct file16 val1;
                  struct file16 val2;
                  struct file32 off_descr;
                  struct file32 off_fnames;
                  struct file32 off_pointers;
                  struct file32 off_huffman;
                 };

struct ic_descr {struct file16 len;
                 uBYTE  color;
                 uBYTE  fill;  /* Don't know */
                 struct file16 width;
                 struct file16 height;
                 struct file16 offset;
                 struct file32 length;
                 struct file32 off_pointers;
                 struct file32 off_huffman;
                };


struct ic_fname  {char fname[12];
                  struct file32 size;
                 };

struct ic_entry {struct file16 fno;
                 struct file32 offset;
                };


enum   SIZES  { S_UNSPEC,S_Base16,S_Base4,S_Base,S_4Base,S_16Base,S_64Base,S_Over,S_Contact };
enum   CORR   { C_UNSPEC,C_LINEAR,C_DARK,C_BRIGHT };

enum   ERRORS { E_NONE,E_READ,E_WRITE,E_INTERN,E_ARG,E_OPT,E_MEM,E_HUFF,
                E_SEQ,E_SEQ1,E_SEQ2,E_SEQ3,E_SEQ4,E_SEQ5,E_SEQ6,E_SEQ7,E_POS,E_IMP,E_OVSKIP,
                E_TAUTO,E_TCANT,E_SUBR,E_PRPAR,E_CONFIG,E_FOPEN };





/**** Macros ****/



#ifdef DEBUG
#define RPRINT  {fprintf(stderr,"R-Position %x\n",bufpos);}
#else
#define RPRINT
#endif

#define melde(x) {if (do_melde) fprintf(stderr,x);}


#define READBUF   READ(sbuffer,sizeof(sbuffer))
#define EREADBUF {if(READBUF < 1) error(E_READ);}

#define SKIP(p)  { if (SKIPn(p)) error(E_READ);}
#define SKIPr(p) { if (SKIPn(p)) return(E_READ);}


#define TRIF(x,u,o,a,b,c) ((x)<(u)? (a) : ( (x)>(o)?(c):(b)  ))
#define xNORM(x) x=TRIF(x,0,255,0,x,255)
#define NORM(x) { if(x<0) x=0; else if (x>255) x=255;}

#ifndef MIN
#define MIN(a,b) (((a) < (b)) ? (a) : (b))
#endif








/* main.c */
extern void         close_all(void);

extern char         *ppmname,*pcdname;
extern sINT         do_info;
extern sINT         do_melde;
extern uBYTE        sbuffer[SECSIZE];
extern enum SIZES   size;
extern enum CORR    corrmode;

extern void         SEEK(int);
extern int          SKIPn(int);
extern int          READ(uBYTE *,int);
extern sINT         bufpos;




/* error.c */
extern void         eerror(enum ERRORS,char *, int);


/* color.c */
extern void	ycctorgb(implane *,implane *,implane *);

/* tools.c */
extern void         clearimpl(implane *,sINT);
extern void         halve(implane *);
extern void         interpolate(implane *);
extern sINT         Skip4Base(void);
extern void         planealloc(implane *,dim,dim);
extern void         typecheck(void);


/* format.c */
extern void         readhqt(sINT);
extern void         readhqtx(sINT);
extern void         decode(sizeinfo *,int,implane *,implane *,implane *,sINT);
extern void         decodex(FILE **,int tag,struct ic_descr *,sizeinfo *,int,implane *,sINT);
extern enum ERRORS  readplain(sizeinfo *,int,implane *,implane *,implane *);





/* Type definitions for output format drives, used in output.c and the drivers */

typedef void (OUT1PL)(FILE *,dim,dim, uBYTE *,sdim,sdim);
typedef void (OUT3PL)(FILE *,dim,dim, uBYTE *,sdim,sdim, uBYTE *,sdim,sdim, uBYTE *,sdim,sdim); 

/* output.c */
extern void         writepicture(FILE *,sizeinfo *,implane *,implane *,implane *);
extern void         druckeid(void);


/* ppm.c */
extern OUT3PL       write_ppm;

/* postscr.c */
// extern OUT3PL       write_epsrgb,write_psrgb;
// extern OUT1PL       write_epsgrey,write_psgrey,write_epsdith,write_psdith;

extern FLTPT        PAPER_LEFT,PAPER_BOTTOM,PAPER_WIDTH,PAPER_HEIGHT,PRINTER_XDPI,PRINTER_YDPI,PRINTER_FAK;
extern sINT         PSIZE_SET,DPI_SET,FAK_SET;







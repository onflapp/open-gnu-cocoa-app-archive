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


uBYTE sbuffer[SECSIZE];

enum SIZES  size     = S_UNSPEC;
enum CORR   corrmode = C_UNSPEC;

sINT do_info;
sINT do_melde;
sINT bufpos=0;

char *pcdname=0,*ppmname=0;
static FILE  *fin=0,*fout=0;

static implane Luma, Chroma1,Chroma2;
static implane *PLuma,*PChroma1,*PChroma2;
static sINT    emulate_seek=0;
static sINT    print_pos;

static char    dir64[512];
static void    get_dir64(void);

#define PrintPos(x) {if(print_pos) fprintf(stderr,"File-Offset: %8d = %8x (hex) = %d (sec)\n",(x),(x),(x)/0x800);}

static void checkin(void);
static void parseargs(int,char**);
static void sizecontrol(sizeinfo *,dim,dim);
static void f_1 (dim,dim,sINT);
static void f_4 (dim,dim,sINT);
static void f_5 (dim,dim);
static void f_6 (dim,dim);


void close_all(void)
 {
  if(fin && (fin != stdin)) fclose(fin);

  if(fout)
   {if(fout==stdout) 
      fflush(fout);
    else 
      fclose(fout);
   }
 }



int main(int argc,char **argv)
 {

  typecheck();

  do_info=0;
  do_melde=0;
  print_pos=0;

  parseargs(argc,argv);

  if(size     == S_UNSPEC) size     = S_DEFAULT;
  if(corrmode == C_UNSPEC) corrmode = C_DEFAULT;

  if(print_pos   && (size != S_Base16) && (size != S_Base4) && (size != S_Base) && (size != S_4Base) ) error(E_OPT);
  if(do_info     && (size != S_Base16) && (size != S_Base4) && (size != S_Base) && (size != S_4Base) ) error(E_OPT);


  if(strcmp(pcdname,"-"))
   { if(!(fin=fopen(pcdname,R_OP))) error(E_FOPEN);
     emulate_seek=0;
   }
  else
   {pcdname="<stdin>";
    emulate_seek=1;
    /* 64Base can't be on stdin - need a suitable error message */
    if (size == S_64Base) error(E_FOPEN);
    fin=stdin;
   }

  bufpos=0;


  checkin();

  PLuma=    &Luma;
  PChroma1= &Chroma1; 
  PChroma2= &Chroma2; 

  switch(size)
   {
    case S_Base16:  f_1(BaseW/4,BaseH/4,L_Head);
                    break;

    case S_Base4:   f_1(BaseW/2,BaseH/2,(L_Head+L_Base16));
                    break;

    case S_Base:    f_1(BaseW,BaseH,(L_Head+L_Base16+L_Base4));
                    break;

    case S_4Base:   f_4(BaseW*2,BaseH*2,(L_Head+L_Base16+L_Base4));
                    break;

    case S_16Base:  f_5(BaseW*4,BaseH*4);
                    break;

    case S_64Base:  f_6(BaseW*8,BaseH*8);
                    break;

    default: error(E_INTERN); 
   }

  close_all();
  return 0;

 }


static void openoutput(void)
{
	if(ppmname) {
		if ((fout = fopen(ppmname,W_OP)) == NULL)
			error(E_WRITE);
	} else
		fout=stdout;
}


static void f_1(dim w,dim h,sINT normal)
 {sizeinfo si;
 
  sizecontrol(&si,w,h);

  planealloc(PLuma   , w, h);
  planealloc(PChroma1, w, h);
  planealloc(PChroma2, w, h);

  PrintPos(normal*SECSIZE);
  SEEK(normal+1);
      
  error(readplain(&si,1,PLuma,PChroma1,PChroma2));
  interpolate(PChroma1);
  interpolate(PChroma2);

  si.imvlen=si.rdvlen;
  si.imhlen=si.rdhlen;
  ycctorgb(PLuma,PChroma1,PChroma2);
  /* Now Luma holds red, Chroma1 hold green, Chroma2 holds blue */

  openoutput();
  writepicture(fout,&si,PLuma,PChroma1,PChroma2);

 }



static void f_4(dim w,dim h,sINT normal)
 {sINT cd_offset;
  sizeinfo si;
  sizecontrol(&si,w,h);

  planealloc(PLuma   , w, h);
  planealloc(PChroma1, w, h);
  planealloc(PChroma2, w, h);

  PrintPos((L_Head+L_Base16+L_Base4+L_Base)*SECSIZE);

  SEEK(L_Head+L_Base16+L_Base4+1);
  error(readplain(&si,-2,PLuma,PChroma1,PChroma2));
  interpolate(PLuma);
  interpolate(PChroma1);
  interpolate(PChroma1);
  interpolate(PChroma2);
  interpolate(PChroma2);


    cd_offset = L_Head + L_Base16 + L_Base4 + L_Base ;
    SEEK(cd_offset + 4);     readhqt(1);
    SEEK(cd_offset + 5);     decode(&si,1,PLuma,nullplane,nullplane,0);

  si.imvlen=si.rdvlen;
  si.imhlen=si.rdhlen;
  ycctorgb(PLuma,PChroma1,PChroma2);
  /* Now Luma holds red, Chroma1 hold green, Chroma2 holds blue */

  openoutput();
  writepicture(fout,&si,PLuma,PChroma1,PChroma2);

 }





static void f_5sub(dim w, dim h, sizeinfo *sip,int fak1,int fak2,int fak3)
 {sINT cd_offset;
  
  sizecontrol(sip,w,h);

  planealloc(PLuma   , w, h);
  planealloc(PChroma1, w, h);
  planealloc(PChroma2, w, h);

  SEEK(L_Head+L_Base16+L_Base4+1);
  error(readplain(sip,fak1,PLuma,PChroma1,PChroma2));
  interpolate(PLuma);
  interpolate(PChroma1);
  interpolate(PChroma1);
  interpolate(PChroma2);
  interpolate(PChroma2);

  cd_offset = L_Head + L_Base16 + L_Base4 + L_Base ;
  SEEK(cd_offset + 4);       readhqt(1);
  SEEK(cd_offset + 5);       decode(sip,fak2,PLuma,nullplane,nullplane,0);
  interpolate(PLuma);


  cd_offset=bufpos;
  if(cd_offset % SECSIZE) error(E_POS);
  PrintPos(cd_offset);
  cd_offset/=SECSIZE;

  SEEK(cd_offset+12);        readhqt(3);
  SEEK(cd_offset+14);        decode(sip,fak3,PLuma,PChroma1,PChroma2,0);

 }




static void f_5(dim w,dim h)
 {sizeinfo si;

  f_5sub(w,h,&si,-4,-2,1);

  interpolate(PChroma1);
  interpolate(PChroma2);

  si.imvlen=si.rdvlen;
  si.imhlen=si.rdhlen;
  ycctorgb(PLuma,PChroma1,PChroma2);
  /* Now Luma holds red, Chroma1 hold green, Chroma2 holds blue */

  openoutput();
  writepicture(fout,&si,PLuma,PChroma1,PChroma2);

 }




static void f_6(dim w,dim h)
 {sizeinfo si;
  FILE *ic,*icr[10];
  struct ic_header ic_h;
  struct ic_descr descr[3];
  struct ic_fname names[10];
  struct ic_entry efrom,eto;
  struct file16 namecount,descrcount;
  int i,j,nc,dc;
  char   FN[300];
  int last,ffrom,fto,foff;


  f_5sub(w,h,&si,-8,-4,-2);

  interpolate(PLuma);
  interpolate(PChroma1);
  interpolate(PChroma2);

  get_dir64();

  sprintf(FN,"%s%c%s",dir64,DIRSEP,"info.ic");
  if(!(ic=fopen(FN,R_OP))) error(E_FOPEN);
  if(fread(&ic_h,sizeof(ic_h),1,ic)<1) error(E_READ);




  /******************************************************************************/
  /* layer descriptions */
  /******************************************************************************/
  if(fseek(ic,FILE32(ic_h.off_descr),0)) error(E_READ);
  
  if(fread(&descrcount,sizeof(descrcount),1,ic)<1) error(E_READ);
  dc=FILE16(descrcount);

  if(dc != 3) error(E_SEQ);

  if(fread(descr,sizeof(descr[0]),dc,ic)<dc) error(E_READ);






  /******************************************************************************/
  /* Filenames */
  /******************************************************************************/
  if(fseek(ic,FILE32(ic_h.off_fnames),0)) error(E_READ);

  if(fread(&namecount,sizeof(namecount),1,ic)<1) error(E_READ);
  nc=FILE16(namecount);

  if((nc<3) || (nc>10)) error(E_SEQ);

  if(fread(names,sizeof(names[0]),nc,ic)<nc) error(E_READ);

#ifdef SMALLNAMES
  for (i=0;i<nc;i++)
   { 
    {for (j=0;j<sizeof(names[0].fname);j++)
      {if((names[i].fname[j]>= 'A') && (names[i].fname[j]<= 'Z'))
        names[i].fname[j] += 'a'-'A';
      }
    }
#ifdef DEBUGhpc
   fprintf(stderr,"%-*.*s %d\n",sizeof(names[0].fname),sizeof(names[0].fname),names[i].fname, FILE32(names[i].size));
#endif
#endif
   }


  /******************************************************************************/
  /* Huffman-Tables */
  /******************************************************************************/
  if(fseek(ic,FILE32(ic_h.off_huffman),0)) error(E_READ);
  if(fread(sbuffer,1,sizeof(sbuffer),ic)<5) error(E_READ);

  readhqtx(3);



  /******************************************************************************/
  /* Decode it */
  /******************************************************************************/
  for(i=0;i< 3; i++)
   {
    last = si.rdvlen;

    if(!i)
     { /* luma */
       if(last>=h) last=h-1;
     }
    else
     { /* chroma */
       last=(last+1)/2;
       if(last>=h/2) last=h/2-1;
     }

    if(fseek(ic,FILE32(descr[i].off_pointers),0)) error(E_READ);
    if(fread(&efrom,sizeof(efrom),1,ic)<1) error(E_READ);

    if(fseek(ic,FILE32(descr[i].off_pointers)+ 6*4*last,0)) error(E_READ);
    if(fread(&eto  ,sizeof(eto  ),1,ic)<1) error(E_READ);

    ffrom=FILE16(efrom.fno);
    fto  =FILE16(eto.fno);
    foff =FILE32(efrom.offset);


/*    fprintf(stderr,"XXX:  %d  %d  %d\n",ffrom,fto,foff);*/

    for(j=ffrom;j<=fto;j++)
     {sprintf(FN,"%s%c%s",dir64,DIRSEP,names[j].fname);

#ifdef DEBUGhpc
    fprintf(stderr,"Filename %s\n",FN);
#endif
      if(!(icr[j-ffrom]=fopen(FN,R_OP))) error(E_FOPEN);
     }
    icr[j-ffrom]=0;

    if(fseek(icr[0],foff,0)) error(E_READ);

    switch (i)
     {case 0:  decodex(icr,0,&descr[0],&si, 1,PLuma,   1);  break;
      case 1:  decodex(icr,1,&descr[1],&si,-2,PChroma1,1);  break;
      case 2:  decodex(icr,2,&descr[2],&si,-2,PChroma2,1);  break;
     }


    for(j=ffrom;j<=fto;j++)  fclose(icr[j-ffrom]);


   }
  fclose(ic);

  interpolate(PChroma1);
  interpolate(PChroma2);

  si.imvlen=si.rdvlen;
  si.imhlen=si.rdhlen;
  ycctorgb(PLuma,PChroma1,PChroma2);
  openoutput();
  writepicture(fout,&si,PLuma,PChroma1,PChroma2);

 }




#define ASKIP { argc--; argv ++;}

static void parseargs(int  argc,char **argv)
 {
  char *opt;

  ASKIP;

  while((argc>0) && argv[0][0]=='-' && argv[0][1])
   {
    opt= (*argv)+1;
    ASKIP;

/**** additional options ****/

    if(!strcmp(opt,"i")) 
     { if (!do_info) do_info=1;
       else error(E_ARG);
       continue;
     }


    if(!strcmp(opt,"m")) 
     { if (!do_melde) do_melde=1;
       else error(E_ARG);
       continue;
     }

    if(!strcmp(opt,"pos")) 
     { if (!print_pos) print_pos=1;
       else error(E_ARG);
       continue;
     }




/**** Color model options ****/

    if(!strcmp(opt,"c0")) 
     { if (corrmode == C_UNSPEC) corrmode = C_LINEAR;
       else error(E_ARG);
       continue;
     }

    if(!strcmp(opt,"c-")) 
     { if (corrmode == C_UNSPEC) corrmode = C_DARK;
       else error(E_ARG);
       continue;
     }

    if(!strcmp(opt,"c+")) 
     { if (corrmode == C_UNSPEC) corrmode = C_BRIGHT;
       else error(E_ARG);
       continue;
     }


/**** Resolution options ****/
   
    if((!strcmp(opt,"Base/16")) || (!strcmp(opt,"1"))  || (!strcmp(opt,"128x192")))
     { if (size == S_UNSPEC) size = S_Base16;
       else error(E_ARG);
       continue;
     }
    if((!strcmp(opt,"Base/4" )) || (!strcmp(opt,"2"))  || (!strcmp(opt,"256x384")))
     { if (size == S_UNSPEC) size = S_Base4;
       else error(E_ARG);
       continue;
     }
    if((!strcmp(opt,"Base"   )) || (!strcmp(opt,"3"))  || (!strcmp(opt,"512x768")))
     { if (size == S_UNSPEC) size = S_Base;
       else error(E_ARG);
       continue;
     }
    if((!strcmp(opt,"4Base"  )) || (!strcmp(opt,"4"))  || (!strcmp(opt,"1024x1536")))
     { if (size == S_UNSPEC) size = S_4Base;
       else error(E_ARG);
       continue;
     }
    if((!strcmp(opt,"16Base" )) || (!strcmp(opt,"5"))  || (!strcmp(opt,"2048x3072")))
     { if (size == S_UNSPEC) size = S_16Base;
       else error(E_ARG);
       continue;
     }

    if((!strcmp(opt,"64Base" )) || (!strcmp(opt,"6"))  || (!strcmp(opt,"4096x6144")))
     { if (size == S_UNSPEC) size = S_64Base;
       else error(E_ARG);
/*
       if(argc<1) error(E_ARG);
       dir64=argv[0];
       ASKIP;
*/
       continue;
     }

   fprintf(stderr,"Unknown option: -%s\n",opt);
   error(E_ARG);
   }

  
  if(argc<1) error(E_ARG);
  pcdname= *argv;
  ASKIP;

  if(argc>0) 
   {ppmname= *argv;
    ASKIP;
   }
  
  if(argc>0) error(E_ARG);


 }
#undef ASKIP










static void checkin(void)
 { 
   if (do_info) 
     { SEEK(1);
       EREADBUF;
     }

    if(do_info) druckeid();

 }



/************************** file access functions **************/

int READ(uBYTE *ptr,int n)
 {int d;
  if(!n) return 1;
  bufpos+=n;
  for(; ;)
   {d=fread((char *)ptr,1,n,fin);
    if(d<1) return 0;
    n-=d;
    if (!n) break;
    ptr+=d;
   }
  return 1;
 }

static int friss(int n)
 {int d;

  while(n>0)
   {
    d= n>sizeof(sbuffer) ? sizeof(sbuffer) : n;
    n-=d;
    if(READ(sbuffer,d) !=1) return 1;
   }

  return 0;
 }


void SEEK(int x)
 {
  x *= SECSIZE;
  if(x<bufpos) error(E_INTERN);
  if(x==bufpos) return;

  if(emulate_seek)
   {if(friss(x-bufpos)) error(E_READ);
    if(x!=bufpos) error(E_INTERN);
   }
  else
   {bufpos=x;
    if (fseek(fin,x,0)) error(E_READ);
   }
#ifdef DEBUGhpc
  fprintf(stderr,"S-Position %x\n",bufpos);
#endif

 }



int SKIPn(int n)
 {
  if(!n) return 0;
  if(n<0) error(E_INTERN);
    
  if(emulate_seek)
   {return friss(n);
   }
  else
   {bufpos+=n;
    return fseek(fin,(n),1);
   }
 }





/************************** size control functions **************/


static void sizecontrol(sizeinfo *si,dim w,dim h)
{
	si->w = si->rdhlen = w;
	si->h = si->rdvlen = h;
	si->imhlen = si->imvlen = 0;
}
 


/* Thanks to James Pearson for writing get_dir64 */

/* finds dir64 from the given input filename 
   Had to change DIRSEP from a string to a character */
static void get_dir64(void)
{
	char	name[32];
	char	*n, *p, *d;
	
	d = dir64;

	/* find if input filename includes a path */
	if ((p = strrchr(pcdname,DIRSEP)) == 0)
		p = pcdname;
	else
	{
		/* copy path to start of dir64 */
		n = pcdname;
		p++;
		while (n < p)
			*d++ = *n++;
	}

	/* get first part of filename (the bit before .pcd) */
	n = name; 
	while (*p != '.' && *p != '\0')
		*n++ = *p++;

	*n = '\0';

#ifdef DEBUGhpc
	*d = '\0';
	fprintf(stderr,"Path64: %s\nName64: %s\n",dir64,name);
#endif

	/* construct path */
#ifdef SMALLNAMES
	sprintf(d,"..%cipe%c%s%c64base",DIRSEP,DIRSEP,name,DIRSEP);
#else
	sprintf(d,"..%cIPE%c%s%c64BASE",DIRSEP,DIRSEP,name,DIRSEP);
#endif
}

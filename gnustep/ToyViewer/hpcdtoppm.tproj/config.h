/* hpcdtoppm (Hadmut's pcdtoppm) v0.6
*  Copyright (c) 1992, 1993, 1994 by Hadmut Danisch (danisch@ira.uka.de).
*  Permission to use and distribute this software and its
*  documentation for noncommercial use and without fee is hereby granted,
*  provided that the above copyright notice appear in all copies and that
*  both that copyright notice and this permission notice appear in
*  supporting documentation. It is not allowed to sell this software in 
*  any way. This software is not public domain.
*/



/* define OWN_WRITE either here or by compiler-option if you don't want to use
   the pbmplus-routines for writing */
#define OWN_WRITE



/* define DEBUG for some debugging informations */
/* #define DEBUG */


/* define LONG_HELP or SHORT_HELP, if you want to have an options
   list if parameters are bad */
#define LONG_HELP


/* define DO_DECL_EXT for external declaration of system and library calls */
// #define DO_DECL_EXT


/* define FASTHUFF for faster Huffman decoding with tables.
** this makes a little speedup, but needs about 768 KByte memory
*/
#define FASTHUFF



#ifdef OWN_WRITE
/* If the own routines are used, this is the size of the buffer in bytes.
   You can shrink if needed. */
#define own_BUsize 50000

/* The header for the ppm-files */
#define PPM_Header "P6\n%d %d\n255\n"
#define PGM_Header "P5\n%d %d\n255\n"


#endif



/* fopen Parameters, for some systems (MS-DOS :-( ) you need "wb" and "rb" */
#define W_OP "w"
#define R_OP "r"


/* define SMALLNAMES if the filenames of PhotoCD have small letters on 
   your filesystem */
#define SMALLNAMES

/* The separator between directory- and filenames */
#define DIRSEP '/'





/* if you can't write to stdout in binary mode, you have to fdopen
   a FILE * in binary mode to stdout. This is important for system,
   where W_OP is something other than "w". Please define the
   Macro USE_FDOPEN in this case and check the instructions, where this
   macro is used.
*/

/* #define USE_FDOPEN */









/** Error detection **/

#define error(x) eerror(x,__FILE__,__LINE__)



/*
** Data Types
** Important: sBYTE must be a signed byte type !
** If your compiler doesn't understand "signed", remove it.
*/

#ifndef sBYTE
typedef   signed char sBYTE;
#endif

typedef unsigned char uBYTE;

/* signed and unsigned 32-bit-integers 
sINT and uINT must at least have 32 bit. If you
don't have 32-bit-integers, take 64-bit and
define the macro U_TOO_LONG !!!

uINT and sINT must be suitable to the printf/scanf-format %d
and %u and to the systemcalls as fread etc.

*/

#define uINT  unsigned int
#define sINT           int
/*
#define uLONG unsigned long
#define sLONG unsigned long
*/
/* #define U_TOO_LONG */






typedef uINT dim;
typedef sINT sdim;




/* Floating point data type and string for sscanf */
#define FLTPT double
#define SSFLTPT "%lf"







/* Default taken when no size parameter given,
** C_DEFAULT depends on your taste and video-hardware,
*/

#define S_DEFAULT S_Base16
#define O_DEFAULT O_PPM
#define C_DEFAULT C_LINEAR
#define T_DEFAULT T_AUTO


/* Background for contact sheet */
#define CONTLUM neutrLum
#define CONTCH1 neutrCh1
#define CONTCH2 neutrCh2




/* Maximum Black value of frame for cutting of the
** frame. If MAX_BLACK is n, a frame is detected, when
** all Luma values are within [ 0 .. (n-1) ]
*/
#define MAX_BLACK 1

/* Default Postscript paper size
** (German DIN A 4 )
*/
#define DEF_PAPER_LEFT    50.0
#define DEF_PAPER_BOTTOM  50.0
#define DEF_PAPER_WIDTH  500.0
#define DEF_PAPER_HEIGHT 750.0
#define DEF_DPI          300.0



/* External Declarations */
#ifdef DO_DECL_EXT

/*extern void *malloc(unsigned);*/
extern int  sscanf(char *,char *,...);    

extern int  fprintf(FILE *,char *,...);
extern int  fclose(FILE *);
extern int  fseek(FILE *,long,int);
extern int  fread(void *,int,int,FILE *);
extern int  fwrite(void *,int,int,FILE *);
extern int  fputs(char *,FILE *);
extern int  fputc(char  ,FILE *);
extern int  fflush(FILE *);

#endif








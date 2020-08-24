/* png2pao.c
 *	is based on pngtopnm(2.31) by A. Lehmann & W. van Schaik.
 *	Ver. 1.1   1997-11-23	For libpng 0.96 by Takeshi Ogihara
 *	Ver. 1.2   1997-12-21	convert to also PXO
 */

#ifndef YES
#define YES 1
#endif
#ifndef NO
#define NO 0
#endif

extern int verbose;
extern int useBackground;
extern int usePXO;
extern float displaygamma; /* display gamma */

/* function prototypes */
void print_err(char *p);
char *pickup_text(png_info *info_ptr);
int is_palette_gray(png_info *info_ptr);
char *pickup_text(png_info *info_ptr);
void print_info(png_info *info_ptr);
png_byte **alloc_png_image(png_info *info_ptr);
int check_sbit(png_info *info_ptr, png_struct *png_ptr, int useback);
void convertpng(FILE *ifp);
